import Foundation

public protocol AccountStore {
    func loadAccounts() -> [String]
}

public protocol UsageService {
    func refreshUsage() -> String
    func usageSnapshot(for accountID: String) -> CodexUsageSnapshot?
}

public struct MockAccountStore: AccountStore {
    public init() {}

    public func loadAccounts() -> [String] {
        []
    }
}

public struct MockUsageService: UsageService {
    public init() {}

    public func refreshUsage() -> String {
        "preview"
    }

    public func usageSnapshot(for accountID: String) -> CodexUsageSnapshot? {
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

    public init(configuration: RuntimeConfiguration) {
        self.configuration = configuration
    }

    public func refreshUsage() -> String {
        guard let cache = try? loadUsageCache(), let latest = cache.entries.values.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return "No usage data"
        }

        return "Updated \(ISO8601DateFormatter().string(from: latest.updatedAt))"
    }

    public func usageSnapshot(for accountID: String) -> CodexUsageSnapshot? {
        try? loadUsageCache().entries[accountID]
    }

    private func loadUsageCache() throws -> CodexUsageCache {
        let url = configuration.paths.usageCacheURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return CodexUsageCache()
        }

        return try JSONDecoder().decode(CodexUsageCache.self, from: Data(contentsOf: url))
    }
}

public enum RuntimeMode: Equatable {
    case preview
    case live
}

public struct RuntimeConfiguration {
    public let paths: CodexPaths
    public let loginRunner: (any CodexLoginRunning)?

    public init(
        paths: CodexPaths = CodexPaths(),
        loginRunner: (any CodexLoginRunning)? = nil
    ) {
        self.paths = paths
        self.loginRunner = loginRunner
    }
}

public final class AppEnvironment {
    public let accountStore: any AccountStore
    public let usageService: any UsageService
    public let accountRepository: AccountRepository?
    public let activeAccountController: ActiveAccountController?
    public let accountImporter: CodexAuthImporter?
    public let loginCoordinator: CodexLoginCoordinator?
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
        emailVisibilityProvider: UserDefaultsEmailVisibilityStore(),
        runtimeMode: .preview,
        codexPaths: nil
    )

    @MainActor
    public static func live(configuration: RuntimeConfiguration) throws -> AppEnvironment {
        let fileStore = CodexAuthFileStore(paths: configuration.paths)
        let archivedAccountStore = CodexArchivedAccountStore(fileStore: fileStore)
        let repository = AccountRepository(catalog: archivedAccountStore)
        let importer = CodexAuthImporter(fileStore: fileStore)
        let usageRefreshService = CodexUsageRefreshService(
            fileStore: fileStore,
            scanner: CodexUsageScanner(paths: configuration.paths)
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
            usageService: LiveUsageService(configuration: configuration),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: importer,
            loginCoordinator: CodexLoginCoordinator(
                runner: loginRunner,
                importer: importer,
                fileStore: fileStore
            ),
            emailVisibilityProvider: UserDefaultsEmailVisibilityStore(),
            runtimeMode: .live,
            codexPaths: configuration.paths
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
