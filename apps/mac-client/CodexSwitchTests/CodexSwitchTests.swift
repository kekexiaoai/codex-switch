import XCTest
@testable import CodexSwitchKit

final class CodexSwitchTests: XCTestCase {
    func testAppEnvironmentStartsWithMockServices() {
        let environment = AppEnvironment.preview

        XCTAssertNotNil(environment.accountStore)
        XCTAssertNotNil(environment.usageService)
    }

    func testAppEnvironmentUsesReferenceSemanticsForStartupContainer() {
        let environment = AppEnvironment.preview
        let object = environment as AnyObject

        XCTAssertTrue(object === (environment as AnyObject))
    }

    func testMenuBarHostDefaultsToSupportedHost() {
        let host = MenuBarHostKind.current

        XCTAssertTrue(host == .statusItemPopover || host == .menuBarExtra)
    }
}
