import AppKit
import CryptoKit
import Foundation
import Network

public protocol CodexDesktopLoginBroking {
    func performLogin() async throws -> Data
}

public enum OAuthCallbackResult: Equatable {
    case code(String, state: String)
    case failure(error: String, description: String?)
}

public protocol OAuthCallbackServing {
    var redirectURI: URL { get }
    func waitForCallback() async throws -> OAuthCallbackResult
    func stop()
}

public struct CodexOAuthTokenResponse: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let idToken: String
    public let accountID: String?

    public init(accessToken: String, refreshToken: String, idToken: String, accountID: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.accountID = accountID
    }
}

public struct DesktopCodexLoginBroker: CodexDesktopLoginBroking {
    private let clientID: String
    private let originator: String
    private let scopes: String
    private let stateGenerator: () -> String
    private let codeVerifierGenerator: () -> String
    private let callbackServerFactory: () throws -> any OAuthCallbackServing
    private let browserOpener: (URL) -> Bool
    private let fallbackBrowserOpener: (URL) -> Bool
    private let applicationActivator: () -> Void
    private let tokenExchanger: @Sendable (String, String, URL) async throws -> CodexOAuthTokenResponse
    private let now: () -> Date
    private let loginTimeoutNanoseconds: UInt64
    private let wait: @Sendable (UInt64) async throws -> Void

    public init(
        clientID: String = "app_EMoamEEZ73f0CkXaXp7hrann",
        originator: String = "codex_chatgpt_desktop",
        scopes: String = "openid profile email offline_access",
        stateGenerator: (() -> String)? = nil,
        codeVerifierGenerator: (() -> String)? = nil,
        callbackServerFactory: (() throws -> any OAuthCallbackServing)? = nil,
        browserOpener: ((URL) -> Bool)? = nil,
        fallbackBrowserOpener: ((URL) -> Bool)? = nil,
        applicationActivator: (() -> Void)? = nil,
        tokenExchanger: (@Sendable (String, String, URL) async throws -> CodexOAuthTokenResponse)? = nil,
        now: @escaping () -> Date = Date.init,
        loginTimeoutNanoseconds: UInt64 = 180_000_000_000,
        wait: @escaping @Sendable (UInt64) async throws -> Void = { duration in
            try await Task.sleep(nanoseconds: duration)
        }
    ) {
        self.clientID = clientID
        self.originator = originator
        self.scopes = scopes
        self.stateGenerator = stateGenerator ?? { Self.randomURLSafeString(length: 32) }
        self.codeVerifierGenerator = codeVerifierGenerator ?? { Self.randomURLSafeString(length: 64) }
        self.callbackServerFactory = callbackServerFactory ?? { try LocalhostOAuthCallbackServer() }
        self.browserOpener = browserOpener ?? SystemBrowserOpener.open(url:)
        self.fallbackBrowserOpener = fallbackBrowserOpener ?? ShellBrowserOpener.open(url:)
        self.applicationActivator = applicationActivator ?? SystemApplicationActivator.activate
        self.tokenExchanger = tokenExchanger ?? Self.exchangeCodeForTokens
        self.now = now
        self.loginTimeoutNanoseconds = loginTimeoutNanoseconds
        self.wait = wait
    }

    public func performLogin() async throws -> Data {
        let callbackServer = try callbackServerFactory()
        defer { callbackServer.stop() }

        let state = stateGenerator()
        let codeVerifier = codeVerifierGenerator()
        let authorizationURL = try buildAuthorizationURL(
            redirectURI: callbackServer.redirectURI,
            state: state,
            codeVerifier: codeVerifier
        )

        let didOpenBrowser = await MainActor.run {
            applicationActivator()
            if browserOpener(authorizationURL) {
                return true
            }

            return fallbackBrowserOpener(authorizationURL)
        }

        guard didOpenBrowser else {
            throw CodexAuthError.browserLaunchFailed
        }

        let callbackResult = try await waitForCallback(using: callbackServer)
        switch callbackResult {
        case let .code(code, returnedState):
            guard returnedState == state else {
                throw CodexAuthError.loginFailed
            }

            let tokenResponse = try await tokenExchanger(code, codeVerifier, callbackServer.redirectURI)
            return try buildAuthData(from: tokenResponse)
        case let .failure(error, _):
            if error == "access_denied" {
                throw CodexAuthError.loginCancelled
            }
            throw CodexAuthError.loginFailed
        }
    }

    private func waitForCallback(using callbackServer: any OAuthCallbackServing) async throws -> OAuthCallbackResult {
        enum AwaitedResult {
            case callback(OAuthCallbackResult)
            case timedOut
        }

        return try await withThrowingTaskGroup(of: AwaitedResult.self) { group in
            group.addTask {
                .callback(try await callbackServer.waitForCallback())
            }
            group.addTask {
                try await wait(loginTimeoutNanoseconds)
                callbackServer.stop()
                return .timedOut
            }

            let firstResult = try await group.next()!
            group.cancelAll()

            switch firstResult {
            case let .callback(result):
                return result
            case .timedOut:
                throw CodexAuthError.loginTimedOut
            }
        }
    }

    private func buildAuthorizationURL(redirectURI: URL, state: String, codeVerifier: String) throws -> URL {
        var components = URLComponents(string: "https://auth.openai.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: codeVerifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "originator", value: originator),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "allowed_workspace_id", value: ""),
        ]

        guard let url = components?.url else {
            throw CodexAuthError.loginFailed
        }

        return url
    }

