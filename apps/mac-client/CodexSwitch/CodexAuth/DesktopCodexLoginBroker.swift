import AppKit
import CryptoKit
import Darwin
import Foundation

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
    private let logger: any CodexDiagnosticsLogging

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
        logger: (any CodexDiagnosticsLogging)? = nil,
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
        self.tokenExchanger = tokenExchanger ?? { code, verifier, redirectURI in
            try await Self.exchangeCodeForTokens(
                code: code,
                codeVerifier: verifier,
                redirectURI: redirectURI
            )
        }
        self.logger = logger ?? NullCodexDiagnosticsLogger()
        self.now = now
        self.loginTimeoutNanoseconds = loginTimeoutNanoseconds
        self.wait = wait
    }

    public func performLogin() async throws -> Data {
        logger.log("browser_login_started")
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
                logger.log("browser_open_primary_result=true")
                return true
            }

            logger.log("browser_open_primary_result=false")
            let didFallbackOpen = fallbackBrowserOpener(authorizationURL)
            logger.log("browser_open_fallback_result=\(didFallbackOpen)")
            return didFallbackOpen
        }

        guard didOpenBrowser else {
            logger.log("browser_launch_failed")
            throw CodexAuthError.browserLaunchFailed
        }

        let callbackResult = try await waitForCallback(using: callbackServer)
        switch callbackResult {
        case let .code(code, returnedState):
            logger.log("callback_received code=true error=false")
            guard returnedState == state else {
                logger.log("callback_state_mismatch")
                throw CodexAuthError.loginFailed
            }

            logger.log("token_exchange_started")
            let tokenResponse = try await tokenExchanger(code, codeVerifier, callbackServer.redirectURI)
            logger.log("token_exchange_succeeded")
            return try buildAuthData(from: tokenResponse)
        case let .failure(error, _):
            logger.log("callback_received code=false error=true type=\(error)")
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
                logger.log("browser_login_timed_out")
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
        broker: (any CodexDesktopLoginBroking)? = nil,
        logger: (any CodexDiagnosticsLogging)? = nil
    ) {
        self.fileStore = fileStore
        let diagnosticsLogger = logger ?? CodexDiagnosticsFileLogger(paths: fileStore.paths)
        self.broker = broker ?? DesktopCodexLoginBroker(
            callbackServerFactory: { try LocalhostOAuthCallbackServer(logger: diagnosticsLogger) },
            logger: diagnosticsLogger
        )
    }

    public func runLogin() async throws -> CodexLoginResult {
        let authData = try await broker.performLogin()
        try fileStore.replaceActiveAuth(with: authData)
        return .success
    }
}

public final class LocalhostOAuthCallbackServer: OAuthCallbackServing {
    public let redirectURI: URL

    private let queue = DispatchQueue(label: "CodexSwitch.OAuthCallbackServer")
    private let stateLock = NSLock()
    private var continuation: CheckedContinuation<OAuthCallbackResult, Error>?
    private var pendingResult: Result<OAuthCallbackResult, Error>?
    private var isStopped = false
    private let logger: any CodexDiagnosticsLogging
    private let listeningSocket: Int32
    private let acceptSource: DispatchSourceRead

    public init(port: UInt16? = 1455, logger: any CodexDiagnosticsLogging = NullCodexDiagnosticsLogger()) throws {
        self.logger = logger
        let socket = try Self.makeListeningSocket(port: port, logger: logger)
        listeningSocket = socket.fileDescriptor
        redirectURI = URL(string: "http://localhost:\(socket.port)/auth/callback")!
        acceptSource = DispatchSource.makeReadSource(fileDescriptor: socket.fileDescriptor, queue: queue)
        acceptSource.setEventHandler { [weak self] in
            self?.acceptIncomingConnections()
        }
        acceptSource.setCancelHandler {
            close(socket.fileDescriptor)
        }
        acceptSource.resume()

        logger.log("callback_listener_ready port=\(socket.port)")
    }

