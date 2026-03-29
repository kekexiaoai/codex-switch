import Foundation

@MainActor
public final class ActiveAccountController: ObservableObject {
    @Published public private(set) var activeAccountID: String?
    @Published public private(set) var lastRefreshSource: String?

    private let switcher: any SwitchCommandRunning
    private let usageService: any UsageRefreshing

    public init(
        activeAccountID: String? = nil,
        switcher: any SwitchCommandRunning,
        usageService: any UsageRefreshing
    ) {
        self.activeAccountID = activeAccountID
        self.switcher = switcher
        self.usageService = usageService
    }

    public func activateAccount(id: String) async throws {
        try await switcher.activateAccount(id: id)
        activeAccountID = id
        do {
            _ = try await usageService.refresh(reason: .switchTriggered)
        } catch let error as CodexAuthError where error == .noUsageData {
            // Account switching/import succeeded; missing usage data should not roll it back.
        }
        lastRefreshSource = "switch"
    }

    public func currentActiveAccountID() -> String? {
        activeAccountID
    }

    public func syncActiveAccountID(_ accountID: String?) {
        activeAccountID = accountID
    }
}
