import Foundation

public protocol MenuBarSnapshotService {
    func loadSnapshot() async -> MenuBarSnapshot
}

public struct EnvironmentMenuBarService: MenuBarSnapshotService {
    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func loadSnapshot() async -> MenuBarSnapshot {
        let accounts = environment.accountStore.loadAccounts()
        let usageText = environment.usageService.refreshUsage()
        let headerEmail = accounts.first ?? "No account"

        return MenuBarSnapshot(
            headerEmail: headerEmail,
            headerTier: environment.runtimeMode == .live ? "LIVE" : "PREVIEW",
            updatedText: usageText,
            summaries: [
                UsageSummaryModel(
                    id: "5h",
                    title: "5 Hours",
                    percentUsed: environment.runtimeMode == .live ? 42 : 56,
                    resetText: "Usage source: \(usageText)"
                ),
            ],
            accounts: accounts.enumerated().map { index, account in
                AccountRowModel(
                    id: "env-\(index)",
                    emailMask: account,
                    tierLabel: environment.runtimeMode == .live ? "Live" : "Preview",
                    fiveHourPercent: environment.runtimeMode == .live ? 42 : 56,
                    weeklyPercent: environment.runtimeMode == .live ? 24 : 13
                )
            }
        )
    }
}

public struct MockMenuBarService: MenuBarSnapshotService {
    public init() {}

    public func loadSnapshot() async -> MenuBarSnapshot {
        MenuBarSnapshot(
            headerEmail: "a••••@gmail.com",
            headerTier: "TEAM",
            updatedText: "Updated 10 seconds ago",
            summaries: [
                UsageSummaryModel(
                    id: "5h",
                    title: "5 Hours",
                    percentUsed: 56,
                    resetText: "Resets in 3h 16m"
                ),
                UsageSummaryModel(
                    id: "weekly",
                    title: "Weekly",
                    percentUsed: 13,
                    resetText: "Resets in 5d"
                ),
            ],
            accounts: [
                AccountRowModel(id: "acct-1", emailMask: "b••••@gmail.com", tierLabel: "Plus", fiveHourPercent: 100, weeklyPercent: 10),
                AccountRowModel(id: "acct-2", emailMask: "r••••@gmail.com", tierLabel: "Team", fiveHourPercent: 67, weeklyPercent: 39),
                AccountRowModel(id: "acct-3", emailMask: "c••••@gmail.com", tierLabel: "Plus", fiveHourPercent: 28, weeklyPercent: 76),
                AccountRowModel(id: "acct-4", emailMask: "r••••@gmail.com", tierLabel: "Pro", fiveHourPercent: 83, weeklyPercent: 51),
                AccountRowModel(id: "acct-5", emailMask: "b••••@gmail.com", tierLabel: "Team", fiveHourPercent: 95, weeklyPercent: 88),
            ]
        )
    }
}
