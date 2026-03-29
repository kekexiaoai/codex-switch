import XCTest
@testable import CodexSwitchKit

final class StatusSnapshotLoaderTests: XCTestCase {
    func testLoaderBuildsStatusSnapshotFromOperationalSources() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let importedAt = Date(timeIntervalSince1970: 1_711_584_800)
        let activeAccount = Account(
            id: "acct-active",
            emailMask: "a••••@example.com",
            email: "active@example.com",
            tier: .team,
            archiveFilename: "active.json",
            source: .browserLogin,
            lastImportedAt: importedAt
        )
        let secondaryAccount = Account(
            id: "acct-secondary",
            emailMask: "s••••@example.com",
            email: "secondary@example.com",
            tier: .pro,
            archiveFilename: "secondary.json",
            source: .backupImport,
            lastImportedAt: importedAt.addingTimeInterval(-60)
        )
        let loader = StatusSnapshotLoader(
            snapshotService: StubMenuBarSnapshotService(
                snapshot: MenuBarSnapshot(
                    headerEmail: activeAccount.emailMask,
                    headerTier: "TEAM",
                    updatedText: "Updated just now",
                    usageSourceText: "API",
                    summaries: [
                        UsageSummaryModel(id: "5h", title: "5 Hours", percentUsed: 42, resetText: "Resets soon"),
                        UsageSummaryModel(id: "weekly", title: "Weekly", percentUsed: 17, resetText: "Resets later"),
                    ],
                    accounts: [
                        AccountRowModel(
                            id: activeAccount.id,
                            emailMask: activeAccount.emailMask,
                            tierLabel: "Team",
                            fiveHourPercent: 42,
                            weeklyPercent: 17
                        ),
                        AccountRowModel(
                            id: secondaryAccount.id,
                            emailMask: secondaryAccount.emailMask,
                            tierLabel: "Pro",
                            fiveHourPercent: 11,
                            weeklyPercent: 9
                        ),
                    ]
                )
            ),
            accountRepository: AccountRepository(catalog: StubAccountCatalog(accounts: [activeAccount, secondaryAccount])),
            activeAccountIDProvider: { activeAccount.id },
            runtimeMode: .live,
            paths: paths,
            currentHostProvider: { .statusItemPopover },
            preferredHostProvider: { .menuBarExtra },
            showFullEmailProvider: { true },
            diagnosticsReader: { [] }
        )

        let snapshot = await loader.loadSnapshot()

        XCTAssertEqual(snapshot.activeAccount?.id, activeAccount.id)
        XCTAssertEqual(snapshot.activeAccount?.displayEmail, "active@example.com")
        XCTAssertEqual(snapshot.activeAccount?.tierLabel, "Team")
        XCTAssertEqual(snapshot.activeAccount?.sourceLabel, "Browser Login")
        XCTAssertEqual(snapshot.activeAccount?.archiveFilename, "active.json")
        XCTAssertEqual(snapshot.archivedAccountCount, 2)
        XCTAssertEqual(snapshot.updatedText, "Updated just now")
        XCTAssertEqual(snapshot.usageStatusText, "API")
        XCTAssertEqual(snapshot.summaries.map(\.id), ["5h", "weekly"])
        XCTAssertEqual(snapshot.accountRows.map(\.id), [activeAccount.id, secondaryAccount.id])
        XCTAssertEqual(snapshot.runtimeModeLabel, "Live")
        XCTAssertEqual(snapshot.currentHostLabel, "NSStatusItem + NSPopover")
        XCTAssertEqual(snapshot.preferredHostLabel, "MenuBarExtra")
        XCTAssertEqual(snapshot.paths.authFilePath, paths.authFileURL.path)
        XCTAssertEqual(snapshot.paths.accountsDirectoryPath, paths.accountsDirectoryURL.path)
        XCTAssertEqual(snapshot.paths.diagnosticsDirectoryPath, paths.diagnosticsDirectoryURL.path)
        XCTAssertEqual(snapshot.paths.browserLoginLogPath, paths.browserLoginDiagnosticsLogURL.path)
        XCTAssertEqual(snapshot.paths.usageRefreshLogPath, paths.usageRefreshDiagnosticsLogURL.path)
        XCTAssertEqual(snapshot.accountInventoryStatusText, "2 archived accounts")
        XCTAssertEqual(snapshot.diagnostics.statusText, "No diagnostics yet")
    }

    func testLoaderProvidesStableEmptyStateWithoutAccountsOrUsage() async {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let loader = StatusSnapshotLoader(
            snapshotService: StubMenuBarSnapshotService(
                snapshot: MenuBarSnapshot(
                    headerEmail: "No account",
                    headerTier: "LIVE",
                    updatedText: "No usage data",
                    usageSourceText: "Unavailable",
                    summaries: [],
                    accounts: []
                )
            ),
            accountRepository: nil,
            activeAccountIDProvider: { nil },
            runtimeMode: .live,
            paths: CodexPaths(baseDirectory: tempDirectoryURL),
            currentHostProvider: { .statusItemPopover },
            preferredHostProvider: { .statusItemPopover },
            showFullEmailProvider: { false },
            diagnosticsReader: { [] }
        )

        let snapshot = await loader.loadSnapshot()

        XCTAssertNil(snapshot.activeAccount)
        XCTAssertEqual(snapshot.activeAccountStatusText, "No active account")
        XCTAssertEqual(snapshot.archivedAccountCount, 0)
        XCTAssertEqual(snapshot.accountInventoryStatusText, "No archived accounts")
        XCTAssertTrue(snapshot.summaries.isEmpty)
        XCTAssertEqual(snapshot.usageStatusText, "Unavailable")
        XCTAssertEqual(snapshot.diagnostics.statusText, "No diagnostics yet")
        XCTAssertTrue(snapshot.diagnostics.recentEvents.isEmpty)
    }
}

private struct StubMenuBarSnapshotService: MenuBarSnapshotService {
    let snapshot: MenuBarSnapshot

    func loadSnapshot(triggerUsageRefresh: Bool) async -> MenuBarSnapshot {
        snapshot
    }
}

private struct StubAccountCatalog: AccountCatalog {
    let accounts: [Account]

    func loadAccounts() async throws -> [Account] {
        accounts
    }
}
