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
    private let preferredLanguages: [String]?

    public init(service: any ProviderSyncServiceProtocol, preferredLanguages: [String]? = nil) {
        self.service = service
        self.preferredLanguages = preferredLanguages
    }

    public var canPruneOldBackups: Bool {
        backups.count > 1 && !isSyncing
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
                title: ProviderSyncStrings.text(.loadFailedTitle, preferredLanguages: preferredLanguages),
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
                title: ProviderSyncStrings.text(.syncCompleteTitle, preferredLanguages: preferredLanguages),
                message: ProviderSyncStrings.syncCompleteMessage(
                    targetProvider: result.targetProvider,
                    filesChanged: result.filesChanged,
                    rowsChanged: result.rowsChanged,
                    preferredLanguages: preferredLanguages
                )
            )
            await loadStatus()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: ProviderSyncStrings.text(.syncFailedTitle, preferredLanguages: preferredLanguages),
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
                title: ProviderSyncStrings.text(.switchCompleteTitle, preferredLanguages: preferredLanguages),
                message: ProviderSyncStrings.switchCompleteMessage(
                    targetProvider: result.targetProvider,
                    filesChanged: result.filesChanged,
                    rowsChanged: result.rowsChanged,
                    preferredLanguages: preferredLanguages
                )
            )
            await loadStatus()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: ProviderSyncStrings.text(.switchFailedTitle, preferredLanguages: preferredLanguages),
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
                title: ProviderSyncStrings.text(.restoreCompleteTitle, preferredLanguages: preferredLanguages),
                message: ProviderSyncStrings.restoreCompleteMessage(backup.id, preferredLanguages: preferredLanguages)
            )
            self.selectedBackupID = nil
            await loadStatus()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: ProviderSyncStrings.text(.restoreFailedTitle, preferredLanguages: preferredLanguages),
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    public func pruneOldBackups() async {
        do {
            try service.pruneBackups()
            lastMessage = ProviderSyncMessage(
                title: ProviderSyncStrings.text(.pruneCompleteTitle, preferredLanguages: preferredLanguages),
                message: ProviderSyncStrings.pruneCompleteMessage(preferredLanguages: preferredLanguages)
            )
            backups = service.listBackups()
        } catch {
            lastMessage = ProviderSyncMessage(
                title: ProviderSyncStrings.text(.pruneFailedTitle, preferredLanguages: preferredLanguages),
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    public func dismissMessage() {
        lastMessage = nil
    }
}
