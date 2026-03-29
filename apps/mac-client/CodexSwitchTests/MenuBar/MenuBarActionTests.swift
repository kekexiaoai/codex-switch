import XCTest
@testable import CodexSwitchKit

@MainActor
final class MenuBarActionTests: XCTestCase {
    func testOpenSettingsDelegatesToActionHandler() {
        let handler = RecordingMenuBarActionHandler()
        let viewModel = MenuBarViewModel(
            service: MockMenuBarService(),
            actionHandler: handler
        )

        viewModel.openSettings()

        XCTAssertEqual(handler.recordedActions, [.openSettings])
    }

    func testQuitDelegatesToActionHandler() {
        let handler = RecordingMenuBarActionHandler()
        let viewModel = MenuBarViewModel(
            service: MockMenuBarService(),
            actionHandler: handler
        )

        viewModel.quit()

        XCTAssertEqual(handler.recordedActions, [.quit])
    }

    func testOpenStatusPageDelegatesToActionHandler() {
        let handler = RecordingMenuBarActionHandler()
        let viewModel = MenuBarViewModel(
            service: MockMenuBarService(),
            actionHandler: handler
        )

        viewModel.openStatusPage()

        XCTAssertEqual(handler.recordedActions, [.openStatusPage])
    }
}
