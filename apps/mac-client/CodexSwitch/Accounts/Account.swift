import Foundation

public enum AccountTier: String, Codable, Equatable {
    case plus
    case pro
    case team
    case unknown
}

public enum AccountSource: String, Codable, Equatable {
    case fixture
    case currentAuth
    case backupImport
    case browserLogin
}

public struct Account: Codable, Equatable, Identifiable {
    public let id: String
    public let emailMask: String
    public let email: String?
    public let tier: AccountTier
    public let archiveFilename: String
    public let source: AccountSource
    public let lastImportedAt: Date
    public var embeddedSecret: String?

    public init(
        id: String,
        emailMask: String,
        email: String? = nil,
        tier: AccountTier,
        archiveFilename: String? = nil,
        source: AccountSource = .fixture,
        lastImportedAt: Date = .distantPast,
        embeddedSecret: String? = nil
    ) {
        self.id = id
        self.emailMask = emailMask
        self.email = email
        self.tier = tier
        self.archiveFilename = archiveFilename ?? "\(id).json"
        self.source = source
        self.lastImportedAt = lastImportedAt
        self.embeddedSecret = embeddedSecret
    }

    public func displayEmail(showFullEmail: Bool) -> String {
        if showFullEmail, let email {
            return email
        }

        return emailMask
    }

    public static func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return email
        }

        let localPart = String(parts[0])
        let domainPart = String(parts[1])
        guard let first = localPart.first else {
            return email
        }

        let maskedCount = max(localPart.count - 1, 0)
        let mask = String(repeating: "\u{2022}", count: maskedCount)
        return "\(first)\(mask)@\(domainPart)"
    }
}
