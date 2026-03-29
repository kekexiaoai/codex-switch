import Foundation

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
    private let lock = NSLock()

    public init(
        paths: CodexPaths,
        category: CodexDiagnosticsLogCategory = .browserLogin,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        switch category {
        case .browserLogin:
            self.logFileURL = paths.browserLoginDiagnosticsLogURL
        case .usageRefresh:
            self.logFileURL = paths.usageRefreshDiagnosticsLogURL
        }
        self.fileManager = fileManager
        self.now = now
    }

    public func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        do {
            try fileManager.createDirectory(
                at: logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let line = "\(Self.timestampFormatter.string(from: now())) \(message)\n"
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

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
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
