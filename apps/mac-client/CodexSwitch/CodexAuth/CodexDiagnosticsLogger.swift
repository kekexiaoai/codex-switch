import Foundation

public protocol CodexDiagnosticsLogging {
    func log(_ message: String)
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
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.logFileURL = paths.loginDiagnosticsLogURL
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
