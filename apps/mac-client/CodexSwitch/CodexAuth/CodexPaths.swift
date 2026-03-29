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

    public var loginDiagnosticsLogURL: URL {
        baseDirectory.appendingPathComponent("codex-switch-login.log")
    }

    public init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex", isDirectory: true)) {
        self.baseDirectory = baseDirectory
    }
}
