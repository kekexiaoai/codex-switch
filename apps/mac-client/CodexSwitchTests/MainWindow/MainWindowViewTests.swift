import XCTest
@testable import CodexSwitchKit

@MainActor
final class MainWindowViewTests: XCTestCase {
    func testMainWindowViewExposesExpectedTabs() {
        let view = MainWindowView(viewModel: MainWindowViewModel(selectedTab: .accounts))

        XCTAssertEqual(view.tabLabels, ["账号", "Provider Sync", "状态", "设置"])
        XCTAssertEqual(view.contentMinimumWidth, 520)
        XCTAssertEqual(view.contentMinimumHeight, 560)
    }
}
