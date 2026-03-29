import XCTest
@testable import CodexSwitchKit

@MainActor
final class SettingsViewTests: XCTestCase {
    func testSettingsViewExposesGroupedSectionsAndControls() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.View")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.View")

        let view = SettingsView(viewModel: SettingsViewModel(defaults: defaults))

        XCTAssertEqual(view.sectionTitles, ["General", "Privacy", "Usage", "Advanced"])
        XCTAssertEqual(
            view.generalControlLabels,
            ["Launch at Login", "Menu Bar Icon", "High Contrast", "High Contrast Bold", "Enable Menu Bar Diagnostics"]
        )
        XCTAssertEqual(
            view.menuBarIconPreviewResourceNames,
            ["StatusBarIconLightHighContrast", "StatusBarIconLightHighContrastBold"]
        )
        XCTAssertEqual(view.privacyControlLabels, [
            "Show full account emails",
            "Clear Diagnostics Log",
            "Clear Usage Cache",
            "Remove Archived Accounts",
        ])
        XCTAssertEqual(view.usageControlLabels, ["Enable Usage Refresh", "Usage Source Mode", "Automatic", "Local Only"])
        XCTAssertEqual(view.usageRiskTitle, "Usage Risk Notice")
        XCTAssertEqual(
            view.usageRiskBody,
            "Automatic mode requests usage from the ChatGPT web backend first, then falls back to local Codex session logs. Local Only skips the remote request and reads only ~/.codex/sessions/YYYY/MM/DD/ rollout logs and cache."
        )
        XCTAssertEqual(view.advancedControlLabels, [
            "Open ~/.codex",
            "Open Diagnostics Folder",
            "Export Diagnostics Summary",
        ])
    }
}
