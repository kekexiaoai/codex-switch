import Foundation

@MainActor
public protocol AccountManagementServicing {
    func loadAccounts() async throws -> [Account]
    func saveManualOrder(idsInOrder: [String]) async throws
    func removeAccount(id: String) async throws
    func activateAccount(id: String) async throws
    func performAddAccountAction(_ action: AccountManagementAddAction) async throws -> Account?
    func usageSnapshot(for accountID: String) async -> CodexUsageSnapshot?
    func currentActiveAccountID() async -> String?
    func showEmails() -> Bool
    func setShowEmails(_ enabled: Bool)
}

@MainActor
public struct AccountManagementService: AccountManagementServicing {
    private let accountRepository: AccountRepository?
    private let orderStore: (any AccountOrderPersisting)?
    private let accountRemover: (any AccountRemoving)?
    private let activeAccountController: ActiveAccountController?
    private let usageService: (any UsageService)?
    private let emailVisibilityStore: (any EmailVisibilityMutating)?
    private let accountImporter: CodexAuthImporter?
    private let backupAuthPicker: (any BackupAuthPicking)?
    private let loginCoordinator: CodexLoginCoordinator?

    public init(
        accountRepository: AccountRepository?,
        orderStore: (any AccountOrderPersisting)?,
        accountRemover: (any AccountRemoving)?,
        activeAccountController: ActiveAccountController?,
        usageService: (any UsageService)?,
        emailVisibilityStore: (any EmailVisibilityMutating)?,
        accountImporter: CodexAuthImporter? = nil,
        backupAuthPicker: (any BackupAuthPicking)? = nil,
        loginCoordinator: CodexLoginCoordinator? = nil
    ) {
        self.accountRepository = accountRepository
        self.orderStore = orderStore
        self.accountRemover = accountRemover
        self.activeAccountController = activeAccountController
        self.usageService = usageService
        self.emailVisibilityStore = emailVisibilityStore
        self.accountImporter = accountImporter
        self.backupAuthPicker = backupAuthPicker
        self.loginCoordinator = loginCoordinator
    }

    public func loadAccounts() async throws -> [Account] {
        try await accountRepository?.loadAccounts() ?? []
    }

    public func saveManualOrder(idsInOrder: [String]) async throws {
        try await orderStore?.saveManualOrder(idsInOrder: idsInOrder)
    }

    public func removeAccount(id: String) async throws {
        _ = try await accountRemover?.removeArchivedAccount(
            id: id,
            activeAccountID: activeAccountController?.currentActiveAccountID()
        )
    }

    public func activateAccount(id: String) async throws {
        try await activeAccountController?.activateAccount(id: id)
    }

    public func performAddAccountAction(_ action: AccountManagementAddAction) async throws -> Account? {
        switch action {
        case .importCurrentAccount:
            guard let accountImporter else {
                return nil
            }

            let account = try accountImporter.importCurrentAccount()
            try await activeAccountController?.activateAccount(id: account.id)
            return account
        case .importBackupAuth:
            guard let accountImporter, let backupAuthPicker else {
                return nil
            }

            guard let backupURL = await backupAuthPicker.pickBackupAuthURL() else {
                return nil
            }

            let account = try accountImporter.importBackupAuth(from: backupURL)
            try await activeAccountController?.activateAccount(id: account.id)
            return account
        case .loginInBrowser:
            guard let loginCoordinator else {
                return nil
            }

            let account = try await loginCoordinator.loginAndImport()
            try await activeAccountController?.activateAccount(id: account.id)
            return account
        }
    }

    public func usageSnapshot(for accountID: String) async -> CodexUsageSnapshot? {
        await usageService?.usageSnapshot(for: accountID)
    }

    public func currentActiveAccountID() async -> String? {
        activeAccountController?.currentActiveAccountID()
    }

    public func showEmails() -> Bool {
        emailVisibilityStore?.showEmails() ?? false
    }

    public func setShowEmails(_ enabled: Bool) {
        emailVisibilityStore?.setShowEmails(enabled)
    }
}