    public func waitForCallback() async throws -> OAuthCallbackResult {
        try await withCheckedThrowingContinuation { continuation in
            let pendingResult: Result<OAuthCallbackResult, Error>?

            stateLock.lock()
            defer { stateLock.unlock() }

            pendingResult = self.pendingResult
            if pendingResult != nil {
                self.pendingResult = nil
            }

            if let pendingResult {
                switch pendingResult {
                case let .success(result):
                    continuation.resume(returning: result)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
                return
            }

            if isStopped {
                continuation.resume(throwing: CodexAuthError.loginFailed)
                return
            }

            self.continuation = continuation
        }
    }

    public func stop() {
        logger.log("callback_listener_stopped")
        acceptSource.cancel()

        let pendingContinuation: CheckedContinuation<OAuthCallbackResult, Error>?
        stateLock.lock()
        isStopped = true
        pendingContinuation = continuation
        continuation = nil
        if pendingContinuation == nil, pendingResult == nil {
            pendingResult = .failure(CodexAuthError.loginFailed)
        }
        stateLock.unlock()

        pendingContinuation?.resume(throwing: CodexAuthError.loginFailed)
    }

    private func acceptIncomingConnections() {
        while true {
            var addressStorage = sockaddr_storage()
            var addressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let clientSocket = withUnsafeMutablePointer(to: &addressStorage) { storagePointer in
                storagePointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    accept(listeningSocket, sockaddrPointer, &addressLength)
                }
            }

            if clientSocket == -1 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    return
                }

                logger.log("callback_connection_error accept errno=\(errno) reason=\(Self.socketErrorDescription(errno))")
                finish(with: .failure(CodexAuthError.loginFailed))
                return
            }

