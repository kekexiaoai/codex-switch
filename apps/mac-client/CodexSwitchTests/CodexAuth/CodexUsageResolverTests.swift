import Foundation
import XCTest
@testable import CodexSwitchKit

final class CodexUsageResolverTests: XCTestCase {
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

    func testAutomaticModePrefersRemoteUsageAndCachesIt() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        try makeCurrentSessionDirectory(paths: paths)

        let authData = try sampleAuthData(
            email: "alex@example.com",
            accountID: "google-oauth2|123",
            tier: "team",
            accessToken: "access-token",
            transportAccountID: "chatgpt-account-id"
        )
        let account = Account(
            id: "google-oauth2|123",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )
        let apiClient = CodexUsageAPIClient(
            transport: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "chatgpt-account-id")
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = Data(
                    #"""
                    {
                      "email": "alex@example.com",
                      "rate_limit": {
                        "primary_window": {
                          "used_percent": 9,
                          "resets_at": "2026-03-29T10:30:00Z"
                        },
                        "secondary_window": {
                          "used_percent": 27,
                          "resets_at": "2026-04-02T00:00:00Z"
                        }
                      }
                    }
                    """#.utf8
                )
                return (data, response)
            },
            now: { Date(timeIntervalSince1970: 1_743_241_200) }
        )
        let resolver = CodexUsageResolver(
            scanner: CodexUsageScanner(paths: paths),
            apiClient: apiClient
        )

        let snapshot = try await resolver.refreshUsage(
            for: account,
            authData: authData,
            mode: .automatic
        )

        XCTAssertEqual(snapshot.fiveHour.percentUsed, 9)
        XCTAssertEqual(snapshot.weekly.percentUsed, 27)

        let cache = try JSONDecoder().decode(CodexUsageCache.self, from: Data(contentsOf: paths.usageCacheURL))
        XCTAssertEqual(cache.entries[account.id]?.fiveHour.percentUsed, 9)
        XCTAssertEqual(cache.entries[account.id]?.weekly.percentUsed, 27)
    }

    func testAutomaticModeFallsBackToLocalSessionsWhenRemoteFetchFails() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let sessionDirectory = try makeCurrentSessionDirectory(paths: paths)
        let logURL = sessionDirectory.appendingPathComponent("rollout-2026-03-29.jsonl")
        try Data(
            #"""
            {"timestamp":"2026-03-29T08:00:00Z","email":"alex@example.com","rate_limits":{"five_hour":{"used_percent":61,"resets_at":"2026-03-29T10:30:00Z"},"weekly":{"used_percent":22,"resets_at":"2026-04-02T00:00:00Z"}}}
            """#.utf8
        ).write(to: logURL)

        let authData = try sampleAuthData(
            email: "alex@example.com",
            accountID: "google-oauth2|123",
            tier: "team",
            accessToken: "access-token",
            transportAccountID: "chatgpt-account-id"
        )
        try authData.write(to: paths.authFileURL)
        let account = Account(
            id: "google-oauth2|123",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )
        let resolver = CodexUsageResolver(
            scanner: CodexUsageScanner(paths: paths),
            apiClient: CodexUsageAPIClient(
                transport: { _ in
                    throw CodexUsageAPIClient.Error.unauthorized
                }
            )
        )

        let snapshot = try await resolver.refreshUsage(
            for: account,
            authData: authData,
            mode: .automatic
        )

        XCTAssertEqual(snapshot.fiveHour.percentUsed, 61)
        XCTAssertEqual(snapshot.weekly.percentUsed, 22)
    }

    func testLocalOnlyModeSkipsRemoteUsageFetch() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let sessionDirectory = try makeCurrentSessionDirectory(paths: paths)
        let logURL = sessionDirectory.appendingPathComponent("rollout-2026-03-29.jsonl")
        try Data(
            #"""
            {"timestamp":"2026-03-29T08:00:00Z","email":"alex@example.com","rate_limits":{"five_hour":{"used_percent":44,"resets_at":"2026-03-29T10:30:00Z"},"weekly":{"used_percent":18,"resets_at":"2026-04-02T00:00:00Z"}}}
            """#.utf8
        ).write(to: logURL)

        let authData = try sampleAuthData(
            email: "alex@example.com",
            accountID: "google-oauth2|123",
            tier: "team",
            accessToken: "access-token",
            transportAccountID: "chatgpt-account-id"
        )
        try authData.write(to: paths.authFileURL)
        let account = Account(
            id: "google-oauth2|123",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )

        let counter = Counter()
        let resolver = CodexUsageResolver(
            scanner: CodexUsageScanner(paths: paths),
            apiClient: CodexUsageAPIClient(
                transport: { _ in
                    await counter.increment()
                    throw CodexUsageAPIClient.Error.unauthorized
                }
            )
        )

        let snapshot = try await resolver.refreshUsage(
            for: account,
            authData: authData,
            mode: .localOnly
        )

        let remoteCallCount = await counter.value
        XCTAssertEqual(remoteCallCount, 0)
        XCTAssertEqual(snapshot.fiveHour.percentUsed, 44)
        XCTAssertEqual(snapshot.weekly.percentUsed, 18)
    }

    private func sampleAuthData(
        email: String,
        accountID: String,
        tier: String,
        accessToken: String,
        transportAccountID: String
    ) throws -> Data {
        let payload: [String: Any] = [
            "sub": accountID,
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
                "access_token": accessToken,
                "account_id": transportAccountID,
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

    @discardableResult
    private func makeCurrentSessionDirectory(paths: CodexPaths) throws -> URL {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let directory = paths.sessionsDirectoryURL
            .appendingPathComponent(String(components.year ?? 0), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.month ?? 0), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.day ?? 0), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
