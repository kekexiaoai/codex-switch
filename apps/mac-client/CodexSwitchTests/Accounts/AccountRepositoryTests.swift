import XCTest
@testable import CodexSwitchKit

final class AccountRepositoryTests: XCTestCase {
    func testRepositoryPersistsAccountMetadataSeparatelyFromSecrets() async throws {
        let repository = AccountRepository(
            metadataStore: InMemoryAccountMetadataStore(),
            credentialStore: InMemoryCredentialStore()
        )

        let account = Account(id: "acct-1", emailMask: "a••••@gmail.com", tier: .team)
        try await repository.save(account: account, secret: "token-123")

        let loaded = try await repository.loadAccounts()

        XCTAssertEqual(loaded.first?.emailMask, account.emailMask)
        XCTAssertNil(loaded.first?.embeddedSecret)
    }
}
