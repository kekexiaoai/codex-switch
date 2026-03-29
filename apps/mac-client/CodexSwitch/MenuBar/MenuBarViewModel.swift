import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public private(set) var headerEmail = ""
    @Published public private(set) var headerTier = ""
    @Published public private(set) var updatedText = ""
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []
    @Published public private(set) var showEmails = false

    private let service: any MenuBarSnapshotService
    private let accountRepository: AccountRepository?
    private let activeAccountController: ActiveAccountController?
    private let accountImporter: CodexAuthImporter?
    private let loginCoordinator: CodexLoginCoordinator?
    private let backupAuthPicker: (any BackupAuthPicking)?
    private let emailVisibilityStore: (any EmailVisibilityMutating)?
    private let actionHandler: (any MenuBarActionHandling)?

    public static let preview = MenuBarViewModel(service: MockMenuBarService())

    public init(
        service: any MenuBarSnapshotService,
        accountRepository: AccountRepository? = nil,
        activeAccountController: ActiveAccountController? = nil,
        accountImporter: CodexAuthImporter? = nil,
        loginCoordinator: CodexLoginCoordinator? = nil,
        backupAuthPicker: (any BackupAuthPicking)? = nil,
        emailVisibilityStore: (any EmailVisibilityMutating)? = nil,
        actionHandler: (any MenuBarActionHandling)? = nil
    ) {
        self.service = service
        self.accountRepository = accountRepository
        self.activeAccountController = activeAccountController
        self.accountImporter = accountImporter
        self.loginCoordinator = loginCoordinator
        self.backupAuthPicker = backupAuthPicker
        self.emailVisibilityStore = emailVisibilityStore
        self.actionHandler = actionHandler
        self.showEmails = emailVisibilityStore?.showEmails() ?? false
    }

    public func refresh() async {
        let snapshot = await service.loadSnapshot()
        showEmails = emailVisibilityStore?.showEmails() ?? showEmails
        headerEmail = snapshot.headerEmail
        headerTier = snapshot.headerTier
        updatedText = snapshot.updatedText
        summaries = snapshot.summaries
        accountRows = snapshot.accounts
    }

    public func switchToAccount(id: String) async throws {
        try await activeAccountController?.activateAccount(id: id)
        await refresh()
    }

    public func toggleShowEmails() async {
        let nextValue = !(emailVisibilityStore?.showEmails() ?? showEmails)
        emailVisibilityStore?.setShowEmails(nextValue)
        showEmails = nextValue
        await refresh()
    }

    public func openStatusPage() {
        actionHandler?.handle(.openStatusPage)
    }

    public func openSettings() {
        actionHandler?.handle(.openSettings)
    }

    public func quit() {
        actionHandler?.handle(.quit)
    }

    public func importCurrentAccount() async throws {
        guard let accountImporter else {
            return
        }

        let account = try accountImporter.importCurrentAccount()
        try await activeAccountController?.activateAccount(id: account.id)
        await refresh()
    }

    public func importBackupAccount() async throws {
        guard let accountImporter, let backupAuthPicker else {
            return
        }

        guard let backupURL = await backupAuthPicker.pickBackupAuthURL() else {
            return
        }

        let account = try accountImporter.importBackupAuth(from: backupURL)
        try await activeAccountController?.activateAccount(id: account.id)
        await refresh()
    }

    public func loginInBrowser() async throws {
        guard let loginCoordinator else {
            return
        }

        let account = try await loginCoordinator.loginAndImport()
        try await activeAccountController?.activateAccount(id: account.id)
        await refresh()
    }
}
