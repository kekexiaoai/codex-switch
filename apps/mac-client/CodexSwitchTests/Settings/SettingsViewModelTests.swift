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

    func testSettingsViewModelPersistsMenuBarIconStylePreference() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.MenuBarIcon")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.MenuBarIcon")

        let viewModel = SettingsViewModel(defaults: defaults)

        viewModel.setMenuBarIconStyle(.highContrastLight)

        XCTAssertEqual(defaults.string(forKey: SettingsViewModel.menuBarIconStyleKey), MenuBarIconStyle.highContrastLight.rawValue)
        XCTAssertEqual(viewModel.menuBarIconStyle, .highContrastLight)
    }

    func testSettingsViewModelDefaultsMenuBarDiagnosticsToDisabledAndPersistsChanges() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.MenuBarDiagnostics")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.MenuBarDiagnostics")

        let viewModel = SettingsViewModel(defaults: defaults)

        XCTAssertFalse(viewModel.menuBarDiagnosticsEnabled)

        viewModel.setMenuBarDiagnosticsEnabled(true)

        XCTAssertTrue(defaults.bool(forKey: SettingsViewModel.menuBarDiagnosticsEnabledKey))
        XCTAssertTrue(viewModel.menuBarDiagnosticsEnabled)
    }

    func testSettingsViewModelDefaultsToHighContrastMenuBarIconStyle() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.MenuBarIcon.Default")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.MenuBarIcon.Default")

        let viewModel = SettingsViewModel(defaults: defaults)

        XCTAssertEqual(viewModel.menuBarIconStyle, .highContrastLightBold)
    }

    func testSettingsViewModelMapsLegacyMenuBarIconPreferencesToNormalHighContrast() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.MenuBarIcon.Legacy")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.MenuBarIcon.Legacy")
        defaults.set("template", forKey: SettingsViewModel.menuBarIconStyleKey)

        let viewModel = SettingsViewModel(defaults: defaults)

        XCTAssertEqual(viewModel.menuBarIconStyle, .highContrastLight)
    }

    func testSettingsViewModelUsesLaunchAtLoginControllerWhenPreferenceChanges() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.LaunchController")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.LaunchController")
        let controller = RecordingLaunchAtLoginController(initialValue: false)

        let viewModel = SettingsViewModel(
            defaults: defaults,
            launchAtLoginController: controller
        )

        viewModel.setLaunchAtLogin(true)

        XCTAssertEqual(controller.values, [true])
        XCTAssertTrue(defaults.bool(forKey: SettingsViewModel.launchAtLoginKey))
        XCTAssertTrue(viewModel.launchAtLogin)
    }

    func testSettingsViewModelRestoresPreviousLaunchAtLoginValueWhenControllerFails() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.LaunchRollback")!
        defaults.set(false, forKey: SettingsViewModel.launchAtLoginKey)
        let controller = RecordingLaunchAtLoginController(
            initialValue: false,
            error: LaunchAtLoginControllerError.unsupportedOS
        )

        let viewModel = SettingsViewModel(
            defaults: defaults,
            launchAtLoginController: controller
        )

        viewModel.setLaunchAtLogin(true)

        XCTAssertEqual(controller.values, [true])
        XCTAssertFalse(defaults.bool(forKey: SettingsViewModel.launchAtLoginKey))
        XCTAssertFalse(viewModel.launchAtLogin)
        XCTAssertEqual(viewModel.lastActionMessage?.title, "Launch at Login Unchanged")
    }

    func testSettingsViewModelRequiresConfirmationBeforeDestructiveActionRuns() throws {
        let actionHandler = RecordingSettingsActionHandler()
        let viewModel = SettingsViewModel(
            defaults: UserDefaults(suiteName: "CodexSwitchTests.Settings.Actions")!,
            actionHandler: actionHandler
        )

        viewModel.requestDestructiveAction(.clearDiagnosticsLog)

        XCTAssertEqual(viewModel.pendingConfirmation?.action, .clearDiagnosticsLog)
        XCTAssertTrue(actionHandler.destructiveActions.isEmpty)

        try viewModel.confirmPendingAction()

        XCTAssertEqual(actionHandler.destructiveActions, [.clearDiagnosticsLog])
        XCTAssertNil(viewModel.pendingConfirmation)
        XCTAssertEqual(viewModel.lastActionMessage?.title, "Diagnostics Cleared")
    }

    func testSettingsViewModelRoutesAdvancedUtilityActions() throws {
        let actionHandler = RecordingSettingsActionHandler()
        let viewModel = SettingsViewModel(
            defaults: UserDefaults(suiteName: "CodexSwitchTests.Settings.Advanced")!,
            actionHandler: actionHandler
        )

        try viewModel.performUtilityAction(.openCodexDirectory)
        try viewModel.performUtilityAction(.openDiagnosticsLog)

        XCTAssertEqual(actionHandler.utilityActions, [.openCodexDirectory, .openDiagnosticsLog])
        XCTAssertEqual(viewModel.lastActionMessage?.title, "Diagnostics Folder Opened")
    }
}

private final class RecordingSettingsActionHandler: SettingsActionHandling {
    private(set) var destructiveActions: [SettingsDestructiveAction] = []
    private(set) var utilityActions: [SettingsUtilityAction] = []

    func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage {
        destructiveActions.append(action)
        switch action {
        case .clearDiagnosticsLog:
            return SettingsActionMessage(title: "Diagnostics Cleared", message: "Removed local diagnostics logs.")
        case .clearUsageCache:
            return SettingsActionMessage(title: "Usage Cache Cleared", message: "Removed cached usage data.")
        case .removeArchivedAccounts:
            return SettingsActionMessage(title: "Accounts Removed", message: "Removed archived accounts.")
        }
    }

    func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage {
        utilityActions.append(action)
        switch action {
        case .openCodexDirectory:
            return SettingsActionMessage(title: "Codex Directory Opened", message: "Opened ~/.codex.")
        case .openDiagnosticsLog:
            return SettingsActionMessage(title: "Diagnostics Folder Opened", message: "Opened the local diagnostics folder.")
        case .exportDiagnosticsSummary:
            return SettingsActionMessage(title: "Diagnostics Exported", message: "Exported a sanitized diagnostics summary.")
        }
    }
}

private final class RecordingLaunchAtLoginController: LaunchAtLoginControlling {
    private let error: LaunchAtLoginControllerError?
    private var currentValue: Bool
    private(set) var values: [Bool] = []

    init(initialValue: Bool, error: LaunchAtLoginControllerError? = nil) {
        self.currentValue = initialValue
        self.error = error
    }

    func isEnabled() -> Bool {
        currentValue
    }

    func setEnabled(_ enabled: Bool) throws {
        values.append(enabled)
        if let error {
            throw error
        }

        currentValue = enabled
    }
}
