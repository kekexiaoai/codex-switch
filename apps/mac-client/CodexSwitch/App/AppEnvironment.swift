import Foundation

public protocol AccountStore {
    func loadAccounts() -> [String]
}

public protocol UsageService {
    func refreshUsage() async -> String
    func usageSnapshot(for accountID: String) async -> CodexUsageSnapshot?
}

public struct MockAccountStore: AccountStore {
    public init() {}

    public func loadAccounts() -> [String] {
        []
    }
}

public struct MockUsageService: UsageService {
    public init() {}

    public func refreshUsage() async -> String {
        "preview"
    }

    public func usageSnapshot(for accountID: String) async -> CodexUsageSnapshot? {
        nil
    }
}

public struct LiveAccountStore: AccountStore {
    private let configuration: RuntimeConfiguration

    public init(configuration: RuntimeConfiguration) {
        self.configuration = configuration
    }

    public func loadAccounts() -> [String] {
        []
    }
}

public struct LiveUsageService: UsageService {
    private let configuration: RuntimeConfiguration
    private let settingsProvider: any UsageSettingsProviding
    private let resolver: CodexUsageResolver

    public init(
        configuration: RuntimeConfiguration,
        settingsProvider: any UsageSettingsProviding = UserDefaultsUsageSettingsStore(),
        resolver: CodexUsageResolver? = nil
    ) {
        self.configuration = configuration
        self.settingsProvider = settingsProvider
        self.resolver = resolver ?? CodexUsageResolver(
            scanner: CodexUsageScanner(paths: configuration.paths),
            apiClient: CodexUsageAPIClient(transport: configuration.usageAPITransport),
            logger: CodexDiagnosticsFileLogger(paths: configuration.paths, category: .usageRefresh)
        )
    }

    public func refreshUsage() async -> String {
        guard settingsProvider.usageRefreshEnabled() else {
            return "Usage refresh disabled"
        }

        let statusSuffix = settingsProvider.usageSourceMode() == .localOnly ? " (Local Only)" : ""
        _ = await refreshCurrentUsageIfPossible()
        guard let cache = try? loadUsageCache(), let latest = cache.entries.values.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return "No usage data\(statusSuffix)"
        }

        return "Updated \(ISO8601DateFormatter().string(from: latest.updatedAt))\(statusSuffix)"
    }

    public func usageSnapshot(for accountID: String) async -> CodexUsageSnapshot? {
        if let snapshot = try? loadUsageCache().entries[accountID] {
            return snapshot
        }

        return await refreshCurrentUsageIfPossible(matching: accountID)
    }

    private func loadUsageCache() throws -> CodexUsageCache {
        let url = configuration.paths.usageCacheURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return CodexUsageCache()
        }

        return try JSONDecoder().decode(CodexUsageCache.self, from: Data(contentsOf: url))
    }

    private func refreshCurrentUsageIfPossible(matching accountID: String? = nil) async -> CodexUsageSnapshot? {
        guard settingsProvider.usageRefreshEnabled() else {
            return nil
        }

        guard let authContext = currentAuthContext() else {
            return nil
        }

        if let accountID, authContext.account.id != accountID {
            return nil
        }

        return try? await resolver.refreshUsage(
            for: authContext.account,
            authData: authContext.authData,
            mode: settingsProvider.usageSourceMode()
        )
    }

    private func currentAuthContext() -> CurrentAuthContext? {
        guard
            let data = try? Data(contentsOf: configuration.paths.authFileURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String,
            let claims = try? CodexJWTDecoder().decode(idToken: idToken)
        else {
            return nil
        }

        return CurrentAuthContext(
            authData: data,
            account: Account(
                id: claims.accountID,
                emailMask: claims.emailMask,
                email: claims.email,
                tier: claims.tier,
                source: .currentAuth
            )
        )
    }
}

private extension LiveUsageService {
    struct CurrentAuthContext {
        let authData: Data
        let account: Account
    }
}

public enum RuntimeMode: Equatable {
    case preview
    case live
}

public struct RuntimeConfiguration {
    public let paths: CodexPaths
    public let loginRunner: (any CodexLoginRunning)?
    public let settingsDefaults: UserDefaults
    public let usageAPITransport: CodexUsageAPIClient.Transport?

    public init(
        paths: CodexPaths = CodexPaths(),
        loginRunner: (any CodexLoginRunning)? = nil,
        settingsDefaults: UserDefaults = .standard,
        usageAPITransport: CodexUsageAPIClient.Transport? = nil
    ) {
        self.paths = paths
        self.loginRunner = loginRunner
        self.settingsDefaults = settingsDefaults
        self.usageAPITransport = usageAPITransport
    }
}

public final class AppEnvironment {
    public let accountStore: any AccountStore
    public let usageService: any UsageService
    public let accountRepository: AccountRepository?
    public let activeAccountController: ActiveAccountController?
    public let accountImporter: CodexAuthImporter?
    public let loginCoordinator: CodexLoginCoordinator?
    public let settingsDefaults: UserDefaults
    public let settingsActionHandler: any SettingsActionHandling
    public let launchAtLoginController: (any LaunchAtLoginControlling)?
    public let emailVisibilityProvider: (any EmailVisibilityProviding)?
    public let runtimeMode: RuntimeMode
    public let codexPaths: CodexPaths?

