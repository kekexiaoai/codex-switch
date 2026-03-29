import Foundation
import XCTest
@testable import CodexSwitchKit

final class CodexUsageAPIClientTests: XCTestCase {
    func testUsageAPIClientBuildsWhamUsageRequestAndParsesWindows() async throws {
        let requestBox = RequestBox()
        let client = CodexUsageAPIClient(
            transport: { request in
                await requestBox.set(request)
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let data = Data(
                    #"""
                    {
                      "email": "alex@example.com",
                      "plan_type": "team",
                      "rate_limit": {
                        "primary_window": {
                          "used_percent": 12,
                          "resets_at": "2026-03-29T10:30:00Z"
                        },
                        "secondary_window": {
                          "used_percent": 34,
                          "resets_at": "2026-04-02T00:00:00Z"
                        }
                      }
                    }
                    """#.utf8
                )
                return (data, response)
            },
            now: { Date(timeIntervalSince1970: 1_743_241_200) }
        )
        let account = Account(
            id: "google-oauth2|123",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )

        let snapshot = try await client.fetchUsage(
            for: account,
            accessToken: "access-token",
            accountID: "chatgpt-account-id"
        )

        let capturedRequest = await requestBox.value
        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "chatgpt-account-id")
        XCTAssertEqual(snapshot.accountID, "google-oauth2|123")
        XCTAssertEqual(snapshot.fiveHour.percentUsed, 12)
        XCTAssertEqual(snapshot.weekly.percentUsed, 34)
    }

    func testUsageAPIClientMapsUnauthorizedResponse() async {
        let client = CodexUsageAPIClient(
            transport: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(), response)
            }
        )
        let account = Account(
            id: "google-oauth2|123",
            emailMask: "a•••@example.com",
            email: "alex@example.com",
            tier: .team
        )

        await XCTAssertThrowsErrorAsync(try await client.fetchUsage(
            for: account,
            accessToken: "access-token",
            accountID: "chatgpt-account-id"
        )) { error in
            XCTAssertEqual(error as? CodexUsageAPIClient.Error, .unauthorized)
        }
    }
}

private actor RequestBox {
    private(set) var value: URLRequest?

    func set(_ request: URLRequest) {
        value = request
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ verification: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        verification(error)
    }
}
