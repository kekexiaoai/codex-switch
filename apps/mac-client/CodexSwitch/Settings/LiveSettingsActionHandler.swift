import AppKit
import Foundation

public enum SettingsActionError: LocalizedError {
    case resourceOpenFailed
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .resourceOpenFailed:
            return SettingsStrings.text(.resourceOpenFailed)
        case .exportFailed:
            return SettingsStrings.text(.exportFailed)
        }
    }
}

public struct LiveSettingsActionHandler: SettingsActionHandling {
    public typealias ResourceOpener = (URL) -> Bool

    private let paths: CodexPaths
    private let fileManager: FileManager
    private let openResource: ResourceOpener
    private let now: () -> Date
    private let timeFormatter: CodexUserFacingTimeFormatter
    private let configParser: ConfigTomlParser
    private let preferredLanguages: [String]?

    public init(
        paths: CodexPaths,
        fileManager: FileManager = .default,
        openResource: @escaping ResourceOpener = { url in
            NSWorkspace.shared.open(url)
        },
        now: @escaping () -> Date = Date.init,
        timeFormatter: CodexUserFacingTimeFormatter = CodexUserFacingTimeFormatter(),
        configParser: ConfigTomlParser = ConfigTomlParser(),
        preferredLanguages: [String]? = nil
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.openResource = openResource
        self.now = now
        self.timeFormatter = timeFormatter
        self.configParser = configParser
        self.preferredLanguages = preferredLanguages
    }

    public func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage {
        switch action {
        case .clearDiagnosticsLog:
            try removeItemIfPresent(at: paths.browserLoginDiagnosticsLogURL)
            try removeItemIfPresent(at: paths.usageRefreshDiagnosticsLogURL)
            try removeItemIfPresent(at: paths.accountReorderDiagnosticsLogURL)
            return SettingsActionMessage(
                title: SettingsStrings.text(.diagnosticsClearedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.diagnosticsClearedMessage, preferredLanguages: preferredLanguages)
            )
        case .clearUsageCache:
            try removeItemIfPresent(at: paths.usageCacheURL)
            return SettingsActionMessage(
                title: SettingsStrings.text(.usageCacheClearedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.usageCacheClearedMessage, preferredLanguages: preferredLanguages)
            )
        case .removeArchivedAccounts:
            try removeArchivedAccounts()
            return SettingsActionMessage(
                title: SettingsStrings.text(.accountsRemovedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.accountsRemovedMessage, preferredLanguages: preferredLanguages)
            )
        }
    }

    public func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage {
        switch action {
        case .openCodexDirectory:
            try fileManager.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
            try open(paths.baseDirectory)
            return SettingsActionMessage(
                title: SettingsStrings.text(.codexDirectoryOpenedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.codexDirectoryOpenedMessage, preferredLanguages: preferredLanguages)
            )
        case .openDiagnosticsLog:
            try ensureDiagnosticsDirectoryExists()
            try open(paths.diagnosticsDirectoryURL)
            return SettingsActionMessage(
                title: SettingsStrings.text(.diagnosticsFolderOpenedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.diagnosticsFolderOpenedMessage, preferredLanguages: preferredLanguages)
            )
        case .exportDiagnosticsSummary:
            let exportURL = try exportDiagnosticsSummary()
            try open(exportURL)
            return SettingsActionMessage(
                title: SettingsStrings.text(.diagnosticsExportedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.diagnosticsExportedMessage, preferredLanguages: preferredLanguages)
            )
        }
    }

    public func performProviderAction(_ action: SettingsProviderAction, providerId: String) throws -> SettingsActionMessage {
        switch action {
        case .removeProvider:
            try configParser.removeProvider(in: paths.configFileURL, providerId: providerId)
            return SettingsActionMessage(
                title: SettingsStrings.text(.providerRemovedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.providerRemovedMessage(providerId, preferredLanguages: preferredLanguages)
            )
        }
    }

    private func removeArchivedAccounts() throws {
        guard fileManager.fileExists(atPath: paths.accountsDirectoryURL.path) else {
            return
        }

        let urls = try fileManager.contentsOfDirectory(at: paths.accountsDirectoryURL, includingPropertiesForKeys: nil)
        for url in urls where shouldRemoveArchivedAccountFile(url) {
            try removeItemIfPresent(at: url)
        }

        try removeItemIfPresent(at: paths.accountMetadataCacheURL)
    }

    private func shouldRemoveArchivedAccountFile(_ url: URL) -> Bool {
        guard url.pathExtension == "json" else {
            return false
        }

        let name = url.lastPathComponent
        return name != paths.accountMetadataCacheURL.lastPathComponent
            && name != paths.usageCacheURL.lastPathComponent
    }

    private func ensureDiagnosticsDirectoryExists() throws {
        try fileManager.createDirectory(at: paths.diagnosticsDirectoryURL, withIntermediateDirectories: true)
    }

    private func exportDiagnosticsSummary() throws -> URL {
        let diagnosticsReader = CodexDiagnosticsLogReader(paths: paths, fileManager: fileManager)
        let events = diagnosticsReader.recentSafeEvents(limit: 50)
        let exportDirectory = paths.baseDirectory.appendingPathComponent("exports", isDirectory: true)
        let currentTime = now()
        let exportURL = exportDirectory.appendingPathComponent("diagnostics-summary-\(timeFormatter.filenameTimestamp(from: currentTime)).txt")

        let body = SettingsStrings.diagnosticsSummaryBody(
            currentTime: timeFormatter.displayTimestamp(from: currentTime),
            codexDirectory: paths.baseDirectory.path,
            diagnosticsDirectory: paths.diagnosticsDirectoryURL.path,
            events: events,
            preferredLanguages: preferredLanguages
        )

        do {
            try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
            try Data(body.utf8).write(to: exportURL, options: .atomic)
            return exportURL
        } catch {
            throw SettingsActionError.exportFailed
        }
    }

    private func open(_ url: URL) throws {
        guard openResource(url) else {
            throw SettingsActionError.resourceOpenFailed
        }
    }

    private func removeItemIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }
}
