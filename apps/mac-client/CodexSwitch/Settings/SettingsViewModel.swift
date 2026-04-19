import Foundation

public enum CodexUsageSourceMode: String, Codable, Equatable, CaseIterable {
    case automatic
    case localOnly
}

public enum MenuBarIconStyle: String, Codable, Equatable, CaseIterable {
    case highContrastLight
    case highContrastLightBold

    public static var allCases: [MenuBarIconStyle] {
        [.highContrastLight, .highContrastLightBold]
    }

    public static func resolved(from rawValue: String?) -> MenuBarIconStyle {
        switch rawValue {
        case MenuBarIconStyle.highContrastLight.rawValue:
            return .highContrastLight
        case MenuBarIconStyle.highContrastLightBold.rawValue, nil:
            return .highContrastLightBold
        case "template", "lightBackground":
            return .highContrastLight
        default:
            return .highContrastLightBold
        }
    }
}

public protocol EmailVisibilityProviding {
    func showEmails() -> Bool
}

public protocol UsageSettingsProviding {
    func usageRefreshEnabled() -> Bool
    func usageSourceMode() -> CodexUsageSourceMode
}

public protocol MenuBarIconStyleProviding {
    func menuBarIconStyle() -> MenuBarIconStyle
}

public protocol EmailVisibilityMutating: EmailVisibilityProviding {
    func setShowEmails(_ enabled: Bool)
}

public protocol MenuBarIconStyleMutating: MenuBarIconStyleProviding {
    func setMenuBarIconStyle(_ style: MenuBarIconStyle)
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

public struct UserDefaultsUsageSettingsStore: UsageSettingsProviding {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func usageRefreshEnabled() -> Bool {
        if defaults.object(forKey: SettingsViewModel.usageRefreshEnabledKey) == nil {
            return true
        }

        return defaults.bool(forKey: SettingsViewModel.usageRefreshEnabledKey)
    }

