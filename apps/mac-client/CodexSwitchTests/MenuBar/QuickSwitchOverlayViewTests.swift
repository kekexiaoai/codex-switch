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
                    fiveHourLabel: "5h 42%",
                    weeklyLabel: "7d 18%",
                    isActive: true
                ),
            ],
            onSelect: { _ in }
        )

        XCTAssertEqual(view.rowIDs, ["acct-1"])
        XCTAssertFalse(view.actionLabels.contains("打开主窗口"))
    }

    func testQuickSwitchOverlayPreferredWidthExpandsForLongEmailButStaysWithinCap() {
        let rows = [
            QuickSwitchRowModel(
                id: "acct-1",
                emailText: "very-long-account-email-address-for-testing@example.com",
                tierBadgeText: "TEAM",
                fiveHourLabel: "5h 49%",
                weeklyLabel: "7d 38%",
                isActive: false
            ),
        ]

        let width = QuickSwitchOverlayView.preferredWidth(for: rows)

        XCTAssertGreaterThan(width, 320)
        XCTAssertLessThanOrEqual(width, 520)
    }
}
