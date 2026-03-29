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
    private let metadataStore: any AccountMetadataStore
    private let credentialStore: any CredentialStore

    public init(
        metadataStore: any AccountMetadataStore,
        credentialStore: any CredentialStore
    ) {
        self.metadataStore = metadataStore
        self.credentialStore = credentialStore
    }

    public func save(account: Account, secret: String) async throws {
        var accounts = try await metadataStore.loadAccounts()
        let sanitized = Account(
            id: account.id,
            emailMask: account.emailMask,
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
        try await metadataStore.loadAccounts().map {
            Account(id: $0.id, emailMask: $0.emailMask, tier: $0.tier)
        }
    }

    public func loadSecret(for accountID: String) async throws -> String? {
        try await credentialStore.loadSecret(for: accountID)
    }
}

public actor InMemoryAccountMetadataStore: AccountMetadataStore {
    private var accounts: [Account] = []

    public init() {}

    public func loadAccounts() -> [Account] {
        accounts
    }

    public func saveAccounts(_ accounts: [Account]) {
        self.accounts = accounts
    }
}

public actor InMemoryCredentialStore: CredentialStore {
    private var secrets: [String: String] = [:]

    public init() {}

    public func saveSecret(_ secret: String, for accountID: String) {
        secrets[accountID] = secret
    }

    public func loadSecret(for accountID: String) -> String? {
        secrets[accountID]
    }
}
