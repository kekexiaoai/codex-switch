import Foundation

public struct SessionChange: Equatable {
    public let path: URL
    public let threadID: String?
    public let directory: String
    public let originalFirstLine: String
    public let originalSeparator: String
    public let originalOffset: UInt64
    public let originalSize: UInt64
    public let originalMtime: TimeInterval
    public let updatedFirstLine: String

    public init(
        path: URL,
        threadID: String?,
        directory: String,
        originalFirstLine: String,
        originalSeparator: String,
        originalOffset: UInt64,
        originalSize: UInt64,
        originalMtime: TimeInterval,
        updatedFirstLine: String
    ) {
        self.path = path
        self.threadID = threadID
        self.directory = directory
        self.originalFirstLine = originalFirstLine
        self.originalSeparator = originalSeparator
        self.originalOffset = originalOffset
        self.originalSize = originalSize
        self.originalMtime = originalMtime
        self.updatedFirstLine = updatedFirstLine
    }
}

public struct CodexSessionScanner {
    private let paths: CodexPaths
    private let fileManager: FileManager

    public init(paths: CodexPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    // MARK: - Scanning

    public func scanProviderDistribution() -> [ProviderDistribution] {
        var counts: [String: (sessions: Int, archived: Int)] = [:]

        for (dirURL, dirName) in scanDirectories() {
            let files = findRolloutFiles(in: dirURL)
            for file in files {
                guard let provider = readProvider(from: file) else { continue }
                var entry = counts[provider, default: (0, 0)]
                if dirName == "archived_sessions" {
                    entry.archived += 1
                } else {
                    entry.sessions += 1
                }
                counts[provider] = entry
            }
        }

        return counts.map { key, value in
            ProviderDistribution(provider: key, sessionCount: value.sessions, archivedCount: value.archived)
        }.sorted { $0.provider < $1.provider }
    }

    public func collectChanges(targetProvider: String) -> [SessionChange] {
        var changes: [SessionChange] = []

        for (dirURL, dirName) in scanDirectories() {
            let files = findRolloutFiles(in: dirURL)
            for file in files {
                guard let change = buildChange(for: file, directory: dirName, targetProvider: targetProvider) else {
                    continue
                }
                changes.append(change)
            }
        }

        return changes
    }

    // MARK: - Applying Changes

    public func applyChanges(_ changes: [SessionChange]) throws {
        for change in changes {
            try rewriteFirstLine(at: change.path, newFirstLine: change.updatedFirstLine, separator: change.originalSeparator, originalOffset: change.originalOffset)
        }
    }

    public func rollbackChanges(_ changes: [SessionChange]) {
        for change in changes {
            try? rewriteFirstLine(at: change.path, newFirstLine: change.originalFirstLine, separator: change.originalSeparator, originalOffset: change.originalOffset)
        }
    }

    // MARK: - Private

    private func scanDirectories() -> [(URL, String)] {
        var dirs: [(URL, String)] = []
        if fileManager.fileExists(atPath: paths.sessionsDirectoryURL.path) {
            dirs.append((paths.sessionsDirectoryURL, "sessions"))
        }
        if fileManager.fileExists(atPath: paths.archivedSessionsDirectoryURL.path) {
            dirs.append((paths.archivedSessionsDirectoryURL, "archived_sessions"))
        }
        return dirs
    }

    private func findRolloutFiles(in directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl" {
                files.append(url)
            }
        }
        return files
    }

    private func readProvider(from file: URL) -> String? {
        guard let (firstLine, _, _) = readFirstLine(from: file) else { return nil }
        guard let meta = parseSessionMeta(firstLine) else { return nil }
        return meta.provider ?? "(missing)"
    }

    private func buildChange(for file: URL, directory: String, targetProvider: String) -> SessionChange? {
        guard let (firstLine, separator, offset) = readFirstLine(from: file) else { return nil }
        guard let meta = parseSessionMeta(firstLine) else { return nil }

        let currentProvider = meta.provider ?? ""
        guard currentProvider != targetProvider else { return nil }

        guard let updatedLine = buildUpdatedFirstLine(firstLine, targetProvider: targetProvider) else { return nil }

        let attrs = try? fileManager.attributesOfItem(atPath: file.path)
        let fileSize = (attrs?[.size] as? UInt64) ?? 0
        let modTime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

        return SessionChange(
            path: file,
            threadID: meta.threadID,
            directory: directory,
            originalFirstLine: firstLine,
            originalSeparator: separator,
            originalOffset: offset,
            originalSize: fileSize,
            originalMtime: modTime,
            updatedFirstLine: updatedLine
        )
    }

    private struct SessionMeta {
        let provider: String?
        let threadID: String?
    }

    private func parseSessionMeta(_ line: String) -> SessionMeta? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "session_meta",
              let payload = json["payload"] as? [String: Any] else {
            return nil
        }

        let provider = payload["model_provider"] as? String
        let threadID = payload["id"] as? String
        return SessionMeta(provider: provider, threadID: threadID)
    }

    private func buildUpdatedFirstLine(_ originalLine: String, targetProvider: String) -> String? {
        guard let data = originalLine.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var payload = json["payload"] as? [String: Any] else {
            return nil
        }

        payload["model_provider"] = targetProvider
        json["payload"] = payload

        guard let updatedData = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
              let updatedString = String(data: updatedData, encoding: .utf8) else {
            return nil
        }

        return updatedString
    }

    private func readFirstLine(from file: URL) -> (line: String, separator: String, offset: UInt64)? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }

        let chunkSize = 8192
        guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else { return nil }

        var lineEndIndex: Data.Index?
        var separator = "\n"

        for i in chunk.indices {
            if chunk[i] == UInt8(ascii: "\n") {
                if i > chunk.startIndex && chunk[i - 1] == UInt8(ascii: "\r") {
                    lineEndIndex = i - 1
                    separator = "\r\n"
                } else {
                    lineEndIndex = i
                }
                break
            }
        }

        let lineData: Data
        let offset: UInt64
        if let endIndex = lineEndIndex {
            lineData = chunk[chunk.startIndex..<endIndex]
            offset = UInt64(endIndex - chunk.startIndex + (separator == "\r\n" ? 2 : 1))
        } else {
            lineData = chunk
            offset = UInt64(chunk.count)
        }

        guard let line = String(data: lineData, encoding: .utf8) else { return nil }
        return (line, separator, offset)
    }

    private func rewriteFirstLine(at path: URL, newFirstLine: String, separator: String, originalOffset: UInt64) throws {
        let tempURL = path.deletingLastPathComponent().appendingPathComponent(".\(path.lastPathComponent).tmp")

        guard let readHandle = try? FileHandle(forReadingFrom: path) else {
            throw ProviderSyncError.syncFailed("Cannot open \(path.path) for reading")
        }
        defer { try? readHandle.close() }

        fileManager.createFile(atPath: tempURL.path, contents: nil)
        guard let writeHandle = try? FileHandle(forWritingTo: tempURL) else {
            throw ProviderSyncError.syncFailed("Cannot create temp file at \(tempURL.path)")
        }
        defer { try? writeHandle.close() }

        let newLineData = Data((newFirstLine + separator).utf8)
        try writeHandle.write(contentsOf: newLineData)

        try readHandle.seek(toOffset: originalOffset)
        let bufferSize = 65536
        while true {
            let chunk = readHandle.readData(ofLength: bufferSize)
            if chunk.isEmpty { break }
            try writeHandle.write(contentsOf: chunk)
        }

        try writeHandle.close()
        try readHandle.close()

        _ = try fileManager.replaceItemAt(path, withItemAt: tempURL)
    }
}
