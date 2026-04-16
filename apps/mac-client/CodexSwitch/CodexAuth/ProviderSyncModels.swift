import Foundation

// MARK: - Session Change

/// Represents a session file that needs its provider updated
public struct SessionChange: Equatable {
    public let path: String
    public let threadId: String?
    public let directory: String
    public let originalFirstLine: String
    public let originalSeparator: String
    public let originalOffset: Int
    public let originalSize: Int64
    public let originalMtimeMs: Int64
    public let updatedFirstLine: String

    public init(
        path: String,
        threadId: String?,
        directory: String,
        originalFirstLine: String,
        originalSeparator: String,
        originalOffset: Int,
        originalSize: Int64,
        originalMtimeMs: Int64,
        updatedFirstLine: String
    ) {
        self.path = path
        self.threadId = threadId
        self.directory = directory
        self.originalFirstLine = originalFirstLine
        self.originalSeparator = originalSeparator
        self.originalOffset = originalOffset
        self.originalSize = originalSize
        self.originalMtimeMs = originalMtimeMs
        self.updatedFirstLine = updatedFirstLine
    }
}

// MARK: - Sync Result

/// Result of a provider sync operation
public struct SyncResult: Equatable {
    public let codexHome: String
    public let targetProvider: String
    public let previousProvider: String?
    public let backupDir: String?
    public let changedSessionFiles: Int
    public let skippedLockedFiles: [String]
    public let sqliteRowsUpdated: Int
    public let sqlitePresent: Bool
    public let rolloutCountsBefore: ProviderCounts
    public let autoPruneResult: PruneResult?

    public init(
        codexHome: String,
        targetProvider: String,
        previousProvider: String?,
        backupDir: String?,
        changedSessionFiles: Int,
        skippedLockedFiles: [String],
        sqliteRowsUpdated: Int,
        sqlitePresent: Bool,
        rolloutCountsBefore: ProviderCounts,
        autoPruneResult: PruneResult? = nil
    ) {
        self.codexHome = codexHome
        self.targetProvider = targetProvider
        self.previousProvider = previousProvider
        self.backupDir = backupDir
        self.changedSessionFiles = changedSessionFiles
        self.skippedLockedFiles = skippedLockedFiles
        self.sqliteRowsUpdated = sqliteRowsUpdated
        self.sqlitePresent = sqlitePresent
        self.rolloutCountsBefore = rolloutCountsBefore
        self.autoPruneResult = autoPruneResult
    }
}

// MARK: - Provider Counts

/// Provider distribution counts for sessions and archived sessions
public struct ProviderCounts: Equatable {
    public let sessions: [String: Int]
    public let archivedSessions: [String: Int]

    public init(sessions: [String: Int] = [:], archivedSessions: [String: Int] = [:]) {
        self.sessions = sessions
        self.archivedSessions = archivedSessions
    }

    public var totalSessions: Int {
        sessions.values.reduce(0, +)
    }

    public var totalArchivedSessions: Int {
        archivedSessions.values.reduce(0, +)
    }
}

// MARK: - Provider Status

/// Current provider status and distribution
public struct ProviderStatus: Equatable {
    public let codexHome: String
    public let currentProvider: String
    public let currentProviderImplicit: Bool
    public let configuredProviders: [String]
    public let rolloutCounts: ProviderCounts
    public let sqliteCounts: ProviderCounts?
    public let backupRoot: String
    public let backupSummary: BackupSummary

    public init(
        codexHome: String,
        currentProvider: String,
        currentProviderImplicit: Bool,
        configuredProviders: [String],
        rolloutCounts: ProviderCounts,
        sqliteCounts: ProviderCounts?,
        backupRoot: String,
        backupSummary: BackupSummary
    ) {
        self.codexHome = codexHome
        self.currentProvider = currentProvider
        self.currentProviderImplicit = currentProviderImplicit
        self.configuredProviders = configuredProviders
        self.rolloutCounts = rolloutCounts
        self.sqliteCounts = sqliteCounts
        self.backupRoot = backupRoot
        self.backupSummary = backupSummary
    }
}

