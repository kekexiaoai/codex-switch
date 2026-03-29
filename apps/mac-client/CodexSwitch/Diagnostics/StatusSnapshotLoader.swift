import Foundation

public struct StatusSnapshotLoader {
    private let snapshotService: any MenuBarSnapshotService
    private let accountRepository: AccountRepository?
    private let activeAccountIDProvider: @Sendable () async -> String?
    private let runtimeMode: RuntimeMode
    private let paths: CodexPaths
    private let currentHostProvider: () -> MenuBarHostKind
    private let preferredHostProvider: () -> MenuBarHostKind
    private let showFullEmailProvider: () -> Bool
    private let diagnosticsReader: () -> [String]

    public init(
        snapshotService: any MenuBarSnapshotService,
        accountRepository: AccountRepository?,
        activeAccountIDProvider: @escaping @Sendable () async -> String?,
        runtimeMode: RuntimeMode,
        paths: CodexPaths,
        currentHostProvider: @escaping () -> MenuBarHostKind = { MenuBarHostKind.current },
        preferredHostProvider: @escaping () -> MenuBarHostKind = { MenuBarHostKind.preferred },
        showFullEmailProvider: @escaping () -> Bool = { false },
        diagnosticsReader: @escaping () -> [String]
    ) {
        self.snapshotService = snapshotService
        self.accountRepository = accountRepository
        self.activeAccountIDProvider = activeAccountIDProvider
        self.runtimeMode = runtimeMode
        self.paths = paths
        self.currentHostProvider = currentHostProvider
        self.preferredHostProvider = preferredHostProvider
        self.showFullEmailProvider = showFullEmailProvider
        self.diagnosticsReader = diagnosticsReader
    }

    public func loadSnapshot() async -> StatusSnapshot {
        let menuBarSnapshot = await snapshotService.loadSnapshot()
        let repositoryAccounts = (try? await accountRepository?.loadAccounts()) ?? []
        let showFullEmails = showFullEmailProvider()
        let activeAccountID = await activeAccountIDProvider()
        let activeAccount = repositoryAccounts.first(where: { $0.id == activeAccountID }) ?? repositoryAccounts.first

        let diagnosticsEvents = diagnosticsReader()
        let archivedAccountCount = repositoryAccounts.isEmpty ? menuBarSnapshot.accounts.count : repositoryAccounts.count
        let usageStatusText = menuBarSnapshot.updatedText.isEmpty ? "No usage data" : menuBarSnapshot.updatedText

        return StatusSnapshot(
            activeAccount: activeAccount.map {
                StatusSnapshot.ActiveAccountSummary(
                    id: $0.id,
                    displayEmail: $0.displayEmail(showFullEmail: showFullEmails),
                    tierLabel: $0.tier.rawValue.capitalized,
                    sourceLabel: sourceLabel(for: $0.source),
                    archiveFilename: $0.archiveFilename,
                    lastImportedAt: $0.lastImportedAt
                )
            },
            activeAccountStatusText: activeAccount.map {
                $0.displayEmail(showFullEmail: showFullEmails)
            } ?? "No active account",
            archivedAccountCount: archivedAccountCount,
            accountInventoryStatusText: accountInventoryStatusText(for: archivedAccountCount),
            updatedText: menuBarSnapshot.updatedText,
            usageStatusText: usageStatusText,
            summaries: menuBarSnapshot.summaries,
            accountRows: menuBarSnapshot.accounts,
            runtimeModeLabel: runtimeMode == .live ? "Live" : "Preview",
            currentHostLabel: hostLabel(for: currentHostProvider()),
            preferredHostLabel: hostLabel(for: preferredHostProvider()),
            paths: StatusSnapshot.PathsSummary(
                authFilePath: paths.authFileURL.path,
                accountsDirectoryPath: paths.accountsDirectoryURL.path,
                diagnosticsLogPath: paths.loginDiagnosticsLogURL.path
            ),
            diagnostics: StatusSnapshot.DiagnosticsSummary(
                statusText: diagnosticsEvents.isEmpty ? "No browser login diagnostics yet" : "Recent browser login activity",
                recentEvents: diagnosticsEvents
            )
        )
    }

    private func accountInventoryStatusText(for count: Int) -> String {
        guard count > 0 else {
            return "No archived accounts"
        }

        let suffix = count == 1 ? "" : "s"
        return "\(count) archived account\(suffix)"
    }

    private func sourceLabel(for source: AccountSource) -> String {
        switch source {
        case .fixture:
            return "Fixture"
        case .currentAuth:
            return "Current Auth"
        case .backupImport:
            return "Backup Import"
        case .browserLogin:
            return "Browser Login"
        }
    }

    private func hostLabel(for host: MenuBarHostKind) -> String {
        switch host {
        case .statusItemPopover:
            return "NSStatusItem + NSPopover"
        case .menuBarExtra:
            return "MenuBarExtra"
        }
    }
}
