import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
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
    }

    @Published public private(set) var headerEmail = ""
    @Published public private(set) var headerTier = ""
    @Published public private(set) var updatedText = ""
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []
    @Published public private(set) var showEmails = false
    @Published public private(set) var alertMessage: MenuBarAlertMessage?

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

    public func performAddAccountAction(_ action: AddAccountAction) async {
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

            if let importedAccount, existingAccountIDs.contains(importedAccount.id) {
                alertMessage = MenuBarAlertMessage(
                    title: "Account Refreshed",
                    message: "Account already exists, auth refreshed."
                )
            }
        } catch {
            alertMessage = alert(for: action, error: error)
        }
    }

    public func dismissAlert() {
        alertMessage = nil
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
            case .loginCancelled:
                return MenuBarAlertMessage(
                    title: "Browser Login Cancelled",
                    message: "Codex browser login was cancelled before a valid auth session was created."
                )
            case .currentAuthFileMissing, .idTokenMissing, .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarAlertMessage(
                    title: "Browser Login Failed",
                    message: "Codex login finished, but no valid browser auth session was created. Complete the browser flow and try again."
                )
            case .loginFailed:
                return MenuBarAlertMessage(
                    title: "Browser Login Failed",
                    message: "Codex browser login did not complete. Make sure the Codex CLI is installed and try again."
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
