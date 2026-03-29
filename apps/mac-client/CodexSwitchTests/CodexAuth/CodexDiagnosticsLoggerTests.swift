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
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let logger = CodexDiagnosticsFileLogger(
            paths: paths,
            now: { Date(timeIntervalSince1970: 1_743_157_872) }
        )

        logger.log("browser_open_started")
        logger.log("callback_received")

        let contents = try String(contentsOf: paths.loginDiagnosticsLogURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("2025-03-28T10:31:12Z browser_open_started"))
        XCTAssertTrue(contents.contains("2025-03-28T10:31:12Z callback_received"))
    }

    func testLogReaderReturnsRecentSafeEventsOnly() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let contents = """
        2026-03-28T11:41:22Z browser_login_started
        2026-03-28T11:41:22Z token_exchange_succeeded
        2026-03-28T11:41:22Z access_token=secret-should-not-appear
        2026-03-28T11:41:22Z callback_received code=true error=false
        2026-03-28T11:41:22Z refresh_token=another-secret
        """
        try contents.write(to: paths.loginDiagnosticsLogURL, atomically: true, encoding: .utf8)

        let events = CodexDiagnosticsLogReader(paths: paths).recentSafeEvents(limit: 2)

        XCTAssertEqual(events, [
            "2026-03-28T11:41:22Z token_exchange_succeeded",
            "2026-03-28T11:41:22Z callback_received code=true error=false",
        ])
    }
}
