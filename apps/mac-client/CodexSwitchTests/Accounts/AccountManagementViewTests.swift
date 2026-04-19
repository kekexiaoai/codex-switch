import XCTest
@testable import CodexSwitchKit

@MainActor
final class AccountManagementViewTests: XCTestCase {
    func testAccountManagementViewShowsMoveControlsAndUsageColumns() {
        let view = AccountManagementView(viewModel: .preview)

        XCTAssertTrue(view.columnTitles.contains("5H"))
        XCTAssertTrue(view.columnTitles.contains("7D"))
        XCTAssertTrue(view.columnTitles.contains("排序"))
    }
}
