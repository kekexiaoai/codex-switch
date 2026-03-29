import XCTest

final class XcodeProjectSyncTests: XCTestCase {
    func testXcodeProjectIncludesCodexAuthBackendSources() throws {
        let projectContents = try String(contentsOf: xcodeProjectFileURL(), encoding: .utf8)
        let requiredFilenames = [
            "BackupAuthPicker.swift",
            "CodexArchiveNaming.swift",
            "CodexArchivedAccountStore.swift",
            "CodexAuthFileStore.swift",
            "CodexAuthImporter.swift",
            "CodexAuthModels.swift",
            "CodexDiagnosticsLogger.swift",
            "CodexJWTDecoder.swift",
            "CodexLoginCoordinator.swift",
            "CodexPaths.swift",
            "CodexUsageScanner.swift",
            "DesktopCodexLoginBroker.swift",
            "CodexAccountSwitcher.swift",
            "SettingsActions.swift",
            "LiveSettingsActionHandler.swift",
        ]

        let missingFilenames = requiredFilenames.filter { !projectContents.contains($0) }

        XCTAssertEqual(
            missingFilenames,
            [],
            "Xcode project is missing source file references: \(missingFilenames.joined(separator: ", "))"
        )
    }

    private func xcodeProjectFileURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CodexSwitch.xcodeproj")
            .appendingPathComponent("project.pbxproj")
    }
}
