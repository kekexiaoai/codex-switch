import XCTest
@testable import CodexSwitchKit

@MainActor
final class CompactAccountRowViewTests: XCTestCase {
    func testSegmentOrderPlacesTierBadgeBeforeEmail() {
        let row = QuickSwitchRowModel(
            id: "acct-1",
            emailText: "a@example.com",
            tierBadgeText: "TEAM",
            fiveHourLabel: "5h 42%",
            weeklyLabel: "7d 18%",
            isActive: true
        )
        let view = CompactAccountRowView(row: row)

        XCTAssertEqual(view.segmentOrder, [.tierBadge, .email, .fiveHour, .weekly, .activeCheckmark])
    }

    func testHoveredBackgroundIsStrongerThanIdleBackground() {
        XCTAssertGreaterThan(
            CompactAccountRowView.backgroundOpacity(isHovered: true, isPressed: false),
            CompactAccountRowView.backgroundOpacity(isHovered: false, isPressed: false)
        )
    }
}