    public func usageSourceMode() -> CodexUsageSourceMode {
        CodexUsageSourceMode(
            rawValue: defaults.string(forKey: SettingsViewModel.usageSourceModeKey) ?? CodexUsageSourceMode.automatic.rawValue
        ) ?? .automatic
    }
}

public struct UserDefaultsMenuBarIconStyleStore: MenuBarIconStyleProviding {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func menuBarIconStyle() -> MenuBarIconStyle {
        MenuBarIconStyle.resolved(from: defaults.string(forKey: SettingsViewModel.menuBarIconStyleKey))
    }
}

extension UserDefaultsMenuBarIconStyleStore: MenuBarIconStyleMutating {
    public func setMenuBarIconStyle(_ style: MenuBarIconStyle) {
        defaults.set(style.rawValue, forKey: SettingsViewModel.menuBarIconStyleKey)
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    public nonisolated static let showEmailsKey = "showEmails"
    public nonisolated static let usageRefreshEnabledKey = "usageRefreshEnabled"
    public nonisolated static let usageSourceModeKey = "usageSourceMode"
    public nonisolated static let launchAtLoginKey = "launchAtLogin"
    public nonisolated static let menuBarIconStyleKey = "menuBarIconStyle"
    public nonisolated static let menuBarIconStyleDidChangeNotification = Notification.Name("SettingsViewModel.menuBarIconStyleDidChange")

    @Published public private(set) var showEmails: Bool
    @Published public private(set) var usageRefreshEnabled: Bool
    @Published public private(set) var usageSourceMode: CodexUsageSourceMode
    @Published public private(set) var launchAtLogin: Bool
    @Published public private(set) var menuBarIconStyle: MenuBarIconStyle
    @Published public private(set) var pendingConfirmation: SettingsConfirmationRequest?
    @Published public private(set) var pendingProviderConfirmation: SettingsProviderConfirmationRequest?
    @Published public private(set) var lastActionMessage: SettingsActionMessage?
    @Published public private(set) var currentProvider: String
    @Published public private(set) var availableProviders: [String]

    private let defaults: UserDefaults
    private let actionHandler: any SettingsActionHandling
    private let launchAtLoginController: (any LaunchAtLoginControlling)?
    private let configParser: ConfigTomlParser
    private let codexPaths: CodexPaths

    public init(
        defaults: UserDefaults = .standard,
        actionHandler: any SettingsActionHandling = NoopSettingsActionHandler(),
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
        configParser: ConfigTomlParser = ConfigTomlParser(),
        codexPaths: CodexPaths = CodexPaths()
    ) {
        self.defaults = defaults
        self.actionHandler = actionHandler
        self.launchAtLoginController = launchAtLoginController
        self.configParser = configParser
        self.codexPaths = codexPaths
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
        self.menuBarIconStyle = MenuBarIconStyle.resolved(from: defaults.string(forKey: Self.menuBarIconStyleKey))
        self.pendingConfirmation = nil
        self.pendingProviderConfirmation = nil
        self.lastActionMessage = nil

        // Load provider state
        let providerResult: (provider: String, implicit: Bool) =
            (try? configParser.readCurrentProvider(from: codexPaths.configFileURL))
            ?? (provider: "openai", implicit: true)
        self.currentProvider = providerResult.provider
        self.availableProviders = (try? configParser.listConfiguredProviderIds(from: String(contentsOf: codexPaths.configFileURL, encoding: .utf8))) ?? ["openai"]

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

    public func setMenuBarIconStyle(_ style: MenuBarIconStyle) {
        defaults.set(style.rawValue, forKey: Self.menuBarIconStyleKey)
        menuBarIconStyle = style
        NotificationCenter.default.post(
            name: Self.menuBarIconStyleDidChangeNotification,
            object: defaults
        )
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

    // MARK: - Provider Management

    public func loadProviders() {
        do {
            let configText = try String(contentsOf: codexPaths.configFileURL, encoding: .utf8)
            let providerResult = configParser.readCurrentProvider(from: configText)
            currentProvider = providerResult.provider
            availableProviders = configParser.listConfiguredProviderIds(from: configText)
        } catch {
            currentProvider = "openai"
            availableProviders = ["openai"]
        }
    }

    public func setCurrentProvider(_ provider: String) {
        do {
            try ensureConfigFileExists()
            try configParser.setRootProvider(in: codexPaths.configFileURL, provider: provider)
            currentProvider = provider
            lastActionMessage = nil
        } catch {
            lastActionMessage = SettingsActionMessage(
                title: "Provider Switch Failed",
                message: error.localizedDescription
            )
        }
    }

    public func addProvider(id: String) throws {
        guard validateProviderId(id) else {
            throw ProviderManagementError.invalidProviderId
        }

        guard !availableProviders.contains(id) else {
            throw ProviderManagementError.duplicateProviderId(id)
        }

        try ensureConfigFileExists()
        try configParser.addProvider(in: codexPaths.configFileURL, providerId: id)
        loadProviders()
        lastActionMessage = SettingsActionMessage(
            title: "Provider Added",
            message: "Added provider '\(id)' to configuration."
        )
    }

    public func requestRemoveProvider(_ providerId: String) {
        pendingProviderConfirmation = SettingsProviderConfirmationRequest(
            action: .removeProvider,
            providerId: providerId
        )
    }

    public func confirmPendingProviderAction() throws {
        guard let confirmation = pendingProviderConfirmation else {
            return
        }

        lastActionMessage = try actionHandler.performProviderAction(
            confirmation.action,
            providerId: confirmation.providerId
        )
        pendingProviderConfirmation = nil
        loadProviders()
    }

    public func cancelPendingProviderAction() {
        pendingProviderConfirmation = nil
    }

    public func validateProviderId(_ id: String) -> Bool {
        configParser.validateProviderId(id)
    }

    public func canRemoveProvider(_ id: String) -> Bool {
        // Cannot remove "openai" (default provider)
        guard id != "openai" else {
            return false
        }

        // Cannot remove currently active provider
        guard id != currentProvider else {
            return false
        }

        return true
    }

    private func ensureConfigFileExists() throws {
        guard !FileManager.default.fileExists(atPath: codexPaths.configFileURL.path) else {
            return
        }

        try FileManager.default.createDirectory(at: codexPaths.baseDirectory, withIntermediateDirectories: true)
        let defaultConfig = """
        model_provider = "openai"

        [model_providers.openai]
        """
        try defaultConfig.write(to: codexPaths.configFileURL, atomically: true, encoding: .utf8)
    }
}

public enum ProviderManagementError: LocalizedError {
    case invalidProviderId
    case duplicateProviderId(String)

    public var errorDescription: String? {
        switch self {
        case .invalidProviderId:
            return "Provider ID must contain only letters, numbers, dots, hyphens, and underscores"
        case .duplicateProviderId(let id):
            return "Provider '\(id)' already exists"
        }
    }
}
