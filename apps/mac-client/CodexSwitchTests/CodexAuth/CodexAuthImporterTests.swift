import XCTest
@testable import CodexSwitchKit

final class CodexAuthImporterTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
    }

    func testImportCurrentAccountArchivesFullAuthAndCachesMetadata() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let importedAt = Date(timeIntervalSince1970: 1_711_584_800)
        try FileManager.default.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
        try sampleAuthData(email: "alex@example.com", tier: "team").write(to: paths.authFileURL)

        let importer = CodexAuthImporter(
            fileStore: CodexAuthFileStore(paths: paths),
            now: { importedAt }
        )

        let account = try importer.importCurrentAccount()
        let archivedURL = paths.accountsDirectoryURL.appendingPathComponent(account.archiveFilename)
        let metadataData = try Data(contentsOf: paths.accountMetadataCacheURL)
        let metadataCache = try JSONDecoder().decode(CodexAccountMetadataCache.self, from: metadataData)

        XCTAssertEqual(account.id, "subject-alex@example.com")
        XCTAssertEqual(account.source, .currentAuth)
        XCTAssertEqual(account.lastImportedAt, importedAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivedURL.path))
        XCTAssertEqual(metadataCache.entries[account.archiveFilename]?.source, .currentAuth)
    }

    func testImportBackupAuthRejectsMissingIDTokenWithoutWritingArchive() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let backupURL = tempDirectoryURL.appendingPathComponent("backup-auth.json")
        try Data(#"{"tokens":{}}"#.utf8).write(to: backupURL)

        let importer = CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths))

        XCTAssertThrowsError(try importer.importBackupAuth(from: backupURL)) { error in
            XCTAssertEqual(error as? CodexAuthError, .idTokenMissing)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.accountsDirectoryURL.path))
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
            "token_type": "Bearer",
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
