import XCTest
@testable import CodexSwitchKit

@MainActor
final class AppDelegateMainWindowTests: XCTestCase {
    func testMainWindowActionDispatcherRoutesThroughSharedPresenter() {
        let presenter = RecordingMainWindowPresenter()
        let dispatcher = MainWindowActionDispatcher(mainWindowPresenter: presenter)

        XCTAssertTrue(dispatcher.handle(.openMainWindow(.accounts)))
        XCTAssertTrue(dispatcher.handle(.openMainWindow(.settings)))
        XCTAssertFalse(dispatcher.handle(.quit))

        XCTAssertEqual(presenter.presentedRoutes, [.tab(.accounts), .tab(.settings)])
    }
}

@MainActor
private final class RecordingMainWindowPresenter: MainWindowPresenting {
    private(set) var presentedRoutes: [MainWindowRoute] = []

    func present(route: MainWindowRoute) {
        presentedRoutes.append(route)
    }
}
