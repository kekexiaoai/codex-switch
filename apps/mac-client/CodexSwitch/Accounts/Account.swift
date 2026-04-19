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
    public let manualOrder: Int
    public let archiveFilename: String
    public let source: AccountSource
    public let lastImportedAt: Date
    public var embeddedSecret: String?

    public init(
        id: String,
        emailMask: String,
        email: String? = nil,
        tier: AccountTier,
        manualOrder: Int = 0,
        archiveFilename: String? = nil,
        source: AccountSource = .fixture,
        lastImportedAt: Date = .distantPast,
        embeddedSecret: String? = nil
    ) {
        self.id = id
        self.emailMask = emailMask
        self.email = email
        self.tier = tier
        self.manualOrder = manualOrder
        self.archiveFilename = archiveFilename ?? "\(id).json"
        self.source = source
        self.lastImportedAt = lastImportedAt
        self.embeddedSecret = embeddedSecret
    }

    enum CodingKeys: String, CodingKey {
        case id
        case emailMask
        case email
        case tier
        case manualOrder
        case archiveFilename
        case source
        case lastImportedAt
        case embeddedSecret
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        emailMask = try container.decode(String.self, forKey: .emailMask)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        tier = try container.decode(AccountTier.self, forKey: .tier)
        manualOrder = try container.decodeIfPresent(Int.self, forKey: .manualOrder) ?? 0
        archiveFilename = try container.decode(String.self, forKey: .archiveFilename)
        source = try container.decode(AccountSource.self, forKey: .source)
        lastImportedAt = try container.decode(Date.self, forKey: .lastImportedAt)
        embeddedSecret = try container.decodeIfPresent(String.self, forKey: .embeddedSecret)
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
