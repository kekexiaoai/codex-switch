import XCTest
@testable import CodexSwitchKit

@MainActor
final class SettingsViewTests: XCTestCase {
    func testSettingsViewExposesGroupedSectionsAndControls() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.View")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.View")

        let view = SettingsView(viewModel: SettingsViewModel(defaults: defaults))

        XCTAssertEqual(view.sectionTitles, ["General", "Privacy", "Usage", "Advanced"])
        XCTAssertEqual(view.generalControlLabels, ["Launch at Login"])
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
            "Usage refresh reads local Codex usage data. Automatic mode may trigger extra scans or refresh work; use Local Only or disable refresh in sensitive environments."
        )
        XCTAssertEqual(view.advancedControlLabels, [
            "Open ~/.codex",
            "Open Diagnostics Log",
            "Export Diagnostics Summary",
        ])
    }
}
