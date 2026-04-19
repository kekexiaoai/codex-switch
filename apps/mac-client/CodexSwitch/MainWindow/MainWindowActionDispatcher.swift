import Foundation

@MainActor
public struct MainWindowActionDispatcher {
    private let mainWindowPresenter: any MainWindowPresenting

    public init(mainWindowPresenter: any MainWindowPresenting) {
        self.mainWindowPresenter = mainWindowPresenter
    }

    @discardableResult
    public func handle(_ action: MenuBarAction) -> Bool {
        switch action {
        case .openMainWindow(let tab):
            mainWindowPresenter.present(route: .tab(tab))
            return true
        case .quit:
            return false
        }
    }
}
