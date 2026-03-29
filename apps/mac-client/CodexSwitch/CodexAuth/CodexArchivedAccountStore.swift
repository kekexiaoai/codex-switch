import Foundation

public protocol AccountCatalog {
    func loadAccounts() async throws -> [Account]
}

public struct CodexArchivedAccountStore: AccountCatalog {
    private let fileStore: CodexAuthFileStore
    private let jwtDecoder: CodexJWTDecoder

    public init(
        fileStore: CodexAuthFileStore,
        jwtDecoder: CodexJWTDecoder = CodexJWTDecoder()
    ) {
        self.fileStore = fileStore
        self.jwtDecoder = jwtDecoder
    }

    public func loadAccounts() async throws -> [Account] {
        let metadata = try fileStore.loadMetadataCache()
        return try fileStore.listArchivedAuthFileURLs().compactMap { url in
            let data = try fileStore.readAuthData(at: url)
            guard let idToken = try extractIDToken(from: data) else {
                return nil
            }

            let claims = try jwtDecoder.decode(idToken: idToken)
            let entry = metadata.entries[url.lastPathComponent]

            return Account(
                id: claims.accountID,
                emailMask: claims.emailMask,
                email: claims.email,
                tier: claims.tier,
                archiveFilename: url.lastPathComponent,
                source: entry?.source ?? .fixture,
                lastImportedAt: entry?.lastImportedAt ?? .distantPast
            )
        }
    }

    public func loadArchivedAuthData(for accountID: String) throws -> Data {
        let accounts = try fileStore.listArchivedAuthFileURLs()
        for url in accounts {
            let data = try fileStore.readAuthData(at: url)
            guard let idToken = try extractIDToken(from: data) else {
                continue
            }

            let claims = try jwtDecoder.decode(idToken: idToken)
            if claims.accountID == accountID {
                return data
            }
        }

        throw CodexAuthError.activeAuthReplacementFailed
    }

    private func extractIDToken(from data: Data) throws -> String? {
        let object = try JSONSerialization.jsonObject(with: data)
        guard
            let dictionary = object as? [String: Any],
            let tokens = dictionary["tokens"] as? [String: Any]
        else {
            return nil
        }

        return tokens["id_token"] as? String
    }
}
