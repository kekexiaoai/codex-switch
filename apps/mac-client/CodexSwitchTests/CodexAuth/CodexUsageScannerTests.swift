import XCTest
@testable import CodexSwitchKit

final class CodexUsageScannerTests: XCTestCase {
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

    func testUsageScannerParsesLatestMatchingRolloutEntry() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        try FileManager.default.createDirectory(at: paths.sessionsDirectoryURL, withIntermediateDirectories: true)
        let logURL = paths.sessionsDirectoryURL.appendingPathComponent("rollout-2026-03-28.jsonl")
        let lines = [
            #"{"timestamp":"2026-03-28T08:00:00Z","email":"other@example.com","rate_limits":{"five_hour":{"used_percent":10,"resets_at":"2026-03-28T10:00:00Z"},"weekly":{"used_percent":20,"resets_at":"2026-04-01T00:00:00Z"}}}"#,
            #"{"timestamp":"2026-03-28T09:00:00Z","email":"alex@example.com","rate_limits":{"five_hour":{"used_percent":42,"resets_at":"2026-03-28T10:30:00Z"},"weekly":{"used_percent":24,"resets_at":"2026-04-02T00:00:00Z"}}}"#,
        ].joined(separator: "\n")
        try Data(lines.utf8).write(to: logURL)

        let scanner = CodexUsageScanner(paths: paths)
        let account = Account(
            id: "subject-alex@example.com",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )

        let snapshot = try scanner.refreshUsage(for: account)

        XCTAssertEqual(snapshot.fiveHour.percentUsed, 42)
        XCTAssertEqual(snapshot.weekly.percentUsed, 24)
    }

    func testUsageScannerFallsBackToCachedSnapshotWhenNoFreshLogExists() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let cachedSnapshot = CodexUsageSnapshot(
            accountID: "subject-alex@example.com",
            updatedAt: Date(timeIntervalSince1970: 1_711_584_800),
            fiveHour: CodexUsageWindow(percentUsed: 40, resetsAt: Date(timeIntervalSince1970: 1_711_591_000)),
            weekly: CodexUsageWindow(percentUsed: 22, resetsAt: Date(timeIntervalSince1970: 1_711_900_000))
        )
        let cache = CodexUsageCache(entries: [
            "subject-alex@example.com": cachedSnapshot,
        ])
        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(cache).write(to: paths.usageCacheURL)

        let scanner = CodexUsageScanner(paths: paths)
        let account = Account(
            id: "subject-alex@example.com",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )

        let snapshot = try scanner.refreshUsage(for: account)

        XCTAssertEqual(snapshot, cachedSnapshot)
    }

    func testUsageScannerParsesNestedTokenCountRateLimitsFromRolloutEntry() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        try FileManager.default.createDirectory(at: paths.sessionsDirectoryURL, withIntermediateDirectories: true)
        let logURL = paths.sessionsDirectoryURL.appendingPathComponent("rollout-2026-03-29.jsonl")
        let lines = [
            #"{"timestamp":"2026-03-29T09:00:00Z","email":"alex@example.com","event_msg":{"token_count":{"rate_limits":{"five_hour":{"used_percent":61,"resets_at":"2026-03-29T10:30:00Z"},"weekly":{"used_percent":33,"resets_at":"2026-04-02T00:00:00Z"}}}}}"#,
        ].joined(separator: "\n")
        try Data(lines.utf8).write(to: logURL)

        let scanner = CodexUsageScanner(paths: paths)
        let account = Account(
            id: "google-oauth2|123",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )

        let snapshot = try scanner.refreshUsage(for: account)

        XCTAssertEqual(snapshot.fiveHour.percentUsed, 61)
        XCTAssertEqual(snapshot.weekly.percentUsed, 33)
    }

    func testUsageScannerParsesCurrentAccountUsageFromNestedRolloutFileHierarchy() throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let nestedDirectory = paths.sessionsDirectoryURL
            .appendingPathComponent("2026", isDirectory: true)
            .appendingPathComponent("03", isDirectory: true)
            .appendingPathComponent("29", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)

        let currentAuth = try sampleAuthData(
            email: "alex@example.com",
            accountID: "google-oauth2|123",
            tier: "team"
        )
        try currentAuth.write(to: paths.authFileURL)

        let logURL = nestedDirectory.appendingPathComponent("rollout-2026-03-29T12-18-11.jsonl")
        let lines = [
            #"{"timestamp":"2026-03-29T04:20:10.848Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":193134,"cached_input_tokens":150272,"output_tokens":1666,"reasoning_output_tokens":131,"total_tokens":194800},"last_token_usage":{"input_tokens":47061,"cached_input_tokens":45312,"output_tokens":335,"reasoning_output_tokens":17,"total_tokens":47396},"model_context_window":258400},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":0.0,"window_minutes":300,"resets_at":1774775972},"secondary":{"used_percent":16.0,"window_minutes":10080,"resets_at":1775182274},"credits":null,"plan_type":"team"}}}"#,
        ].joined(separator: "\n")
        try Data(lines.utf8).write(to: logURL)

        let scanner = CodexUsageScanner(paths: paths)
        let account = Account(
            id: "google-oauth2|123",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )

        let snapshot = try scanner.refreshUsage(for: account)

        XCTAssertEqual(snapshot.fiveHour.percentUsed, 0)
        XCTAssertEqual(snapshot.weekly.percentUsed, 16)
        XCTAssertEqual(snapshot.fiveHour.resetsAt, Date(timeIntervalSince1970: 1_774_775_972))
        XCTAssertEqual(snapshot.weekly.resetsAt, Date(timeIntervalSince1970: 1_775_182_274))
    }

    private func sampleAuthData(email: String, accountID: String, tier: String) throws -> Data {
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
