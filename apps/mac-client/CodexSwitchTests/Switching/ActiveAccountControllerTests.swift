import XCTest
@testable import CodexSwitchKit

@MainActor
final class ActiveAccountControllerTests: XCTestCase {
    func testSwitchingAccountMarksSelectionAndRefreshesUsage() async throws {
        let controller = ActiveAccountController(
            switcher: StubSwitchCommandRunner(),
            usageService: StubUsageRefreshService()
        )

        try await controller.activateAccount(id: "acct-2")

        XCTAssertEqual(controller.activeAccountID, "acct-2")
        XCTAssertEqual(controller.lastRefreshSource, "switch")
    }
}
