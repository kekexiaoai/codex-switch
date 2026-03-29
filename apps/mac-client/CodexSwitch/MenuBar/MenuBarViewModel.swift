import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public private(set) var headerEmail = ""
    @Published public private(set) var headerTier = ""
    @Published public private(set) var updatedText = ""
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []

    private let service: any MenuBarSnapshotService
    private let accountRepository: AccountRepository?
    private let activeAccountController: ActiveAccountController?

    public static let preview = MenuBarViewModel(service: MockMenuBarService())

    public init(
        service: any MenuBarSnapshotService,
        accountRepository: AccountRepository? = nil,
        activeAccountController: ActiveAccountController? = nil
    ) {
        self.service = service
        self.accountRepository = accountRepository
        self.activeAccountController = activeAccountController
    }

    public func refresh() async {
        let snapshot = await service.loadSnapshot()
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

    public func addDemoAccount() async throws {
        guard let accountRepository else {
            return
        }

        let existingAccounts = try await accountRepository.loadAccounts()
        let nextIndex = existingAccounts.count + 1
        let accountID = "demo-\(nextIndex)"
        let account = Account(
            id: accountID,
            emailMask: "d••••\(nextIndex)@example.com",
            email: "demo\(nextIndex)@example.com",
            tier: .plus
        )

        try await accountRepository.save(account: account, secret: "demo-secret-\(nextIndex)")
        try await activeAccountController?.activateAccount(id: accountID)
        await refresh()
    }
}
