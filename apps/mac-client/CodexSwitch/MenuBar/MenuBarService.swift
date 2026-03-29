import Foundation

public protocol MenuBarSnapshotService {
    func loadSnapshot() async -> MenuBarSnapshot
    func loadSnapshot(triggerUsageRefresh: Bool) async -> MenuBarSnapshot
}

public extension MenuBarSnapshotService {
    func loadSnapshot() async -> MenuBarSnapshot {
        await loadSnapshot(triggerUsageRefresh: true)
    }
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

    public func loadSnapshot(triggerUsageRefresh: Bool) async -> MenuBarSnapshot {
        let repositoryAccounts = try? await environment.accountRepository?.loadAccounts()
        let accounts = repositoryAccounts?.map(\.emailMask) ?? environment.accountStore.loadAccounts()
        let settingsStore = UserDefaultsUsageSettingsStore(defaults: environment.settingsDefaults)
        let usageSettings = (
            enabled: settingsStore.usageRefreshEnabled(),
            mode: settingsStore.usageSourceMode()
        )
        var cachedUsage = loadCachedUsage()
        let usageText: String
        if triggerUsageRefresh {
            usageText = await environment.usageService.refreshUsage()
            cachedUsage = loadCachedUsage()
        } else {
            usageText = verboseUsageText(for: cachedUsage.latestSnapshot, settings: usageSettings)
        }
        let showFullEmails = environment.emailVisibilityProvider?.showEmails() ?? false
        let activeAccountID = await environment.activeAccountController?.currentActiveAccountID()
        let activeAccount = repositoryAccounts?.first(where: { $0.id == activeAccountID }) ?? repositoryAccounts?.first
        let activeSnapshot: CodexUsageSnapshot?
        if let activeAccount {
            if triggerUsageRefresh {
                activeSnapshot = await environment.usageService.usageSnapshot(for: activeAccount.id)
            } else {
                activeSnapshot = cachedUsage.entries[activeAccount.id]
            }
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
                let snapshot: CodexUsageSnapshot?
                if triggerUsageRefresh {
                    snapshot = await environment.usageService.usageSnapshot(for: account.id)
                } else {
                    snapshot = cachedUsage.entries[account.id]
                }
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
            headerStatusText: headerStatusText(for: cachedUsage.latestSnapshot, settings: usageSettings),
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

    private func headerStatusText(
        for snapshot: CodexUsageSnapshot?,
        settings: (enabled: Bool, mode: CodexUsageSourceMode)
    ) -> String {
        guard settings.enabled else {
            return "Refresh off"
        }

        guard let snapshot else {
            return "No usage"
        }

        let suffix = settings.mode == .localOnly ? "Local" : "Auto"
        return "\(timeFormatter.compactClockTimestamp(from: snapshot.updatedAt)) \(suffix)"
    }

    private func verboseUsageText(
        for snapshot: CodexUsageSnapshot?,
        settings: (enabled: Bool, mode: CodexUsageSourceMode)
    ) -> String {
        guard settings.enabled else {
            return "Usage refresh disabled"
        }

        guard let snapshot else {
            let suffix = settings.mode == .localOnly ? " (Local Only)" : ""
            return "No usage data\(suffix)"
        }

        let suffix = settings.mode == .localOnly ? " (Local Only)" : ""
        return "Updated \(timeFormatter.displayTimestamp(from: snapshot.updatedAt))\(suffix)"
    }

    private func loadCachedUsage() -> (entries: [String: CodexUsageSnapshot], latestSnapshot: CodexUsageSnapshot?) {
        guard
            let paths = environment.codexPaths,
            let cache = try? CodexAuthFileStore(paths: paths).loadUsageCache()
        else {
            return ([:], nil)
        }

        let latestSnapshot = cache.entries.values.max(by: { $0.updatedAt < $1.updatedAt })
        return (cache.entries, latestSnapshot)
    }
}

public struct MockMenuBarService: MenuBarSnapshotService {
    public init() {}

    public func loadSnapshot(triggerUsageRefresh: Bool) async -> MenuBarSnapshot {
        MenuBarSnapshot(
            headerEmail: "a••••@gmail.com",
            headerTier: "TEAM",
            updatedText: "Updated 10 seconds ago",
            headerStatusText: "10:15 Auto",
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
