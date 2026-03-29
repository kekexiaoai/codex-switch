import XCTest
@testable import CodexSwitchKit

final class CodexLoginCoordinatorTests: XCTestCase {
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

    func testLoginCoordinatorImportsCurrentAuthAfterSuccessfulLogin() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        try FileManager.default.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
        try sampleAuthData(email: "alex@example.com", tier: "team").write(to: paths.authFileURL)

        let coordinator = CodexLoginCoordinator(
            runner: StubCodexLoginRunner(result: .success),
            importer: CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths)),
            fileStore: CodexAuthFileStore(paths: paths)
        )

        let account = try await coordinator.loginAndImport()

        XCTAssertEqual(account.id, "subject-alex@example.com")
        XCTAssertEqual(account.source, .browserLogin)
    }

    func testLoginCoordinatorMapsCancelledLoginToUserFacingError() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let coordinator = CodexLoginCoordinator(
            runner: StubCodexLoginRunner(result: .cancelled),
            importer: CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths)),
            fileStore: CodexAuthFileStore(paths: paths)
        )

        do {
            _ = try await coordinator.loginAndImport()
            XCTFail("Expected login to be cancelled")
        } catch {
            XCTAssertEqual(error as? CodexAuthError, .loginCancelled)
        }
    }

    func testLoginCoordinatorImportsUpdatedAuthWhenRunnerReportsFailure() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        try FileManager.default.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
        try sampleAuthData(email: "before@example.com", tier: "pro").write(to: paths.authFileURL)

        let updatedAuthData = try sampleAuthData(email: "after@example.com", tier: "team")
        let coordinator = CodexLoginCoordinator(
            runner: AuthWritingCodexLoginRunner(authFileURL: paths.authFileURL, dataToWrite: updatedAuthData, result: .failure),
            importer: CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths)),
            fileStore: CodexAuthFileStore(paths: paths)
        )

        let account = try await coordinator.loginAndImport()

        XCTAssertEqual(account.id, "subject-after@example.com")
        XCTAssertEqual(account.email, "after@example.com")
        XCTAssertEqual(account.source, .browserLogin)
    }

    func testProcessLoginRunnerMapsExitCodesToCoordinatorResults() {
        XCTAssertEqual(ProcessCodexLoginRunner.result(forExitStatus: 0), .success)
        XCTAssertEqual(ProcessCodexLoginRunner.result(forExitStatus: 130), .cancelled)
        XCTAssertEqual(ProcessCodexLoginRunner.result(forExitStatus: 1), .failure)
    }

    func testProcessLoginRunnerUsesLoginShellToResolveCodexCLI() {
        let process = ProcessCodexLoginRunner.makeProcess()

        XCTAssertEqual(process.executableURL?.path, "/bin/zsh")
        XCTAssertEqual(process.arguments, ["-lc", "codex login"])
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

private struct AuthWritingCodexLoginRunner: CodexLoginRunning {
    let authFileURL: URL
    let dataToWrite: Data
    let result: CodexLoginResult

    func runLogin() async throws -> CodexLoginResult {
        try dataToWrite.write(to: authFileURL, options: .atomic)
        return result
    }
}
