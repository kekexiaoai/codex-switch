import XCTest
@testable import CodexSwitchKit

@MainActor
final class AccountManagementViewTests: XCTestCase {
    func testAccountManagementViewShowsRichSectionsAndUsageColumns() {
        let view = AccountManagementView(viewModel: .preview)

        XCTAssertEqual(view.pageTitle, "账号")
        XCTAssertEqual(view.summaryLabels, ["当前账号", "归档账号", "排序来源"])
        XCTAssertEqual(view.emailVisibilityButtonLabel, "显示邮箱")
        XCTAssertEqual(view.reorderInstructionText, "拖动卡片即可调整顺序。")
        XCTAssertEqual(view.usageCardTitles, ["5 小时额度", "7 天额度"])
        XCTAssertTrue(view.columnTitles.contains("5H"))
        XCTAssertTrue(view.columnTitles.contains("7D"))
        XCTAssertTrue(view.columnTitles.contains("拖拽"))
        XCTAssertFalse(view.columnTitles.contains("排序"))
    }
}
