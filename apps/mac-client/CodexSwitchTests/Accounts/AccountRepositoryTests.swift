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

    func testRepositoryLoadsAccountsFromArchivedCodexAuthFiles() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: "alex@example.com")
        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        try sampleAuthData(email: "alex@example.com", tier: "team").write(
            to: paths.accountsDirectoryURL.appendingPathComponent(archiveFilename)
        )
        let metadata = CodexAccountMetadataCache(entries: [
            archiveFilename: CodexAccountMetadataEntry(
                source: .currentAuth,
                lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)
            ),
        ])
        try JSONEncoder().encode(metadata).write(to: paths.accountMetadataCacheURL)

        let repository = AccountRepository(catalog: CodexArchivedAccountStore(fileStore: CodexAuthFileStore(paths: paths)))

        let loaded = try await repository.loadAccounts()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "subject-alex@example.com")
        XCTAssertEqual(loaded.first?.archiveFilename, archiveFilename)
        XCTAssertEqual(loaded.first?.source, .currentAuth)
    }

    private func sampleAuthData(email: String, tier: String) throws -> Data {
        let payload = [
            "sub": "subject-\(email)",
            "email": email,
            "tier": tier,
        ]
        let token = [
            base64URL(#"{"alg":"none","typ":"JWT"}"#),
            base64URL(String(data: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), encoding: .utf8)!),
            "signature",
        ].joined(separator: ".")
        let object: [String: Any] = [
            "tokens": [
                "id_token": token,
            ],
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func base64URL(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
