import Foundation

public protocol EmailVisibilityProviding {
    func showEmails() -> Bool
}

public protocol EmailVisibilityMutating: EmailVisibilityProviding {
    func setShowEmails(_ enabled: Bool)
}

public struct UserDefaultsEmailVisibilityStore: EmailVisibilityProviding {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func showEmails() -> Bool {
        defaults.bool(forKey: SettingsViewModel.showEmailsKey)
    }
}

extension UserDefaultsEmailVisibilityStore: EmailVisibilityMutating {
    public func setShowEmails(_ enabled: Bool) {
        defaults.set(enabled, forKey: SettingsViewModel.showEmailsKey)
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    public static let showEmailsKey = "showEmails"

    @Published public private(set) var showEmails: Bool

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showEmails = defaults.bool(forKey: Self.showEmailsKey)
    }

    public func setShowEmails(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.showEmailsKey)
        showEmails = enabled
    }
}
