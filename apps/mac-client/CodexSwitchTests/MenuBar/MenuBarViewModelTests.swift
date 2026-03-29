import XCTest
@testable import CodexSwitchKit

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testAccountMaskingHidesMostOfLocalPart() {
        XCTAssertEqual(Account.maskedEmail("alex@example.com"), "a•••@example.com")
        XCTAssertEqual(Account.maskedEmail("ab@example.com"), "a•@example.com")
    }

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

        XCTAssertEqual(viewModel.headerEmail, "f••••••@example.com")
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
        XCTAssertEqual(viewModel.accountRows.map(\.id), ["acct-1", "acct-2"])
        try await viewModel.switchToAccount(id: "acct-2")

        XCTAssertEqual(controller.currentActiveAccountID(), "acct-2")
        XCTAssertEqual(viewModel.headerEmail, "b@example.com")
    }

    func testAddDemoAccountAppendsAccountAndActivatesIt() async throws {
        let metadataStore = InMemoryAccountMetadataStore(
            accounts: [
                Account(id: "acct-1", emailMask: "a••••@example.com", email: "a@example.com", tier: .team),
            ]
        )
        let credentialStore = InMemoryCredentialStore()
        let repository = AccountRepository(
            metadataStore: metadataStore,
            credentialStore: credentialStore
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
            accountRepository: repository,
            activeAccountController: controller
        )

        await viewModel.refresh()
        try await viewModel.addDemoAccount()

        XCTAssertEqual(viewModel.accountRows.count, 2)
        XCTAssertEqual(controller.currentActiveAccountID(), "demo-2")
        XCTAssertEqual(viewModel.headerEmail, "d••••@example.com")
    }

    func testEnvironmentBackedServiceShowsFullEmailsWhenPreferenceEnabled() async throws {
        let metadataStore = InMemoryAccountMetadataStore(
            accounts: [
                Account(id: "acct-1", emailMask: "a••••@example.com", email: "a@example.com", tier: .team),
            ]
        )
        let repository = AccountRepository(
            metadataStore: metadataStore,
            credentialStore: InMemoryCredentialStore()
        )
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.EmailVisibility")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.EmailVisibility")
        defaults.set(true, forKey: SettingsViewModel.showEmailsKey)

        let environment = AppEnvironment(
            accountStore: MockAccountStore(),
            usageService: MockUsageService(),
            accountRepository: repository,
            activeAccountController: nil,
            emailVisibilityProvider: UserDefaultsEmailVisibilityStore(defaults: defaults),
            runtimeMode: .live
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.headerEmail, "a@example.com")
        XCTAssertEqual(viewModel.accountRows.first?.emailMask, "a@example.com")
    }

    func testToggleShowEmailsRefreshesVisibleEmailState() async throws {
        let metadataStore = InMemoryAccountMetadataStore(
            accounts: [
                Account(id: "acct-1", emailMask: "a••••@example.com", email: "a@example.com", tier: .team),
            ]
        )
        let repository = AccountRepository(
            metadataStore: metadataStore,
            credentialStore: InMemoryCredentialStore()
        )
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.ToggleVisibility")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.ToggleVisibility")
        let environment = AppEnvironment(
            accountStore: MockAccountStore(),
            usageService: MockUsageService(),
            accountRepository: repository,
            activeAccountController: nil,
            emailVisibilityProvider: UserDefaultsEmailVisibilityStore(defaults: defaults),
            runtimeMode: .live
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment),
            emailVisibilityStore: UserDefaultsEmailVisibilityStore(defaults: defaults)
        )

        await viewModel.refresh()
        XCTAssertEqual(viewModel.headerEmail, "a••••@example.com")

        await viewModel.toggleShowEmails()

        XCTAssertEqual(viewModel.headerEmail, "a@example.com")
    }

    func testSubmitNewAccountPersistsDraftAndActivatesIt() async throws {
        let metadataStore = InMemoryAccountMetadataStore(
            accounts: [
                Account(id: "acct-1", emailMask: "a••••@example.com", email: "a@example.com", tier: .team),
            ]
        )
        let credentialStore = InMemoryCredentialStore()
        let repository = AccountRepository(
            metadataStore: metadataStore,
            credentialStore: credentialStore
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
            accountRepository: repository,
            activeAccountController: controller
        )

        viewModel.startAddingAccount()
        viewModel.draftEmail = "newperson@example.com"
        viewModel.draftSecret = "secret-2"
        viewModel.draftTier = .pro

        try await viewModel.submitNewAccount()

        let savedAccounts = try await repository.loadAccounts()
        XCTAssertEqual(savedAccounts.count, 2)
        XCTAssertEqual(savedAccounts.last?.email, "newperson@example.com")
        XCTAssertEqual(savedAccounts.last?.emailMask, "n••••••••@example.com")
        XCTAssertEqual(savedAccounts.last?.tier, .pro)
        XCTAssertEqual(controller.currentActiveAccountID(), "acct-2")
    }
}
