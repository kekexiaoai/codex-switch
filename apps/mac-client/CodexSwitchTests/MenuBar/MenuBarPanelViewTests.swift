import CoreGraphics
import XCTest
@testable import CodexSwitchKit

@MainActor
final class MenuBarPanelViewTests: XCTestCase {
    func testPanelWidthStaysBaseWidthWhenQuickSwitchOverlayIsVisible() {
        XCTAssertEqual(MenuBarPanelView.contentWidth(isShowingQuickSwitchOverlay: false), 360)
        XCTAssertEqual(MenuBarPanelView.contentWidth(isShowingQuickSwitchOverlay: true), 360)
    }

    func testQuickSwitchOverlayOriginAnchorsToRightOfTriggerRow() {
        let anchorFrame = CGRect(x: 6, y: 184, width: 328, height: 28)

        let origin = MenuBarQuickSwitchOverlayLayout.overlayOrigin(for: anchorFrame)

        XCTAssertEqual(origin.x, 346, accuracy: 0.1)
        XCTAssertEqual(origin.y, 184, accuracy: 0.1)
    }
}