    private func buildAuthData(from tokenResponse: CodexOAuthTokenResponse) throws -> Data {
        var tokens: [String: String] = [
            "access_token": tokenResponse.accessToken,
            "refresh_token": tokenResponse.refreshToken,
            "id_token": tokenResponse.idToken,
        ]
        if let accountID = tokenResponse.accountID, !accountID.isEmpty {
            tokens["account_id"] = accountID
        }

        let object: [String: Any] = [
            "OPENAI_API_KEY": "",
            "auth_mode": "chatgpt",
            "last_refresh": Self.iso8601Formatter.string(from: now()),
            "tokens": tokens,
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectURI: URL
    ) async throws -> CodexOAuthTokenResponse {
        var request = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "client_id", value: "app_EMoamEEZ73f0CkXaXp7hrann"),
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw CodexAuthError.loginFailed
        }

        let decoded = try JSONDecoder().decode(TokenExchangePayload.self, from: data)
        return CodexOAuthTokenResponse(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            idToken: decoded.idToken,
            accountID: decoded.accountID
        )
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func randomURLSafeString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

public struct DesktopCodexLoginRunner: CodexLoginRunning {
    private let broker: any CodexDesktopLoginBroking
    private let fileStore: CodexAuthFileStore

    public init(
        fileStore: CodexAuthFileStore,
        broker: any CodexDesktopLoginBroking = DesktopCodexLoginBroker()
    ) {
        self.fileStore = fileStore
        self.broker = broker
    }

    public func runLogin() async throws -> CodexLoginResult {
        let authData = try await broker.performLogin()
        try fileStore.replaceActiveAuth(with: authData)
        return .success
    }
}

public final class LocalhostOAuthCallbackServer: OAuthCallbackServing {
    public let redirectURI: URL

    private let listener: NWListener
    private let queue = DispatchQueue(label: "CodexSwitch.OAuthCallbackServer")
    private let stateLock = NSLock()
    private var continuation: CheckedContinuation<OAuthCallbackResult, Error>?
    private var isStopped = false

    public init(port: UInt16? = 1455) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let requestedPort = port.flatMap(NWEndpoint.Port.init(rawValue:))
        listener = try NWListener(using: parameters, on: requestedPort ?? .any)

        var actualPort: UInt16?
        var startupError: NWError?
        let startupSemaphore = DispatchSemaphore(value: 0)

        listener.stateUpdateHandler = { [listener] listenerState in
            switch listenerState {
            case .ready:
                actualPort = listener.port?.rawValue
                startupSemaphore.signal()
            case let .failed(error):
                startupError = error
                startupSemaphore.signal()
            default:
                break
            }
        }

        listener.start(queue: queue)
        startupSemaphore.wait()

        if startupError != nil {
            throw CodexAuthError.loginFailed
        }

        guard let actualPort else {
            throw CodexAuthError.loginFailed
        }

        redirectURI = URL(string: "http://localhost:\(actualPort)/auth/callback")!
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
    }

    public func waitForCallback() async throws -> OAuthCallbackResult {
        try await withCheckedThrowingContinuation { continuation in
            stateLock.lock()
            defer { stateLock.unlock() }

            if isStopped {
                continuation.resume(throwing: CodexAuthError.loginFailed)
                return
            }

            self.continuation = continuation
        }
    }

    public func stop() {
        listener.cancel()

        let pendingContinuation: CheckedContinuation<OAuthCallbackResult, Error>?
        stateLock.lock()
        isStopped = true
        pendingContinuation = continuation
        continuation = nil
        stateLock.unlock()

        pendingContinuation?.resume(throwing: CodexAuthError.loginFailed)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                self.finish(with: .failure(CodexAuthError.loginFailed))
                connection.cancel()
                _ = error
                return
            }

            guard
                let data,
                let request = String(data: data, encoding: .utf8),
                let callbackResult = self.parseCallback(from: request)
            else {
                self.writeHTTPResponse(
                    body: "<html><body><h1>Codex login failed</h1><p>You can close this window.</p></body></html>",
                    to: connection
                )
                self.finish(with: .failure(CodexAuthError.loginFailed))
                connection.cancel()
                return
            }

            self.writeHTTPResponse(
                body: "<html><body><h1>Codex login complete</h1><p>You can close this window and return to Codex Switch.</p></body></html>",
                to: connection
            )
            self.finish(with: .success(callbackResult))
            connection.cancel()
        }
    }

    private func parseCallback(from request: String) -> OAuthCallbackResult? {
        guard let requestLine = request.components(separatedBy: "\r\n").first else {
            return nil
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }

        let pathWithQuery = String(parts[1])
        guard pathWithQuery.hasPrefix("/auth/callback") else {
            return nil
        }

        guard let components = URLComponents(string: "http://localhost\(pathWithQuery)") else {
            return nil
        }

        let queryItems = Dictionary(uniqueKeysWithValues: components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [])
        if let code = queryItems["code"], let state = queryItems["state"], !code.isEmpty, !state.isEmpty {
            return .code(code, state: state)
        }

        if let error = queryItems["error"], !error.isEmpty {
            return .failure(error: error, description: queryItems["error_description"])
        }

        return nil
    }

    private func finish(with result: Result<OAuthCallbackResult, Error>) {
        let pendingContinuation: CheckedContinuation<OAuthCallbackResult, Error>?
        stateLock.lock()
        pendingContinuation = continuation
        continuation = nil
        stateLock.unlock()

        switch result {
        case let .success(callbackResult):
            pendingContinuation?.resume(returning: callbackResult)
        case let .failure(error):
            pendingContinuation?.resume(throwing: error)
        }
    }

    private func writeHTTPResponse(body: String, to connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in })
    }
}

private struct SystemBrowserOpener {
    static func open(url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

private struct ShellBrowserOpener {
    static func open(url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

private struct SystemApplicationActivator {
    static func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct TokenExchangePayload: Decodable {
    let accessToken: String
    let refreshToken: String
    let idToken: String
    let accountID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case accountID = "account_id"
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
