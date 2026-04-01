import Foundation
import SQLite3

public struct CodexProviderSQLite {
    private let databaseURL: URL
    private let fileManager: FileManager

    public init(paths: CodexPaths, fileManager: FileManager = .default) {
        self.databaseURL = paths.sqliteDatabaseURL
        self.fileManager = fileManager
    }

    public init(databaseURL: URL, fileManager: FileManager = .default) {
        self.databaseURL = databaseURL
        self.fileManager = fileManager
    }

    public var databaseExists: Bool {
        fileManager.fileExists(atPath: databaseURL.path)
    }

    // MARK: - Read

    public func providerCounts() throws -> [ProviderDistribution] {
        guard databaseExists else {
            return []
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw ProviderSyncError.sqliteError("Cannot open database")
        }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT
                CASE WHEN model_provider IS NULL OR model_provider = '' THEN '(missing)' ELSE model_provider END AS provider,
                archived,
                COUNT(*) AS count
            FROM threads
            GROUP BY provider, archived
            ORDER BY archived, provider
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw ProviderSyncError.sqliteError("Prepare failed: \(errmsg)")
        }
        defer { sqlite3_finalize(stmt) }

        var counts: [String: (sessions: Int, archived: Int)] = [:]

        while sqlite3_step(stmt) == SQLITE_ROW {
            let provider = String(cString: sqlite3_column_text(stmt, 0))
            let archived = sqlite3_column_int(stmt, 1)
            let count = Int(sqlite3_column_int(stmt, 2))

            var entry = counts[provider, default: (0, 0)]
            if archived != 0 {
                entry.archived += count
            } else {
                entry.sessions += count
            }
            counts[provider] = entry
        }

        return counts.map { key, value in
            ProviderDistribution(provider: key, sessionCount: value.sessions, archivedCount: value.archived)
        }.sorted { $0.provider < $1.provider }
    }

    // MARK: - Write

    public func updateProvider(_ targetProvider: String) throws -> Int {
        guard databaseExists else {
            return 0
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw ProviderSyncError.sqliteError("Cannot open database for writing")
        }
        defer { sqlite3_close(db) }

        guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw ProviderSyncError.sqliteError("Begin transaction failed: \(errmsg)")
        }

        let sql = "UPDATE threads SET model_provider = ? WHERE COALESCE(model_provider, '') <> ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw ProviderSyncError.sqliteError("Prepare update failed: \(errmsg)")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, targetProvider, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, targetProvider, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw ProviderSyncError.sqliteError("Update failed: \(errmsg)")
        }

        let changedRows = Int(sqlite3_changes(db))

        guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw ProviderSyncError.sqliteError("Commit failed: \(errmsg)")
        }

        return changedRows
    }

    // MARK: - Writable Check

    public func assertWritable() throws {
        guard databaseExists else {
            throw ProviderSyncError.sqliteDatabaseNotFound
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw ProviderSyncError.sqliteError("Cannot open database for writing")
        }
        defer { sqlite3_close(db) }

        guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw ProviderSyncError.sqliteError("Database is not writable: \(errmsg)")
        }

        sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
    }
}
