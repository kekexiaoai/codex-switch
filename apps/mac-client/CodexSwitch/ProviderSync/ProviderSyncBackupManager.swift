import Foundation

public struct ProviderSyncBackupManager {
    private let paths: CodexPaths
    private let fileManager: FileManager
    private let retentionCount: Int

    public init(paths: CodexPaths, fileManager: FileManager = .default, retentionCount: Int = 5) {
        self.paths = paths
        self.fileManager = fileManager
        self.retentionCount = retentionCount
    }

    // MARK: - Create

    public func createBackup(
        targetProvider: String,
        configText: String?,
        sessionChanges: [SessionChange]
    ) throws -> URL {
        let timestamp = Self.timestampString()
        let backupDir = paths.providerSyncBackupsDirectoryURL.appendingPathComponent(timestamp, isDirectory: true)
        let dbDir = backupDir.appendingPathComponent("db", isDirectory: true)

        try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)

        // Backup SQLite
        let dbURL = paths.sqliteDatabaseURL
        if fileManager.fileExists(atPath: dbURL.path) {
            try fileManager.copyItem(at: dbURL, to: dbDir.appendingPathComponent("state_5.sqlite"))
            for ext in ["-shm", "-wal"] {
                let walURL = dbURL.deletingLastPathComponent().appendingPathComponent("state_5.sqlite\(ext)")
                if fileManager.fileExists(atPath: walURL.path) {
                    try fileManager.copyItem(at: walURL, to: dbDir.appendingPathComponent("state_5.sqlite\(ext)"))
                }
            }
        }

        // Backup config.toml
        if let configText {
            try Data(configText.utf8).write(to: backupDir.appendingPathComponent("config.toml"), options: .atomic)
        } else if fileManager.fileExists(atPath: paths.configFileURL.path) {
            try fileManager.copyItem(at: paths.configFileURL, to: backupDir.appendingPathComponent("config.toml"))
        }

        // Backup metadata
        let metadata: [String: Any] = [
            "version": 1,
            "namespace": "provider-sync",
            "codexHome": paths.baseDirectory.path,
            "targetProvider": targetProvider,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "changedSessionFiles": sessionChanges.count,
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try metadataData.write(to: backupDir.appendingPathComponent("metadata.json"), options: .atomic)

        // Backup session meta
        let sessionEntries: [[String: Any]] = sessionChanges.map { change in
            [
                "path": change.path.path,
                "originalFirstLine": change.originalFirstLine,
                "originalSeparator": change.originalSeparator,
            ]
        }
        let sessionBackup: [String: Any] = [
            "version": 1,
            "namespace": "provider-sync",
            "codexHome": paths.baseDirectory.path,
            "targetProvider": targetProvider,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "files": sessionEntries,
        ]
        let sessionData = try JSONSerialization.data(withJSONObject: sessionBackup, options: [.prettyPrinted, .sortedKeys])
        try sessionData.write(to: backupDir.appendingPathComponent("session-meta-backup.json"), options: .atomic)

        return backupDir
    }

    // MARK: - List

