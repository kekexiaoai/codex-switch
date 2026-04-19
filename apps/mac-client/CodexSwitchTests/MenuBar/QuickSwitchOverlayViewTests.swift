import XCTest
@testable import CodexSwitchKit

@MainActor
final class QuickSwitchOverlayViewTests: XCTestCase {
    func testQuickSwitchOverlayHasScrollableRowsAndNoManagementAction() {
        let view = QuickSwitchOverlayView(
            rows: [
                QuickSwitchRowModel(
                    id: "acct-1",
                    emailText: "a@example.com",
                    tierBadgeText: "TEAM",
                    fiveHourLabel: "5H 42%",
                    weeklyLabel: "7D 18%",
                    isActive: true
                ),
            ],
            onSelect: { _ in }
        )

        XCTAssertEqual(view.rowIDs, ["acct-1"])
        XCTAssertFalse(view.actionLabels.contains("打开主窗口"))
    }
}
