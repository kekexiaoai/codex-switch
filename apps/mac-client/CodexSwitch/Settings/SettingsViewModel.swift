import Foundation

public enum CodexUsageSourceMode: String, Codable, Equatable, CaseIterable {
    case automatic
    case localOnly
}

public protocol EmailVisibilityProviding {
    func showEmails() -> Bool
}

public protocol EmailVisibilityMutating: EmailVisibilityProviding {
    func setShowEmails(_ enabled: Bool)
}

public struct UserDefaultsEmailVisibilityStore: EmailVisibilityProviding {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func showEmails() -> Bool {
        defaults.bool(forKey: SettingsViewModel.showEmailsKey)
    }
}

extension UserDefaultsEmailVisibilityStore: EmailVisibilityMutating {
    public func setShowEmails(_ enabled: Bool) {
        defaults.set(enabled, forKey: SettingsViewModel.showEmailsKey)
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    public static let showEmailsKey = "showEmails"
    public static let usageRefreshEnabledKey = "usageRefreshEnabled"
    public static let usageSourceModeKey = "usageSourceMode"
    public static let launchAtLoginKey = "launchAtLogin"

    @Published public private(set) var showEmails: Bool
    @Published public private(set) var usageRefreshEnabled: Bool
    @Published public private(set) var usageSourceMode: CodexUsageSourceMode
    @Published public private(set) var launchAtLogin: Bool
    @Published public private(set) var pendingConfirmation: SettingsConfirmationRequest?
    @Published public private(set) var lastActionMessage: SettingsActionMessage?

    private let defaults: UserDefaults
    private let actionHandler: any SettingsActionHandling
    private let launchAtLoginController: (any LaunchAtLoginControlling)?

    public init(
        defaults: UserDefaults = .standard,
        actionHandler: any SettingsActionHandling = NoopSettingsActionHandler(),
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil
    ) {
        self.defaults = defaults
        self.actionHandler = actionHandler
        self.launchAtLoginController = launchAtLoginController
        self.showEmails = defaults.bool(forKey: Self.showEmailsKey)
        if defaults.object(forKey: Self.usageRefreshEnabledKey) == nil {
            self.usageRefreshEnabled = true
        } else {
            self.usageRefreshEnabled = defaults.bool(forKey: Self.usageRefreshEnabledKey)
        }
        self.usageSourceMode = CodexUsageSourceMode(
            rawValue: defaults.string(forKey: Self.usageSourceModeKey) ?? CodexUsageSourceMode.automatic.rawValue
        ) ?? .automatic
        let storedLaunchAtLogin = defaults.bool(forKey: Self.launchAtLoginKey)
        let resolvedLaunchAtLogin = launchAtLoginController?.isEnabled() ?? storedLaunchAtLogin
        self.launchAtLogin = resolvedLaunchAtLogin
        self.pendingConfirmation = nil
        self.lastActionMessage = nil

        if storedLaunchAtLogin != resolvedLaunchAtLogin {
            defaults.set(resolvedLaunchAtLogin, forKey: Self.launchAtLoginKey)
        }
    }

    public func setShowEmails(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.showEmailsKey)
        showEmails = enabled
    }

    public func setUsageRefreshEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.usageRefreshEnabledKey)
        usageRefreshEnabled = enabled
    }

    public func setUsageSourceMode(_ mode: CodexUsageSourceMode) {
        defaults.set(mode.rawValue, forKey: Self.usageSourceModeKey)
        usageSourceMode = mode
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        let previousValue = launchAtLogin

        if let launchAtLoginController {
            do {
                try launchAtLoginController.setEnabled(enabled)
            } catch {
                defaults.set(previousValue, forKey: Self.launchAtLoginKey)
                launchAtLogin = previousValue
                lastActionMessage = SettingsActionMessage(
                    title: "Launch at Login Unchanged",
                    message: error.localizedDescription
                )
                return
            }
        }

        defaults.set(enabled, forKey: Self.launchAtLoginKey)
        launchAtLogin = enabled
        lastActionMessage = nil
    }

    public func requestDestructiveAction(_ action: SettingsDestructiveAction) {
        pendingConfirmation = SettingsConfirmationRequest(action: action)
    }

    public func confirmPendingAction() throws {
        guard let confirmation = pendingConfirmation else {
            return
        }

        lastActionMessage = try actionHandler.performDestructiveAction(confirmation.action)
        pendingConfirmation = nil
    }

    public func cancelPendingAction() {
        pendingConfirmation = nil
    }

    public func performUtilityAction(_ action: SettingsUtilityAction) throws {
        lastActionMessage = try actionHandler.performUtilityAction(action)
    }
}
