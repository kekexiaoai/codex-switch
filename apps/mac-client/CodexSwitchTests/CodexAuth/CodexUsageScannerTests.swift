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
}
