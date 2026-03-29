import XCTest
@testable import CodexSwitchKit

final class DesktopCodexLoginBrokerTests: XCTestCase {
    func testBrokerBuildsCodexCompatibleAuthDataAfterBrowserCallbackSucceeds() async throws {
        let opener = BrowserOpenSpy()
        let callbackServer = StubOAuthCallbackServer(
            redirectURI: URL(string: "http://localhost:1455/auth/callback")!,
            result: .success(.code("browser-code", state: "expected-state"))
        )
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: { callbackServer },
            browserOpener: opener.open(url:),
            tokenExchanger: { code, verifier, redirectURI in
                XCTAssertEqual(code, "browser-code")
                XCTAssertEqual(verifier, "expected-verifier")
                XCTAssertEqual(redirectURI.absoluteString, "http://localhost:1455/auth/callback")
                return CodexOAuthTokenResponse(
                    accessToken: "access-token",
                    refreshToken: "refresh-token",
                    idToken: Self.sampleIDToken(email: "broker@example.com", tier: "team"),
                    accountID: "account-123"
                )
            },
            now: { Self.sampleRefreshDate }
        )

        let authData = try await broker.performLogin()
        let authObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: authData) as? [String: Any])
        let tokens = try XCTUnwrap(authObject["tokens"] as? [String: String])

        XCTAssertEqual(opener.openedURLs.count, 1)
        XCTAssertEqual(authObject["auth_mode"] as? String, "chatgpt")
        XCTAssertEqual(authObject["OPENAI_API_KEY"] as? String, "")
        XCTAssertEqual(authObject["last_refresh"] as? String, "2025-03-28T10:31:12.345Z")
        XCTAssertEqual(tokens["access_token"], "access-token")
        XCTAssertEqual(tokens["refresh_token"], "refresh-token")
        XCTAssertEqual(tokens["account_id"], "account-123")
        XCTAssertEqual(tokens["id_token"], Self.sampleIDToken(email: "broker@example.com", tier: "team"))
        XCTAssertEqual(
            opener.openedURLs.first?.absoluteString,
            "https://auth.openai.com/oauth/authorize?response_type=code&client_id=app_EMoamEEZ73f0CkXaXp7hrann&redirect_uri=http://localhost:1455/auth/callback&scope=openid%20profile%20email%20offline_access&code_challenge=a7vAnVI-b6qjdd18p8m2utvFMMIs0_T3n9RWc495DxQ&code_challenge_method=S256&state=expected-state&originator=codex_chatgpt_desktop&id_token_add_organizations=true&codex_cli_simplified_flow=true&allowed_workspace_id="
        )
        XCTAssertTrue(callbackServer.stopWasCalled)
    }

    func testBrokerMapsAccessDeniedCallbackToLoginCancelled() async {
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: {
                StubOAuthCallbackServer(
                    redirectURI: URL(string: "http://localhost:1455/auth/callback")!,
                    result: .success(.failure(error: "access_denied", description: "cancelled"))
                )
            },
            browserOpener: { _ in true },
            tokenExchanger: { _, _, _ in
                XCTFail("Token exchange should not run after cancellation")
                return CodexOAuthTokenResponse(
                    accessToken: "unused",
                    refreshToken: "unused",
                    idToken: "unused",
                    accountID: "unused"
                )
            }
        )

        do {
            _ = try await broker.performLogin()
            XCTFail("Expected login to be cancelled")
        } catch {
            XCTAssertEqual(error as? CodexAuthError, .loginCancelled)
        }
    }

    func testBrokerMapsCallbackTimeoutToTimedOutError() async {
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: {
                StubOAuthCallbackServer(
                    redirectURI: URL(string: "http://localhost:1455/auth/callback")!,
                    result: .failure(CodexAuthError.loginTimedOut)
                )
            },
            browserOpener: { _ in true },
            tokenExchanger: { _, _, _ in
                XCTFail("Token exchange should not run after timeout")
                return CodexOAuthTokenResponse(
                    accessToken: "unused",
                    refreshToken: "unused",
                    idToken: "unused",
                    accountID: "unused"
                )
            }
        )

        do {
            _ = try await broker.performLogin()
            XCTFail("Expected login to time out")
        } catch {
            XCTAssertEqual(error as? CodexAuthError, .loginTimedOut)
        }
    }

    func testBrokerActivatesAppBeforeOpeningBrowser() async throws {
        var events: [String] = []
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: {
                StubOAuthCallbackServer(
                    redirectURI: URL(string: "http://localhost:1455/auth/callback")!,
                    result: .success(.failure(error: "access_denied", description: "cancelled"))
                )
            },
            browserOpener: { _ in
                events.append("open")
                return true
            },
            applicationActivator: {
                events.append("activate")
            },
            tokenExchanger: { _, _, _ in
                XCTFail("Token exchange should not run when callback reports cancellation")
                return CodexOAuthTokenResponse(
                    accessToken: "unused",
                    refreshToken: "unused",
                    idToken: "unused",
                    accountID: "unused"
                )
            }
        )

        do {
            _ = try await broker.performLogin()
            XCTFail("Expected login to be cancelled")
        } catch {
            XCTAssertEqual(error as? CodexAuthError, .loginCancelled)
        }

        XCTAssertEqual(events, ["activate", "open"])
    }

    func testBrokerFallsBackToSystemOpenCommandWhenPrimaryBrowserOpenerFails() async throws {
        var events: [String] = []
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: {
                StubOAuthCallbackServer(
                    redirectURI: URL(string: "http://localhost:1455/auth/callback")!,
                    result: .success(.failure(error: "access_denied", description: "cancelled"))
                )
            },
            browserOpener: { _ in
                events.append("primary")
                return false
            },
            fallbackBrowserOpener: { _ in
                events.append("fallback")
                return true
            },
            applicationActivator: {
                events.append("activate")
            },
            tokenExchanger: { _, _, _ in
                XCTFail("Token exchange should not run when callback reports cancellation")
                return CodexOAuthTokenResponse(
                    accessToken: "unused",
                    refreshToken: "unused",
                    idToken: "unused",
                    accountID: "unused"
                )
            }
        )

        do {
            _ = try await broker.performLogin()
            XCTFail("Expected login to be cancelled")
        } catch {
            XCTAssertEqual(error as? CodexAuthError, .loginCancelled)
        }

        XCTAssertEqual(events, ["activate", "primary", "fallback"])
    }

    func testBrokerReportsBrowserLaunchFailureWhenAllOpenersFail() async {
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: {
                StubOAuthCallbackServer(
                    redirectURI: URL(string: "http://localhost:1455/auth/callback")!,
                    result: .failure(CodexAuthError.loginTimedOut)
                )
            },
            browserOpener: { _ in false },
            fallbackBrowserOpener: { _ in false },
            applicationActivator: {}
        )

        do {
            _ = try await broker.performLogin()
            XCTFail("Expected browser launch to fail")
        } catch {
            XCTAssertEqual(error as? CodexAuthError, .browserLaunchFailed)
        }
    }

    func testBrokerLogsLifecycleEventsWithoutSecrets() async throws {
        let logger = InMemoryDiagnosticsLogger()
        let callbackServer = StubOAuthCallbackServer(
            redirectURI: URL(string: "http://localhost:1455/auth/callback")!,
            result: .success(.code("browser-code", state: "expected-state"))
        )
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: { callbackServer },
            browserOpener: { _ in true },
            applicationActivator: {},
            tokenExchanger: { _, _, _ in
                CodexOAuthTokenResponse(
                    accessToken: "access-token",
                    refreshToken: "refresh-token",
                    idToken: Self.sampleIDToken(email: "broker@example.com", tier: "team"),
                    accountID: "account-123"
                )
            },
            logger: logger
        )

        _ = try await broker.performLogin()

        XCTAssertTrue(logger.entries.contains(where: { $0.contains("browser_login_started") }))
        XCTAssertTrue(logger.entries.contains(where: { $0.contains("browser_open_primary_result=true") }))
        XCTAssertTrue(logger.entries.contains(where: { $0.contains("callback_received code=true error=false") }))
        XCTAssertTrue(logger.entries.contains(where: { $0.contains("token_exchange_started") }))
        XCTAssertTrue(logger.entries.contains(where: { $0.contains("token_exchange_succeeded") }))
        XCTAssertFalse(logger.entries.contains(where: { $0.contains("browser-code") }))
        XCTAssertFalse(logger.entries.contains(where: { $0.contains("access-token") }))
    }

    func testBrokerStopsCallbackServerWhenLoginTaskIsCancelled() async throws {
        let callbackServer = BlockingOAuthCallbackServer(
            redirectURI: URL(string: "http://localhost:1455/auth/callback")!
        )
        let broker = DesktopCodexLoginBroker(
            callbackServerFactory: { callbackServer },
            browserOpener: { _ in true },
            applicationActivator: {}
        )

        let loginTask = Task {
            try await broker.performLogin()
        }

        try await waitForCondition { callbackServer.didBeginWaiting() }
        loginTask.cancel()

        do {
            _ = try await loginTask.value
            XCTFail("Expected login task to be cancelled")
        } catch is CancellationError {
            XCTAssertTrue(callbackServer.stopWasCalled)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    private static let sampleRefreshDate = Date(timeIntervalSince1970: 1_743_157_872.345)

    private static func sampleIDToken(email: String, tier: String) -> String {
        let payload = [
            "sub": "subject-\(email)",
            "email": email,
            "tier": tier,
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadData = try! encoder.encode(payload)
        return [
            base64URL(#"{"alg":"none","typ":"JWT"}"#),
            base64URL(String(data: payloadData, encoding: .utf8)!),
            "signature",
        ].joined(separator: ".")
    }

    private static func base64URL(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func waitForCondition(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<200 {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for condition", file: file, line: line)
    }
}

private final class BrowserOpenSpy {
    private(set) var openedURLs: [URL] = []

    func open(url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}

private final class InMemoryDiagnosticsLogger: CodexDiagnosticsLogging {
    private(set) var entries: [String] = []

    func log(_ message: String) {
        entries.append(message)
    }
}

private final class StubOAuthCallbackServer: OAuthCallbackServing {
    let redirectURI: URL
    let result: Result<OAuthCallbackResult, Error>
    private(set) var stopWasCalled = false

    init(redirectURI: URL, result: Result<OAuthCallbackResult, Error>) {
        self.redirectURI = redirectURI
        self.result = result
    }

    func waitForCallback() async throws -> OAuthCallbackResult {
        try result.get()
    }

    func stop() {
        stopWasCalled = true
    }
}

private final class BlockingOAuthCallbackServer: OAuthCallbackServing {
    let redirectURI: URL
    private let lock = NSLock()
    private var _stopWasCalled = false
    private var _hasStartedWaiting = false

    init(redirectURI: URL) {
        self.redirectURI = redirectURI
    }

    func waitForCallback() async throws -> OAuthCallbackResult {
        markStartedWaiting()

        while true {
            if didStop() {
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        throw CodexAuthError.loginFailed
    }

    func stop() {
        lock.lock()
        _stopWasCalled = true
        lock.unlock()
    }

    func didBeginWaiting() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasStartedWaiting
    }

    var stopWasCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _stopWasCalled
    }

    private func markStartedWaiting() {
        lock.lock()
        _hasStartedWaiting = true
        lock.unlock()
    }

    private func didStop() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _stopWasCalled
    }
}
