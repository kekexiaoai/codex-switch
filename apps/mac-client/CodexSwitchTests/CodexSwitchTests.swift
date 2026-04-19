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

    @MainActor
    func testProviderSyncUsesChineseLabelsWhenPreferredLanguageIsChinese() async {
        let viewModel = ProviderSyncViewModel(
            service: MockProviderSyncService(),
            preferredLanguages: ["zh-Hans"]
        )

        await viewModel.loadStatus()
        await viewModel.syncNow()

        let view = ProviderSyncView(
            viewModel: viewModel,
            preferredLanguages: ["zh-Hans"]
        )

        XCTAssertEqual(view.titleText, "Provider 同步")
        XCTAssertEqual(view.sectionTitles, ["当前状态", "会话分布", "同步", "备份"])
        XCTAssertEqual(view.lastAlertTitle, "同步完成")
        XCTAssertEqual(
            view.lastAlertMessage,
            "已同步到 'openai'：更新了 5 个文件、3 条数据库记录。"
        )
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

    func performProviderAction(_ action: SettingsProviderAction, providerId: String) throws -> SettingsActionMessage {
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
