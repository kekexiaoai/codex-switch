import Foundation

public struct CodexUserFacingTimeFormatter {
    public let timeZone: TimeZone

    public init(timeZone: TimeZone = .current) {
        self.timeZone = timeZone
    }

    public func displayTimestamp(from date: Date) -> String {
        formatter(dateFormat: "yyyy-MM-dd HH:mm:ss ZZZZZ").string(from: date)
    }

    public func logTimestamp(from date: Date) -> String {
        formatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ssZZZZZ").string(from: date)
    }

    public func filenameTimestamp(from date: Date) -> String {
        formatter(dateFormat: "yyyyMMdd'T'HHmmss").string(from: date)
    }

    private func formatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = dateFormat
        return formatter
    }
}

public protocol CodexDiagnosticsLogging {
    func log(_ message: String)
}

public enum CodexDiagnosticsLogCategory: Equatable {
    case browserLogin
    case usageRefresh
}

public struct NullCodexDiagnosticsLogger: CodexDiagnosticsLogging {
    public init() {}

    public func log(_ message: String) {}
}

public final class CodexDiagnosticsFileLogger: CodexDiagnosticsLogging {
    private let logFileURL: URL
    private let fileManager: FileManager
    private let now: () -> Date
    private let timeFormatter: CodexUserFacingTimeFormatter
    private let lock = NSLock()

    public init(
        paths: CodexPaths,
        category: CodexDiagnosticsLogCategory = .browserLogin,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        timeFormatter: CodexUserFacingTimeFormatter = CodexUserFacingTimeFormatter()
    ) {
        switch category {
        case .browserLogin:
            self.logFileURL = paths.browserLoginDiagnosticsLogURL
        case .usageRefresh:
            self.logFileURL = paths.usageRefreshDiagnosticsLogURL
        }
        self.fileManager = fileManager
        self.now = now
        self.timeFormatter = timeFormatter
    }

    public func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        do {
            try fileManager.createDirectory(
                at: logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let line = "\(timeFormatter.logTimestamp(from: now())) \(message)\n"
            let data = Data(line.utf8)

            if !fileManager.fileExists(atPath: logFileURL.path) {
                try data.write(to: logFileURL, options: .atomic)
                return
            }

            let handle = try FileHandle(forWritingTo: logFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Diagnostics logging must never break the product flow.
        }
    }

}

public struct CodexDiagnosticsLogReader {
    private let logFileURL: URL
    private let fileManager: FileManager

    public init(paths: CodexPaths, fileManager: FileManager = .default) {
        self.logFileURL = paths.diagnosticsDirectoryURL
        self.fileManager = fileManager
    }

    public func recentSafeEvents(limit: Int = 5) -> [String] {
        guard limit > 0 else {
            return []
        }

        let candidateURLs = [
            logFileURL.appendingPathComponent("browser-login.log"),
            logFileURL.appendingPathComponent("usage-refresh.log"),
        ]
        let safeLines = candidateURLs
            .filter { fileManager.fileExists(atPath: $0.path) }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .flatMap { $0.split(separator: "\n").map(String.init) }
            .filter(isSafeLogLine)
            .sorted()

        return Array(safeLines.suffix(limit))
    }

    private func isSafeLogLine(_ line: String) -> Bool {
        let forbiddenMarkers = [
            "access_token",
            "refresh_token",
            "id_token",
            "OPENAI_API_KEY",
            "authorization:",
            "bearer ",
        ]

        let lowercased = line.lowercased()
        return !forbiddenMarkers.contains(where: { lowercased.contains($0) })
    }
}