    public func listBackups() -> [BackupEntry] {
        let baseDir = paths.providerSyncBackupsDirectoryURL
        guard fileManager.fileExists(atPath: baseDir.path) else { return [] }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries: [BackupEntry] = []
        for dir in contents {
            guard let isDir = try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir else {
                continue
            }

            let metadataURL = dir.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let namespace = json["namespace"] as? String,
                  namespace == "provider-sync" else {
                continue
            }

            let targetProvider = json["targetProvider"] as? String ?? "unknown"
            let createdAt = (json["createdAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date.distantPast
            let totalSize = Self.directorySize(dir, fileManager: fileManager)

            entries.append(BackupEntry(
                id: dir.lastPathComponent,
                directoryURL: dir,
                timestamp: createdAt,
                targetProvider: targetProvider,
                totalSize: totalSize
            ))
        }

        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    public func backupSummary() -> (count: Int, totalSize: UInt64) {
        let backups = listBackups()
        let totalSize = backups.reduce(UInt64(0)) { $0 + $1.totalSize }
        return (backups.count, totalSize)
    }

    // MARK: - Restore

    public func restore(from backup: BackupEntry) throws {
        let backupDir = backup.directoryURL

        // Validate
        let metadataURL = backupDir.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let namespace = json["namespace"] as? String,
              namespace == "provider-sync" else {
            throw ProviderSyncError.restoreFailed("Invalid backup metadata")
        }

        // Restore config
        let configBackup = backupDir.appendingPathComponent("config.toml")
        if fileManager.fileExists(atPath: configBackup.path) {
            try? fileManager.removeItem(at: paths.configFileURL)
            try fileManager.copyItem(at: configBackup, to: paths.configFileURL)
        }

        // Restore database
        let dbDir = backupDir.appendingPathComponent("db", isDirectory: true)
        let dbBackup = dbDir.appendingPathComponent("state_5.sqlite")
        if fileManager.fileExists(atPath: dbBackup.path) {
            // Remove stale WAL files not in backup
            for ext in ["-shm", "-wal"] {
                let liveWAL = paths.sqliteDatabaseURL.deletingLastPathComponent().appendingPathComponent("state_5.sqlite\(ext)")
                let backupWAL = dbDir.appendingPathComponent("state_5.sqlite\(ext)")
                if fileManager.fileExists(atPath: liveWAL.path) && !fileManager.fileExists(atPath: backupWAL.path) {
                    try? fileManager.removeItem(at: liveWAL)
                }
            }

            // Copy DB files
            try? fileManager.removeItem(at: paths.sqliteDatabaseURL)
            try fileManager.copyItem(at: dbBackup, to: paths.sqliteDatabaseURL)
            for ext in ["-shm", "-wal"] {
                let backupWAL = dbDir.appendingPathComponent("state_5.sqlite\(ext)")
                let liveWAL = paths.sqliteDatabaseURL.deletingLastPathComponent().appendingPathComponent("state_5.sqlite\(ext)")
                if fileManager.fileExists(atPath: backupWAL.path) {
                    try? fileManager.removeItem(at: liveWAL)
                    try fileManager.copyItem(at: backupWAL, to: liveWAL)
                }
            }
        }

        // Restore session first lines
        let sessionBackupURL = backupDir.appendingPathComponent("session-meta-backup.json")
        if let sessionData = try? Data(contentsOf: sessionBackupURL),
           let sessionJSON = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
           let files = sessionJSON["files"] as? [[String: Any]] {
            for entry in files {
                guard let path = entry["path"] as? String,
                      let originalFirstLine = entry["originalFirstLine"] as? String,
                      let originalSeparator = entry["originalSeparator"] as? String else {
                    continue
                }

                let fileURL = URL(fileURLWithPath: path)
                guard fileManager.fileExists(atPath: fileURL.path) else { continue }

                let scanner = CodexSessionScanner(paths: paths, fileManager: fileManager)
                // We need to determine original offset to rewrite
                // Read the current first line to get its offset
                if let handle = try? FileHandle(forReadingFrom: fileURL) {
                    defer { try? handle.close() }
                    if let chunk = try? handle.read(upToCount: 8192), !chunk.isEmpty {
                        var offset: UInt64 = UInt64(chunk.count)
                        for i in chunk.indices {
                            if chunk[i] == UInt8(ascii: "\n") {
                                offset = UInt64(i - chunk.startIndex + 1)
                                break
                            }
                        }
                        let change = SessionChange(
                            path: fileURL,
                            threadID: nil,
                            directory: "",
                            originalFirstLine: "",
                            originalSeparator: originalSeparator,
                            originalOffset: offset,
                            originalSize: 0,
                            originalMtime: 0,
                            updatedFirstLine: originalFirstLine
                        )
                        try? scanner.applyChanges([change])
                    }
                }
            }
        }
    }

    // MARK: - Prune

    public func pruneBackups(keeping: Int? = nil) throws {
        let keep = keeping ?? retentionCount
        let backups = listBackups()
        guard backups.count > keep else { return }

        let toRemove = backups.dropFirst(keep)
        for backup in toRemove {
            try fileManager.removeItem(at: backup.directoryURL)
        }
    }

    // MARK: - Helpers

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmss"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    static func directorySize(_ url: URL, fileManager: FileManager) -> UInt64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: UInt64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}
