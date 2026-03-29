import XCTest
@testable import CodexSwitchKit

final class DesktopCodexLoginBrokerTests: XCTestCase {
    func testBrokerBuildsCodexCompatibleAuthDataAfterBrowserCallbackSucceeds() async throws {
        let opener = BrowserOpenSpy()
        let callbackServer = StubOAuthCallbackServer(
            redirectURI: URL(string: "http://127.0.0.1:8787/auth/callback")!,
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
                XCTAssertEqual(redirectURI.absoluteString, "http://127.0.0.1:8787/auth/callback")
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
            "https://auth.openai.com/oauth/authorize?response_type=code&client_id=app_EMoamEEZ73f0CkXaXp7hrann&redirect_uri=http://127.0.0.1:8787/auth/callback&scope=openid%20profile%20email%20offline_access&code_challenge=a7vAnVI-b6qjdd18p8m2utvFMMIs0_T3n9RWc495DxQ&code_challenge_method=S256&state=expected-state&originator=codex_chatgpt_desktop&id_token_add_organizations=true&allowed_workspace_id="
        )
        XCTAssertTrue(callbackServer.stopWasCalled)
    }

    func testBrokerMapsAccessDeniedCallbackToLoginCancelled() async {
        let broker = DesktopCodexLoginBroker(
            stateGenerator: { "expected-state" },
            codeVerifierGenerator: { "expected-verifier" },
            callbackServerFactory: {
                StubOAuthCallbackServer(
                    redirectURI: URL(string: "http://127.0.0.1:8787/auth/callback")!,
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
                    redirectURI: URL(string: "http://127.0.0.1:8787/auth/callback")!,
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
}

private final class BrowserOpenSpy {
    private(set) var openedURLs: [URL] = []

    func open(url: URL) -> Bool {
        openedURLs.append(url)
        return true
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
