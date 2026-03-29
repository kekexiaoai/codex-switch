import Foundation

public protocol AccountMetadataStore {
    func loadAccounts() async throws -> [Account]
    func saveAccounts(_ accounts: [Account]) async throws
}

public protocol CredentialStore {
    func saveSecret(_ secret: String, for accountID: String) async throws
    func loadSecret(for accountID: String) async throws -> String?
}

public struct AccountRepository {
    private let catalog: (any AccountCatalog)?
    private let metadataStore: any AccountMetadataStore
    private let credentialStore: any CredentialStore

    public init(
        metadataStore: any AccountMetadataStore,
        credentialStore: any CredentialStore
    ) {
        self.catalog = nil
        self.metadataStore = metadataStore
        self.credentialStore = credentialStore
    }

    public init(catalog: any AccountCatalog) {
        self.catalog = catalog
        self.metadataStore = InMemoryAccountMetadataStore()
        self.credentialStore = InMemoryCredentialStore()
    }

    public func save(account: Account, secret: String) async throws {
        var accounts = try await metadataStore.loadAccounts()
        let sanitized = Account(
            id: account.id,
            emailMask: account.emailMask,
            email: account.email,
            tier: account.tier
        )

        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = sanitized
        } else {
            accounts.append(sanitized)
        }

        try await metadataStore.saveAccounts(accounts)
        try await credentialStore.saveSecret(secret, for: account.id)
    }

    public func loadAccounts() async throws -> [Account] {
        if let catalog {
            return try await catalog.loadAccounts()
        }

        return try await metadataStore.loadAccounts().map {
            Account(
                id: $0.id,
                emailMask: $0.emailMask,
                email: $0.email,
                tier: $0.tier,
                archiveFilename: $0.archiveFilename,
                source: $0.source,
                lastImportedAt: $0.lastImportedAt
            )
        }
    }

    public func loadSecret(for accountID: String) async throws -> String? {
        try await credentialStore.loadSecret(for: accountID)
    }
}

public actor InMemoryAccountMetadataStore: AccountMetadataStore {
    private var accounts: [Account] = []

    public init(accounts: [Account] = []) {
        self.accounts = accounts
    }

    public func loadAccounts() -> [Account] {
        accounts
    }

    public func saveAccounts(_ accounts: [Account]) {
        self.accounts = accounts
    }
}

public actor InMemoryCredentialStore: CredentialStore {
    private var secrets: [String: String] = [:]

    public init(secrets: [String: String] = [:]) {
        self.secrets = secrets
    }

    public func saveSecret(_ secret: String, for accountID: String) {
        secrets[accountID] = secret
    }

    public func loadSecret(for accountID: String) -> String? {
        secrets[accountID]
    }
}
