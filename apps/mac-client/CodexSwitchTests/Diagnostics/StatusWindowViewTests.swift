import XCTest
@testable import CodexSwitchKit

final class StatusWindowViewTests: XCTestCase {
    func testWindowViewBuildsOperationalAndDiagnosticsSectionsFromSnapshot() {
        let snapshot = StatusSnapshot(
            activeAccount: StatusSnapshot.ActiveAccountSummary(
                id: "acct-active",
                displayEmail: "active@example.com",
                tierLabel: "Team",
                sourceLabel: "Browser Login",
                archiveFilename: "active.json",
                lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)
            ),
            activeAccountStatusText: "active@example.com",
            archivedAccountCount: 2,
            accountInventoryStatusText: "2 archived accounts",
            updatedText: "Updated just now",
            usageStatusText: "Local Logs",
            summaries: [
                UsageSummaryModel(id: "5h", title: "5 Hours", percentUsed: 42, resetText: "Resets soon"),
                UsageSummaryModel(id: "weekly", title: "Weekly", percentUsed: 17, resetText: "Resets later"),
            ],
            accountRows: [
                AccountRowModel(id: "acct-active", emailMask: "a••••@example.com", tierLabel: "Team", fiveHourPercent: 42, weeklyPercent: 17),
                AccountRowModel(id: "acct-backup", emailMask: "b••••@example.com", tierLabel: "Pro", fiveHourPercent: 11, weeklyPercent: 9),
            ],
            runtimeModeLabel: "Live",
            currentHostLabel: "NSStatusItem + NSPopover",
            preferredHostLabel: "MenuBarExtra",
            paths: StatusSnapshot.PathsSummary(
                authFilePath: "/tmp/auth.json",
                accountsDirectoryPath: "/tmp/accounts",
                diagnosticsDirectoryPath: "/tmp/codex-switch",
                browserLoginLogPath: "/tmp/codex-switch/browser-login.log",
                usageRefreshLogPath: "/tmp/codex-switch/usage-refresh.log"
            ),
            diagnostics: StatusSnapshot.DiagnosticsSummary(
                statusText: "Recent diagnostics activity",
                recentEvents: [
                    "2026-03-28T11:41:22Z browser_login_started",
                    "2026-03-29T13:45:09Z usage_refresh_local_succeeded mode=automatic account=acct-active source=rollout_logs",
                ]
            )
        )

        let view = StatusWindowView(snapshot: snapshot)

        XCTAssertEqual(view.sectionTitles, ["Operations", "Usage", "Accounts", "Diagnostics", "Paths"])
        XCTAssertEqual(view.activeAccountTitle, "active@example.com")
        XCTAssertEqual(view.activeAccountDetails, ["Team", "Browser Login", "active.json", "Local Logs", "Updated just now"])
        XCTAssertEqual(view.usageTitles, ["5 Hours", "Weekly"])
        XCTAssertEqual(view.accountEmails, ["a••••@example.com", "b••••@example.com"])
        XCTAssertEqual(view.diagnosticsLines, [
            "2026-03-28T11:41:22Z browser_login_started",
            "2026-03-29T13:45:09Z usage_refresh_local_succeeded mode=automatic account=acct-active source=rollout_logs",
        ])
        XCTAssertEqual(view.pathLines, ["/tmp/auth.json", "/tmp/accounts", "/tmp/codex-switch", "/tmp/codex-switch/browser-login.log", "/tmp/codex-switch/usage-refresh.log"])
    }
}
