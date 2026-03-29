import Foundation

public struct CodexAuthFileStore {
    public let paths: CodexPaths
    private let fileManager: FileManager

    public init(paths: CodexPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func readCurrentAuthData() throws -> Data {
        guard fileManager.fileExists(atPath: paths.authFileURL.path) else {
            throw CodexAuthError.currentAuthFileMissing
        }

        do {
            return try Data(contentsOf: paths.authFileURL)
        } catch {
            throw CodexAuthError.authFileUnreadable
        }
    }

    public func readAuthData(at url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw CodexAuthError.authFileUnreadable
        }
    }

    public func writeArchive(data: Data, filename: String) throws {
        do {
            try fileManager.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: paths.accountsDirectoryURL.appendingPathComponent(filename), options: .atomic)
        } catch {
            throw CodexAuthError.archiveWriteFailed
        }
    }

    public func loadMetadataCache() throws -> CodexAccountMetadataCache {
        guard fileManager.fileExists(atPath: paths.accountMetadataCacheURL.path) else {
            return CodexAccountMetadataCache()
        }

        let data = try Data(contentsOf: paths.accountMetadataCacheURL)
        return try JSONDecoder().decode(CodexAccountMetadataCache.self, from: data)
    }

    public func saveMetadataCache(_ cache: CodexAccountMetadataCache) throws {
        do {
            try fileManager.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(cache)
            try data.write(to: paths.accountMetadataCacheURL, options: .atomic)
        } catch {
            throw CodexAuthError.archiveWriteFailed
        }
    }

    public func listArchivedAuthFileURLs() throws -> [URL] {
        guard fileManager.fileExists(atPath: paths.accountsDirectoryURL.path) else {
            return []
        }

        return try fileManager.contentsOfDirectory(
            at: paths.accountsDirectoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" && $0.lastPathComponent != paths.accountMetadataCacheURL.lastPathComponent }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func replaceActiveAuth(with data: Data) throws {
        do {
            try fileManager.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
            let tempURL = paths.baseDirectory.appendingPathComponent(".auth.json.tmp")
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: paths.authFileURL.path) {
                try fileManager.removeItem(at: paths.authFileURL)
            }
            try fileManager.moveItem(at: tempURL, to: paths.authFileURL)
        } catch {
            throw CodexAuthError.activeAuthReplacementFailed
        }
    }
}
