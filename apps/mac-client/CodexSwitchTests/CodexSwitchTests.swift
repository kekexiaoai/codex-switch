import XCTest
@testable import CodexSwitchKit

final class CodexSwitchTests: XCTestCase {
    func testAppEnvironmentStartsWithMockServices() {
        let environment = AppEnvironment.preview

        XCTAssertNotNil(environment.accountStore)
        XCTAssertNotNil(environment.usageService)
    }

    func testMenuBarHostDefaultsToSupportedHost() {
        let host = MenuBarHostKind.current

        XCTAssertTrue(host == .statusItemPopover || host == .menuBarExtra)
    }
}
