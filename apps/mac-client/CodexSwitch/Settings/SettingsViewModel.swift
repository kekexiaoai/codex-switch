import Foundation

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
