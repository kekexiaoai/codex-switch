import Foundation

/// File-based lock for preventing concurrent provider sync operations
public struct ProviderSyncLock {
    public let lockDirectoryURL: URL
    private let fileManager: FileManager

    public init(lockDirectoryURL: URL, fileManager: FileManager = .default) {
        self.lockDirectoryURL = lockDirectoryURL
        self.fileManager = fileManager
    }

    /// Acquires the lock, returns a release function
    /// - Throws: An error if the lock is already held
    /// - Returns: A function to release the lock
    public func acquire() throws -> () -> Void {
        let parentDir = lockDirectoryURL.deletingLastPathComponent()

        // Ensure parent directory exists
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Try to create lock directory (atomic on all filesystems)
        do {
            try fileManager.createDirectory(at: lockDirectoryURL, withIntermediateDirectories: false)
        } catch let error as NSError {
            if error.code == NSFileWriteFileExistsError {
                // Lock already exists - check if it's stale
                if let lockInfo = try? readLockInfo(), isStaleLock(lockInfo) {
                    // Remove stale lock and retry
                    try? fileManager.removeItem(at: lockDirectoryURL)
                    try fileManager.createDirectory(at: lockDirectoryURL, withIntermediateDirectories: false)
                } else {
                    throw ProviderSyncError.lockAlreadyExists(lockDirectoryURL.path)
                }
            } else {
                throw error
            }
        }

        // Write lock info
        let lockInfo = LockInfo(
            pid: ProcessInfo.processInfo.processIdentifier,
            startedAt: ISO8601DateFormatter().string(from: Date()),
            label: "provider-sync",
            cwd: fileManager.currentDirectoryPath
        )
        try writeLockInfo(lockInfo)

        var released = false
        return {
            guard !released else { return }
            released = true
            try? self.release()
        }
    }

    /// Releases the lock
    public func release() throws {
        if fileManager.fileExists(atPath: lockDirectoryURL.path) {
            try fileManager.removeItem(at: lockDirectoryURL)
        }
    }

    /// Checks if a lock exists
    public var isLocked: Bool {
        fileManager.fileExists(atPath: lockDirectoryURL.path)
    }

    /// Reads lock info if lock exists
    public func readLockInfo() throws -> LockInfo? {
        let ownerPath = lockDirectoryURL.appendingPathComponent("owner.json")
        guard fileManager.fileExists(atPath: ownerPath.path) else {
            return nil
        }

        let data = try Data(contentsOf: ownerPath)
        return try JSONDecoder().decode(LockInfo.self, from: data)
    }

    // MARK: - Private

    private func writeLockInfo(_ lockInfo: LockInfo) throws {
        let ownerPath = lockDirectoryURL.appendingPathComponent("owner.json")
        let data = try JSONEncoder().encode(lockInfo)
        try data.write(to: ownerPath, options: .atomic)
    }

    private func isStaleLock(_ lockInfo: LockInfo?) -> Bool {
        guard let lockInfo = lockInfo else { return true }

        // Check if process is still running
        let pid = lockInfo.pid
        let result = kill(pid, 0)
        if result != 0 && errno == ESRCH {
            // Process doesn't exist - lock is stale
            return true
        }

        // Check lock age (older than 1 hour is considered stale)
        guard let lockDate = ISO8601DateFormatter().date(from: lockInfo.startedAt) else {
            return true
        }
        let age = Date().timeIntervalSince(lockDate)
        return age > 3600 // 1 hour
    }
}

// MARK: - Errors

public enum ProviderSyncError: LocalizedError {
    case lockAlreadyExists(String)
    case configFileNotFound(String)
    case configFileUnreadable(String)
    case sqliteBusy
    case sessionFileBusy(String)
    case backupFailed(String)
    case restoreFailed(String)

    public var errorDescription: String? {
        switch self {
        case .lockAlreadyExists(let path):
            return "Lock already exists at \(path). Close Codex and retry, or remove the stale lock."
        case .configFileNotFound(let path):
            return "Config file not found at \(path)"
        case .configFileUnreadable(let path):
            return "Config file is unreadable at \(path)"
        case .sqliteBusy:
            return "Database is locked. Close Codex and retry."
        case .sessionFileBusy(let path):
            return "Session file is locked: \(path)"
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        case .restoreFailed(let reason):
            return "Restore failed: \(reason)"
        }
    }
}
