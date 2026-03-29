import AppKit
import Foundation

public enum SettingsActionError: LocalizedError {
    case resourceOpenFailed
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .resourceOpenFailed:
            return "The requested resource could not be opened."
        case .exportFailed:
            return "The diagnostics summary could not be exported."
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

    public init(
        paths: CodexPaths,
        fileManager: FileManager = .default,
        openResource: @escaping ResourceOpener = { url in
            NSWorkspace.shared.open(url)
        },
        now: @escaping () -> Date = Date.init,
        timeFormatter: CodexUserFacingTimeFormatter = CodexUserFacingTimeFormatter()
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.openResource = openResource
        self.now = now
        self.timeFormatter = timeFormatter
    }

    public func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage {
        switch action {
        case .clearDiagnosticsLog:
            try removeItemIfPresent(at: paths.browserLoginDiagnosticsLogURL)
            try removeItemIfPresent(at: paths.usageRefreshDiagnosticsLogURL)
            return SettingsActionMessage(title: "Diagnostics Cleared", message: "Removed local diagnostics logs.")
        case .clearUsageCache:
            try removeItemIfPresent(at: paths.usageCacheURL)
            return SettingsActionMessage(title: "Usage Cache Cleared", message: "Removed cached usage data.")
        case .removeArchivedAccounts:
            try removeArchivedAccounts()
            return SettingsActionMessage(title: "Accounts Removed", message: "Removed archived accounts.")
        }
    }

    public func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage {
        switch action {
        case .openCodexDirectory:
            try fileManager.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
            try open(paths.baseDirectory)
            return SettingsActionMessage(title: "Codex Directory Opened", message: "Opened ~/.codex.")
        case .openDiagnosticsLog:
            try ensureDiagnosticsDirectoryExists()
            try open(paths.diagnosticsDirectoryURL)
            return SettingsActionMessage(title: "Diagnostics Folder Opened", message: "Opened the local diagnostics folder.")
        case .exportDiagnosticsSummary:
            let exportURL = try exportDiagnosticsSummary()
            try open(exportURL)
            return SettingsActionMessage(title: "Diagnostics Exported", message: "Exported a sanitized diagnostics summary.")
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

        let body = """
        Codex Switch Diagnostics Summary
        Generated: \(timeFormatter.displayTimestamp(from: currentTime))
        Codex Directory: \(paths.baseDirectory.path)
        Diagnostics Directory: \(paths.diagnosticsDirectoryURL.path)

        Recent Safe Events:
        \(events.isEmpty ? "- No diagnostics events captured." : events.map { "- \($0)" }.joined(separator: "\n"))
        """

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
