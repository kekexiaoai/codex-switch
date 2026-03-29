import XCTest
@testable import CodexSwitchKit

final class RealIntegrationSmokeTests: XCTestCase {
    @MainActor
    func testRealEnvironmentCanResolveConfiguredAccountBackend() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: "fixture@example.com")
        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        try sampleAuthData(email: "fixture@example.com", tier: "team").write(
            to: paths.accountsDirectoryURL.appendingPathComponent(archiveFilename)
        )
        let metadata = CodexAccountMetadataCache(entries: [
            archiveFilename: CodexAccountMetadataEntry(
                source: .currentAuth,
                lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)
            ),
        ])
        try JSONEncoder().encode(metadata).write(to: paths.accountMetadataCacheURL)
        let usageCache = CodexUsageCache(entries: [
            "subject-fixture@example.com": CodexUsageSnapshot(
                accountID: "subject-fixture@example.com",
                updatedAt: Date(timeIntervalSince1970: 1_711_584_800),
                fiveHour: CodexUsageWindow(percentUsed: 42, resetsAt: Date(timeIntervalSince1970: 1_711_591_000)),
                weekly: CodexUsageWindow(percentUsed: 24, resetsAt: Date(timeIntervalSince1970: 1_711_900_000))
            ),
        ])
        try JSONEncoder().encode(usageCache).write(to: paths.usageCacheURL)

        let environment = try AppEnvironment.live(
            configuration: RuntimeConfiguration(
                paths: paths,
                loginRunner: StubCodexLoginRunner(result: .success)
            )
        )

        XCTAssertEqual(environment.runtimeMode, .live)
        XCTAssertNotNil(environment.accountRepository)
        XCTAssertNotNil(environment.activeAccountController)
        let accounts = try await environment.accountRepository?.loadAccounts()
        XCTAssertEqual(accounts?.first?.emailMask, "f••••••@example.com")
        XCTAssertEqual(accounts?.first?.email, "fixture@example.com")
        let snapshot = await environment.usageService.usageSnapshot(for: "subject-fixture@example.com")
        XCTAssertEqual(snapshot?.fiveHour.percentUsed, 42)
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
