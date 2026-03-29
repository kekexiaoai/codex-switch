import Foundation

public enum AccountTier: String, Codable, Equatable {
    case plus
    case pro
    case team
}

public struct Account: Codable, Equatable, Identifiable {
    public let id: String
    public let emailMask: String
    public let tier: AccountTier
    public var embeddedSecret: String?

    public init(
        id: String,
        emailMask: String,
        tier: AccountTier,
        embeddedSecret: String? = nil
    ) {
        self.id = id
        self.emailMask = emailMask
        self.tier = tier
        self.embeddedSecret = embeddedSecret
    }
}
