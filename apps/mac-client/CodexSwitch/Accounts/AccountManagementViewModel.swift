import Foundation

public struct AccountManagementRowModel: Identifiable, Equatable {
    public let id: String
    public let emailText: String
    public let tierText: String
    public let fiveHourPercent: Int
    public let weeklyPercent: Int
    public let fiveHourText: String
    public let weeklyText: String
    public let isActive: Bool
    public let canMoveUp: Bool
    public let canMoveDown: Bool
}

@MainActor
public final class AccountManagementViewModel: ObservableObject {
    @Published public private(set) var rows: [AccountManagementRowModel] = []
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var isReordering = false
    @Published public private(set) var showEmails = false

    private let service: any AccountManagementServicing

    public static let preview = AccountManagementViewModel(service: PreviewAccountManagementService())

    public init(service: any AccountManagementServicing) {
        self.service = service
    }

    public func load() async {
        do {
            let accounts = try await service.loadAccounts()
            let activeAccountID = await service.currentActiveAccountID()
            let showEmails = service.showEmails()
            var nextRows: [AccountManagementRowModel] = []

            for (index, account) in accounts.enumerated() {
                let snapshot = await service.usageSnapshot(for: account.id)
                let fiveHourPercent = snapshot?.fiveHour.percentUsed ?? 0
                let weeklyPercent = snapshot?.weekly.percentUsed ?? 0
                nextRows.append(
                    AccountManagementRowModel(
                        id: account.id,
                        emailText: account.displayEmail(showFullEmail: showEmails),
                        tierText: account.tier.rawValue.capitalized,
                        fiveHourPercent: fiveHourPercent,
                        weeklyPercent: weeklyPercent,
                        fiveHourText: "5H \(fiveHourPercent)%",
                        weeklyText: "7D \(weeklyPercent)%",
                        isActive: account.id == activeAccountID,
                        canMoveUp: index > 0,
                        canMoveDown: index < accounts.count - 1
                    )
                )
            }

            rows = nextRows
            self.showEmails = showEmails
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func toggleShowEmails() async {
        service.setShowEmails(!service.showEmails())
        await load()
    }

    public func moveUp(id: String) async {
        guard !isReordering else {
            return
        }
        guard let index = rows.firstIndex(where: { $0.id == id }), index > 0 else {
            return
        }

        var orderedIDs = rows.map(\.id)
        orderedIDs.swapAt(index, index - 1)
        await persistOrder(orderedIDs)
    }

    public func moveDown(id: String) async {
        guard !isReordering else {
            return
        }
        guard let index = rows.firstIndex(where: { $0.id == id }), index < rows.count - 1 else {
            return
        }

        var orderedIDs = rows.map(\.id)
        orderedIDs.swapAt(index, index + 1)
        await persistOrder(orderedIDs)
    }

    private func persistOrder(_ orderedIDs: [String]) async {
        isReordering = true
        defer { isReordering = false }

        do {
            try await service.saveManualOrder(idsInOrder: orderedIDs)
            await load()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

@MainActor
private final class PreviewAccountManagementService: AccountManagementServicing {
    private let accounts: [Account] = [
        Account(id: "acct-1", emailMask: "a••••@example.com", tier: .team, manualOrder: 0),
        Account(id: "acct-2", emailMask: "b••••@example.com", tier: .plus, manualOrder: 1),
    ]

    func loadAccounts() async throws -> [Account] {
        accounts
    }

    func saveManualOrder(idsInOrder: [String]) async throws {}

    func removeAccount(id: String) async throws {}

    func activateAccount(id: String) async throws {}

    func usageSnapshot(for accountID: String) async -> CodexUsageSnapshot? {
        CodexUsageSnapshot(
            accountID: accountID,
            updatedAt: Date(timeIntervalSince1970: 1_711_584_800),
            fiveHour: CodexUsageWindow(percentUsed: accountID == "acct-1" ? 42 : 13, resetsAt: Date(timeIntervalSince1970: 1_711_591_000)),
            weekly: CodexUsageWindow(percentUsed: accountID == "acct-1" ? 18 : 62, resetsAt: Date(timeIntervalSince1970: 1_711_900_000))
        )
    }

    func currentActiveAccountID() async -> String? {
        "acct-1"
    }

    func showEmails() -> Bool {
        false
    }

    func setShowEmails(_ enabled: Bool) {}
}
