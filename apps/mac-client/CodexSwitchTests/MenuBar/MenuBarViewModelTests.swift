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

    func testEnvironmentBackedServiceRefreshesActiveAccountUsageFromRolloutLogs() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: "fixture@example.com")
        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        let authData = try sampleAuthDataWithNestedPlan(
            email: "fixture@example.com",
            accountID: "google-oauth2|123456789",
            plan: "team"
        )
        try authData.write(to: paths.accountsDirectoryURL.appendingPathComponent(archiveFilename))
        try authData.write(to: paths.authFileURL)
        let metadata = CodexAccountMetadataCache(entries: [
            archiveFilename: CodexAccountMetadataEntry(
                source: .currentAuth,
                lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)
            ),
        ])
        try JSONEncoder().encode(metadata).write(to: paths.accountMetadataCacheURL)
        let sessionDirectory = currentSessionDirectory(paths: paths)
        let rolloutURL = sessionDirectory.appendingPathComponent("rollout-2026-03-29.jsonl")
        let rolloutLines = [
            #"{"timestamp":"2026-03-29T08:00:00Z","email":"fixture@example.com","rate_limits":{"five_hour":{"used_percent":42,"resets_at":"2026-03-29T10:30:00Z"},"weekly":{"used_percent":24,"resets_at":"2026-04-02T00:00:00Z"}}}"#,
        ].joined(separator: "\n")
        try Data(rolloutLines.utf8).write(to: rolloutURL)

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

        XCTAssertEqual(viewModel.headerTier, "TEAM")
        XCTAssertTrue(viewModel.updatedText.hasPrefix("Updated "))
        XCTAssertEqual(viewModel.accountRows.count, 1)
        XCTAssertEqual(viewModel.accountRows.first?.fiveHourPercent, 42)
        XCTAssertEqual(viewModel.accountRows.first?.weeklyPercent, 24)
    }

    func testEnvironmentBackedServiceUsesRemoteUsageInAutomaticMode() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let archiveFilename = CodexArchiveNaming.archiveFilename(for: "fixture@example.com")
        try FileManager.default.createDirectory(at: paths.accountsDirectoryURL, withIntermediateDirectories: true)
        let authData = try sampleAuthDataWithTransport(
            email: "fixture@example.com",
            accountID: "google-oauth2|123456789",
            plan: "team",
            accessToken: "access-token",
            transportAccountID: "chatgpt-account-id"
        )
        try authData.write(to: paths.accountsDirectoryURL.appendingPathComponent(archiveFilename))
        try authData.write(to: paths.authFileURL)
        let metadata = CodexAccountMetadataCache(entries: [
            archiveFilename: CodexAccountMetadataEntry(
                source: .currentAuth,
                lastImportedAt: Date(timeIntervalSince1970: 1_711_584_800)
            ),
        ])
        try JSONEncoder().encode(metadata).write(to: paths.accountMetadataCacheURL)

        let sessionDirectory = currentSessionDirectory(paths: paths)
        let rolloutURL = sessionDirectory.appendingPathComponent("rollout-2026-03-29.jsonl")
        let rolloutLines = [
            #"{"timestamp":"2026-03-29T08:00:00Z","email":"fixture@example.com","rate_limits":{"five_hour":{"used_percent":42,"resets_at":"2026-03-29T10:30:00Z"},"weekly":{"used_percent":24,"resets_at":"2026-04-02T00:00:00Z"}}}"#,
        ].joined(separator: "\n")
        try Data(rolloutLines.utf8).write(to: rolloutURL)

        let environment = try AppEnvironment.live(
            configuration: RuntimeConfiguration(
                paths: paths,
                loginRunner: StubCodexLoginRunner(result: .success),
                usageAPITransport: { request in
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "chatgpt-account-id")
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    let data = Data(
                        #"""
                        {
                          "email": "fixture@example.com",
                          "rate_limit": {
                            "primary_window": {
                              "used_percent": 11,
                              "resets_at": "2026-03-29T10:30:00Z"
                            },
                            "secondary_window": {
                              "used_percent": 19,
                              "resets_at": "2026-04-02T00:00:00Z"
                            }
                          }
                        }
                        """#.utf8
                    )
                    return (data, response)
                }
            )
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.headerTier, "TEAM")
        XCTAssertEqual(viewModel.accountRows.count, 1)
        XCTAssertEqual(viewModel.accountRows.first?.fiveHourPercent, 11)
        XCTAssertEqual(viewModel.accountRows.first?.weeklyPercent, 19)
    }

    func testEnvironmentBackedServiceReportsUsageRefreshDisabled() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let defaults = UserDefaults(suiteName: "CodexSwitchTests.UsageDisabled")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.UsageDisabled")
        defaults.set(false, forKey: SettingsViewModel.usageRefreshEnabledKey)

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
                loginRunner: StubCodexLoginRunner(result: .success),
                settingsDefaults: defaults
            )
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.updatedText, "Usage refresh disabled")
        XCTAssertEqual(viewModel.accountRows.first?.fiveHourPercent, 42)
    }

    func testEnvironmentBackedServiceLabelsLocalOnlyUsageMode() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let defaults = UserDefaults(suiteName: "CodexSwitchTests.UsageLocalOnly")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.UsageLocalOnly")
        defaults.set(CodexUsageSourceMode.localOnly.rawValue, forKey: SettingsViewModel.usageSourceModeKey)

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
                loginRunner: StubCodexLoginRunner(result: .success),
                settingsDefaults: defaults
            )
        )
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment)
        )

        await viewModel.refresh()

        XCTAssertTrue(viewModel.updatedText.hasPrefix("Updated "))
        XCTAssertTrue(viewModel.updatedText.contains("(Local Only)"))
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
            "Codex browser login did not complete. Complete the browser sign-in and try again."
        )
    }

    func testLoginInBrowserShowsFriendlyErrorWhenLoginTimesOut() async {
        let paths = CodexPaths(
            baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        let viewModel = MenuBarViewModel(
            service: MockMenuBarService(),
            loginCoordinator: CodexLoginCoordinator(
                runner: ThrowingCodexLoginRunner(error: .loginTimedOut),
                importer: CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths)),
                fileStore: CodexAuthFileStore(paths: paths)
            )
        )

        await viewModel.performAddAccountAction(.loginInBrowser)

        XCTAssertEqual(viewModel.alertMessage?.title, "Browser Login Timed Out")
        XCTAssertEqual(
            viewModel.alertMessage?.message,
            "The browser sign-in did not finish before timing out. Try Login in Browser again."
        )
    }

    func testLoginInBrowserShowsFriendlyErrorWhenBrowserCouldNotBeOpened() async {
        let paths = CodexPaths(
            baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        let viewModel = MenuBarViewModel(
            service: MockMenuBarService(),
            loginCoordinator: CodexLoginCoordinator(
                runner: ThrowingCodexLoginRunner(error: .browserLaunchFailed),
                importer: CodexAuthImporter(fileStore: CodexAuthFileStore(paths: paths)),
                fileStore: CodexAuthFileStore(paths: paths)
            )
        )

        await viewModel.performAddAccountAction(.loginInBrowser)

        XCTAssertEqual(viewModel.alertMessage?.title, "Browser Could Not Open")
        XCTAssertEqual(
            viewModel.alertMessage?.message,
            "Codex Switch could not open your default browser. Check your browser settings, then review ~/.codex/codex-switch-login.log and try again."
        )
    }

    func testStartAddAccountActionShowsBrowserLoginProgressAndIgnoresSecondTap() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let paths = CodexPaths(baseDirectory: tempDirectoryURL)
        let fileStore = CodexAuthFileStore(paths: paths)
        try sampleAuthData(email: "concurrent@example.com", tier: "pro").write(to: paths.authFileURL)

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
        let runner = CancellableBlockingCodexLoginRunner()
        let viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(
                environment: AppEnvironment(
                    accountStore: MockAccountStore(),
                    usageService: MockUsageService(),
                    accountRepository: repository,
                    activeAccountController: controller,
                    accountImporter: CodexAuthImporter(fileStore: fileStore),
                    runtimeMode: .live
                )
            ),
            accountRepository: repository,
            activeAccountController: controller,
            accountImporter: CodexAuthImporter(fileStore: fileStore),
            loginCoordinator: CodexLoginCoordinator(
                runner: runner,
                importer: CodexAuthImporter(fileStore: fileStore),
                fileStore: fileStore
            )
        )

        viewModel.startAddAccountAction(.loginInBrowser)
        try await waitForCondition { await runner.invocationCount() == 1 }

        XCTAssertTrue(viewModel.isPerformingAddAccountAction)
        XCTAssertEqual(
            viewModel.addAccountProgress,
            MenuBarViewModel.AddAccountProgressState(
                title: "Browser Login In Progress",
                message: "Complete the sign-in flow in your browser. You can cancel here and try again at any time.",
                showsCancelButton: true
            )
        )

        viewModel.startAddAccountAction(.loginInBrowser)
        let invocationCount = await runner.invocationCount()
        XCTAssertEqual(invocationCount, 1)
        XCTAssertNil(viewModel.alertMessage)

        viewModel.cancelAddAccountAction()
        try await waitForCondition { await runner.didObserveCancellation() }

        XCTAssertFalse(viewModel.isPerformingAddAccountAction)
        XCTAssertNil(viewModel.addAccountProgress)
        XCTAssertNil(viewModel.alertMessage)
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

    private func sampleAuthDataWithNestedPlan(email: String, accountID: String, plan: String) throws -> Data {
        let payload: [String: Any] = [
            "sub": accountID,
            "email": email,
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": plan,
            ],
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

    private func sampleAuthDataWithTransport(
        email: String,
        accountID: String,
        plan: String,
        accessToken: String,
        transportAccountID: String
    ) throws -> Data {
        let payload: [String: Any] = [
            "sub": accountID,
            "email": email,
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": plan,
            ],
        ]
        let token = [
            base64URL(#"{"alg":"none","typ":"JWT"}"#),
            base64URL(String(data: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), encoding: .utf8)!),
            "signature",
        ].joined(separator: ".")
        let object: [String: Any] = [
            "tokens": [
                "id_token": token,
                "access_token": accessToken,
                "account_id": transportAccountID,
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

    private func currentSessionDirectory(paths: CodexPaths) -> URL {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let directory = paths.sessionsDirectoryURL
            .appendingPathComponent(String(components.year ?? 0), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.month ?? 0), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.day ?? 0), isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func waitForCondition(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<200 {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for condition", file: file, line: line)
    }
}

private struct ThrowingCodexLoginRunner: CodexLoginRunning {
    let error: CodexAuthError

    func runLogin() async throws -> CodexLoginResult {
        throw error
    }
}

private actor CancellableBlockingCodexLoginRunner: CodexLoginRunning {
    private var count = 0
    private var observedCancellation = false

    func runLogin() async throws -> CodexLoginResult {
        count += 1
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        observedCancellation = true
        throw CancellationError()
    }

    func invocationCount() -> Int {
        count
    }

    func didObserveCancellation() -> Bool {
        observedCancellation
    }
}
