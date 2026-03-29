import XCTest
@testable import CodexSwitchKit

final class RealIntegrationSmokeTests: XCTestCase {
    @MainActor
    func testRealEnvironmentCanResolveConfiguredAccountBackend() async throws {
        let environment = try AppEnvironment.live(configuration: .fixture)

        XCTAssertEqual(environment.runtimeMode, .live)
        XCTAssertNotNil(environment.accountRepository)
        XCTAssertNotNil(environment.activeAccountController)
        let accounts = try await environment.accountRepository?.loadAccounts()
        XCTAssertEqual(accounts?.first?.emailMask, "f••••••@example.com")
        XCTAssertEqual(accounts?.first?.email, "fixture@example.com")
    }
}