    public init(
        accountStore: any AccountStore,
        usageService: any UsageService,
        accountRepository: AccountRepository? = nil,
        activeAccountController: ActiveAccountController? = nil,
        accountImporter: CodexAuthImporter? = nil,
        loginCoordinator: CodexLoginCoordinator? = nil,
        settingsDefaults: UserDefaults = .standard,
        settingsActionHandler: any SettingsActionHandling = NoopSettingsActionHandler(),
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
        emailVisibilityProvider: (any EmailVisibilityProviding)? = UserDefaultsEmailVisibilityStore(),
        runtimeMode: RuntimeMode,
        codexPaths: CodexPaths? = nil
    ) {
        self.accountStore = accountStore
        self.usageService = usageService
        self.accountRepository = accountRepository
        self.activeAccountController = activeAccountController
        self.accountImporter = accountImporter
        self.loginCoordinator = loginCoordinator
        self.settingsDefaults = settingsDefaults
        self.settingsActionHandler = settingsActionHandler
        self.launchAtLoginController = launchAtLoginController
        self.emailVisibilityProvider = emailVisibilityProvider
        self.runtimeMode = runtimeMode
        self.codexPaths = codexPaths
    }

    public static let preview = AppEnvironment(
        accountStore: MockAccountStore(),
        usageService: MockUsageService(),
        accountRepository: nil,
        activeAccountController: nil,
        accountImporter: nil,
        loginCoordinator: nil,
        settingsDefaults: .standard,
        settingsActionHandler: NoopSettingsActionHandler(),
        launchAtLoginController: nil,
        emailVisibilityProvider: UserDefaultsEmailVisibilityStore(),
        runtimeMode: .preview,
        codexPaths: nil
    )

    @MainActor
    public static func live(configuration: RuntimeConfiguration) throws -> AppEnvironment {
        let fileStore = CodexAuthFileStore(paths: configuration.paths)
        let browserDiagnosticsLogger = CodexDiagnosticsFileLogger(paths: configuration.paths, category: .browserLogin)
        let usageDiagnosticsLogger = CodexDiagnosticsFileLogger(paths: configuration.paths, category: .usageRefresh)
        let archivedAccountStore = CodexArchivedAccountStore(fileStore: fileStore)
        let repository = AccountRepository(catalog: archivedAccountStore)
        let importer = CodexAuthImporter(fileStore: fileStore)
        let usageRefreshService = CodexUsageRefreshService(
            fileStore: fileStore,
            resolver: CodexUsageResolver(
                scanner: CodexUsageScanner(paths: configuration.paths),
                apiClient: CodexUsageAPIClient(transport: configuration.usageAPITransport),
                logger: usageDiagnosticsLogger
            ),
            settingsProvider: UserDefaultsUsageSettingsStore(defaults: configuration.settingsDefaults)
        )
        let controller = ActiveAccountController(
            activeAccountID: currentActiveAccountID(fileStore: fileStore),
            switcher: CodexAccountSwitcher(
                archivedAccountStore: archivedAccountStore,
                fileStore: fileStore
            ),
            usageService: usageRefreshService
        )

        let loginRunner = configuration.loginRunner ?? DesktopCodexLoginRunner(fileStore: fileStore)

        return AppEnvironment(
            accountStore: LiveAccountStore(configuration: configuration),
            usageService: LiveUsageService(
                configuration: configuration,
                settingsProvider: UserDefaultsUsageSettingsStore(defaults: configuration.settingsDefaults),
                resolver: CodexUsageResolver(
                    scanner: CodexUsageScanner(paths: configuration.paths),
                    apiClient: CodexUsageAPIClient(transport: configuration.usageAPITransport),
                    logger: usageDiagnosticsLogger
                )
            ),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: importer,
            loginCoordinator: CodexLoginCoordinator(
                runner: loginRunner,
                importer: importer,
                fileStore: fileStore,
                logger: browserDiagnosticsLogger
            ),
            settingsDefaults: configuration.settingsDefaults,
            settingsActionHandler: LiveSettingsActionHandler(paths: configuration.paths),
            launchAtLoginController: LiveLaunchAtLoginController(),
            emailVisibilityProvider: UserDefaultsEmailVisibilityStore(defaults: configuration.settingsDefaults),
            runtimeMode: .live,
            codexPaths: configuration.paths
        )
    }

    @MainActor
    public func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            defaults: settingsDefaults,
            actionHandler: settingsActionHandler,
            launchAtLoginController: launchAtLoginController
        )
    }

    public func makeStatusSnapshotLoader(
        snapshotService: (any MenuBarSnapshotService)? = nil
    ) -> StatusSnapshotLoader? {
        guard let codexPaths else {
            return nil
        }

        let environmentSnapshotService = snapshotService ?? EnvironmentMenuBarService(environment: self)
        let activeAccountController = self.activeAccountController
        let emailVisibilityProvider = self.emailVisibilityProvider

        return StatusSnapshotLoader(
            snapshotService: environmentSnapshotService,
            accountRepository: accountRepository,
            activeAccountIDProvider: {
                await MainActor.run {
                    activeAccountController?.currentActiveAccountID()
                }
            },
            runtimeMode: runtimeMode,
            paths: codexPaths,
            showFullEmailProvider: {
                emailVisibilityProvider?.showEmails() ?? false
            },
            diagnosticsReader: {
                CodexDiagnosticsLogReader(paths: codexPaths).recentSafeEvents()
            }
        )
    }

    private static func currentActiveAccountID(fileStore: CodexAuthFileStore) -> String? {
        guard
            let data = try? fileStore.readCurrentAuthData(),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = object["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String,
            let claims = try? CodexJWTDecoder().decode(idToken: idToken)
        else {
            return nil
        }

        return claims.accountID
    }
}
