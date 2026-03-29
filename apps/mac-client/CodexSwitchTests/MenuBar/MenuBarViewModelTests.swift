import XCTest
@testable import CodexSwitchKit

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testMenuBarViewModelFormatsCurrentAccountSummary() async {
        let viewModel = MenuBarViewModel.preview

        await viewModel.refresh()

        XCTAssertEqual(viewModel.headerEmail, "a••••@gmail.com")
        XCTAssertEqual(viewModel.accountRows.count, 5)
    }

    func testEnvironmentBackedServiceLoadsLiveSnapshot() async throws {
        let environment = try AppEnvironment.live(configuration: .fixture)
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.headerEmail, "fixture-account")
        XCTAssertEqual(viewModel.updatedText, "live-fixture")
        XCTAssertEqual(viewModel.accountRows.count, 1)
    }
}
