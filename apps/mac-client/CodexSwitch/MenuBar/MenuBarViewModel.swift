import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public private(set) var headerEmail = ""
    @Published public private(set) var headerTier = ""
    @Published public private(set) var updatedText = ""
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []

    private let service: any MenuBarSnapshotService
    private let activeAccountController: ActiveAccountController?

    public static let preview = MenuBarViewModel(service: MockMenuBarService())

    public init(
        service: any MenuBarSnapshotService,
        activeAccountController: ActiveAccountController? = nil
    ) {
        self.service = service
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
}
