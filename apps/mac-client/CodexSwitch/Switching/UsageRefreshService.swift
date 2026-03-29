import Foundation

public enum UsageRefreshReason: String {
    case switchTriggered
    case manual
}

public protocol UsageRefreshing {
    func refresh(reason: UsageRefreshReason) async throws -> [UsageSummaryModel]
}

public struct StubUsageRefreshService: UsageRefreshing {
    public init() {}

    public func refresh(reason: UsageRefreshReason) async throws -> [UsageSummaryModel] {
        []
    }
}
