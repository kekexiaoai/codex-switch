import Foundation

public enum MainWindowRoute: Equatable {
    case tab(MainWindowTab)

    public var selectedTab: MainWindowTab {
        switch self {
        case .tab(let tab):
            return tab
        }
    }
}
