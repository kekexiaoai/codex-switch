import Foundation

public enum CodexAuthError: Error, Equatable {
    case currentAuthFileMissing
    case authFileUnreadable
    case authJSONInvalid
    case apiKeyModeDetected
    case idTokenMissing
    case jwtPayloadInvalid
    case archiveWriteFailed
    case activeAuthReplacementFailed
    case loginCancelled
    case loginTimedOut
    case browserLaunchFailed
    case loginFailed
    case noUsageData
}

public struct CodexJWTClaims: Equatable {
    public let accountID: String
    public let email: String
    public let emailMask: String
    public let tier: AccountTier

    public init(accountID: String, email: String, emailMask: String, tier: AccountTier) {
        self.accountID = accountID
        self.email = email
        self.emailMask = emailMask
        self.tier = tier
    }
}

public struct CodexAccountMetadataEntry: Codable, Equatable {
    public let source: AccountSource
    public let lastImportedAt: Date
    public let manualOrder: Int

    public init(source: AccountSource, lastImportedAt: Date, manualOrder: Int = 0) {
        self.source = source
        self.lastImportedAt = lastImportedAt
        self.manualOrder = manualOrder
    }

    enum CodingKeys: String, CodingKey {
        case source
        case lastImportedAt
        case manualOrder
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(AccountSource.self, forKey: .source)
        lastImportedAt = try container.decode(Date.self, forKey: .lastImportedAt)
        manualOrder = try container.decodeIfPresent(Int.self, forKey: .manualOrder) ?? 0
    }
}

public struct CodexAccountMetadataCache: Codable, Equatable {
    public var entries: [String: CodexAccountMetadataEntry]

    public init(entries: [String: CodexAccountMetadataEntry] = [:]) {
        self.entries = entries
    }
}
