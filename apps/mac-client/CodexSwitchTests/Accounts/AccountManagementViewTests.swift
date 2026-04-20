import XCTest
@testable import CodexSwitchKit

@MainActor
final class AccountManagementViewTests: XCTestCase {
    func testAccountManagementViewShowsRichSectionsAndUsageColumns() {
        let view = AccountManagementView(viewModel: .preview)

        XCTAssertEqual(view.pageTitle, "账号")
        XCTAssertEqual(view.summaryLabels, ["当前账号", "归档账号", "排序来源"])
        XCTAssertEqual(view.emailVisibilityButtonLabel, "显示邮箱")
        XCTAssertTrue(view.columnTitles.contains("5H"))
        XCTAssertTrue(view.columnTitles.contains("7D"))
        XCTAssertTrue(view.columnTitles.contains("排序"))
    }
}
