import XCTest
@testable import CodexSwitchKit

final class CodexArchivedAccountStoreTests: XCTestCase {
    func testRemoveArchivedAccountDeletesInactiveAccountFileAndMetadata() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let paths = CodexPaths(baseDirectory: baseDirectory)
        let fileStore = CodexAuthFileStore(paths: paths)
        let store = CodexArchivedAccountStore(fileStore: fileStore)

        let alexFilename = CodexArchiveNaming.archiveFilename(for: "alex@example.com")
        let bethFilename = CodexArchiveNaming.archiveFilename(for: "beth@example.com")
        try fileStore.writeArchive(data: try sampleAuthData(email: "alex@example.com", tier: "team"), filename: alexFilename)
        try fileStore.writeArchive(data: try sampleAuthData(email: "beth@example.com", tier: "pro"), filename: bethFilename)
        try fileStore.saveMetadataCache(
            CodexAccountMetadataCache(entries: [
                alexFilename: CodexAccountMetadataEntry(source: .currentAuth, lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)),
                bethFilename: CodexAccountMetadataEntry(source: .backupImport, lastImportedAt: Date(timeIntervalSince1970: 1_711_585_800)),
            ])
        )

        let result = try await store.removeArchivedAccount(
            id: "subject-alex@example.com",
            activeAccountID: "subject-beth@example.com"
        )

        XCTAssertEqual(result.removedAccountID, "subject-alex@example.com")
        XCTAssertEqual(result.nextActiveAccountID, "subject-beth@example.com")
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.accountsDirectoryURL.appendingPathComponent(alexFilename).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.accountsDirectoryURL.appendingPathComponent(bethFilename).path))
        let metadata = try fileStore.loadMetadataCache()
        XCTAssertNil(metadata.entries[alexFilename])
        XCTAssertNotNil(metadata.entries[bethFilename])
    }

    func testRemoveArchivedAccountReplacesActiveAuthWithFallbackWhenRemovingActiveAccount() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let paths = CodexPaths(baseDirectory: baseDirectory)
        let fileStore = CodexAuthFileStore(paths: paths)
        let store = CodexArchivedAccountStore(fileStore: fileStore)

        let alexData = try sampleAuthData(email: "alex@example.com", tier: "team")
        let bethData = try sampleAuthData(email: "beth@example.com", tier: "pro")
        let alexFilename = CodexArchiveNaming.archiveFilename(for: "alex@example.com")
        let bethFilename = CodexArchiveNaming.archiveFilename(for: "beth@example.com")
        try fileStore.writeArchive(data: alexData, filename: alexFilename)
        try fileStore.writeArchive(data: bethData, filename: bethFilename)
        try fileStore.saveMetadataCache(
            CodexAccountMetadataCache(entries: [
                alexFilename: CodexAccountMetadataEntry(source: .currentAuth, lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)),
                bethFilename: CodexAccountMetadataEntry(source: .backupImport, lastImportedAt: Date(timeIntervalSince1970: 1_711_585_800)),
            ])
        )
        try fileStore.replaceActiveAuth(with: alexData)

        let result = try await store.removeArchivedAccount(
            id: "subject-alex@example.com",
            activeAccountID: "subject-alex@example.com"
        )

        XCTAssertEqual(result.removedAccountID, "subject-alex@example.com")
        XCTAssertEqual(result.nextActiveAccountID, "subject-beth@example.com")
        let activeData = try fileStore.readCurrentAuthData()
        XCTAssertEqual(try jsonObject(from: activeData) as? NSDictionary, try jsonObject(from: bethData) as? NSDictionary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.accountsDirectoryURL.appendingPathComponent(alexFilename).path))
    }

    func testRemoveArchivedAccountClearsCurrentAuthWhenRemovingLastActiveAccount() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let paths = CodexPaths(baseDirectory: baseDirectory)
        let fileStore = CodexAuthFileStore(paths: paths)
        let store = CodexArchivedAccountStore(fileStore: fileStore)

        let alexData = try sampleAuthData(email: "alex@example.com", tier: "team")
        let alexFilename = CodexArchiveNaming.archiveFilename(for: "alex@example.com")
        try fileStore.writeArchive(data: alexData, filename: alexFilename)
        try fileStore.saveMetadataCache(
            CodexAccountMetadataCache(entries: [
                alexFilename: CodexAccountMetadataEntry(source: .currentAuth, lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)),
            ])
        )
        try fileStore.replaceActiveAuth(with: alexData)

        let result = try await store.removeArchivedAccount(
            id: "subject-alex@example.com",
            activeAccountID: "subject-alex@example.com"
        )

        XCTAssertEqual(result.removedAccountID, "subject-alex@example.com")
        XCTAssertNil(result.nextActiveAccountID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.authFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.accountsDirectoryURL.appendingPathComponent(alexFilename).path))
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

    private func jsonObject(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }
}
