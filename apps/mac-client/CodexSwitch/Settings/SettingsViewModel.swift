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

    public init(
        defaults: UserDefaults = .standard,
        actionHandler: any SettingsActionHandling = NoopSettingsActionHandler()
    ) {
        self.defaults = defaults
        self.actionHandler = actionHandler
        self.showEmails = defaults.bool(forKey: Self.showEmailsKey)
        if defaults.object(forKey: Self.usageRefreshEnabledKey) == nil {
            self.usageRefreshEnabled = true
        } else {
            self.usageRefreshEnabled = defaults.bool(forKey: Self.usageRefreshEnabledKey)
        }
        self.usageSourceMode = CodexUsageSourceMode(
            rawValue: defaults.string(forKey: Self.usageSourceModeKey) ?? CodexUsageSourceMode.automatic.rawValue
        ) ?? .automatic
        self.launchAtLogin = defaults.bool(forKey: Self.launchAtLoginKey)
        self.pendingConfirmation = nil
        self.lastActionMessage = nil
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
        defaults.set(enabled, forKey: Self.launchAtLoginKey)
        launchAtLogin = enabled
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
