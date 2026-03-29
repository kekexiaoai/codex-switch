import XCTest
@testable import CodexSwitchKit

final class RealIntegrationSmokeTests: XCTestCase {
    func testRealEnvironmentCanResolveConfiguredAccountBackend() throws {
        let environment = try AppEnvironment.live(configuration: .fixture)

        XCTAssertEqual(environment.runtimeMode, .live)
    }
}
