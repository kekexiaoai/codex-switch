import XCTest
@testable import CodexSwitchKit

final class LocalhostOAuthCallbackServerTests: XCTestCase {
    func testServerReceivesAuthorizationCodeCallback() async throws {
        let logger = TestDiagnosticsLogger()
        let server: LocalhostOAuthCallbackServer
        do {
            server = try LocalhostOAuthCallbackServer(port: nil, logger: logger)
        } catch {
            XCTFail("Server startup failed with logs: \(logger.entries.joined(separator: " | "))")
            return
        }
        defer { server.stop() }

        let callbackTask = Task {
            try await server.waitForCallback()
        }

        let callbackURL = try XCTUnwrap(
            URL(string: "\(server.redirectURI.absoluteString)?code=test-code&state=test-state")
        )
        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(from: callbackURL)
        } catch {
            XCTFail("HTTP callback request failed with logs: \(logger.entries.joined(separator: " | ")) error: \(error)")
            return
        }

        let callbackResult: OAuthCallbackResult
        do {
            callbackResult = try await callbackTask.value
        } catch {
            XCTFail("Callback wait failed with logs: \(logger.entries.joined(separator: " | ")) error: \(error)")
            return
        }

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(callbackResult, .code("test-code", state: "test-state"))
    }

    func testServerReceivesAuthorizationFailureCallback() async throws {
        let logger = TestDiagnosticsLogger()
        let server: LocalhostOAuthCallbackServer
        do {
            server = try LocalhostOAuthCallbackServer(port: nil, logger: logger)
        } catch {
            XCTFail("Server startup failed with logs: \(logger.entries.joined(separator: " | "))")
            return
        }
        defer { server.stop() }

        let callbackTask = Task {
            try await server.waitForCallback()
        }

        let callbackURL = try XCTUnwrap(
            URL(string: "\(server.redirectURI.absoluteString)?error=access_denied&error_description=cancelled")
        )
        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(from: callbackURL)
        } catch {
            XCTFail("HTTP callback request failed with logs: \(logger.entries.joined(separator: " | ")) error: \(error)")
            return
        }

        let callbackResult: OAuthCallbackResult
        do {
            callbackResult = try await callbackTask.value
        } catch {
            XCTFail("Callback wait failed with logs: \(logger.entries.joined(separator: " | ")) error: \(error)")
            return
        }

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(callbackResult, .failure(error: "access_denied", description: "cancelled"))
    }

    func testServerIgnoresUnrelatedBrowserRequestsAfterSuccessfulCallback() async throws {
        let logger = TestDiagnosticsLogger()
        let server = try LocalhostOAuthCallbackServer(port: nil, logger: logger)
        defer { server.stop() }

        let callbackTask = Task {
            try await server.waitForCallback()
        }

        let callbackURL = try XCTUnwrap(
            URL(string: "\(server.redirectURI.absoluteString)?code=test-code&state=test-state")
        )
        let (_, callbackResponse) = try await URLSession.shared.data(from: callbackURL)
        let callbackResult = try await callbackTask.value

        let faviconURL = try XCTUnwrap(
            URL(string: "http://localhost:\(server.redirectURI.port ?? 0)/favicon.ico")
        )
        let (_, faviconResponse) = try await URLSession.shared.data(from: faviconURL)

        XCTAssertEqual((callbackResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(callbackResult, .code("test-code", state: "test-state"))
        XCTAssertEqual((faviconResponse as? HTTPURLResponse)?.statusCode, 404)
        XCTAssertFalse(logger.entries.contains(where: { $0.contains("callback_parse_failed") }))
    }
}

private final class TestDiagnosticsLogger: CodexDiagnosticsLogging {
    private(set) var entries: [String] = []

    func log(_ message: String) {
        entries.append(message)
    }
}
