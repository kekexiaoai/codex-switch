import XCTest
@testable import CodexSwitchKit

final class CodexSwitchTests: XCTestCase {
    func testAppEnvironmentStartsWithMockServices() {
        let environment = AppEnvironment.preview

        XCTAssertNotNil(environment.accountStore)
        XCTAssertNotNil(environment.usageService)
    }

    func testAppEnvironmentUsesReferenceSemanticsForStartupContainer() {
        let environment = AppEnvironment.preview
        let object = environment as AnyObject

        XCTAssertTrue(object === (environment as AnyObject))
    }

    func testMenuBarHostDefaultsToSupportedHost() {
        let host = MenuBarHostKind.current

        XCTAssertTrue(host == .statusItemPopover || host == .menuBarExtra)
    }

    @MainActor
    func testAppEnvironmentCreatesSettingsViewModelWithConfiguredActionHandler() throws {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Environment.Settings")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Environment.Settings")
        let handler = RecordingSettingsEnvironmentActionHandler()
        let launchController = RecordingEnvironmentLaunchAtLoginController()
        let environment = AppEnvironment(
            accountStore: MockAccountStore(),
            usageService: MockUsageService(),
            settingsDefaults: defaults,
            settingsActionHandler: handler,
            launchAtLoginController: launchController,
            runtimeMode: .preview,
            codexPaths: nil
        )

        let viewModel = environment.makeSettingsViewModel()
        viewModel.requestDestructiveAction(.clearDiagnosticsLog)
        try viewModel.confirmPendingAction()
        viewModel.setLaunchAtLogin(true)

        XCTAssertEqual(handler.destructiveActions, [.clearDiagnosticsLog])
        XCTAssertEqual(launchController.values, [true])
    }
}

private final class RecordingSettingsEnvironmentActionHandler: SettingsActionHandling {
    private(set) var destructiveActions: [SettingsDestructiveAction] = []

    func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage {
        destructiveActions.append(action)
        return SettingsActionMessage(title: "Done", message: "Done")
    }

    func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage {
        SettingsActionMessage(title: "Done", message: "Done")
    }
}

private final class RecordingEnvironmentLaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var values: [Bool] = []

    func isEnabled() -> Bool {
        false
    }

    func setEnabled(_ enabled: Bool) throws {
        values.append(enabled)
    }
}
