import Foundation

public struct CodexJWTDecoder {
    public init() {}

    public func decode(idToken: String) throws -> CodexJWTClaims {
        let parts = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            throw CodexAuthError.jwtPayloadInvalid
        }

        let payload = try decodePayload(String(parts[1]))
        let normalizedEmail = payload.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let accountID = payload.sub?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? payload.sub!.trimmingCharacters(in: .whitespacesAndNewlines)
            : normalizedEmail

        return CodexJWTClaims(
            accountID: accountID,
            email: normalizedEmail,
            emailMask: Account.maskedEmail(normalizedEmail),
            tier: resolveTier(from: payload)
        )
    }

    private func resolveTier(from payload: Payload) -> AccountTier {
        let candidate = (
            payload.tier ??
            payload.plan ??
            payload.openAIAuth?.chatgptPlanType ??
            "unknown"
        ).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if candidate.contains("team") {
            return .team
        }

        if candidate.contains("pro") {
            return .pro
        }

        if candidate.contains("plus") {
            return .plus
        }

        return AccountTier(rawValue: candidate) ?? .unknown
    }

    private func decodePayload(_ payloadSegment: String) throws -> Payload {
        let padded = payloadSegment.padding(
            toLength: ((payloadSegment.count + 3) / 4) * 4,
            withPad: "=",
            startingAt: 0
        )
        let normalized = padded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: normalized) else {
            throw CodexAuthError.jwtPayloadInvalid
        }

        do {
            return try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw CodexAuthError.jwtPayloadInvalid
        }
    }
}

private extension CodexJWTDecoder {
    struct Payload: Decodable {
        let sub: String?
        let email: String
        let tier: String?
        let plan: String?
        let openAIAuth: OpenAIAuthPayload?

        enum CodingKeys: String, CodingKey {
            case sub
            case email
            case tier
            case plan
            case openAIAuth = "https://api.openai.com/auth"
        }
    }

    struct OpenAIAuthPayload: Decodable {
        let chatgptPlanType: String?

        enum CodingKeys: String, CodingKey {
            case chatgptPlanType = "chatgpt_plan_type"
        }
    }
}
