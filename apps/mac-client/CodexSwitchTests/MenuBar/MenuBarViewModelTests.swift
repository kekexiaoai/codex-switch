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
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: "fixture@example.com")
        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        try sampleAuthData(email: "fixture@example.com", tier: "team").write(
            to: paths.accountsDirectoryURL.appendingPathComponent(archiveFilename)
        )
        let metadata = CodexAccountMetadataCache(entries: [
            archiveFilename: CodexAccountMetadataEntry(
                source: .currentAuth,
                lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)
            ),
        ])
        try JSONEncoder().encode(metadata).write(to: paths.accountMetadataCacheURL)
        let usageCache = CodexUsageCache(entries: [
            "subject-fixture@example.com": CodexUsageSnapshot(
                accountID: "subject-fixture@example.com",
                updatedAt: Date(timeIntervalSince1970: 1_711_584_800),
                fiveHour: CodexUsageWindow(percentUsed: 42, resetsAt: Date(timeIntervalSince1970: 1_711_591_000)),
                weekly: CodexUsageWindow(percentUsed: 24, resetsAt: Date(timeIntervalSince1970: 1_711_900_000))
            ),
        ])
        try JSONEncoder().encode(usageCache).write(to: paths.usageCacheURL)

        let environment = try AppEnvironment.live(
            configuration: RuntimeConfiguration(
                paths: paths,
                loginRunner: StubCodexLoginRunner(result: .success)
            )
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.headerEmail, "f••••••@example.com")
        XCTAssertTrue(viewModel.updatedText.hasPrefix("Updated "))
        XCTAssertEqual(viewModel.accountRows.count, 1)
        XCTAssertEqual(viewModel.accountRows.first?.fiveHourPercent, 42)
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

    func testImportCurrentAccountArchivesAccountAndActivatesIt() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let fileStore = CodexAuthFileStore(paths: paths)
        try sampleAuthData(email: "imported@example.com", tier: "pro").write(to: paths.authFileURL)

        let archivedAccountStore = CodexArchivedAccountStore(fileStore: fileStore)
        let repository = AccountRepository(catalog: archivedAccountStore)
        let controller = ActiveAccountController(
            activeAccountID: nil,
            switcher: CodexAccountSwitcher(
                archivedAccountStore: archivedAccountStore,
                fileStore: fileStore
            ),
            usageService: StubUsageRefreshService()
        )
        let environment = AppEnvironment(
            accountStore: MockAccountStore(),
            usageService: MockUsageService(),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: CodexAuthImporter(fileStore: fileStore),
            runtimeMode: .live
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: environment.accountImporter
        )

        await viewModel.refresh()
        _ = try await viewModel.importCurrentAccount()

        XCTAssertEqual(viewModel.accountRows.count, 1)
        XCTAssertEqual(controller.currentActiveAccountID(), "subject-imported@example.com")
        XCTAssertEqual(viewModel.headerEmail, "i•••••••@example.com")
    }

    func testImportCurrentAccountShowsFriendlyErrorForAPIKeyOnlyAuth() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let fileStore = CodexAuthFileStore(paths: paths)
        let apiKeyOnlyAuth = """
        {"api_key":"sk-test","provider":"openai"}
        """
        try Data(apiKeyOnlyAuth.utf8).write(to: paths.authFileURL)

        let viewModel = MenuBarViewModel(
            service: MockMenuBarService(),
            accountImporter: CodexAuthImporter(fileStore: fileStore)
        )

        await viewModel.performAddAccountAction(.importCurrentAccount)

        XCTAssertEqual(viewModel.alertMessage?.title, "Cannot Import Current Account")
        XCTAssertEqual(
            viewModel.alertMessage?.message,
            "Current Codex auth does not contain a browser login session. If this machine is using OPENAI_API_KEY mode, choose Login in Browser or import a backup auth.json."
        )
    }

    func testImportCurrentAccountShowsRefreshMessageForExistingAccount() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let fileStore = CodexAuthFileStore(paths: paths)
        try sampleAuthData(email: "existing@example.com", tier: "team").write(to: paths.authFileURL)

        let archivedAccountStore = CodexArchivedAccountStore(fileStore: fileStore)
        let repository = AccountRepository(catalog: archivedAccountStore)
        let controller = ActiveAccountController(
            activeAccountID: nil,
            switcher: CodexAccountSwitcher(
                archivedAccountStore: archivedAccountStore,
                fileStore: fileStore
            ),
            usageService: StubUsageRefreshService()
        )
        let importer = CodexAuthImporter(fileStore: fileStore)
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(
                environment: AppEnvironment(
                    accountStore: MockAccountStore(),
                    usageService: MockUsageService(),
                    accountRepository: repository,
                    activeAccountController: controller,
                    accountImporter: importer,
                    runtimeMode: .live
                )
            ),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: importer
        )

        _ = try await viewModel.importCurrentAccount()
        viewModel.dismissAlert()

        try sampleAuthData(email: "existing@example.com", tier: "pro").write(to: paths.authFileURL)
        await viewModel.performAddAccountAction(.importCurrentAccount)

        XCTAssertEqual(viewModel.alertMessage?.title, "Account Refreshed")
        XCTAssertEqual(viewModel.alertMessage?.message, "Account already exists, auth refreshed.")
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

    func testImportBackupAccountUsesPickerResultAndActivatesIt() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let fileStore = CodexAuthFileStore(paths: paths)
        let backupURL = tempDirectoryURL.appendingPathComponent("backup-auth.json")
        try sampleAuthData(email: "backup@example.com", tier: "team").write(to: backupURL)

        let archivedAccountStore = CodexArchivedAccountStore(fileStore: fileStore)
        let repository = AccountRepository(catalog: archivedAccountStore)
        let controller = ActiveAccountController(
            activeAccountID: nil,
            switcher: CodexAccountSwitcher(
                archivedAccountStore: archivedAccountStore,
                fileStore: fileStore
            ),
            usageService: StubUsageRefreshService()
        )
        let environment = AppEnvironment(
            accountStore: MockAccountStore(),
            usageService: MockUsageService(),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: CodexAuthImporter(fileStore: fileStore),
            runtimeMode: .live
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: environment.accountImporter,
            backupAuthPicker: StubBackupAuthPicker(selectedURL: backupURL)
        )

        _ = try await viewModel.importBackupAccount()

        let savedAccounts = try await repository.loadAccounts()
        XCTAssertEqual(savedAccounts.count, 1)
        XCTAssertEqual(savedAccounts.last?.email, "backup@example.com")
        XCTAssertEqual(savedAccounts.last?.tier, .team)
        XCTAssertEqual(controller.currentActiveAccountID(), "subject-backup@example.com")
    }

    func testLoginInBrowserShowsFriendlyErrorWhenLoginFails() async {
        let paths = CodexPaths(
            baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        let viewModel = MenuBarViewModel(
            service: MockMenuBarService(),
            loginCoordinator: CodexLoginCoordinator(
                runner: StubCodexLoginRunner(result: .failure),
                importer: CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths)),
                fileStore: CodexAuthFileStore(paths: paths)
            )
        )

        await viewModel.performAddAccountAction(.loginInBrowser)

        XCTAssertEqual(viewModel.alertMessage?.title, "Browser Login Failed")
        XCTAssertEqual(
            viewModel.alertMessage?.message,
            "Codex browser login did not complete. A Terminal window was opened for login. Finish login there, then try Import Current Account if it was not imported automatically."
        )
    }

    func testAddAccountMenuExposesThreeChoices() {
        XCTAssertEqual(
            MenuBarViewModel.AddAccountAction.allCases.map { "\($0.title)|\($0.systemImageName)" },
            [
                "Import Current Account|person.crop.circle.badge.clock",
                "Import Backup Auth|tray.and.arrow.down",
                "Login in Browser|globe",
            ]
        )
    }

    func testEmailVisibilityToggleUsesCurrentStateIcon() {
        XCTAssertEqual(emailVisibilityToggleSystemImage(showEmails: true), "eye")
        XCTAssertEqual(emailVisibilityToggleSystemImage(showEmails: false), "eye.slash")
    }

    private func sampleAuthData(email: String, tier: String) throws -> Data {
        let payload = [
            "sub": "subject-\(email)",
            "email": email,
            "tier": tier,
        ]
        let token = [
            base64URL(#"{"alg":"none","typ":"JWT"}"#),
            base64URL(String(data: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), encoding: .utf8)!),
            "signature",
        ].joined(separator: ".")
        let object: [String: Any] = [
            "tokens": [
                "id_token": token,
            ],
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func base64URL(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func emailVisibilityToggleSystemImage(showEmails: Bool) -> String {
        showEmails ? "eye" : "eye.slash"
    }
}
