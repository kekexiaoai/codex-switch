import Foundation

public enum MainWindowTab: String, CaseIterable, Equatable {
    case accounts
    case providerSync
    case settings
    case status

    public var title: String {
        switch self {
        case .accounts:
            return "账号"
        case .providerSync:
            return "Provider Sync"
        case .settings:
            return "设置"
        case .status:
            return "状态"
        }
    }
}
