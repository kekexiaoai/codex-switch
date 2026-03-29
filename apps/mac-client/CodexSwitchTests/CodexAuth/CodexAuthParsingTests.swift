import XCTest
@testable import CodexSwitchKit

final class CodexAuthParsingTests: XCTestCase {
    func testJWTDecoderExtractsStableIdentityAndTier() throws {
        let idToken = makeJWT(payload: [
            "sub": "subject-123",
            "email": "alex@example.com",
            "tier": "team",
        ])

        let claims = try CodexJWTDecoder().decode(idToken: idToken)

        XCTAssertEqual(claims.accountID, "subject-123")
        XCTAssertEqual(claims.email, "alex@example.com")
        XCTAssertEqual(claims.emailMask, "a•••@example.com")
        XCTAssertEqual(claims.tier, .team)
    }

    func testJWTDecoderFallsBackToNormalizedEmailWhenSubMissing() throws {
        let idToken = makeJWT(payload: [
            "email": "Alex@Example.com",
            "plan": "pro",
        ])

        let claims = try CodexJWTDecoder().decode(idToken: idToken)

        XCTAssertEqual(claims.accountID, "alex@example.com")
        XCTAssertEqual(claims.email, "alex@example.com")
        XCTAssertEqual(claims.tier, .pro)
    }

    func testArchiveFilenameUsesBase64URLEncodedEmail() {
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: "alex@example.com")

        XCTAssertEqual(archiveFilename, "YWxleEBleGFtcGxlLmNvbQ.json")
    }

    private func makeJWT(payload: [String: String]) -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        let payloadData = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let payloadString = String(data: payloadData, encoding: .utf8)!
        return [
            Self.base64URL(header),
            Self.base64URL(payloadString),
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
