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

public struct AppEnvironment {
    public let accountStore: any AccountStore
    public let usageService: any UsageService

    public init(
        accountStore: any AccountStore,
        usageService: any UsageService
    ) {
        self.accountStore = accountStore
        self.usageService = usageService
    }

    public static let preview = AppEnvironment(
        accountStore: MockAccountStore(),
        usageService: MockUsageService()
    )
}
