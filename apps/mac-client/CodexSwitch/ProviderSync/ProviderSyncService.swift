import Foundation

public protocol ProviderSyncServiceProtocol {
    func loadStatus() async throws -> ProviderSyncStatus
    func sync(targetProvider: String?) async throws -> SyncResult
    func switchProvider(_ provider: String) async throws -> SyncResult
    func listBackups() -> [BackupEntry]
    func restore(from backup: BackupEntry) async throws
    func pruneBackups() throws
}

public struct LiveProviderSyncService: ProviderSyncServiceProtocol {
    private let paths: CodexPaths
    private let configParser: CodexConfigParser
    private let sessionScanner: CodexSessionScanner
    private let sqliteStore: CodexProviderSQLite
    private let backupManager: ProviderSyncBackupManager
    private let fileManager: FileManager

    public init(paths: CodexPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        self.configParser = CodexConfigParser(paths: paths, fileManager: fileManager)
        self.sessionScanner = CodexSessionScanner(paths: paths, fileManager: fileManager)
        self.sqliteStore = CodexProviderSQLite(paths: paths, fileManager: fileManager)
        self.backupManager = ProviderSyncBackupManager(paths: paths, fileManager: fileManager)
    }

    // MARK: - Status

    public func loadStatus() async throws -> ProviderSyncStatus {
        let currentProvider = (try? configParser.currentProvider()) ?? CodexConfigParser.defaultProvider
        let configuredProviders = (try? configParser.configuredProviders()) ?? [CodexConfigParser.defaultProvider]
        let rolloutDistribution = sessionScanner.scanProviderDistribution()
        let sqliteDistribution = (try? sqliteStore.providerCounts()) ?? []
        let backupSummary = backupManager.backupSummary()

        return ProviderSyncStatus(
            currentProvider: currentProvider,
            configuredProviders: configuredProviders,
            rolloutDistribution: rolloutDistribution,
            sqliteDistribution: sqliteDistribution,
            backupCount: backupSummary.count,
            backupTotalSize: backupSummary.totalSize
        )
    }

    // MARK: - Sync

    public func sync(targetProvider: String?) async throws -> SyncResult {
        let target = targetProvider ?? (try? configParser.currentProvider()) ?? CodexConfigParser.defaultProvider

        try acquireLock()
        defer { releaseLock() }

        let changes = sessionScanner.collectChanges(targetProvider: target)

        if sqliteStore.databaseExists {
            try sqliteStore.assertWritable()
        }

        // Create backup
        let configText = try? configParser.readConfigText()
        _ = try backupManager.createBackup(
            targetProvider: target,
            configText: configText,
            sessionChanges: changes
        )

        // Apply session changes
        do {
            try sessionScanner.applyChanges(changes)
        } catch {
            sessionScanner.rollbackChanges(changes)
            throw ProviderSyncError.syncFailed("Session file rewrite failed: \(error.localizedDescription)")
        }

        // Update SQLite
        let rowsChanged: Int
        if sqliteStore.databaseExists {
            do {
                rowsChanged = try sqliteStore.updateProvider(target)
            } catch {
                sessionScanner.rollbackChanges(changes)
                throw ProviderSyncError.syncFailed("SQLite update failed: \(error.localizedDescription)")
            }
        } else {
            rowsChanged = 0
        }

        // Auto-prune backups
        try? backupManager.pruneBackups()

        return SyncResult(
            targetProvider: target,
            filesChanged: changes.count,
            rowsChanged: rowsChanged
        )
    }

    // MARK: - Switch

