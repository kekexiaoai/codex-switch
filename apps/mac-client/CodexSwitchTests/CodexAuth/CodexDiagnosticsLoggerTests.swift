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
}
