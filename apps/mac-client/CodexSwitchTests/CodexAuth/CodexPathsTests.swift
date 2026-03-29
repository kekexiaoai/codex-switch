import XCTest
@testable import CodexSwitchKit

final class CodexPathsTests: XCTestCase {
    func testDefaultPathsResolveWithinCodexDirectory() {
        let homeURL = URL(fileURLWithPath: "/tmp/codex-home", isDirectory: true)
        let paths = CodexPaths(baseDirectory: homeURL.appendingPathComponent(".codex", isDirectory: true))

        XCTAssertEqual(paths.authFileURL.path, "/tmp/codex-home/.codex/auth.json")
        XCTAssertEqual(paths.accountsDirectoryURL.path, "/tmp/codex-home/.codex/accounts")
        XCTAssertEqual(paths.accountMetadataCacheURL.path, "/tmp/codex-home/.codex/accounts/metadata.json")
        XCTAssertEqual(paths.usageCacheURL.path, "/tmp/codex-home/.codex/accounts/usage-cache.json")
        XCTAssertEqual(paths.sessionsDirectoryURL.path, "/tmp/codex-home/.codex/sessions")
        XCTAssertEqual(paths.diagnosticsDirectoryURL.path, "/tmp/codex-home/.codex/codex-switch")
        XCTAssertEqual(paths.browserLoginDiagnosticsLogURL.path, "/tmp/codex-home/.codex/codex-switch/browser-login.log")
        XCTAssertEqual(paths.usageRefreshDiagnosticsLogURL.path, "/tmp/codex-home/.codex/codex-switch/usage-refresh.log")
    }

    func testAccountStoresArchiveMetadataNeededByCodexBackend() {
        let importedAt = Date(timeIntervalSince1970: 1_711_584_800)
        let account = Account(
            id: "subject-123",
            emailMask: "a••••@example.com",
            email: "alex@example.com",
            tier: .team,
            archiveFilename: "YWxleEBleGFtcGxlLmNvbQ.json",
            source: .browserLogin,
            lastImportedAt: importedAt
        )

        XCTAssertEqual(account.archiveFilename, "YWxleEBleGFtcGxlLmNvbQ.json")
        XCTAssertEqual(account.source, .browserLogin)
        XCTAssertEqual(account.lastImportedAt, importedAt)
    }
}
