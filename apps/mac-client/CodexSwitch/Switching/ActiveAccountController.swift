import Foundation

@MainActor
public final class ActiveAccountController: ObservableObject {
    @Published public private(set) var activeAccountID: String?
    @Published public private(set) var lastRefreshSource: String?

    private let switcher: any SwitchCommandRunning
    private let usageService: any UsageRefreshing

    public init(
        switcher: any SwitchCommandRunning,
        usageService: any UsageRefreshing
    ) {
        self.switcher = switcher
        self.usageService = usageService
    }

    public func activateAccount(id: String) async throws {
        try await switcher.activateAccount(id: id)
        activeAccountID = id
        _ = try await usageService.refresh(reason: .switchTriggered)
        lastRefreshSource = "switch"
    }
}