            handleClientSocket(clientSocket)
        }
    }

    private func handleClientSocket(_ clientSocket: Int32) {
        let flags = fcntl(clientSocket, F_GETFL)
        if flags != -1 {
            _ = fcntl(clientSocket, F_SETFL, flags & ~O_NONBLOCK)
        }

        defer {
            shutdown(clientSocket, SHUT_RDWR)
            close(clientSocket)
        }

        guard let request = readRequest(from: clientSocket) else {
            logger.log("callback_parse_failed")
            writeHTTPResponse(
                body: "<html><body><h1>Codex login failed</h1><p>You can close this window.</p></body></html>",
                to: clientSocket
            )
            finish(with: .failure(CodexAuthError.loginFailed))
            return
        }

        switch parseRequest(request) {
        case let .callback(callbackResult):
            writeHTTPResponse(
                body: "<html><body><h1>Codex login complete</h1><p>You can close this window and return to Codex Switch.</p></body></html>",
                to: clientSocket
            )
            finish(with: .success(callbackResult))
        case .ignored:
            writeHTTPResponse(
                statusLine: "HTTP/1.1 404 Not Found",
                body: "<html><body><h1>Not found</h1></body></html>",
                to: clientSocket
            )
        case .invalid:
            logger.log("callback_parse_failed")
            writeHTTPResponse(
                body: "<html><body><h1>Codex login failed</h1><p>You can close this window.</p></body></html>",
                to: clientSocket
            )
            finish(with: .failure(CodexAuthError.loginFailed))
        }
    }

    private func readRequest(from clientSocket: Int32) -> String? {
        var requestData = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)

        while requestData.count < 16_384 {
            let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
            if bytesRead > 0 {
                requestData.append(buffer, count: bytesRead)
                if requestData.range(of: Data("\r\n\r\n".utf8)) != nil {
                    break
                }
                continue
            }

            if bytesRead == 0 {
                break
            }

            if errno == EINTR {
                continue
            }

            logger.log("callback_connection_error recv errno=\(errno) reason=\(Self.socketErrorDescription(errno))")
            return nil
        }

        guard !requestData.isEmpty else {
            return nil
        }

        return String(data: requestData, encoding: .utf8)
    }

    private func parseRequest(_ request: String) -> ParsedCallbackRequest {
        guard let requestLine = request.components(separatedBy: "\r\n").first else {
            return .invalid
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return .invalid
        }

        let pathWithQuery = String(parts[1])
        guard pathWithQuery.hasPrefix("/auth/callback") else {
            return .ignored
        }

        guard let components = URLComponents(string: "http://localhost\(pathWithQuery)") else {
            return .invalid
        }

        let queryItems = Dictionary(uniqueKeysWithValues: components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [])
        if let code = queryItems["code"], let state = queryItems["state"], !code.isEmpty, !state.isEmpty {
            logger.log("callback_query code=true error=false")
            return .callback(.code(code, state: state))
        }

        if let error = queryItems["error"], !error.isEmpty {
            logger.log("callback_query code=false error=true type=\(error)")
            return .callback(.failure(error: error, description: queryItems["error_description"]))
        }

        return .invalid
    }

    private func finish(with result: Result<OAuthCallbackResult, Error>) {
        let pendingContinuation: CheckedContinuation<OAuthCallbackResult, Error>?
        stateLock.lock()
        pendingContinuation = continuation
        continuation = nil
        stateLock.unlock()

        switch result {
        case let .success(callbackResult):
            if let pendingContinuation {
                pendingContinuation.resume(returning: callbackResult)
            } else {
                stateLock.lock()
                pendingResult = .success(callbackResult)
                stateLock.unlock()
            }
        case let .failure(error):
            if let pendingContinuation {
                pendingContinuation.resume(throwing: error)
            } else {
                stateLock.lock()
                pendingResult = .failure(error)
                stateLock.unlock()
            }
        }
    }

    private func writeHTTPResponse(
        statusLine: String = "HTTP/1.1 200 OK",
        body: String,
        to clientSocket: Int32
    ) {
        let response = """
        \(statusLine)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        let data = Data(response.utf8)
        data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else {
                return
            }

            var bytesSent = 0
            while bytesSent < data.count {
                let result = send(clientSocket, baseAddress.advanced(by: bytesSent), data.count - bytesSent, 0)
                if result > 0 {
                    bytesSent += result
                    continue
                }

                if errno == EINTR {
                    continue
                }

                return
            }
        }
    }

    private static func makeListeningSocket(
        port: UInt16?,
        logger: any CodexDiagnosticsLogging
    ) throws -> (fileDescriptor: Int32, port: UInt16) {
        let requestedService = port.map(String.init) ?? "0"
        var hints = addrinfo(
            ai_flags: AI_NUMERICSERV,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var resultPointer: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo("localhost", requestedService, &hints, &resultPointer) == 0, let firstResult = resultPointer else {
            logger.log("callback_listener_failed getaddrinfo service=\(requestedService)")
            throw CodexAuthError.loginFailed
        }
        defer { freeaddrinfo(firstResult) }

        var cursor: UnsafeMutablePointer<addrinfo>? = firstResult
        var failures: [String] = []
        while let addressInfo = cursor {
            let socketFD = socket(addressInfo.pointee.ai_family, addressInfo.pointee.ai_socktype, addressInfo.pointee.ai_protocol)
            if socketFD == -1 {
                failures.append("socket family=\(addressInfo.pointee.ai_family) errno=\(errno) reason=\(socketErrorDescription(errno))")
                cursor = addressInfo.pointee.ai_next
                continue
            }

            var reuseAddress: Int32 = 1
            setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout<Int32>.size))

            if bind(socketFD, addressInfo.pointee.ai_addr, addressInfo.pointee.ai_addrlen) == 0,
               listen(socketFD, 16) == 0 {
                let flags = fcntl(socketFD, F_GETFL)
                if flags != -1 {
                    _ = fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)
                }
                return (socketFD, try localPort(for: socketFD))
            }

            failures.append("bind_listen family=\(addressInfo.pointee.ai_family) errno=\(errno) reason=\(socketErrorDescription(errno))")
            close(socketFD)
            cursor = addressInfo.pointee.ai_next
        }

        logger.log("callback_listener_failed \(failures.joined(separator: "; "))")
        throw CodexAuthError.loginFailed
    }

    private static func localPort(for socketFD: Int32) throws -> UInt16 {
        var addressStorage = sockaddr_storage()
        var addressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
        guard withUnsafeMutablePointer(to: &addressStorage, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFD, $0, &addressLength)
            }
        }) == 0 else {
            throw CodexAuthError.loginFailed
        }

        switch Int32(addressStorage.ss_family) {
        case AF_INET:
            return withUnsafePointer(to: &addressStorage) { storagePointer in
                storagePointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    UInt16(bigEndian: $0.pointee.sin_port)
                }
            }
        case AF_INET6:
            return withUnsafePointer(to: &addressStorage) { storagePointer in
                storagePointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    UInt16(bigEndian: $0.pointee.sin6_port)
                }
            }
        default:
            throw CodexAuthError.loginFailed
        }
    }

    private static func socketErrorDescription(_ errorNumber: Int32) -> String {
        String(cString: strerror(errorNumber))
    }
}

private enum ParsedCallbackRequest {
    case callback(OAuthCallbackResult)
    case ignored
    case invalid
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
