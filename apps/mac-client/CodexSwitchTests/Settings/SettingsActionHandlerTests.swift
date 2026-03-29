import XCTest
@testable import CodexSwitchKit

final class SettingsActionHandlerTests: XCTestCase {
    func testLiveSettingsActionHandlerClearsLocalArtifactsWithoutRemovingUsageCache() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = CodexPaths(baseDirectory: baseDirectory)

        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        try "diagnostics".data(using: .utf8)!.write(to: paths.loginDiagnosticsLogURL)
        try "{}".data(using: .utf8)!.write(to: paths.usageCacheURL)
        try "{\"archive\":1}".data(using: .utf8)!.write(to: paths.accountsDirectoryURL.appendingPathComponent("a.json"))
        try "{\"archive\":2}".data(using: .utf8)!.write(to: paths.accountsDirectoryURL.appendingPathComponent("b.json"))
        try "{}".data(using: .utf8)!.write(to: paths.accountMetadataCacheURL)

        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let handler = LiveSettingsActionHandler(
            paths: paths,
            openResource: { _ in true }
        )

        _ = try handler.performDestructiveAction(.clearDiagnosticsLog)
        _ = try handler.performDestructiveAction(.removeArchivedAccounts)

        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.loginDiagnosticsLogURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.accountsDirectoryURL.appendingPathComponent("a.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.accountsDirectoryURL.appendingPathComponent("b.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.accountMetadataCacheURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.usageCacheURL.path))
    }

    func testLiveSettingsActionHandlerExportsSanitizedDiagnosticsSummaryAndOpensResources() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = CodexPaths(baseDirectory: baseDirectory)
        var openedURLs: [URL] = []

        try FileManager.default.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
        try """
        2026-03-28T11:41:22Z browser_login_started
        2026-03-28T11:45:08Z access_token=secret
        """.data(using: .utf8)!.write(to: paths.loginDiagnosticsLogURL)

        defer {
            try? FileManager.default.removeItem(at: baseDirectory)
        }

        let handler = LiveSettingsActionHandler(
            paths: paths,
            openResource: { url in
                openedURLs.append(url)
                return true
            }
        )

        _ = try handler.performUtilityAction(.openCodexDirectory)
        _ = try handler.performUtilityAction(.openDiagnosticsLog)
        let message = try handler.performUtilityAction(.exportDiagnosticsSummary)

        XCTAssertEqual(openedURLs[0], paths.baseDirectory)
        XCTAssertEqual(openedURLs[1], paths.loginDiagnosticsLogURL)
        XCTAssertEqual(message.title, "Diagnostics Exported")
        XCTAssertEqual(openedURLs.count, 3)

        let exportURL = openedURLs[2]
        let contents = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("browser_login_started"))
        XCTAssertFalse(contents.contains("access_token"))
    }
}
