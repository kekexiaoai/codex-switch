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

public protocol SettingsActionHandling {
    func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage
    func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage
}

public struct NoopSettingsActionHandler: SettingsActionHandling {
    public init() {}

    public func performDestructiveAction(_ action: SettingsDestructiveAction) throws -> SettingsActionMessage {
        switch action {
        case .clearDiagnosticsLog:
            return SettingsActionMessage(title: "Diagnostics Cleared", message: "Removed local diagnostics logs.")
        case .clearUsageCache:
            return SettingsActionMessage(title: "Usage Cache Cleared", message: "Removed cached usage data.")
        case .removeArchivedAccounts:
            return SettingsActionMessage(title: "Accounts Removed", message: "Removed archived accounts.")
        }
    }

    public func performUtilityAction(_ action: SettingsUtilityAction) throws -> SettingsActionMessage {
        switch action {
        case .openCodexDirectory:
            return SettingsActionMessage(title: "Codex Directory Opened", message: "Opened ~/.codex.")
        case .openDiagnosticsLog:
            return SettingsActionMessage(title: "Diagnostics Folder Opened", message: "Opened the local diagnostics folder.")
        case .exportDiagnosticsSummary:
            return SettingsActionMessage(title: "Diagnostics Exported", message: "Exported a sanitized diagnostics summary.")
        }
    }
}
