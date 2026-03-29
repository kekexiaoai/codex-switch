import Foundation

public struct UsageSummaryModel: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let percentUsed: Int
    public let resetText: String

    public init(id: String, title: String, percentUsed: Int, resetText: String) {
        self.id = id
        self.title = title
        self.percentUsed = percentUsed
        self.resetText = resetText
    }
}

public struct AccountRowModel: Identifiable, Equatable {
    public let id: String
    public let emailMask: String
    public let tierLabel: String
    public let fiveHourPercent: Int
    public let weeklyPercent: Int

    public init(
        id: String,
        emailMask: String,
        tierLabel: String,
        fiveHourPercent: Int,
        weeklyPercent: Int
    ) {
        self.id = id
        self.emailMask = emailMask
        self.tierLabel = tierLabel
        self.fiveHourPercent = fiveHourPercent
        self.weeklyPercent = weeklyPercent
    }
}

public struct MenuBarSnapshot: Equatable {
    public let headerEmail: String
    public let headerTier: String
    public let updatedText: String
    public let summaries: [UsageSummaryModel]
    public let accounts: [AccountRowModel]

    public init(
        headerEmail: String,
        headerTier: String,
        updatedText: String,
        summaries: [UsageSummaryModel],
        accounts: [AccountRowModel]
    ) {
        self.headerEmail = headerEmail
        self.headerTier = headerTier
        self.updatedText = updatedText
        self.summaries = summaries
        self.accounts = accounts
    }
}
