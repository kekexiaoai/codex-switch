import XCTest
@testable import CodexSwitchKit

@MainActor
final class AccountManagementViewModelTests: XCTestCase {
    func testMoveDownPersistsManualOrderAndReloadsRows() async throws {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
                makeAccount(id: "acct-2", order: 1, tier: .plus),
            ],
            activeAccountID: "acct-1"
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()
        await viewModel.moveDown(id: "acct-1")

        XCTAssertEqual(viewModel.rows.map(\.id), ["acct-2", "acct-1"])
        XCTAssertEqual(service.savedOrderHistory, [["acct-2", "acct-1"]])
    }

    func testMoveDownKeepsRowsAndExposesErrorWhenSaveFails() async {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
                makeAccount(id: "acct-2", order: 1, tier: .plus),
            ],
            activeAccountID: "acct-1",
            saveError: StubError.failed
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()
        let originalRows = viewModel.rows
        await viewModel.moveDown(id: "acct-1")

        XCTAssertEqual(viewModel.rows, originalRows)
        XCTAssertEqual(viewModel.lastErrorMessage, "failed")
    }

    private func makeAccount(id: String, order: Int, tier: AccountTier) -> Account {
        Account(
            id: id,
            emailMask: "\(id)@example.com",
            email: "\(id)@example.com",
            tier: tier,
            manualOrder: order
        )
    }
}

@MainActor
private final class InMemoryAccountManagementService: AccountManagementServicing {
    private var accounts: [Account]
    private let activeAccountID: String?
    private let usageSnapshots: [String: CodexUsageSnapshot]
    private let saveError: Error?
    private var emailVisibilityEnabled: Bool

    private(set) var savedOrderHistory: [[String]] = []

    init(
        accounts: [Account],
        activeAccountID: String? = nil,
        usageSnapshots: [String: CodexUsageSnapshot] = [:],
        saveError: Error? = nil,
        emailVisibilityEnabled: Bool = false
    ) {
        self.accounts = accounts
        self.activeAccountID = activeAccountID
        self.usageSnapshots = usageSnapshots
        self.saveError = saveError
        self.emailVisibilityEnabled = emailVisibilityEnabled
    }

    func loadAccounts() async throws -> [Account] {
        accounts.sorted { $0.manualOrder < $1.manualOrder }
    }

    func saveManualOrder(idsInOrder: [String]) async throws {
        if let saveError {
            throw saveError
        }
        savedOrderHistory.append(idsInOrder)
        let orderByID = Dictionary(uniqueKeysWithValues: idsInOrder.enumerated().map { ($1, $0) })
        accounts = accounts.map { account in
            Account(
                id: account.id,
                emailMask: account.emailMask,
                email: account.email,
                tier: account.tier,
                manualOrder: orderByID[account.id] ?? account.manualOrder,
                archiveFilename: account.archiveFilename,
                source: account.source,
                lastImportedAt: account.lastImportedAt,
                embeddedSecret: account.embeddedSecret
            )
        }
    }

    func removeAccount(id: String) async throws {}

    func activateAccount(id: String) async throws {}

    func usageSnapshot(for accountID: String) async -> CodexUsageSnapshot? {
        usageSnapshots[accountID]
    }

    func currentActiveAccountID() async -> String? {
        activeAccountID
    }

    func showEmails() -> Bool {
        emailVisibilityEnabled
    }

    func setShowEmails(_ enabled: Bool) {
        emailVisibilityEnabled = enabled
    }
}

private enum StubError: LocalizedError {
    case failed

    var errorDescription: String? {
        "failed"
    }
}
