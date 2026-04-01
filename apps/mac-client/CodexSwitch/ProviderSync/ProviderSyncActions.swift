import Foundation

public struct ProviderDistribution: Equatable {
    public let provider: String
    public let sessionCount: Int
    public let archivedCount: Int

    public init(provider: String, sessionCount: Int, archivedCount: Int) {
        self.provider = provider
        self.sessionCount = sessionCount
        self.archivedCount = archivedCount
    }
}

public struct ProviderSyncStatus: Equatable {
    public let currentProvider: String
    public let configuredProviders: [String]
    public let rolloutDistribution: [ProviderDistribution]
    public let sqliteDistribution: [ProviderDistribution]
    public let backupCount: Int
    public let backupTotalSize: UInt64

    public init(
        currentProvider: String,
        configuredProviders: [String],
        rolloutDistribution: [ProviderDistribution],
        sqliteDistribution: [ProviderDistribution],
        backupCount: Int,
        backupTotalSize: UInt64
    ) {
        self.currentProvider = currentProvider
        self.configuredProviders = configuredProviders
        self.rolloutDistribution = rolloutDistribution
        self.sqliteDistribution = sqliteDistribution
        self.backupCount = backupCount
        self.backupTotalSize = backupTotalSize
    }
}

public struct SyncResult: Equatable {
    public let targetProvider: String
    public let filesChanged: Int
    public let rowsChanged: Int
    public let configUpdated: Bool

    public init(targetProvider: String, filesChanged: Int, rowsChanged: Int, configUpdated: Bool = false) {
        self.targetProvider = targetProvider
        self.filesChanged = filesChanged
        self.rowsChanged = rowsChanged
        self.configUpdated = configUpdated
    }
}

public struct BackupEntry: Equatable, Identifiable {
    public let id: String
    public let directoryURL: URL
    public let timestamp: Date
    public let targetProvider: String
    public let totalSize: UInt64

    public init(id: String, directoryURL: URL, timestamp: Date, targetProvider: String, totalSize: UInt64) {
        self.id = id
        self.directoryURL = directoryURL
        self.timestamp = timestamp
        self.targetProvider = targetProvider
        self.totalSize = totalSize
    }
}

public struct ProviderSyncMessage: Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let message: String
    public let isError: Bool

    public init(id: UUID = UUID(), title: String, message: String, isError: Bool = false) {
        self.id = id
        self.title = title
        self.message = message
        self.isError = isError
    }
}

public enum ProviderSyncError: LocalizedError {
    case configFileNotFound
    case configParseError(String)
    case sqliteDatabaseNotFound
    case sqliteError(String)
    case syncFailed(String)
    case backupFailed(String)
    case restoreFailed(String)
    case providerNotConfigured(String, available: [String])
    case lockAcquisitionFailed

    public var errorDescription: String? {
        switch self {
        case .configFileNotFound:
            return "config.toml not found at ~/.codex/config.toml"
        case .configParseError(let detail):
            return "Failed to parse config.toml: \(detail)"
        case .sqliteDatabaseNotFound:
            return "state_5.sqlite not found at ~/.codex/state_5.sqlite"
        case .sqliteError(let detail):
            return "SQLite error: \(detail)"
        case .syncFailed(let detail):
            return "Sync failed: \(detail)"
        case .backupFailed(let detail):
            return "Backup failed: \(detail)"
        case .restoreFailed(let detail):
            return "Restore failed: \(detail)"
        case .providerNotConfigured(let provider, let available):
            return "Provider '\(provider)' is not configured. Available: \(available.joined(separator: ", "))"
        case .lockAcquisitionFailed:
            return "Could not acquire lock. Another sync operation may be in progress."
        }
    }
}
