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
    public let isActive: Bool

    public init(
        id: String,
        emailMask: String,
        tierLabel: String,
        fiveHourPercent: Int,
        weeklyPercent: Int,
        isActive: Bool = false
    ) {
        self.id = id
        self.emailMask = emailMask
        self.tierLabel = tierLabel
        self.fiveHourPercent = fiveHourPercent
        self.weeklyPercent = weeklyPercent
        self.isActive = isActive
    }
}

public struct AccountRemovalConfirmation: Identifiable, Equatable {
    public let accountID: String
    public let title: String
    public let message: String

    public var id: String {
        accountID
    }

    public init(accountID: String, title: String, message: String) {
        self.accountID = accountID
        self.title = title
        self.message = message
    }
}

public struct MenuBarSnapshot: Equatable {
    public let headerEmail: String
    public let headerTier: String
    public let updatedText: String
    public let headerStatusText: String
    public let usageSourceText: String
    public let recentEvents: [String]
    public let summaries: [UsageSummaryModel]
    public let accounts: [AccountRowModel]

    public init(
        headerEmail: String,
        headerTier: String,
        updatedText: String,
        headerStatusText: String? = nil,
        usageSourceText: String = "",
        recentEvents: [String] = [],
        summaries: [UsageSummaryModel],
        accounts: [AccountRowModel]
    ) {
        self.headerEmail = headerEmail
        self.headerTier = headerTier
        self.updatedText = updatedText
        self.headerStatusText = headerStatusText ?? updatedText
        self.usageSourceText = usageSourceText
        self.recentEvents = recentEvents
        self.summaries = summaries
        self.accounts = accounts
    }
}

public struct MenuBarAlertMessage: Identifiable, Equatable {
    public let title: String
    public let message: String

    public var id: String {
        "\(title)\n\(message)"
    }

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public struct MenuBarInlineMessage: Identifiable, Equatable {
    public enum Tone: Equatable {
        case success
        case error
    }

    public let title: String
    public let message: String
    public let tone: Tone

    public var id: String {
        "\(title)\n\(message)\n\(tone)"
    }

    public init(title: String, message: String, tone: Tone) {
        self.title = title
        self.message = message
        self.tone = tone
    }
}
