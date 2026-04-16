import Foundation

/// Handles reading and rewriting JSONL session files
public struct SessionFileRewriter {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - List Files

    /// Lists all JSONL rollout files in a directory recursively
    public func listJsonlFiles(in directory: URL) throws -> [URL] {
        var files: [URL] = []
        guard fileManager.fileExists(atPath: directory.path) else {
            return files
        }

        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            let name = url.lastPathComponent
            if name.hasPrefix("rollout-") && name.hasSuffix(".jsonl") {
                files.append(url)
            }
        }

        return files.sorted { $0.path < $1.path }
    }

    // MARK: - Read First Line

    /// Reads the first line of a file, preserving the line separator
    public func readFirstLineRecord(at url: URL) throws -> FirstLineRecord {
        guard let handle = try FileHandle(forReadingFrom: url) else {
            throw ProviderSyncError.sessionFileBusy(url.path)
        }
        defer { try? handle.close() }

        var position: UInt64 = 0
        var collected = Data()
        let chunkSize = 64 * 1024

        while true {
            try handle.seek(toOffset: position)
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }

            position += UInt64(chunk.count)
            collected.append(chunk)

            // Look for newline
            if let newlineIndex = collected.firstIndex(of: 0x0A) {
                let hasCRLF = newlineIndex > 0 && collected[newlineIndex - 1] == 0x0D
                let lineEnd = hasCRLF ? newlineIndex - 1 : newlineIndex
                let lineData = collected[0..<lineEnd]
                let separator = hasCRLF ? "\r\n" : "\n"

                return FirstLineRecord(
                    firstLine: String(data: lineData, encoding: .utf8) ?? "",
                    separator: separator,
                    offset: newlineIndex + 1
                )
            }
        }

        // No newline found - entire file is first line
        return FirstLineRecord(
            firstLine: String(data: collected, encoding: .utf8) ?? "",
            separator: "",
            offset: collected.count
        )
    }

    // MARK: - Parse Session Meta

    /// Parses a session_meta record from the first line JSON
    public func parseSessionMetaRecord(_ firstLine: String) -> SessionMetaRecord? {
        guard !firstLine.isEmpty else { return nil }

        guard let data = firstLine.data(using: .utf8) else { return nil }

        struct RawRecord: Decodable {
            let type: String?
            let payload: RawPayload?
        }

        struct RawPayload: Decodable {
            let id: String?
            let model_provider: String?
        }

        guard let raw = try? JSONDecoder().decode(RawRecord.self, from: data) else {
            return nil
        }

        guard raw.type == "session_meta",
              let payload = raw.payload else {
            return nil
        }

        return SessionMetaRecord(
            type: raw.type!,
            payload: SessionMetaPayload(
                id: payload.id,
                modelProvider: payload.model_provider
            )
        )
    }

    // MARK: - Collect Changes

    /// Collects all session files that need provider updates
    public func collectSessionChanges(
        codexHome: URL,
        targetProvider: String,
        skipLockedReads: Bool = false
    ) throws -> (changes: [SessionChange], lockedPaths: [String], providerCounts: ProviderCounts) {
        var changes: [SessionChange] = []
        var lockedPaths: [String] = []
        var sessionsCounts: [String: Int] = [:]
        var archivedCounts: [String: Int] = [:]

        let sessionDirs = ["sessions", "archived_sessions"]

        for dirName in sessionDirs {
            let dirURL = codexHome.appendingPathComponent(dirName, isDirectory: true)

            guard fileManager.fileExists(atPath: dirURL.path) else { continue }

            let files = try listJsonlFiles(in: dirURL)

            for fileURL in files {
                let record: FirstLineRecord
                do {
                    record = try readFirstLineRecord(at: fileURL)
                } catch {
                    if skipLockedReads && isErrorBusy(error) {
                        lockedPaths.append(fileURL.path)
                        continue
                    }
                    throw error
                }

                guard let meta = parseSessionMetaRecord(record.firstLine) else {
                    continue
                }

                let currentProvider = meta.payload.modelProvider ?? "(missing)"

                // Update counts
                if dirName == "sessions" {
                    sessionsCounts[currentProvider, default: 0] += 1
                } else {
                    archivedCounts[currentProvider, default: 0] += 1
                }

                // Check if needs update
                guard meta.payload.modelProvider != targetProvider else { continue }

                // Get file snapshot
                let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
                let size = (attrs[.size] as? Int64) ?? 0
                let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

                // Build updated first line
                var updatedPayload = meta.payload
                updatedPayload = SessionMetaPayload(
                    id: updatedPayload.id,
                    modelProvider: targetProvider
                )

                // Re-encode with same structure
                guard let updatedLine = encodeSessionMetaRecord(
                    original: record.firstLine,
                    newProvider: targetProvider
                ) else { continue }

                changes.append(SessionChange(
                    path: fileURL.path,
                    threadId: meta.payload.id,
                    directory: dirName,
                    originalFirstLine: record.firstLine,
                    originalSeparator: record.separator,
                    originalOffset: record.offset,
                    originalSize: size,
                    originalMtimeMs: Int64(mtime * 1000),
                    updatedFirstLine: updatedLine
                ))
            }
        }

        return (
            changes,
            lockedPaths,
            ProviderCounts(sessions: sessionsCounts, archivedSessions: archivedCounts)
        )
    }

    // MARK: - Rewrite First Line

    /// Atomically rewrites the first line of a file
    public func rewriteFirstLine(
        at url: URL,
        updatedFirstLine: String,
        separator: String
    ) throws {
        let current = try readFirstLineRecord(at: url)
        let tmpURL = url.appendingPathExtension("provider-sync.\(ProcessInfo.processInfo.processIdentifier).\(Int(Date().timeIntervalSince1970 * 1000)).tmp")

        do {
            // Write new first line to temp file
            try updatedFirstLine.write(to: tmpURL, atomically: false, encoding: .utf8)

            // Append separator if present
            if !separator.isEmpty {
                try separator.append(to: tmpURL, encoding: .utf8)
            }

            // Check if there's content after first line
            let headerOnly = current.separator.isEmpty && current.offset == current.firstLine.count

            if !headerOnly {
                // Append remaining content from original file
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }

                try handle.seek(toOffset: UInt64(current.offset))
                let remainingData = handle.readDataToEndOfFile()

                let writeHandle = try FileHandle(forWritingTo: tmpURL)
                defer { try? writeHandle.close() }
                try writeHandle.seekToEnd()
                writeHandle.write(remainingData)
            }

            // Atomic rename
            try fileManager.replaceItem(at: url, withItemAt: tmpURL, backupItemName: nil, resultingItemURL: nil)
        } catch {
            try? fileManager.removeItem(at: tmpURL)
            throw error
        }
    }

    /// Attempts to rewrite if the file still matches the expected snapshot
    public func tryRewriteCollectedFirstLine(_ change: SessionChange) throws -> Bool {
        // Verify file hasn't changed
        let attrs = try fileManager.attributesOfItem(atPath: change.path)
        let currentSize = (attrs[.size] as? Int64) ?? -1
        let currentMtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1

        guard currentSize == change.originalSize,
              Int64(currentMtime * 1000) == change.originalMtimeMs else {
            return false
        }

        // Verify content matches
        let current = try readFirstLineRecord(at: URL(fileURLWithPath: change.path))
        guard current.firstLine == change.originalFirstLine,
              current.offset == change.originalOffset else {
            return false
        }

        // Perform rewrite
        try rewriteFirstLine(
            at: URL(fileURLWithPath: change.path),
            updatedFirstLine: change.updatedFirstLine,
            separator: change.originalSeparator
        )

        return true
    }

    /// Applies all session changes, returning applied and skipped paths
    public func applySessionChanges(_ changes: [SessionChange]) throws -> (applied: Int, appliedPaths: [String], skippedPaths: [String]) {
        var applied = 0
        var appliedPaths: [String] = []
        var skippedPaths: [String] = []

        for change in changes {
            do {
                if try tryRewriteCollectedFirstLine(change) {
                    applied += 1
                    appliedPaths.append(change.path)
                } else {
                    skippedPaths.append(change.path)
                }
            } catch {
                skippedPaths.append(change.path)
            }
        }

        appliedPaths.sort()
        skippedPaths.sort()

        return (applied, appliedPaths, skippedPaths)
    }

    /// Restores session files from backup manifest entries
    public func restoreSessionChanges(_ entries: [SessionBackupEntry]) throws {
        for entry in entries {
            try rewriteFirstLine(
                at: URL(fileURLWithPath: entry.path),
                updatedFirstLine: entry.originalFirstLine,
                separator: entry.originalSeparator
            )
        }
    }

    // MARK: - Private Helpers

    private func isErrorBusy(_ error: Error) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("busy") ||
               message.contains("locked") ||
               message.contains("used by another process")
    }

    /// Re-encodes a session meta record with a new provider, preserving structure
    private func encodeSessionMetaRecord(original: String, newProvider: String) -> String? {
        // Simple string replacement for model_provider field
        // This preserves the original JSON structure
        guard let data = original.data(using: .utf8) else { return nil }
        guard var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard var payload = obj["payload"] as? [String: Any] else { return nil }

        payload["model_provider"] = newProvider
        obj["payload"] = payload

        guard let newData = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        return String(data: newData, encoding: .utf8)
    }
}
