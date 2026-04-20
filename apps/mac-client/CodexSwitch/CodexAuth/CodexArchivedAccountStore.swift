import Foundation

public protocol AccountCatalog {
    func loadAccounts() async throws -> [Account]
}

public protocol AccountRemoving {
    func removeArchivedAccount(id: String, activeAccountID: String?) async throws -> AccountRemovalResult
}

public protocol AccountOrderPersisting {
    func saveManualOrder(idsInOrder: [String]) async throws
}

public struct AccountRemovalResult: Equatable {
    public let removedAccountID: String
    public let nextActiveAccountID: String?

    public init(removedAccountID: String, nextActiveAccountID: String?) {
        self.removedAccountID = removedAccountID
        self.nextActiveAccountID = nextActiveAccountID
    }
}

public struct CodexArchivedAccountStore: AccountCatalog, AccountRemoving, AccountOrderPersisting {
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
        let archivedURLs = try fileStore.listArchivedAuthFileURLs()
        let accounts: [Account] = try archivedURLs.compactMap { url in
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
                manualOrder: entry?.manualOrder ?? 0,
                archiveFilename: url.lastPathComponent,
                source: entry?.source ?? .fixture,
                lastImportedAt: entry?.lastImportedAt ?? .distantPast
            )
        }

        return accounts.sorted { lhs, rhs in
            if lhs.manualOrder != rhs.manualOrder {
                return lhs.manualOrder < rhs.manualOrder
            }
            if lhs.lastImportedAt != rhs.lastImportedAt {
                return lhs.lastImportedAt < rhs.lastImportedAt
            }
            return lhs.archiveFilename < rhs.archiveFilename
        }
    }

    public func saveManualOrder(idsInOrder: [String]) async throws {
        let loadedAccounts = try await loadAccounts()
        let loadedAccountsByID = loadedAccounts.reduce(into: [String: [Account]]()) { result, account in
            result[account.id, default: []].append(account)
        }
        let remainingIDs = uniqueIDs(in: loadedAccounts.map(\.id)).filter { !idsInOrder.contains($0) }
        let finalIDs = uniqueIDs(in: idsInOrder + remainingIDs)

        var metadata = try fileStore.loadMetadataCache()
        for (index, id) in finalIDs.enumerated() {
            guard let accounts = loadedAccountsByID[id] else {
                continue
            }

            for account in accounts {
                guard let existingEntry = metadata.entries[account.archiveFilename] else {
                    continue
                }

                metadata.entries[account.archiveFilename] = CodexAccountMetadataEntry(
                    source: existingEntry.source,
                    lastImportedAt: existingEntry.lastImportedAt,
                    manualOrder: index
                )
            }
        }

        try fileStore.saveMetadataCache(metadata)
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

    public func removeArchivedAccount(id: String, activeAccountID: String?) async throws -> AccountRemovalResult {
        let accounts = try await loadAccounts()
        guard let removedAccount = accounts.first(where: { $0.id == id }) else {
            throw CodexAuthError.authFileUnreadable
        }

        let fallbackAccount = accounts.first(where: { $0.id != id })

        if activeAccountID == id {
            if let fallbackAccount {
                let fallbackData = try loadArchivedAuthData(for: fallbackAccount.id)
                try fileStore.replaceActiveAuth(with: fallbackData)
            } else {
                try fileStore.clearActiveAuth()
            }
        }

        var metadata = try fileStore.loadMetadataCache()
        metadata.entries.removeValue(forKey: removedAccount.archiveFilename)
        try fileStore.saveMetadataCache(metadata)

        var usageCache = try fileStore.loadUsageCache()
        usageCache.entries.removeValue(forKey: removedAccount.id)
        try fileStore.saveUsageCache(usageCache)

        try fileStore.removeArchive(filename: removedAccount.archiveFilename)

        return AccountRemovalResult(
            removedAccountID: removedAccount.id,
            nextActiveAccountID: activeAccountID == id ? fallbackAccount?.id : activeAccountID
        )
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

    private func uniqueIDs(in ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for id in ids where seen.insert(id).inserted {
            result.append(id)
        }

        return result
    }
}
