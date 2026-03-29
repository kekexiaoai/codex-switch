import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public private(set) var headerEmail = ""
    @Published public private(set) var headerTier = ""
    @Published public private(set) var updatedText = ""
    @Published public private(set) var summaries: [UsageSummaryModel] = []
    @Published public private(set) var accountRows: [AccountRowModel] = []

    private let service: any MenuBarSnapshotService

    public static let preview = MenuBarViewModel(service: MockMenuBarService())

    public init(service: any MenuBarSnapshotService) {
        self.service = service
    }

    public func refresh() async {
        let snapshot = await service.loadSnapshot()
        headerEmail = snapshot.headerEmail
        headerTier = snapshot.headerTier
        updatedText = snapshot.updatedText
        summaries = snapshot.summaries
        accountRows = snapshot.accounts
    }
}
