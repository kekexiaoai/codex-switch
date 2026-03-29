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
        XCTAssertEqual(viewModel.lastActionMessage?.title, "Diagnostics Log Opened")
    }
}

private final class RecordingSettingsActionHandler: SettingsActionHandling {
    private(set) var destructiveActions: [SettingsDestructiveAction] = []
    private(set) var utilityActions: [SettingsUtilityAction] = []

    func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage {
        destructiveActions.append(action)
        switch action {
        case .clearDiagnosticsLog:
            return SettingsActionMessage(title: "Diagnostics Cleared", message: "Removed the local diagnostics log.")
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
            return SettingsActionMessage(title: "Diagnostics Log Opened", message: "Opened the local diagnostics log.")
        case .exportDiagnosticsSummary:
            return SettingsActionMessage(title: "Diagnostics Exported", message: "Exported a sanitized diagnostics summary.")
        }
    }
}