// MARK: - Backup Summary

/// Summary of backup state
public struct BackupSummary: Equatable {
    public let count: Int
    public let totalBytes: Int64

    public init(count: Int, totalBytes: Int64) {
        self.count = count
        self.totalBytes = totalBytes
    }
}

// MARK: - Prune Result

/// Result of pruning old backups
public struct PruneResult: Equatable {
    public let backupRoot: String
    public let deletedCount: Int
    public let remainingCount: Int
    public let freedBytes: Int64

    public init(backupRoot: String, deletedCount: Int, remainingCount: Int, freedBytes: Int64) {
        self.backupRoot = backupRoot
        self.deletedCount = deletedCount
        self.remainingCount = remainingCount
        self.freedBytes = freedBytes
    }
}

// MARK: - First Line Record

/// Parsed first line from a JSONL file
public struct FirstLineRecord: Equatable {
    public let firstLine: String
    public let separator: String
    public let offset: Int

    public init(firstLine: String, separator: String, offset: Int) {
        self.firstLine = firstLine
        self.separator = separator
        self.offset = offset
    }
}

// MARK: - Session Meta Record

/// Parsed session_meta record from JSONL first line
public struct SessionMetaRecord: Equatable {
    public let type: String
    public let payload: SessionMetaPayload

    public init(type: String, payload: SessionMetaPayload) {
        self.type = type
        self.payload = payload
    }
}

public struct SessionMetaPayload: Equatable {
    public let id: String?
    public let modelProvider: String?

    public init(id: String?, modelProvider: String?) {
        self.id = id
        self.modelProvider = modelProvider
    }
}

// MARK: - Backup Metadata

/// Metadata stored in backup directory
public struct BackupMetadata: Equatable, Codable {
    public let version: Int
    public let namespace: String
    public let codexHome: String
    public let targetProvider: String
    public let createdAt: String
    public let dbFiles: [String]
    public let changedSessionFiles: Int

    public init(
        version: Int,
        namespace: String,
        codexHome: String,
        targetProvider: String,
        createdAt: String,
        dbFiles: [String],
        changedSessionFiles: Int
    ) {
        self.version = version
        self.namespace = namespace
        self.codexHome = codexHome
        self.targetProvider = targetProvider
        self.createdAt = createdAt
        self.dbFiles = dbFiles
        self.changedSessionFiles = changedSessionFiles
    }
}

// MARK: - Session Backup Manifest

/// Manifest of session file first lines for backup/restore
public struct SessionBackupManifest: Equatable, Codable {
    public let version: Int
    public let namespace: String
    public let codexHome: String
    public let targetProvider: String
    public let createdAt: String
    public let files: [SessionBackupEntry]

    public init(
        version: Int,
        namespace: String,
        codexHome: String,
        targetProvider: String,
        createdAt: String,
        files: [SessionBackupEntry]
    ) {
        self.version = version
        self.namespace = namespace
        self.codexHome = codexHome
        self.targetProvider = targetProvider
        self.createdAt = createdAt
        self.files = files
    }
}

public struct SessionBackupEntry: Equatable, Codable {
    public let path: String
    public let originalFirstLine: String
    public let originalSeparator: String

    public init(path: String, originalFirstLine: String, originalSeparator: String) {
        self.path = path
        self.originalFirstLine = originalFirstLine
        self.originalSeparator = originalSeparator
    }
}

// MARK: - Lock Info

/// Information about a lock owner
public struct LockInfo: Equatable, Codable {
    public let pid: Int32
    public let startedAt: String
    public let label: String
    public let cwd: String

    public init(pid: Int32, startedAt: String, label: String, cwd: String) {
        self.pid = pid
        self.startedAt = startedAt
        self.label = label
        self.cwd = cwd
    }
}
