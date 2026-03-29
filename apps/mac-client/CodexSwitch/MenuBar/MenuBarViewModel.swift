import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    public struct AddAccountProgressState: Equatable {
        public let title: String
        public let message: String
        public let showsCancelButton: Bool

        public init(title: String, message: String, showsCancelButton: Bool) {
            self.title = title
            self.message = message
            self.showsCancelButton = showsCancelButton
        }
    }

    public enum AddAccountAction: CaseIterable {
        case importCurrentAccount
        case importBackupAuth
        case loginInBrowser

        public var title: String {
            switch self {
            case .importCurrentAccount:
                return "Import Current Account"
            case .importBackupAuth:
                return "Import Backup Auth"
            case .loginInBrowser:
                return "Login in Browser"
            }
        }

        public var systemImageName: String {
            switch self {
            case .importCurrentAccount:
                return "person.crop.circle.badge.clock"
            case .importBackupAuth:
                return "tray.and.arrow.down"
            case .loginInBrowser:
                return "globe"
            }
        }
    }

    @Published public private(set) var headerEmail = ""
    @Published public private(set) var headerTier = ""
    @Published public private(set) var updatedText = ""
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []
    @Published public private(set) var showEmails = false
    @Published public private(set) var isPerformingAddAccountAction = false
    @Published public private(set) var addAccountProgress: AddAccountProgressState?
    @Published public private(set) var alertMessage: MenuBarAlertMessage?
    @Published public private(set) var pendingAccountRemoval: AccountRemovalConfirmation?

    private let service: any MenuBarSnapshotService
    private let accountRepository: AccountRepository?
    private let activeAccountController: ActiveAccountController?
    private let accountImporter: CodexAuthImporter?
    private let accountRemover: (any AccountRemoving)?
    private let loginCoordinator: CodexLoginCoordinator?
    private let backupAuthPicker: (any BackupAuthPicking)?
    private let emailVisibilityStore: (any EmailVisibilityMutating)?
    private let actionHandler: (any MenuBarActionHandling)?
    private var addAccountTask: Task<Void, Never>?
    private var switchUsageRefreshTask: Task<Void, Never>?
    private var activeAddAccountOperationID: UUID?

    public static let preview = MenuBarViewModel(service: MockMenuBarService())

    public init(
        service: any MenuBarSnapshotService,
        accountRepository: AccountRepository? = nil,
        activeAccountController: ActiveAccountController? = nil,
        accountImporter: CodexAuthImporter? = nil,
        accountRemover: (any AccountRemoving)? = nil,
        loginCoordinator: CodexLoginCoordinator? = nil,
        backupAuthPicker: (any BackupAuthPicking)? = nil,
        emailVisibilityStore: (any EmailVisibilityMutating)? = nil,
        actionHandler: (any MenuBarActionHandling)? = nil
    ) {
        self.service = service
        self.accountRepository = accountRepository
        self.activeAccountController = activeAccountController
        self.accountImporter = accountImporter
        self.accountRemover = accountRemover
        self.loginCoordinator = loginCoordinator
        self.backupAuthPicker = backupAuthPicker
        self.emailVisibilityStore = emailVisibilityStore
        self.actionHandler = actionHandler
        self.showEmails = emailVisibilityStore?.showEmails() ?? false
    }

    public func refresh() async {
        await refresh(triggerUsageRefresh: true)
    }

    private func refresh(triggerUsageRefresh: Bool) async {
        let snapshot = await service.loadSnapshot(triggerUsageRefresh: triggerUsageRefresh)
        applySnapshot(snapshot)
    }

    private func applySnapshot(_ snapshot: MenuBarSnapshot) {
        showEmails = emailVisibilityStore?.showEmails() ?? showEmails
        headerEmail = snapshot.headerEmail
        headerTier = snapshot.headerTier
        updatedText = snapshot.headerStatusText
        summaries = snapshot.summaries
        accountRows = snapshot.accounts
    }

    public func switchToAccount(id: String) async throws {
        try await activeAccountController?.activateAccount(id: id)
        await refresh(triggerUsageRefresh: false)
        switchUsageRefreshTask?.cancel()
        switchUsageRefreshTask = Task { [weak self] in
            await self?.refresh()
        }
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

    public func importCurrentAccount() async throws -> Account? {
        guard let accountImporter else {
            return nil
        }

        let account = try accountImporter.importCurrentAccount()
        try await activeAccountController?.activateAccount(id: account.id)
        await refresh()
        return account
    }

    public func importBackupAccount() async throws -> Account? {
        guard let accountImporter, let backupAuthPicker else {
            return nil
        }

        guard let backupURL = await backupAuthPicker.pickBackupAuthURL() else {
            return nil
        }

        let account = try accountImporter.importBackupAuth(from: backupURL)
        try await activeAccountController?.activateAccount(id: account.id)
        await refresh()
        return account
    }

    public func loginInBrowser() async throws -> Account? {
        guard let loginCoordinator else {
            return nil
        }

        let account = try await loginCoordinator.loginAndImport()
        try await activeAccountController?.activateAccount(id: account.id)
        await refresh()
        return account
    }

    public func startAddAccountAction(_ action: AddAccountAction) {
        guard addAccountTask == nil else {
            return
        }

        let operationID = UUID()
        activeAddAccountOperationID = operationID
        isPerformingAddAccountAction = true
        addAccountProgress = progressState(for: action)

        addAccountTask = Task { [weak self] in
            await self?.performAddAccountAction(action, operationID: operationID)
        }
    }

    public func cancelAddAccountAction() {
        guard addAccountTask != nil else {
            return
        }

        addAccountTask?.cancel()
        addAccountTask = nil
        activeAddAccountOperationID = nil
        isPerformingAddAccountAction = false
        addAccountProgress = nil
    }

    public func performAddAccountAction(_ action: AddAccountAction) async {
        await performAddAccountAction(action, operationID: nil)
    }

    private func performAddAccountAction(_ action: AddAccountAction, operationID: UUID?) async {
        if operationID == nil {
            guard !isPerformingAddAccountAction else {
                if action == .loginInBrowser {
                    alertMessage = MenuBarAlertMessage(
                        title: "Browser Login In Progress",
                        message: "A browser login is already in progress. Finish that sign-in flow, or wait for it to time out before trying again."
                    )
                }
                return
            }

            isPerformingAddAccountAction = true
            addAccountProgress = progressState(for: action)
        }

        defer {
            let isCurrentOperation = isCurrentAddAccountOperation(operationID)

            if isCurrentOperation {
                addAccountTask = nil
                activeAddAccountOperationID = nil
            }

            if operationID == nil || isCurrentOperation {
                isPerformingAddAccountAction = false
                addAccountProgress = nil
            }
        }

        do {
            let existingAccountIDs = try await knownAccountIDs()
            let importedAccount: Account?
            switch action {
            case .importCurrentAccount:
                importedAccount = try await importCurrentAccount()
            case .importBackupAuth:
                importedAccount = try await importBackupAccount()
            case .loginInBrowser:
                importedAccount = try await loginInBrowser()
            }

            guard !Task.isCancelled else {
                return
            }

            if let importedAccount, existingAccountIDs.contains(importedAccount.id) {
                alertMessage = MenuBarAlertMessage(
                    title: "Account Refreshed",
                    message: "Account already exists, auth refreshed."
                )
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }
            alertMessage = alert(for: action, error: error)
        }
    }

    public func dismissAlert() {
        alertMessage = nil
    }

    public func requestRemoveAccount(id: String) {
        guard let account = accountRows.first(where: { $0.id == id }) else {
            return
        }

        let isActive = account.isActive
        pendingAccountRemoval = AccountRemovalConfirmation(
            accountID: id,
            title: "Remove Account?",
            message: isActive
                ? "Remove \(account.emailMask) from archived accounts? Because it is currently active, Codex Switch will switch to another archived account when available, or clear the current Codex session."
                : "Remove \(account.emailMask) from archived accounts? This only deletes the archived copy stored on this Mac."
        )
    }

    public func cancelPendingAccountRemoval() {
        pendingAccountRemoval = nil
    }

    public func confirmPendingAccountRemoval() async throws {
        guard let pendingAccountRemoval else {
            return
        }

        defer {
            self.pendingAccountRemoval = nil
        }

        guard let accountRemover else {
            return
        }

        let result = try await accountRemover.removeArchivedAccount(
            id: pendingAccountRemoval.accountID,
            activeAccountID: activeAccountController?.currentActiveAccountID()
        )
        activeAccountController?.syncActiveAccountID(result.nextActiveAccountID)
        await refresh()
        alertMessage = MenuBarAlertMessage(
            title: "Account Removed",
            message: result.nextActiveAccountID == nil
                ? "The archived account was removed and there is no remaining active account."
                : "The archived account was removed."
        )
    }

    private func isCurrentAddAccountOperation(_ operationID: UUID?) -> Bool {
        guard let operationID else {
            return true
        }

        return activeAddAccountOperationID == operationID
    }

    private func progressState(for action: AddAccountAction) -> AddAccountProgressState? {
        switch action {
        case .loginInBrowser:
            return AddAccountProgressState(
                title: "Browser Login In Progress",
                message: "Complete the sign-in flow in your browser. You can cancel here and try again at any time.",
                showsCancelButton: true
            )
        case .importCurrentAccount:
            return AddAccountProgressState(
                title: "Importing Current Account",
                message: "Reading your current Codex auth and adding it to Codex Switch.",
                showsCancelButton: false
            )
        case .importBackupAuth:
            return nil
        }
    }

    private func knownAccountIDs() async throws -> Set<String> {
        guard let accountRepository else {
            return []
        }

        return Set(try await accountRepository.loadAccounts().map(\.id))
    }

    private func alert(for action: AddAccountAction, error: Error) -> MenuBarAlertMessage {
        let authError = error as? CodexAuthError

        switch action {
        case .importCurrentAccount:
            switch authError {
            case .currentAuthFileMissing, .authFileUnreadable:
                return MenuBarAlertMessage(
                    title: "Cannot Import Current Account",
                    message: "No current Codex auth.json was found. Log in with Codex first, or import a backup auth.json."
                )
            case .idTokenMissing:
                return MenuBarAlertMessage(
                    title: "Cannot Import Current Account",
                    message: "Current Codex auth does not contain a browser login session. If this machine is using OPENAI_API_KEY mode, choose Login in Browser or import a backup auth.json."
                )
            case .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarAlertMessage(
                    title: "Cannot Import Current Account",
                    message: "The current Codex auth.json is not a valid browser auth file."
                )
            case .archiveWriteFailed:
                return MenuBarAlertMessage(
                    title: "Cannot Import Current Account",
                    message: "Codex Switch could not archive the current auth file into ~/.codex/accounts/."
                )
            default:
                return MenuBarAlertMessage(
                    title: "Cannot Import Current Account",
                    message: "Current account import failed. Please try again."
                )
            }
        case .importBackupAuth:
            switch authError {
            case .authFileUnreadable:
                return MenuBarAlertMessage(
                    title: "Cannot Import Backup Auth",
                    message: "The selected auth.json could not be read."
                )
            case .idTokenMissing, .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarAlertMessage(
                    title: "Cannot Import Backup Auth",
                    message: "The selected auth.json does not contain a valid browser login session."
                )
            case .archiveWriteFailed:
                return MenuBarAlertMessage(
                    title: "Cannot Import Backup Auth",
                    message: "Codex Switch could not archive the selected auth.json into ~/.codex/accounts/."
                )
            default:
                return MenuBarAlertMessage(
                    title: "Cannot Import Backup Auth",
                    message: "Backup auth import failed. Please try again."
                )
            }
        case .loginInBrowser:
            switch authError {
            case .browserLaunchFailed:
                return MenuBarAlertMessage(
                    title: "Browser Could Not Open",
                    message: "Codex Switch could not open your default browser. Check your browser settings, then review ~/.codex/codex-switch/browser-login.log and try again."
                )
            case .loginCancelled:
                return MenuBarAlertMessage(
                    title: "Browser Login Cancelled",
                    message: "Codex browser login was cancelled before a valid auth session was created."
                )
            case .loginTimedOut:
                return MenuBarAlertMessage(
                    title: "Browser Login Timed Out",
                    message: "The browser sign-in did not finish before timing out. Try Login in Browser again."
                )
            case .currentAuthFileMissing, .idTokenMissing, .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarAlertMessage(
                    title: "Browser Login Failed",
                    message: "Codex login finished, but no valid browser auth session was created. Complete the browser flow and try again."
                )
            case .loginFailed:
                return MenuBarAlertMessage(
                    title: "Browser Login Failed",
                    message: "Codex browser login did not complete. Complete the browser sign-in and try again."
                )
            default:
                return MenuBarAlertMessage(
                    title: "Browser Login Failed",
                    message: "Browser login failed. Please try again."
                )
            }
        }
    }
}
