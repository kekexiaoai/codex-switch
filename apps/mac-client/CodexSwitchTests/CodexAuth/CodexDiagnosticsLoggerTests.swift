import XCTest
@testable import CodexSwitchKit

final class CodexDiagnosticsLoggerTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
    }

    func testFileLoggerAppendsTimestampedEntriesToCodexLogFile() throws {
        let originalTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: 8 * 3600)!
        defer { NSTimeZone.default = originalTimeZone }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let logger = CodexDiagnosticsFileLogger(
            paths: paths,
            category: .browserLogin,
            now: { Date(timeIntervalSince1970: 1_743_157_872) }
        )

        logger.log("browser_open_started")
        logger.log("callback_received")

        let contents = try String(contentsOf: paths.browserLoginDiagnosticsLogURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("2025-03-28T18:31:12+08:00 browser_open_started"))
        XCTAssertTrue(contents.contains("2025-03-28T18:31:12+08:00 callback_received"))
    }

    func testLogReaderReturnsRecentSafeEventsAcrossSeparatedLogFiles() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let browserContents = """
        2026-03-28T11:41:22Z browser_login_started
        2026-03-28T11:41:22Z token_exchange_succeeded
        """
        let usageContents = """
        2026-03-29T13:41:22Z usage_refresh_started mode=automatic account=acct-1
        2026-03-29T13:41:23Z access_token=secret-should-not-appear
        2026-03-29T13:41:24Z usage_refresh_local_succeeded mode=automatic account=acct-1 source=rollout_logs
        """
        try FileManager.default.createDirectory(at: paths.diagnosticsDirectoryURL, withIntermediateDirectories: true)
        try browserContents.write(to: paths.browserLoginDiagnosticsLogURL, atomically: true, encoding: .utf8)
        try usageContents.write(to: paths.usageRefreshDiagnosticsLogURL, atomically: true, encoding: .utf8)

        let events = CodexDiagnosticsLogReader(paths: paths).recentSafeEvents(limit: 3)

        XCTAssertEqual(events, [
            "2026-03-28T11:41:22Z token_exchange_succeeded",
            "2026-03-29T13:41:22Z usage_refresh_started mode=automatic account=acct-1",
            "2026-03-29T13:41:24Z usage_refresh_local_succeeded mode=automatic account=acct-1 source=rollout_logs",
        ])
    }
}
