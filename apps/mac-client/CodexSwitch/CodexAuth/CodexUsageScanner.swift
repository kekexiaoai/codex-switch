import Foundation

public struct CodexUsageWindow: Codable, Equatable {
    public let percentUsed: Int
    public let resetsAt: Date

    public init(percentUsed: Int, resetsAt: Date) {
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
    }
}

public struct CodexUsageSnapshot: Codable, Equatable {
    public let accountID: String
    public let updatedAt: Date
    public let fiveHour: CodexUsageWindow
    public let weekly: CodexUsageWindow

    public init(accountID: String, updatedAt: Date, fiveHour: CodexUsageWindow, weekly: CodexUsageWindow) {
        self.accountID = accountID
        self.updatedAt = updatedAt
        self.fiveHour = fiveHour
        self.weekly = weekly
    }
}

public struct CodexUsageCache: Codable, Equatable {
    public var entries: [String: CodexUsageSnapshot]

    public init(entries: [String: CodexUsageSnapshot] = [:]) {
        self.entries = entries
    }
}

public struct CodexUsageScanner {
    private let paths: CodexPaths
    private let fileManager: FileManager

    public init(paths: CodexPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func refreshUsage(for account: Account) throws -> CodexUsageSnapshot {
        if let snapshot = try loadLatestSnapshot(for: account) {
            try saveCachedSnapshot(snapshot)
            return snapshot
        }

        if let cached = try loadCachedSnapshot(for: account.id) {
            return cached
        }

        throw CodexAuthError.noUsageData
    }

    private func loadLatestSnapshot(for account: Account) throws -> CodexUsageSnapshot? {
        guard fileManager.fileExists(atPath: paths.sessionsDirectoryURL.path) else {
            return nil
        }

        let logURLs = try fileManager.contentsOfDirectory(
            at: paths.sessionsDirectoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("rollout-") && $0.pathExtension == "jsonl" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }

        for url in logURLs {
            let data = try Data(contentsOf: url)
            let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
            for line in lines.reversed() {
                guard let snapshot = try decodeSnapshot(from: String(line), account: account) else {
                    continue
                }

                return snapshot
            }
        }

        return nil
    }

    private func decodeSnapshot(from line: String, account: Account) throws -> CodexUsageSnapshot? {
        guard let data = line.data(using: .utf8) else {
            return nil
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entry = decodeEntry(from: object)
        else {
            return nil
        }

        guard entry.email.lowercased() == account.email?.lowercased() else {
            return nil
        }

        return CodexUsageSnapshot(
            accountID: account.id,
            updatedAt: entry.timestamp,
            fiveHour: CodexUsageWindow(
                percentUsed: entry.rateLimits.fiveHour.usedPercent,
                resetsAt: entry.rateLimits.fiveHour.resetsAt
            ),
            weekly: CodexUsageWindow(
                percentUsed: entry.rateLimits.weekly.usedPercent,
                resetsAt: entry.rateLimits.weekly.resetsAt
            )
        )
    }

    private func decodeEntry(from object: [String: Any]) -> RolloutEntry? {
        guard
            let timestampString = stringValue(in: object, paths: [["timestamp"], ["event_msg", "timestamp"]]),
            let timestamp = parseDate(timestampString),
            let email = stringValue(in: object, paths: [["email"], ["event_msg", "email"]]),
            let rateLimitsObject = dictionaryValue(
                in: object,
                paths: [["rate_limits"], ["event_msg", "token_count", "rate_limits"]]
            ),
            let rateLimits = decodeRateLimits(from: rateLimitsObject)
        else {
            return nil
        }

        return RolloutEntry(timestamp: timestamp, email: email, rateLimits: rateLimits)
    }

    private func decodeRateLimits(from object: [String: Any]) -> RateLimits? {
        guard
            let fiveHourObject = object["five_hour"] as? [String: Any],
            let weeklyObject = object["weekly"] as? [String: Any],
            let fiveHour = decodeWindow(from: fiveHourObject),
            let weekly = decodeWindow(from: weeklyObject)
        else {
            return nil
        }

        return RateLimits(fiveHour: fiveHour, weekly: weekly)
    }

    private func decodeWindow(from object: [String: Any]) -> Window? {
        guard
            let usedPercent = object["used_percent"] as? Int,
            let resetsAtString = object["resets_at"] as? String,
            let resetsAt = parseDate(resetsAtString)
        else {
            return nil
        }

        return Window(usedPercent: usedPercent, resetsAt: resetsAt)
    }

    private func stringValue(in object: [String: Any], paths: [[String]]) -> String? {
        for path in paths {
            if let value = value(in: object, path: path) as? String, !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private func dictionaryValue(in object: [String: Any], paths: [[String]]) -> [String: Any]? {
        for path in paths {
            if let value = value(in: object, path: path) as? [String: Any] {
                return value
            }
        }

        return nil
    }

    private func value(in object: [String: Any], path: [String]) -> Any? {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any], let next = dictionary[component] else {
                return nil
            }
            current = next
        }

        return current
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func loadCachedSnapshot(for accountID: String) throws -> CodexUsageSnapshot? {
        guard fileManager.fileExists(atPath: paths.usageCacheURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: paths.usageCacheURL)
        let cache = try JSONDecoder().decode(CodexUsageCache.self, from: data)
        return cache.entries[accountID]
    }

    private func saveCachedSnapshot(_ snapshot: CodexUsageSnapshot) throws {
        let existingCache: CodexUsageCache
        if fileManager.fileExists(atPath: paths.usageCacheURL.path) {
            existingCache = try JSONDecoder().decode(CodexUsageCache.self, from: Data(contentsOf: paths.usageCacheURL))
        } else {
            existingCache = CodexUsageCache()
        }

        var updatedCache = existingCache
        updatedCache.entries[snapshot.accountID] = snapshot
        try fileManager.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(updatedCache).write(to: paths.usageCacheURL, options: .atomic)
    }
}

private extension CodexUsageScanner {
    struct RolloutEntry {
        let timestamp: Date
        let email: String
        let rateLimits: RateLimits
    }

    struct RateLimits {
        let fiveHour: Window
        let weekly: Window
    }

    struct Window {
        let usedPercent: Int
        let resetsAt: Date
    }
}
