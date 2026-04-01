import Foundation

@MainActor
public final class ProviderSyncViewModel: ObservableObject {
    @Published public private(set) var currentProvider: String = ""
    @Published public private(set) var configuredProviders: [String] = []
    @Published public private(set) var rolloutDistribution: [ProviderDistribution] = []
    @Published public private(set) var sqliteDistribution: [ProviderDistribution] = []
    @Published public private(set) var backups: [BackupEntry] = []
    @Published public private(set) var backupTotalSize: UInt64 = 0
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastMessage: ProviderSyncMessage?
    @Published public var selectedSyncTarget: String = ""
    @Published public var selectedSwitchTarget: String = ""
    @Published public private(set) var selectedBackupID: String?

    private let service: any ProviderSyncServiceProtocol

    public init(service: any ProviderSyncServiceProtocol) {
        self.service = service
    }

    // MARK: - Load

    public func loadStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let status = try await service.loadStatus()
            currentProvider = status.currentProvider
            configuredProviders = status.configuredProviders
            rolloutDistribution = status.rolloutDistribution
            sqliteDistribution = status.sqliteDistribution
            backupTotalSize = status.backupTotalSize

            if selectedSyncTarget.isEmpty {
                selectedSyncTarget = status.currentProvider
            }
            if selectedSwitchTarget.isEmpty {
                selectedSwitchTarget = status.configuredProviders.first(where: { $0 != status.currentProvider }) ?? status.currentProvider
            }

            backups = service.listBackups()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: "Load Failed",
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    // MARK: - Sync

    public func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let result = try await service.sync(targetProvider: selectedSyncTarget)
            lastMessage = ProviderSyncMessage(
                title: "Sync Complete",
                message: "Synced to '\(result.targetProvider)': \(result.filesChanged) files, \(result.rowsChanged) database rows updated."
            )
            await loadStatus()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: "Sync Failed",
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    // MARK: - Switch

    public func switchAndSync() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let result = try await service.switchProvider(selectedSwitchTarget)
            lastMessage = ProviderSyncMessage(
                title: "Switch Complete",
                message: "Switched to '\(result.targetProvider)': \(result.filesChanged) files, \(result.rowsChanged) database rows updated."
            )
            await loadStatus()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: "Switch Failed",
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    // MARK: - Backups

    public func selectBackup(id: String?) {
        selectedBackupID = id
    }

    public func restoreSelectedBackup() async {
        guard let selectedBackupID,
              let backup = backups.first(where: { $0.id == selectedBackupID }) else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await service.restore(from: backup)
            lastMessage = ProviderSyncMessage(
                title: "Restore Complete",
                message: "Restored from backup '\(backup.id)'."
            )
            self.selectedBackupID = nil
            await loadStatus()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: "Restore Failed",
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    public func pruneOldBackups() async {
        do {
            try service.pruneBackups()
            lastMessage = ProviderSyncMessage(
                title: "Prune Complete",
                message: "Old backups removed."
            )
            backups = service.listBackups()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: "Prune Failed",
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    public func dismissMessage() {
        lastMessage = nil
    }
}
