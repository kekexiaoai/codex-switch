import Foundation

public struct StatusSnapshot: Equatable {
    public struct ActiveAccountSummary: Equatable {
        public let id: String
        public let displayEmail: String
        public let tierLabel: String
        public let sourceLabel: String
        public let archiveFilename: String
        public let lastImportedAt: Date

        public init(
            id: String,
            displayEmail: String,
            tierLabel: String,
            sourceLabel: String,
            archiveFilename: String,
            lastImportedAt: Date
        ) {
            self.id = id
            self.displayEmail = displayEmail
            self.tierLabel = tierLabel
            self.sourceLabel = sourceLabel
            self.archiveFilename = archiveFilename
            self.lastImportedAt = lastImportedAt
        }
    }

    public struct PathsSummary: Equatable {
        public let authFilePath: String
        public let accountsDirectoryPath: String
        public let diagnosticsLogPath: String

        public init(authFilePath: String, accountsDirectoryPath: String, diagnosticsLogPath: String) {
            self.authFilePath = authFilePath
            self.accountsDirectoryPath = accountsDirectoryPath
            self.diagnosticsLogPath = diagnosticsLogPath
        }
    }

    public struct DiagnosticsSummary: Equatable {
        public let statusText: String
        public let recentEvents: [String]

        public init(statusText: String, recentEvents: [String]) {
            self.statusText = statusText
            self.recentEvents = recentEvents
        }
    }

    public let activeAccount: ActiveAccountSummary?
    public let activeAccountStatusText: String
    public let archivedAccountCount: Int
    public let accountInventoryStatusText: String
    public let updatedText: String
    public let usageStatusText: String
    public let summaries: [UsageSummaryModel]
    public let accountRows: [AccountRowModel]
    public let runtimeModeLabel: String
    public let currentHostLabel: String
    public let preferredHostLabel: String
    public let paths: PathsSummary
    public let diagnostics: DiagnosticsSummary

    public init(
        activeAccount: ActiveAccountSummary?,
        activeAccountStatusText: String,
        archivedAccountCount: Int,
        accountInventoryStatusText: String,
        updatedText: String,
        usageStatusText: String,
        summaries: [UsageSummaryModel],
        accountRows: [AccountRowModel],
        runtimeModeLabel: String,
        currentHostLabel: String,
        preferredHostLabel: String,
        paths: PathsSummary,
        diagnostics: DiagnosticsSummary
    ) {
        self.activeAccount = activeAccount
        self.activeAccountStatusText = activeAccountStatusText
        self.archivedAccountCount = archivedAccountCount
        self.accountInventoryStatusText = accountInventoryStatusText
        self.updatedText = updatedText
        self.usageStatusText = usageStatusText
        self.summaries = summaries
        self.accountRows = accountRows
        self.runtimeModeLabel = runtimeModeLabel
        self.currentHostLabel = currentHostLabel
        self.preferredHostLabel = preferredHostLabel
        self.paths = paths
        self.diagnostics = diagnostics
    }
}
