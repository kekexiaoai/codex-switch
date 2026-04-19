import Foundation

public struct CodexPaths: Equatable {
    public let baseDirectory: URL

    public var authFileURL: URL {
        baseDirectory.appendingPathComponent("auth.json")
    }

    public var accountsDirectoryURL: URL {
        baseDirectory.appendingPathComponent("accounts", isDirectory: true)
    }

    public var accountMetadataCacheURL: URL {
        accountsDirectoryURL.appendingPathComponent("metadata.json")
    }

    public var usageCacheURL: URL {
        accountsDirectoryURL.appendingPathComponent("usage-cache.json")
    }

    public var sessionsDirectoryURL: URL {
        baseDirectory.appendingPathComponent("sessions", isDirectory: true)
    }

    public var configFileURL: URL {
        baseDirectory.appendingPathComponent("config.toml")
    }

    public var sqliteDatabaseURL: URL {
        baseDirectory.appendingPathComponent("state_5.sqlite")
    }

    public var archivedSessionsDirectoryURL: URL {
        baseDirectory.appendingPathComponent("archived_sessions", isDirectory: true)
    }

    public var providerSyncBackupsDirectoryURL: URL {
        baseDirectory
            .appendingPathComponent("backups_state", isDirectory: true)
            .appendingPathComponent("provider-sync", isDirectory: true)
    }

    public var providerSyncLockFileURL: URL {
        baseDirectory
            .appendingPathComponent("tmp", isDirectory: true)
            .appendingPathComponent("provider-sync.lock")
    }

    public var diagnosticsDirectoryURL: URL {
        baseDirectory.appendingPathComponent("codex-switch", isDirectory: true)
    }

    public var browserLoginDiagnosticsLogURL: URL {
        diagnosticsDirectoryURL.appendingPathComponent("browser-login.log")
    }

    public var usageRefreshDiagnosticsLogURL: URL {
        diagnosticsDirectoryURL.appendingPathComponent("usage-refresh.log")
    }

    public var loginDiagnosticsLogURL: URL {
        browserLoginDiagnosticsLogURL
    }

    public init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex", isDirectory: true)) {
        self.baseDirectory = baseDirectory
    }
}
