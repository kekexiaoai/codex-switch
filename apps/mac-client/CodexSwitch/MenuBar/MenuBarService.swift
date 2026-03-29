import Foundation

public protocol MenuBarSnapshotService {
    func loadSnapshot() async -> MenuBarSnapshot
}

public struct EnvironmentMenuBarService: MenuBarSnapshotService {
    private let environment: AppEnvironment
    private let timeFormatter: CodexUserFacingTimeFormatter

    public init(
        environment: AppEnvironment,
        timeFormatter: CodexUserFacingTimeFormatter = CodexUserFacingTimeFormatter()
    ) {
        self.environment = environment
        self.timeFormatter = timeFormatter
    }

    public func loadSnapshot() async -> MenuBarSnapshot {
        let repositoryAccounts = try? await environment.accountRepository?.loadAccounts()
        let accounts = repositoryAccounts?.map(\.emailMask) ?? environment.accountStore.loadAccounts()
        let usageText = await environment.usageService.refreshUsage()
        let showFullEmails = environment.emailVisibilityProvider?.showEmails() ?? false
        let activeAccountID = await environment.activeAccountController?.currentActiveAccountID()
        let activeAccount = repositoryAccounts?.first(where: { $0.id == activeAccountID }) ?? repositoryAccounts?.first
        let activeSnapshot: CodexUsageSnapshot?
        if let activeAccount {
            activeSnapshot = await environment.usageService.usageSnapshot(for: activeAccount.id)
        } else {
            activeSnapshot = nil
        }
        let headerEmail: String
        if
            let repositoryAccounts,
            let activeAccountID,
            let activeAccount = repositoryAccounts.first(where: { $0.id == activeAccountID })
        {
            headerEmail = activeAccount.displayEmail(showFullEmail: showFullEmails)
        } else if let firstRepositoryAccount = repositoryAccounts?.first {
            headerEmail = firstRepositoryAccount.displayEmail(showFullEmail: showFullEmails)
        } else {
            headerEmail = accounts.first ?? "No account"
        }

        let usageSourceText: String
        if usageText == "Usage refresh disabled" {
            usageSourceText = "Refresh Disabled"
        } else {
            usageSourceText = activeSnapshot?.sourceLabel ?? "Unavailable"
        }

        var accountRows: [AccountRowModel]
        if let repositoryAccounts {
            accountRows = []
            for account in repositoryAccounts {
                let snapshot = await environment.usageService.usageSnapshot(for: account.id)
                accountRows.append(
                    AccountRowModel(
                        id: account.id,
                        emailMask: account.displayEmail(showFullEmail: showFullEmails),
                        tierLabel: account.tier.rawValue.capitalized,
                        fiveHourPercent: snapshot?.fiveHour.percentUsed ?? (environment.runtimeMode == .live ? 0 : 56),
                        weeklyPercent: snapshot?.weekly.percentUsed ?? (environment.runtimeMode == .live ? 0 : 13),
                        isActive: account.id == activeAccountID
                    )
                )
            }
        } else {
            accountRows = accounts.enumerated().map { index, account in
                AccountRowModel(
                    id: "env-\(index)",
                    emailMask: account,
                    tierLabel: environment.runtimeMode == .live ? "Live" : "Preview",
                    fiveHourPercent: environment.runtimeMode == .live ? 42 : 56,
                    weeklyPercent: environment.runtimeMode == .live ? 24 : 13,
                    isActive: index == 0
                )
            }
        }

        return MenuBarSnapshot(
            headerEmail: headerEmail,
            headerTier: activeAccount?.tier.rawValue.uppercased() ?? (environment.runtimeMode == .live ? "LIVE" : "PREVIEW"),
            updatedText: usageText,
            usageSourceText: usageSourceText,
            summaries: activeSnapshot.map { snapshot in
                [
                    UsageSummaryModel(
                        id: "5h",
                        title: "5 Hours",
                        percentUsed: snapshot.fiveHour.percentUsed,
                        resetText: "Resets \(timeFormatter.displayTimestamp(from: snapshot.fiveHour.resetsAt))"
                    ),
                    UsageSummaryModel(
                        id: "weekly",
                        title: "Weekly",
                        percentUsed: snapshot.weekly.percentUsed,
                        resetText: "Resets \(timeFormatter.displayTimestamp(from: snapshot.weekly.resetsAt))"
                    ),
                ]
            } ?? [
                UsageSummaryModel(
                    id: "5h",
                    title: "5 Hours",
                    percentUsed: environment.runtimeMode == .live ? 0 : 56,
                    resetText: "Usage source: \(usageText)"
                ),
            ],
            accounts: accountRows
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
            usageSourceText: "API",
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
