import Foundation

public enum CodexAuthError: Error, Equatable {
    case currentAuthFileMissing
    case authFileUnreadable
    case authJSONInvalid
    case idTokenMissing
    case jwtPayloadInvalid
    case archiveWriteFailed
    case activeAuthReplacementFailed
    case loginCancelled
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

    public init(source: AccountSource, lastImportedAt: Date) {
        self.source = source
        self.lastImportedAt = lastImportedAt
    }
}

public struct CodexAccountMetadataCache: Codable, Equatable {
    public var entries: [String: CodexAccountMetadataEntry]

    public init(entries: [String: CodexAccountMetadataEntry] = [:]) {
        self.entries = entries
    }
}
