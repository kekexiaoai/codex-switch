import XCTest
@testable import CodexSwitchKit

final class CodexAuthFileStoreTests: XCTestCase {
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

    func testWriteArchivePrettyPrintsAuthJSON() throws {
        let fileStore = CodexAuthFileStore(paths: CodexPaths(baseDirectory: tempDirectoryURL))
        let authData = try minifiedAuthData(email: "archive@example.com")

        try fileStore.writeArchive(data: authData, filename: "archive.json")

        let saved = try String(
            contentsOf: tempDirectoryURL.appendingPathComponent("accounts/archive.json"),
            encoding: .utf8
        )
        XCTAssertTrue(saved.contains("\n"))
        XCTAssertTrue(saved.contains("  \"tokens\""))
    }

    func testReplaceActiveAuthPrettyPrintsAuthJSON() throws {
        let fileStore = CodexAuthFileStore(paths: CodexPaths(baseDirectory: tempDirectoryURL))
        let authData = try minifiedAuthData(email: "active@example.com")

        try fileStore.replaceActiveAuth(with: authData)

        let saved = try String(
            contentsOf: tempDirectoryURL.appendingPathComponent("auth.json"),
            encoding: .utf8
        )
        XCTAssertTrue(saved.contains("\n"))
        XCTAssertTrue(saved.contains("  \"tokens\""))
    }

    private func minifiedAuthData(email: String) throws -> Data {
        let payload = [
            "sub": "subject-\(email)",
            "email": email,
            "tier": "team",
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let token = [
            base64URL(#"{"alg":"none","typ":"JWT"}"#),
            base64URL(String(data: payloadData, encoding: .utf8)!),
            "signature",
        ].joined(separator: ".")
        let object: [String: Any] = [
            "OPENAI_API_KEY": "",
            "auth_mode": "chatgpt",
            "tokens": [
                "id_token": token,
                "access_token": "access-token",
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
