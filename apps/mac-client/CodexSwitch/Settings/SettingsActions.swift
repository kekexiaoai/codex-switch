import Foundation

public enum SettingsDestructiveAction: String, Equatable, CaseIterable, Identifiable {
    case clearDiagnosticsLog
    case clearUsageCache
    case removeArchivedAccounts

    public var id: String { rawValue }
}

public enum SettingsUtilityAction: String, Equatable, CaseIterable, Identifiable {
    case openCodexDirectory
    case openDiagnosticsLog
    case exportDiagnosticsSummary

    public var id: String { rawValue }
}

public enum SettingsProviderAction: String, Equatable, CaseIterable, Identifiable {
    case removeProvider

    public var id: String { rawValue }
}

public struct SettingsActionMessage: Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let message: String

    public init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }
}

public struct SettingsConfirmationRequest: Equatable, Identifiable {
    public let id: UUID
    public let action: SettingsDestructiveAction

    public init(id: UUID = UUID(), action: SettingsDestructiveAction) {
        self.id = id
        self.action = action
    }
}

public struct SettingsProviderConfirmationRequest: Equatable, Identifiable {
    public let id: UUID
    public let action: SettingsProviderAction
    public let providerId: String

    public init(id: UUID = UUID(), action: SettingsProviderAction, providerId: String) {
        self.id = id
        self.action = action
        self.providerId = providerId
    }
}

public protocol SettingsActionHandling {
    func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage
    func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage
    func performProviderAction(_ action: SettingsProviderAction, providerId: String) throws -> SettingsActionMessage
}

public struct NoopSettingsActionHandler: SettingsActionHandling {
    private let preferredLanguages: [String]?

    public init(preferredLanguages: [String]? = nil) {
        self.preferredLanguages = preferredLanguages
    }

    public func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage {
        switch action {
        case .clearDiagnosticsLog:
            return SettingsActionMessage(
                title: SettingsStrings.text(.diagnosticsClearedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.diagnosticsClearedMessage, preferredLanguages: preferredLanguages)
            )
        case .clearUsageCache:
            return SettingsActionMessage(
                title: SettingsStrings.text(.usageCacheClearedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.usageCacheClearedMessage, preferredLanguages: preferredLanguages)
            )
        case .removeArchivedAccounts:
            return SettingsActionMessage(
                title: SettingsStrings.text(.accountsRemovedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.accountsRemovedMessage, preferredLanguages: preferredLanguages)
            )
        }
    }

    public func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage {
        switch action {
        case .openCodexDirectory:
            return SettingsActionMessage(
                title: SettingsStrings.text(.codexDirectoryOpenedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.codexDirectoryOpenedMessage, preferredLanguages: preferredLanguages)
            )
        case .openDiagnosticsLog:
            return SettingsActionMessage(
                title: SettingsStrings.text(.diagnosticsFolderOpenedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.diagnosticsFolderOpenedMessage, preferredLanguages: preferredLanguages)
            )
        case .exportDiagnosticsSummary:
            return SettingsActionMessage(
                title: SettingsStrings.text(.diagnosticsExportedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.text(.diagnosticsExportedMessage, preferredLanguages: preferredLanguages)
            )
        }
    }

    public func performProviderAction(_ action: SettingsProviderAction, providerId: String) throws -> SettingsActionMessage {
        switch action {
        case .removeProvider:
            return SettingsActionMessage(
                title: SettingsStrings.text(.providerRemovedTitle, preferredLanguages: preferredLanguages),
                message: SettingsStrings.providerRemovedNoConfigMessage(providerId, preferredLanguages: preferredLanguages)
            )
        }
    }
}
