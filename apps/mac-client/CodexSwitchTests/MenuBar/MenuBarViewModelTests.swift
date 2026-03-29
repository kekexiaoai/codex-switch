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

        XCTAssertEqual(viewModel.headerEmail, "fixture@example.com")
        XCTAssertEqual(viewModel.updatedText, "live-fixture")
        XCTAssertEqual(viewModel.accountRows.count, 1)
    }

    func testSwitchingAccountRefreshesHeaderState() async throws {
        let metadataStore = InMemoryAccountMetadataStore(
            accounts: [
                Account(id: "acct-1", emailMask: "a@example.com", tier: .team),
                Account(id: "acct-2", emailMask: "b@example.com", tier: .plus),
            ]
        )
        let repository = AccountRepository(
            metadataStore: metadataStore,
            credentialStore: InMemoryCredentialStore()
        )
        let controller = ActiveAccountController(
            activeAccountID: "acct-1",
            switcher: StubSwitchCommandRunner(),
            usageService: StubUsageRefreshService()
        )
        let environment = AppEnvironment(
            accountStore: MockAccountStore(),
            usageService: MockUsageService(),
            accountRepository: repository,
            activeAccountController: controller,
            runtimeMode: .live
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment),
            activeAccountController: controller
        )

        await viewModel.refresh()
        try await viewModel.switchToAccount(id: "acct-2")

        XCTAssertEqual(controller.currentActiveAccountID(), "acct-2")
        XCTAssertEqual(viewModel.headerEmail, "b@example.com")
    }
}
