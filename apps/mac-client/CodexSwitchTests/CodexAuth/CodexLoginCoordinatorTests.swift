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

    func testLoginCoordinatorWaitsForUpdatedAuthWhenInteractiveLoginStarts() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        try FileManager.default.createDirectory(at: paths.baseDirectory, withIntermediateDirectories: true)
        try sampleAuthData(email: "before@example.com", tier: "pro").write(to: paths.authFileURL)

        let updatedAuthData = try sampleAuthData(email: "after@example.com", tier: "team")
        let writeGate = AuthWriteGate()
        let coordinator = CodexLoginCoordinator(
            runner: StubCodexLoginRunner(result: .started),
            importer: CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths)),
            fileStore: CodexAuthFileStore(paths: paths),
            pollIntervalNanoseconds: 1,
            maxPollAttempts: 2,
            wait: { _ in
                if await writeGate.shouldWriteUpdatedAuth() {
                    try updatedAuthData.write(to: paths.authFileURL, options: .atomic)
                }
            }
        )

        let account = try await coordinator.loginAndImport()

        XCTAssertEqual(account.id, "subject-after@example.com")
        XCTAssertEqual(account.email, "after@example.com")
        XCTAssertEqual(account.source, .browserLogin)
    }

    func testDesktopLoginRunnerWritesBrokerAuthDataToCurrentAuthFile() async throws {
        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let authData = try sampleAuthData(email: "desktop@example.com", tier: "pro")
        let runner = DesktopCodexLoginRunner(
            fileStore: CodexAuthFileStore(paths: paths),
            broker: StubDesktopCodexLoginBroker(authData: authData)
        )

        let result = try await runner.runLogin()

        XCTAssertEqual(result, .success)
        let savedData = try Data(contentsOf: paths.authFileURL)
        XCTAssertEqual(try jsonObject(from: savedData) as? NSDictionary, try jsonObject(from: authData) as? NSDictionary)
        XCTAssertTrue(String(decoding: savedData, as: UTF8.self).contains("\n"))
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

private struct AuthWritingCodexLoginRunner: CodexLoginRunning {
    let authFileURL: URL
    let dataToWrite: Data
    let result: CodexLoginResult

    func runLogin() async throws -> CodexLoginResult {
        try dataToWrite.write(to: authFileURL, options: .atomic)
        return result
    }
}

private struct StubDesktopCodexLoginBroker: CodexDesktopLoginBroking {
    let authData: Data

    func performLogin() async throws -> Data {
        authData
    }
}

private actor AuthWriteGate {
    private var didWriteUpdatedAuth = false

    func shouldWriteUpdatedAuth() -> Bool {
        guard !didWriteUpdatedAuth else {
            return false
        }

        didWriteUpdatedAuth = true
        return true
    }
}
