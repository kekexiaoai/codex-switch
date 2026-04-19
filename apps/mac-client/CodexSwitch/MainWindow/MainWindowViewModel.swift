import Foundation

@MainActor
public final class MainWindowViewModel: ObservableObject {
    @Published public var selectedTab: MainWindowTab

    public init(selectedTab: MainWindowTab = .accounts) {
        self.selectedTab = selectedTab
    }
}
