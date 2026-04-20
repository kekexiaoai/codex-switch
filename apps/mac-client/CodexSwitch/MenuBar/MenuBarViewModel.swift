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
                return MenuBarStrings.text(.importCurrentAccount)
            case .importBackupAuth:
                return MenuBarStrings.text(.importBackupAuth)
            case .loginInBrowser:
                return MenuBarStrings.text(.loginInBrowser)
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
    @Published public private(set) var usageSourceText = ""
    @Published public private(set) var recentEvents: [String] = []
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []
    @Published public private(set) var quickSwitchRows: [QuickSwitchRowModel] = []
    @Published public private(set) var showEmails = false
    @Published public private(set) var isPerformingAddAccountAction = false
    @Published public private(set) var addAccountProgress: AddAccountProgressState?
    @Published public private(set) var alertMessage: MenuBarAlertMessage?
    @Published public private(set) var removalFeedback: MenuBarInlineMessage?
    @Published public private(set) var pendingAccountRemoval: AccountRemovalConfirmation?
    @Published public private(set) var pendingAccountActivationConfirmation: AccountActivationConfirmation?

    private let service: any MenuBarSnapshotService
    private let accountRepository: AccountRepository?
    private let activeAccountController: ActiveAccountController?
    private let accountImporter: CodexAuthImporter?
    private let accountRemover: (any AccountRemoving)?
    private let loginCoordinator: CodexLoginCoordinator?
    private let backupAuthPicker: (any BackupAuthPicking)?
    private let emailVisibilityStore: (any EmailVisibilityMutating)?
    private let actionHandler: (any MenuBarActionHandling)?
    private let currentAuthUsesAPIKeyMode: (() -> Bool)?
    private var addAccountTask: Task<Void, Never>?
    private var switchUsageRefreshTask: Task<Void, Never>?
    private var presentationSnapshotTask: Task<Void, Never>?
    private var presentationUsageRefreshTask: Task<Void, Never>?
    private var activeAddAccountOperationID: UUID?
    private var hasLoadedPresentationSnapshot = false

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
        actionHandler: (any MenuBarActionHandling)? = nil,
        currentAuthUsesAPIKeyMode: (() -> Bool)? = nil
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
        self.currentAuthUsesAPIKeyMode = currentAuthUsesAPIKeyMode
        self.showEmails = emailVisibilityStore?.showEmails() ?? false
    }

    public func refresh() async {
        await refresh(triggerUsageRefresh: true)
    }

    private func refresh(triggerUsageRefresh: Bool) async {
        let snapshot = await service.loadSnapshot(triggerUsageRefresh: triggerUsageRefresh)
        applySnapshot(snapshot)
        hasLoadedPresentationSnapshot = true
    }

    private func applySnapshot(_ snapshot: MenuBarSnapshot) {
        showEmails = emailVisibilityStore?.showEmails() ?? showEmails
        headerEmail = snapshot.headerEmail
        headerTier = snapshot.headerTier
        updatedText = snapshot.headerStatusText
        usageSourceText = snapshot.usageSourceText
        recentEvents = snapshot.recentEvents
        summaries = snapshot.summaries
        accountRows = snapshot.accounts
        quickSwitchRows = snapshot.accounts.map { account in
            QuickSwitchRowModel(
                id: account.id,
                emailText: account.emailMask,
                tierBadgeText: account.tierLabel.uppercased(),
                fiveHourLabel: "5h \(account.fiveHourPercent)%",
                weeklyLabel: "7d \(account.weeklyPercent)%",
                isActive: account.isActive
            )
        }
    }

    public func switchToAccount(id: String) async throws {
        try await activeAccountController?.activateAccount(id: id)
        await refresh(triggerUsageRefresh: false)
        switchUsageRefreshTask?.cancel()
        switchUsageRefreshTask = Task { [weak self] in
            await self?.refresh()
        }
    }

    @discardableResult
    public func requestSwitchToAccount(id: String) -> AccountSwitchRequestDisposition {
        guard let account = accountRows.first(where: { $0.id == id }) else {
            return .ignored
        }

        guard !account.isActive else {
            return .ignored
        }

        guard currentAuthUsesAPIKeyMode?() == true else {
            Task { [weak self] in
                await self?.performAccountSwitch(id: id)
            }
            return .started
        }

        pendingAccountActivationConfirmation = AccountActivationConfirmation(
            accountID: id,
            title: MenuBarStrings.text(.confirmActivation),
            message: MenuBarStrings.activationConfirmationMessage()
        )
        return .confirmationRequired
    }

    public func refreshForPresentation() async {
        if !hasLoadedPresentationSnapshot {
            if presentationSnapshotTask == nil {
                presentationSnapshotTask = Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    await self.refresh(triggerUsageRefresh: false)
                    self.presentationSnapshotTask = nil
                }
            }

            await presentationSnapshotTask?.value
        }

        presentationUsageRefreshTask?.cancel()
        presentationUsageRefreshTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.refresh()
            self.presentationUsageRefreshTask = nil
        }
    }

    public func toggleShowEmails() async {
        let nextValue = !(emailVisibilityStore?.showEmails() ?? showEmails)
        emailVisibilityStore?.setShowEmails(nextValue)
        showEmails = nextValue
        await refresh()
    }

    public func openMainWindow() {
        actionHandler?.handle(.openMainWindow(.accounts))
    }

    public func openStatusPage() {
        actionHandler?.handle(.openMainWindow(.status))
    }

    public func openSettings() {
        actionHandler?.handle(.openMainWindow(.settings))
    }

    public func openProviderSync() {
        actionHandler?.handle(.openMainWindow(.providerSync))
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
                        title: MenuBarStrings.text(.browserLoginInProgressTitle),
                        message: MenuBarStrings.text(.browserLoginInProgressMessage)
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
                    title: MenuBarStrings.text(.accountRefreshedTitle),
                    message: MenuBarStrings.text(.accountRefreshedMessage)
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

    public func cancelPendingAccountActivation() {
        pendingAccountActivationConfirmation = nil
    }

    public func performPendingAccountActivation() async {
        guard let confirmation = pendingAccountActivationConfirmation else {
            return
        }

        pendingAccountActivationConfirmation = nil
        await performAccountSwitch(id: confirmation.accountID)
    }

    public func dismissRemovalFeedback() {
        removalFeedback = nil
    }

    public func requestRemoveAccount(id: String) {
        guard let account = accountRows.first(where: { $0.id == id }) else {
            return
        }

        removalFeedback = nil
        let isActive = account.isActive
        pendingAccountRemoval = AccountRemovalConfirmation(
            accountID: id,
            title: MenuBarStrings.text(.removeAccountConfirmationTitle),
            message: MenuBarStrings.accountRemovalMessage(
                emailMask: account.emailMask,
                isCurrent: isActive
            )
        )
    }

    public func cancelPendingAccountRemoval() {
        pendingAccountRemoval = nil
        removalFeedback = nil
    }

    public func performPendingAccountRemoval() async {
        do {
            try await confirmPendingAccountRemoval()
        } catch {
            removalFeedback = MenuBarInlineMessage(
                title: MenuBarStrings.text(.removeFailedTitle),
                message: MenuBarStrings.text(.removeFailedMessage),
                tone: .error
            )
        }
    }

    public func confirmPendingAccountRemoval() async throws {
        guard let pendingAccountRemoval else {
            return
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
        self.pendingAccountRemoval = nil
        removalFeedback = MenuBarInlineMessage(
            title: MenuBarStrings.text(.accountRemovedTitle),
            message: result.nextActiveAccountID == nil
                ? MenuBarStrings.text(.accountRemovedNoActiveMessage)
                : MenuBarStrings.text(.accountRemovedMessage),
            tone: .success
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
                title: MenuBarStrings.text(.browserLoginInProgressTitle),
                message: MenuBarStrings.text(.browserLoginInProgressMessage),
                showsCancelButton: true
            )
        case .importCurrentAccount:
            return AddAccountProgressState(
                title: MenuBarStrings.text(.importingCurrentAccountTitle),
                message: MenuBarStrings.text(.importingCurrentAccountMessage),
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

    private func performAccountSwitch(id: String) async {
        do {
            try await switchToAccount(id: id)
        } catch {
            alertMessage = MenuBarAlertMessage(
                title: MenuBarStrings.text(.cannotActivateAccountTitle),
                message: MenuBarStrings.text(.cannotActivateAccountMessage)
            )
        }
    }

    private func alert(for action: AddAccountAction, error: Error) -> MenuBarAlertMessage {
        let authError = error as? CodexAuthError

        switch action {
        case .importCurrentAccount:
            switch authError {
            case .currentAuthFileMissing, .authFileUnreadable:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportCurrentAccountTitle),
                    message: MenuBarStrings.text(.cannotImportCurrentAccountNoAuth)
                )
            case .apiKeyModeDetected, .idTokenMissing:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportCurrentAccountTitle),
                    message: MenuBarStrings.text(.cannotImportCurrentAccountNoSession)
                )
            case .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportCurrentAccountTitle),
                    message: MenuBarStrings.text(.cannotImportCurrentAccountInvalid)
                )
            case .archiveWriteFailed:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportCurrentAccountTitle),
                    message: MenuBarStrings.text(.cannotImportCurrentAccountArchive)
                )
            default:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportCurrentAccountTitle),
                    message: MenuBarStrings.text(.cannotImportCurrentAccountGeneric)
                )
            }
        case .importBackupAuth:
            switch authError {
            case .authFileUnreadable:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportBackupAuthTitle),
                    message: MenuBarStrings.text(.cannotImportBackupAuthUnreadable)
                )
            case .apiKeyModeDetected, .idTokenMissing, .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportBackupAuthTitle),
                    message: MenuBarStrings.text(.cannotImportBackupAuthInvalid)
                )
            case .archiveWriteFailed:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportBackupAuthTitle),
                    message: MenuBarStrings.text(.cannotImportBackupAuthArchive)
                )
            default:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.cannotImportBackupAuthTitle),
                    message: MenuBarStrings.text(.cannotImportBackupAuthGeneric)
                )
            }
        case .loginInBrowser:
            switch authError {
            case .browserLaunchFailed:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.browserCouldNotOpenTitle),
                    message: MenuBarStrings.text(.browserCouldNotOpenMessage)
                )
            case .loginCancelled:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.browserLoginCancelledTitle),
                    message: MenuBarStrings.text(.browserLoginCancelledMessage)
                )
            case .loginTimedOut:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.browserLoginTimedOutTitle),
                    message: MenuBarStrings.text(.browserLoginTimedOutMessage)
                )
            case .currentAuthFileMissing, .idTokenMissing, .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.browserLoginFailedTitle),
                    message: MenuBarStrings.text(.browserLoginNoSessionMessage)
                )
            case .loginFailed:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.browserLoginFailedTitle),
                    message: MenuBarStrings.text(.browserLoginFailedMessage)
                )
            default:
                return MenuBarAlertMessage(
                    title: MenuBarStrings.text(.browserLoginFailedTitle),
                    message: MenuBarStrings.text(.browserLoginGenericMessage)
                )
            }
        }
    }
}
