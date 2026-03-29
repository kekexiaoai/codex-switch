import XCTest
@testable import CodexSwitchKit

@MainActor
final class ActiveAccountControllerTests: XCTestCase {
    func testSwitchingAccountMarksSelectionAndRefreshesUsage() async throws {
        let controller = ActiveAccountController(
            switcher: StubSwitchCommandRunner(),
            usageService: StubUsageRefreshService()
        )

        try await controller.activateAccount(id: "acct-2")

        XCTAssertEqual(controller.activeAccountID, "acct-2")
        XCTAssertEqual(controller.lastRefreshSource, "switch")
    }

    func testSwitchingAccountKeepsActivatedStateWhenUsageDataMissing() async throws {
        let controller = ActiveAccountController(
            switcher: StubSwitchCommandRunner(),
            usageService: FailingUsageRefreshService(error: .noUsageData)
        )

        try await controller.activateAccount(id: "acct-2")

        XCTAssertEqual(controller.activeAccountID, "acct-2")
        XCTAssertEqual(controller.lastRefreshSource, "switch")
    }

    func testCodexAccountSwitcherReplacesActiveAuthWithArchivedAuth() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: "alex@example.com")
        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        let archivedData = try sampleAuthData(email: "alex@example.com", tier: "team")
        try archivedData.write(to: paths.accountsDirectoryURL.appendingPathComponent(archiveFilename))
        let metadata = CodexAccountMetadataCache(entries: [
            archiveFilename: CodexAccountMetadataEntry(
                source: .currentAuth,
                lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)
            ),
        ])
        try JSONEncoder().encode(metadata).write(to: paths.accountMetadataCacheURL)
        try Data("old-auth".utf8).write(to: paths.authFileURL)

        let switcher = CodexAccountSwitcher(
            archivedAccountStore: CodexArchivedAccountStore(fileStore: CodexAuthFileStore(paths: paths)),
            fileStore: CodexAuthFileStore(paths: paths)
        )

        try await switcher.activateAccount(id: "subject-alex@example.com")

        let activeData = try Data(contentsOf: paths.authFileURL)
        XCTAssertEqual(try jsonObject(from: activeData) as? NSDictionary, try jsonObject(from: archivedData) as? NSDictionary)
        XCTAssertTrue(String(decoding: activeData, as: UTF8.self).contains("\n"))
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

private struct FailingUsageRefreshService: UsageRefreshing {
    let error: CodexAuthError

    func refresh(reason: UsageRefreshReason) async throws -> [UsageSummaryModel] {
        throw error
    }
}
