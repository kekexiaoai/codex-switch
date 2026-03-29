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
    public let runtimeMode: RuntimeMode

    public init(
        accountStore: any AccountStore,
        usageService: any UsageService,
        runtimeMode: RuntimeMode
    ) {
        self.accountStore = accountStore
        self.usageService = usageService
        self.runtimeMode = runtimeMode
    }

    public static let preview = AppEnvironment(
        accountStore: MockAccountStore(),
        usageService: MockUsageService(),
        runtimeMode: .preview
    )

    public static func live(configuration: RuntimeConfiguration) throws -> AppEnvironment {
        AppEnvironment(
            accountStore: LiveAccountStore(configuration: configuration),
            usageService: LiveUsageService(configuration: configuration),
            runtimeMode: .live
        )
    }
}
