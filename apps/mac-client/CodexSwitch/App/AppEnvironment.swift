import Foundation

public protocol AccountStore {
    func loadAccounts() -> [String]
}

public protocol UsageService {
    func refreshUsage() -> String
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
}

public struct LiveAccountStore: AccountStore {
    private let configuration: RuntimeConfiguration

    public init(configuration: RuntimeConfiguration) {
        self.configuration = configuration
    }

    public func loadAccounts() -> [String] {
        switch configuration.kind {
        case .fixture:
            return ["fixture-account"]
        }
    }
}

public struct LiveUsageService: UsageService {
    private let configuration: RuntimeConfiguration

    public init(configuration: RuntimeConfiguration) {
        self.configuration = configuration
    }

    public func refreshUsage() -> String {
        switch configuration.kind {
        case .fixture:
            return "live-fixture"
        }
    }
}

public enum RuntimeMode: Equatable {
    case preview
    case live
}

public struct RuntimeConfiguration {
    public enum Kind {
        case fixture
    }

    public let kind: Kind

    public static let fixture = RuntimeConfiguration(kind: .fixture)

    public init(kind: Kind) {
        self.kind = kind
    }
}

public struct AppEnvironment {
    public let accountStore: any AccountStore
    public let usageService: any UsageService
    public let accountRepository: AccountRepository?
    public let activeAccountController: ActiveAccountController?
    public let runtimeMode: RuntimeMode

    public init(
        accountStore: any AccountStore,
        usageService: any UsageService,
        accountRepository: AccountRepository? = nil,
        activeAccountController: ActiveAccountController? = nil,
        runtimeMode: RuntimeMode
    ) {
        self.accountStore = accountStore
        self.usageService = usageService
        self.accountRepository = accountRepository
        self.activeAccountController = activeAccountController
        self.runtimeMode = runtimeMode
    }

    public static let preview = AppEnvironment(
        accountStore: MockAccountStore(),
        usageService: MockUsageService(),
        accountRepository: nil,
        activeAccountController: nil,
        runtimeMode: .preview
    )

    @MainActor
    public static func live(configuration: RuntimeConfiguration) throws -> AppEnvironment {
        let fixtureAccounts = [
            Account(id: "fixture-1", emailMask: "fixture@example.com", tier: .team),
        ]
        let repository = AccountRepository(
            metadataStore: InMemoryAccountMetadataStore(accounts: fixtureAccounts),
            credentialStore: InMemoryCredentialStore(secrets: ["fixture-1": "fixture-token"])
        )
        let controller = ActiveAccountController(
            activeAccountID: "fixture-1",
            switcher: StubSwitchCommandRunner(),
            usageService: StubUsageRefreshService()
        )

        return AppEnvironment(
            accountStore: LiveAccountStore(configuration: configuration),
            usageService: LiveUsageService(configuration: configuration),
            accountRepository: repository,
            activeAccountController: controller,
            runtimeMode: .live
        )
    }
}
