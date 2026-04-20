import XCTest
@testable import CodexSwitchKit

@MainActor
final class ProviderSyncViewTests: XCTestCase {
    func testProviderSyncViewUsesFlexibleFrameWhenEmbeddedInMainWindow() {
        let view = ProviderSyncView(
            viewModel: ProviderSyncViewModel(service: MockProviderSyncService()),
            layoutMode: .embeddedMainWindow
        )

        XCTAssertNil(view.fixedFrameSize)
    }

    func testViewModelAllowsPruningWhenMultipleBackupsExist() async {
        let service = StubProviderSyncService(backups: [
            BackupEntry(id: "backup-1", directoryURL: URL(fileURLWithPath: "/tmp/backup-1"), timestamp: .distantPast, targetProvider: "openai", totalSize: 100),
            BackupEntry(id: "backup-2", directoryURL: URL(fileURLWithPath: "/tmp/backup-2"), timestamp: .now, targetProvider: "openai", totalSize: 200),
        ])
        let viewModel = ProviderSyncViewModel(service: service)

        await viewModel.loadStatus()

        XCTAssertTrue(viewModel.canPruneOldBackups)
    }

    func testPruneOldBackupsRefreshesBackupListAndShowsCompletionMessage() async {
        let service = StubProviderSyncService(backups: [
            BackupEntry(id: "backup-1", directoryURL: URL(fileURLWithPath: "/tmp/backup-1"), timestamp: Date(timeIntervalSince1970: 1), targetProvider: "openai", totalSize: 100),
            BackupEntry(id: "backup-2", directoryURL: URL(fileURLWithPath: "/tmp/backup-2"), timestamp: Date(timeIntervalSince1970: 2), targetProvider: "openai", totalSize: 200),
        ])
        let viewModel = ProviderSyncViewModel(service: service)

        await viewModel.loadStatus()
        await viewModel.pruneOldBackups()

        XCTAssertEqual(service.pruneCallCount, 1)
        XCTAssertEqual(viewModel.backups.map(\.id), ["backup-2"])
        XCTAssertEqual(viewModel.lastMessage?.isError, false)
    }

    func testLiveServiceManualPruneKeepsNewestBackupOnly() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let paths = CodexPaths(baseDirectory: baseDirectory)
        let backupRoot = paths.providerSyncBackupsDirectoryURL
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        try makeBackupDirectory(at: backupRoot.appendingPathComponent("backup-old", isDirectory: true), createdAt: "2026-04-01T08:00:00Z")
        try makeBackupDirectory(at: backupRoot.appendingPathComponent("backup-new", isDirectory: true), createdAt: "2026-04-02T08:00:00Z")

        let service = LiveProviderSyncService(paths: paths)

        try service.pruneBackups()

        let remainingDirectories = try FileManager.default.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent).sorted()

        XCTAssertEqual(remainingDirectories, ["backup-new"])
    }

    private func makeBackupDirectory(at directoryURL: URL, createdAt: String) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let metadata: [String: Any] = [
            "version": 1,
            "namespace": "provider-sync",
            "codexHome": "/tmp/.codex",
            "targetProvider": "openai",
            "createdAt": createdAt,
            "changedSessionFiles": 1,
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directoryURL.appendingPathComponent("metadata.json"), options: .atomic)
    }
}

@MainActor
private final class StubProviderSyncService: ProviderSyncServiceProtocol {
    private var backupEntries: [BackupEntry]
    private(set) var pruneCallCount = 0

    init(backups: [BackupEntry]) {
        self.backupEntries = backups.sorted { $0.timestamp > $1.timestamp }
    }

    func loadStatus() async throws -> ProviderSyncStatus {
        ProviderSyncStatus(
            currentProvider: "openai",
            configuredProviders: ["openai"],
            rolloutDistribution: [],
            sqliteDistribution: [],
            backupCount: backupEntries.count,
            backupTotalSize: backupEntries.reduce(0) { $0 + $1.totalSize }
        )
    }

    func sync(targetProvider: String?) async throws -> SyncResult {
        SyncResult(targetProvider: targetProvider ?? "openai", filesChanged: 0, rowsChanged: 0)
    }

    func switchProvider(_ provider: String) async throws -> SyncResult {
        SyncResult(targetProvider: provider, filesChanged: 0, rowsChanged: 0)
    }

    func listBackups() -> [BackupEntry] {
        backupEntries
    }

    func restore(from backup: BackupEntry) async throws {}

    func pruneBackups() throws {
        pruneCallCount += 1
        guard backupEntries.count > 1 else {
            return
        }
        backupEntries = [backupEntries[0]]
    }
}
