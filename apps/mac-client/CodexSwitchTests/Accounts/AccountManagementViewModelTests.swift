import XCTest
@testable import CodexSwitchKit

@MainActor
final class AccountManagementViewModelTests: XCTestCase {
    func testStartBrowserLoginActionCanBeCancelled() async throws {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
            ],
            blockingActions: [.loginInBrowser]
        )
        let viewModel = AccountManagementViewModel(service: service)

        viewModel.startAddAccountAction(.loginInBrowser)
        try await waitForCondition { await service.invocationCount(for: .loginInBrowser) == 1 }

        XCTAssertTrue(viewModel.isPerformingAddAccountAction)
        XCTAssertEqual(viewModel.addAccountProgressText, MenuBarStrings.text(.browserLoginInProgressTitle))
        XCTAssertTrue(viewModel.showsCancelAddAccountAction)

        viewModel.cancelAddAccountAction()
        try await waitForCondition { await service.didObserveCancellation(for: .loginInBrowser) }

        XCTAssertFalse(viewModel.isPerformingAddAccountAction)
        XCTAssertFalse(viewModel.showsCancelAddAccountAction)
        XCTAssertNil(viewModel.addAccountProgressText)
        XCTAssertNil(viewModel.lastErrorMessage)
    }

    func testPerformAddAccountActionReloadsRowsAfterImportCurrentAccount() async throws {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
            ],
            activeAccountID: "acct-1",
            importedAccountsByAction: [
                .importCurrentAccount: makeAccount(id: "acct-2", order: 1, tier: .plus),
            ]
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()
        await viewModel.performAddAccountAction(.importCurrentAccount)

        XCTAssertEqual(service.performedAddActions, [.importCurrentAccount])
        XCTAssertEqual(viewModel.rows.map(\.id), ["acct-1", "acct-2"])
        XCTAssertEqual(viewModel.rows.first(where: \.isActive)?.id, "acct-2")
        XCTAssertNil(viewModel.lastErrorMessage)
        XCTAssertFalse(viewModel.isPerformingAddAccountAction)
    }

    func testPerformAddAccountActionShowsErrorWhenImportFails() async {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
            ],
            addAccountErrorsByAction: [
                .importCurrentAccount: StubError.failed,
            ]
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()
        await viewModel.performAddAccountAction(.importCurrentAccount)

        XCTAssertEqual(service.performedAddActions, [.importCurrentAccount])
        XCTAssertEqual(viewModel.lastErrorMessage, "failed")
        XCTAssertFalse(viewModel.isPerformingAddAccountAction)
    }

    func testMoveRowsPersistsManualOrderAndReloadsRows() async throws {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
                makeAccount(id: "acct-2", order: 1, tier: .plus),
            ],
            activeAccountID: "acct-1"
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()
        await viewModel.moveRows(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertEqual(viewModel.rows.map(\.id), ["acct-2", "acct-1"])
        XCTAssertEqual(service.savedOrderHistory, [["acct-2", "acct-1"]])
    }

    func testMoveRowsToEarlierPositionPersistsManualOrder() async throws {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
                makeAccount(id: "acct-2", order: 1, tier: .plus),
                makeAccount(id: "acct-3", order: 2, tier: .pro),
            ]
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()
        await viewModel.moveRows(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        XCTAssertEqual(viewModel.rows.map(\.id), ["acct-3", "acct-1", "acct-2"])
        XCTAssertEqual(service.savedOrderHistory, [["acct-3", "acct-1", "acct-2"]])
    }

    func testMoveRowsToNextPositionPersistsManualOrder() async throws {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
                makeAccount(id: "acct-2", order: 1, tier: .plus),
                makeAccount(id: "acct-3", order: 2, tier: .pro),
            ]
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()
        await viewModel.moveRows(fromOffsets: IndexSet(integer: 0), toOffset: 1)

        XCTAssertEqual(viewModel.rows.map(\.id), ["acct-2", "acct-1", "acct-3"])
        XCTAssertEqual(service.savedOrderHistory, [["acct-2", "acct-1", "acct-3"]])
    }

    func testMoveRowPersistsManualOrderForDropTargetIndex() async throws {
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
                makeAccount(id: "acct-2", order: 1, tier: .plus),
                makeAccount(id: "acct-3", order: 2, tier: .pro),
            ]
        )
        let logger = InMemoryDiagnosticsLogger()
        let viewModel = AccountManagementViewModel(service: service, logger: logger)

        await viewModel.load()
        await viewModel.moveRow(id: "acct-1", to: 1)

        XCTAssertEqual(viewModel.rows.map(\.id), ["acct-2", "acct-1", "acct-3"])
        XCTAssertEqual(service.savedOrderHistory, [["acct-2", "acct-1", "acct-3"]])
        XCTAssertTrue(logger.entries.contains("account_reorder_loaded count=3 order=acct-1,acct-2,acct-3"))
        XCTAssertTrue(logger.entries.contains("account_reorder_requested source=0 destination=1 order=acct-1,acct-2,acct-3"))
        XCTAssertTrue(logger.entries.contains("account_reorder_persist_started order=acct-2,acct-1,acct-3"))
        XCTAssertTrue(logger.entries.contains("account_reorder_persist_succeeded order=acct-2,acct-1,acct-3"))
    }

    func testMoveRowsKeepsRowsAndExposesErrorWhenSaveFails() async {
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
        await viewModel.moveRows(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertEqual(viewModel.rows, originalRows)
        XCTAssertEqual(viewModel.lastErrorMessage, "failed")
    }

    func testLoadFormatsWeeklyResetWithConcreteDate() async {
        let originalTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: 8 * 3600)!
        defer { NSTimeZone.default = originalTimeZone }

        let resetDate = Date(timeIntervalSince1970: 1_743_157_872)
        let service = InMemoryAccountManagementService(
            accounts: [
                makeAccount(id: "acct-1", order: 0, tier: .team),
            ],
            usageSnapshots: [
                "acct-1": CodexUsageSnapshot(
                    accountID: "acct-1",
                    updatedAt: resetDate,
                    fiveHour: CodexUsageWindow(percentUsed: 42, resetsAt: resetDate),
                    weekly: CodexUsageWindow(percentUsed: 18, resetsAt: resetDate)
                ),
            ]
        )
        let viewModel = AccountManagementViewModel(service: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.weeklyResetText, "重置 03-28 18:31")
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
    private var activeAccountID: String?
    private let usageSnapshots: [String: CodexUsageSnapshot]
    private let saveError: Error?
    private var emailVisibilityEnabled: Bool
    private let importedAccountsByAction: [AccountManagementAddAction: Account]
    private let addAccountErrorsByAction: [AccountManagementAddAction: Error]
    private let blockingActions: Set<AccountManagementAddAction>
    private var actionInvocationCounts: [AccountManagementAddAction: Int] = [:]
    private var cancellationObservations: Set<AccountManagementAddAction> = []

    private(set) var savedOrderHistory: [[String]] = []
    private(set) var performedAddActions: [AccountManagementAddAction] = []

    init(
        accounts: [Account],
        activeAccountID: String? = nil,
        usageSnapshots: [String: CodexUsageSnapshot] = [:],
        saveError: Error? = nil,
        emailVisibilityEnabled: Bool = false,
        importedAccountsByAction: [AccountManagementAddAction: Account] = [:],
        addAccountErrorsByAction: [AccountManagementAddAction: Error] = [:],
        blockingActions: Set<AccountManagementAddAction> = []
    ) {
        self.accounts = accounts
        self.activeAccountID = activeAccountID
        self.usageSnapshots = usageSnapshots
        self.saveError = saveError
        self.emailVisibilityEnabled = emailVisibilityEnabled
        self.importedAccountsByAction = importedAccountsByAction
        self.addAccountErrorsByAction = addAccountErrorsByAction
        self.blockingActions = blockingActions
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

    func performAddAccountAction(_ action: AccountManagementAddAction) async throws -> Account? {
        performedAddActions.append(action)
        actionInvocationCounts[action, default: 0] += 1

        if blockingActions.contains(action) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            cancellationObservations.insert(action)
            throw CancellationError()
        }

        if let error = addAccountErrorsByAction[action] {
            throw error
        }

        guard let importedAccount = importedAccountsByAction[action] else {
            return nil
        }

        accounts.append(importedAccount)
        activeAccountID = importedAccount.id
        return importedAccount
    }

    func invocationCount(for action: AccountManagementAddAction) -> Int {
        actionInvocationCounts[action, default: 0]
    }

    func didObserveCancellation(for action: AccountManagementAddAction) -> Bool {
        cancellationObservations.contains(action)
    }
}

private enum StubError: LocalizedError {
    case failed

    var errorDescription: String? {
        "failed"
    }
}

private final class InMemoryDiagnosticsLogger: CodexDiagnosticsLogging {
    private(set) var entries: [String] = []

    func log(_ message: String) {
        entries.append(message)
    }
}

private extension AccountManagementViewModelTests {
    func waitForCondition(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<200 {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for condition", file: file, line: line)
    }
}
