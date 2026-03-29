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
}
