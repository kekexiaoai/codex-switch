import Foundation
import SQLite3

/// Handles SQLite database operations for provider sync
public struct SqliteProviderUpdater {
    public let dbPath: URL
    private let busyTimeoutMs: Int32 = 5000

    public init(dbPath: URL) {
        self.dbPath = dbPath
    }

    // MARK: - Read Counts

    /// Reads provider counts from the threads table
    public func readProviderCounts() throws -> ProviderCounts? {
        guard FileManager.default.fileExists(atPath: dbPath.path) else {
            return nil
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, busyTimeoutMs)

        let query = """
            SELECT
                CASE
                    WHEN model_provider IS NULL OR model_provider = '' THEN '(missing)'
                    ELSE model_provider
                END AS model_provider,
                archived,
                COUNT(*) AS count
            FROM threads
            GROUP BY model_provider, archived
            ORDER BY archived, model_provider
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        var sessionsCounts: [String: Int] = [:]
        var archivedCounts: [String: Int] = [:]

        while sqlite3_step(stmt) == SQLITE_ROW {
            let provider = String(cString: sqlite3_column_text(stmt, 0))
            let archived = sqlite3_column_int(stmt, 1) != 0
            let count = Int(sqlite3_column_int(stmt, 2))

            if archived {
                archivedCounts[provider] = count
            } else {
                sessionsCounts[provider] = count
            }
        }

        return ProviderCounts(sessions: sessionsCounts, archivedSessions: archivedCounts)
    }

    // MARK: - Check Writable

    /// Checks if the database is writable (not locked)
    public func assertWritable() throws {
        guard FileManager.default.fileExists(atPath: dbPath.path) else {
            return // Database doesn't exist, that's fine
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw ProviderSyncError.sqliteBusy
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, busyTimeoutMs)

        // Try to begin immediate transaction
        if sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) != SQLITE_OK {
            throw ProviderSyncError.sqliteBusy
        }

        // Rollback immediately - we just wanted to test the lock
        sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
    }

    // MARK: - Update Provider

    /// Updates all threads to the target provider
    /// - Parameters:
    ///   - targetProvider: The provider to set
    ///   - afterUpdate: Optional callback after update but before commit
    /// - Returns: Number of rows updated and whether database was present
    @discardableResult
    public func updateProvider(
        targetProvider: String,
        afterUpdate: ((Int, Bool) -> Void)? = nil
    ) throws -> (updatedRows: Int, databasePresent: Bool) {
        guard FileManager.default.fileExists(atPath: dbPath.path) else {
            afterUpdate?(0, false)
            return (0, false)
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw ProviderSyncError.sqliteBusy
        }

        var transactionOpen = false

        do {
            sqlite3_busy_timeout(db, busyTimeoutMs)

            // Begin immediate transaction
            if sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) != SQLITE_OK {
                throw ProviderSyncError.sqliteBusy
            }
            transactionOpen = true

            // Update statement
            let updateSQL = "UPDATE threads SET model_provider = ? WHERE COALESCE(model_provider, '') <> ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, updateSQL, -1, &stmt, nil) == SQLITE_OK else {
                throw ProviderSyncError.sqliteBusy
            }
            defer { sqlite3_finalize(stmt) }

            // Bind parameters
            sqlite3_bind_text(stmt, 1, (targetProvider as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (targetProvider as NSString).utf8String, -1, nil)

            // Execute
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw ProviderSyncError.sqliteBusy
            }

            let changes = Int(sqlite3_changes(db))

            // Callback before commit
            afterUpdate?(changes, true)

            // Commit
            if sqlite3_exec(db, "COMMIT", nil, nil, nil) != SQLITE_OK {
                throw ProviderSyncError.sqliteBusy
            }
            transactionOpen = false

            sqlite3_close(db)
            return (changes, true)

        } catch {
            if transactionOpen {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            }
            sqlite3_close(db)
            throw error
        }
    }
}
