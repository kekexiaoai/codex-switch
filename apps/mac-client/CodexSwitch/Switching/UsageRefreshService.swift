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

public struct CodexUsageRefreshService: UsageRefreshing {
    private let fileStore: CodexAuthFileStore
    private let scanner: CodexUsageScanner

    public init(fileStore: CodexAuthFileStore, scanner: CodexUsageScanner) {
        self.fileStore = fileStore
        self.scanner = scanner
    }

    public func refresh(reason: UsageRefreshReason) async throws -> [UsageSummaryModel] {
        let data = try fileStore.readCurrentAuthData()
        let object = try JSONSerialization.jsonObject(with: data)
        guard
            let dictionary = object as? [String: Any],
            let tokens = dictionary["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String
        else {
            throw CodexAuthError.idTokenMissing
        }

        let claims = try CodexJWTDecoder().decode(idToken: idToken)
        let account = Account(
            id: claims.accountID,
            emailMask: claims.emailMask,
            email: claims.email,
            tier: claims.tier
        )
        let snapshot = try scanner.refreshUsage(for: account)

        return [
            UsageSummaryModel(
                id: "5h",
                title: "5 Hours",
                percentUsed: snapshot.fiveHour.percentUsed,
                resetText: "Resets \(ISO8601DateFormatter().string(from: snapshot.fiveHour.resetsAt))"
            ),
            UsageSummaryModel(
                id: "weekly",
                title: "Weekly",
                percentUsed: snapshot.weekly.percentUsed,
                resetText: "Resets \(ISO8601DateFormatter().string(from: snapshot.weekly.resetsAt))"
            ),
        ]
    }
}