    public func switchProvider(_ provider: String) async throws -> SyncResult {
        let configuredProviders = (try? configParser.configuredProviders()) ?? [CodexConfigParser.defaultProvider]
        guard configuredProviders.contains(provider) || provider == CodexConfigParser.defaultProvider else {
            throw ProviderSyncError.providerNotConfigured(provider, available: configuredProviders)
        }

        let originalConfigText = try? configParser.readConfigText()

        do {
            try configParser.setProvider(provider)
        } catch {
            throw ProviderSyncError.syncFailed("Failed to update config.toml: \(error.localizedDescription)")
        }

        do {
            var result = try await sync(targetProvider: provider)
            result = SyncResult(
                targetProvider: result.targetProvider,
                filesChanged: result.filesChanged,
                rowsChanged: result.rowsChanged,
                configUpdated: true
            )
            return result
        } catch {
            // Rollback config
            if let originalConfigText {
                try? Data(originalConfigText.utf8).write(to: paths.configFileURL, options: .atomic)
            }
            throw error
        }
    }

    // MARK: - Backups

    public func listBackups() -> [BackupEntry] {
        backupManager.listBackups()
    }

    public func restore(from backup: BackupEntry) async throws {
        try acquireLock()
        defer { releaseLock() }
        try backupManager.restore(from: backup)
    }

    public func pruneBackups() throws {
        try backupManager.pruneBackups()
    }

    // MARK: - Lock

    private func acquireLock() throws {
        let lockDir = paths.providerSyncLockFileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: lockDir, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: paths.providerSyncLockFileURL.path) {
            fileManager.createFile(atPath: paths.providerSyncLockFileURL.path, contents: nil)
        }

        guard let handle = FileHandle(forWritingAtPath: paths.providerSyncLockFileURL.path) else {
            throw ProviderSyncError.lockAcquisitionFailed
        }

        let fd = handle.fileDescriptor
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            try? handle.close()
            throw ProviderSyncError.lockAcquisitionFailed
        }

        // Keep handle open — lock is held until close
        lockHandle = handle
    }

    private func releaseLock() {
        if let handle = lockHandle {
            let fd = handle.fileDescriptor
            flock(fd, LOCK_UN)
            try? handle.close()
        }
        lockHandle = nil
    }

    // Lock handle storage — using a static thread-local to avoid mutating self
    private static var _lockHandleKey = "ProviderSyncService.lockHandle"
    private var lockHandle: FileHandle? {
        get { Thread.current.threadDictionary[Self._lockHandleKey] as? FileHandle }
        nonmutating set { Thread.current.threadDictionary[Self._lockHandleKey] = newValue }
    }
}

public struct MockProviderSyncService: ProviderSyncServiceProtocol {
    public init() {}

    public func loadStatus() async throws -> ProviderSyncStatus {
        ProviderSyncStatus(
            currentProvider: "openai",
            configuredProviders: ["openai", "apigather"],
            rolloutDistribution: [
                ProviderDistribution(provider: "openai", sessionCount: 42, archivedCount: 8),
                ProviderDistribution(provider: "apigather", sessionCount: 3, archivedCount: 0),
            ],
            sqliteDistribution: [
                ProviderDistribution(provider: "openai", sessionCount: 45, archivedCount: 8),
                ProviderDistribution(provider: "(missing)", sessionCount: 2, archivedCount: 1),
            ],
            backupCount: 3,
            backupTotalSize: 1_200_000
        )
    }

    public func sync(targetProvider: String?) async throws -> SyncResult {
        SyncResult(targetProvider: targetProvider ?? "openai", filesChanged: 5, rowsChanged: 3)
    }

    public func switchProvider(_ provider: String) async throws -> SyncResult {
        SyncResult(targetProvider: provider, filesChanged: 5, rowsChanged: 3, configUpdated: true)
    }

    public func listBackups() -> [BackupEntry] {
        [
            BackupEntry(id: "2026-04-01T143000", directoryURL: URL(fileURLWithPath: "/tmp"), timestamp: Date(), targetProvider: "openai", totalSize: 500_000),
            BackupEntry(id: "2026-03-30T091500", directoryURL: URL(fileURLWithPath: "/tmp"), timestamp: Date().addingTimeInterval(-86400 * 2), targetProvider: "apigather", totalSize: 700_000),
        ]
    }

    public func restore(from backup: BackupEntry) async throws {}
    public func pruneBackups() throws {}
}
