import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public private(set) var headerEmail = ""
    @Published public private(set) var headerTier = ""
    @Published public private(set) var updatedText = ""
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []
    @Published public private(set) var isPresentingAddAccount = false
    @Published public private(set) var showEmails = false
    @Published public var draftEmail = ""
    @Published public var draftSecret = ""
    @Published public var draftTier: AccountTier = .plus

    private let service: any MenuBarSnapshotService
    private let accountRepository: AccountRepository?
    private let activeAccountController: ActiveAccountController?
    private let emailVisibilityStore: (any EmailVisibilityMutating)?

    public static let preview = MenuBarViewModel(service: MockMenuBarService())

    public init(
        service: any MenuBarSnapshotService,
        accountRepository: AccountRepository? = nil,
        activeAccountController: ActiveAccountController? = nil,
        emailVisibilityStore: (any EmailVisibilityMutating)? = nil
    ) {
        self.service = service
        self.accountRepository = accountRepository
        self.activeAccountController = activeAccountController
        self.emailVisibilityStore = emailVisibilityStore
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

    public func startAddingAccount() {
        draftEmail = ""
        draftSecret = ""
        draftTier = .plus
        isPresentingAddAccount = true
    }

    public func cancelAddingAccount() {
        isPresentingAddAccount = false
    }

    public func toggleShowEmails() async {
        let nextValue = !(emailVisibilityStore?.showEmails() ?? showEmails)
        emailVisibilityStore?.setShowEmails(nextValue)
        showEmails = nextValue
        await refresh()
    }

    public func addDemoAccount() async throws {
        guard let accountRepository else {
            return
        }

        let existingAccounts = try await accountRepository.loadAccounts()
        let nextIndex = existingAccounts.count + 1
        let accountID = "demo-\(nextIndex)"
        let fullEmail = "demo\(nextIndex)@example.com"
        let account = Account(
            id: accountID,
            emailMask: Account.maskedEmail(fullEmail),
            email: fullEmail,
            tier: .plus
        )

        try await accountRepository.save(account: account, secret: "demo-secret-\(nextIndex)")
        try await activeAccountController?.activateAccount(id: accountID)
        await refresh()
    }

    public func submitNewAccount() async throws {
        guard let accountRepository else {
            return
        }

        let trimmedEmail = draftEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            return
        }

        let existingAccounts = try await accountRepository.loadAccounts()
        let nextIndex = existingAccounts.count + 1
        let accountID = "acct-\(nextIndex)"
        let account = Account(
            id: accountID,
            emailMask: Account.maskedEmail(trimmedEmail),
            email: trimmedEmail,
            tier: draftTier
        )

        try await accountRepository.save(account: account, secret: draftSecret)
        try await activeAccountController?.activateAccount(id: accountID)
        isPresentingAddAccount = false
        await refresh()
    }
}
