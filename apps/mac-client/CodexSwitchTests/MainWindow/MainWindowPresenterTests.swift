import AppKit
import XCTest
@testable import CodexSwitchKit

@MainActor
final class MainWindowPresenterTests: XCTestCase {
    func testMainWindowPresenterUsesStatusWindowWidthAsDefaultContentWidth() {
        XCTAssertEqual(MainWindowPresenter.defaultContentSize.width, 640)
        XCTAssertEqual(MainWindowPresenter.minimumContentSize.width, 520)
        XCTAssertEqual(MainWindowPresenter.minimumContentSize.height, 560)
    }

    func testMainWindowPresenterReusesWindowAndUpdatesSelectedTab() {
        var makeCount = 0
        var renderedTabs: [MainWindowTab] = []
        var presentedControllers: [NSWindowController] = []

        let presenter = MainWindowPresenter(
            makeViewModel: { route in
                MainWindowViewModel(selectedTab: route.selectedTab)
            },
            makeWindowController: { viewModel in
                makeCount += 1
                renderedTabs.append(viewModel.selectedTab)
                return NSWindowController(window: NSWindow())
            },
            updateWindowController: { _, viewModel in
                renderedTabs.append(viewModel.selectedTab)
            },
            presentWindowController: { controller in
                presentedControllers.append(controller)
            }
        )

        presenter.present(route: .tab(.accounts))
        presenter.present(route: .tab(.settings))

        XCTAssertEqual(makeCount, 1)
        XCTAssertEqual(renderedTabs, [.accounts, .settings])
        XCTAssertEqual(presentedControllers.count, 2)
        XCTAssertTrue(presentedControllers[0] === presentedControllers[1])
    }
}
