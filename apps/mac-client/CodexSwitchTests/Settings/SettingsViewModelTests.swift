import XCTest
@testable import CodexSwitchKit

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testSettingsViewModelTogglesEmailVisibilityPreference() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings")

        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.setShowEmails(true)

        XCTAssertTrue(defaults.bool(forKey: SettingsViewModel.showEmailsKey))
    }

    func testSettingsViewModelPersistsUsageRefreshAndSourceModePreferences() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.Usage")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.Usage")

        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.setUsageRefreshEnabled(false)
        viewModel.setUsageSourceMode(.localOnly)

        XCTAssertFalse(defaults.bool(forKey: SettingsViewModel.usageRefreshEnabledKey))
        XCTAssertEqual(defaults.string(forKey: SettingsViewModel.usageSourceModeKey), CodexUsageSourceMode.localOnly.rawValue)
        XCTAssertFalse(viewModel.usageRefreshEnabled)
        XCTAssertEqual(viewModel.usageSourceMode, .localOnly)
    }

    func testSettingsViewModelPersistsLaunchAtLoginPreference() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.General")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.General")

        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.setLaunchAtLogin(true)

        XCTAssertTrue(defaults.bool(forKey: SettingsViewModel.launchAtLoginKey))
        XCTAssertTrue(viewModel.launchAtLogin)
    }
}
