import Foundation

public struct CodexAuthImporter {
    private let fileStore: CodexAuthFileStore
    private let jwtDecoder: CodexJWTDecoder
    private let now: () -> Date

    public init(
        fileStore: CodexAuthFileStore,
        jwtDecoder: CodexJWTDecoder = CodexJWTDecoder(),
        now: @escaping () -> Date = Date.init
    ) {
        self.fileStore = fileStore
        self.jwtDecoder = jwtDecoder
        self.now = now
    }

    public func importCurrentAccount(source: AccountSource = .currentAuth) throws -> Account {
        try importAuthData(fileStore.readCurrentAuthData(), source: source)
    }

    public func importBackupAuth(from url: URL) throws -> Account {
        try importAuthData(fileStore.readAuthData(at: url), source: .backupImport)
    }

    public func importAuthData(_ data: Data, source: AccountSource) throws -> Account {
        let idToken = try extractIDToken(from: data)
        let claims = try jwtDecoder.decode(idToken: idToken)
        let importedAt = now()
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: claims.email)

        try fileStore.writeArchive(data: data, filename: archiveFilename)
        var metadataCache = try fileStore.loadMetadataCache()
        metadataCache.entries[archiveFilename] = CodexAccountMetadataEntry(
            source: source,
            lastImportedAt: importedAt
        )
        try fileStore.saveMetadataCache(metadataCache)

        return Account(
            id: claims.accountID,
            emailMask: claims.emailMask,
            email: claims.email,
            tier: claims.tier,
            archiveFilename: archiveFilename,
            source: source,
            lastImportedAt: importedAt
        )
    }

    private func extractIDToken(from data: Data) throws -> String {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CodexAuthError.authJSONInvalid
        }

        guard
            let dictionary = object as? [String: Any],
            let tokens = dictionary["tokens"] as? [String: Any],
            let idToken = tokens["id_token"] as? String,
            !idToken.isEmpty
        else {
            throw CodexAuthError.idTokenMissing
        }

        return idToken
    }
}
