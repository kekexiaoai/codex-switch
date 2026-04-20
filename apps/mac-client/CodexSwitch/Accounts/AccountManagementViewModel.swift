import Foundation

public struct AccountManagementRowModel: Identifiable, Equatable {
    public let id: String
    public let emailText: String
    public let tierText: String
    public let fiveHourPercent: Int
    public let weeklyPercent: Int
    public let fiveHourResetText: String
    public let weeklyResetText: String
    public let fiveHourText: String
    public let weeklyText: String
    public let isActive: Bool
}

public enum AccountManagementAddAction: CaseIterable, Equatable, Identifiable {
    case importCurrentAccount
    case importBackupAuth
    case loginInBrowser

    public var id: Self {
        self
    }

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

    public var progressText: String? {
        switch self {
        case .importCurrentAccount:
            return MenuBarStrings.text(.importingCurrentAccountTitle)
        case .importBackupAuth:
            return nil
        case .loginInBrowser:
            return MenuBarStrings.text(.browserLoginInProgressTitle)
        }
    }
}

@MainActor
public final class AccountManagementViewModel: ObservableObject {
    @Published public private(set) var rows: [AccountManagementRowModel] = []
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var isReordering = false
    @Published public private(set) var showEmails = false
    @Published public private(set) var isPerformingAddAccountAction = false
    @Published public private(set) var addAccountProgressText: String?

    private let service: any AccountManagementServicing
    private let logger: any CodexDiagnosticsLogging
    private let timeFormatter = CodexUserFacingTimeFormatter()

    public static let preview = AccountManagementViewModel(service: PreviewAccountManagementService())

    public init(
        service: any AccountManagementServicing,
        logger: any CodexDiagnosticsLogging = NullCodexDiagnosticsLogger()
    ) {
        self.service = service
        self.logger = logger
    }

    public var addAccountActions: [AccountManagementAddAction] {
        AccountManagementAddAction.allCases
    }

    public func load() async {
        do {
            let accounts = try await service.loadAccounts()
            let activeAccountID = await service.currentActiveAccountID()
            let showEmails = service.showEmails()
            var nextRows: [AccountManagementRowModel] = []

            for account in accounts {
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
                        fiveHourResetText: snapshot.map { "重置 \(timeFormatter.monthDayClockTimestamp(from: $0.fiveHour.resetsAt))" } ?? "重置 --:--",
                        weeklyResetText: snapshot.map { "重置 \(timeFormatter.monthDayClockTimestamp(from: $0.weekly.resetsAt))" } ?? "重置 --:--",
                        fiveHourText: "5H \(fiveHourPercent)%",
                        weeklyText: "7D \(weeklyPercent)%",
                        isActive: account.id == activeAccountID
                    )
                )
            }

            rows = nextRows
            self.showEmails = showEmails
            lastErrorMessage = nil
            logger.log("account_reorder_loaded count=\(nextRows.count) order=\(orderDescription(for: nextRows.map(\.id)))")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.log("account_reorder_load_failed error=\(error.localizedDescription)")
        }
    }

    public func toggleShowEmails() async {
        service.setShowEmails(!service.showEmails())
        await load()
    }

    public func performAddAccountAction(_ action: AccountManagementAddAction) async {
        guard !isPerformingAddAccountAction else {
            return
        }

        isPerformingAddAccountAction = true
        addAccountProgressText = action.progressText
        lastErrorMessage = nil

        defer {
            isPerformingAddAccountAction = false
            addAccountProgressText = nil
        }

        do {
            let importedAccount = try await service.performAddAccountAction(action)
            if importedAccount != nil {
                await load()
            }
        } catch {
            lastErrorMessage = addAccountErrorMessage(for: action, error: error)
        }
    }

    public func moveUp(id: String) async {
        guard let index = rows.firstIndex(where: { $0.id == id }), index > 0 else {
            return
        }
        await moveRow(id: id, to: index - 1)
    }

    public func moveDown(id: String) async {
        guard let index = rows.firstIndex(where: { $0.id == id }), index < rows.count - 1 else {
            return
        }
        await moveRow(id: id, to: index + 1)
    }

    public func moveRow(id: String, to destination: Int) async {
        guard !isReordering else {
            logger.log("account_reorder_ignored reason=reordering_in_progress dragged=\(id) destination=\(destination)")
            return
        }
        guard let sourceIndex = rows.firstIndex(where: { $0.id == id }) else {
            logger.log("account_reorder_ignored reason=missing_dragged_row dragged=\(id) destination=\(destination)")
            return
        }

        await applyReorder(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destination)
    }

    public func moveRows(fromOffsets source: IndexSet, toOffset destination: Int) async {
        guard !isReordering else {
            logger.log("account_reorder_ignored reason=reordering_in_progress source=\(indexDescription(for: source)) destination=\(destination)")
            return
        }

        await applyReorder(fromOffsets: source, toOffset: destination)
    }

    func logDragStarted(id: String) {
        logger.log("account_reorder_drag_started dragged=\(id) order=\(currentOrderDescription())")
    }

    func logDropEntered(draggedID: String, targetID: String, destinationIndex: Int) {
        logger.log(
            "account_reorder_drop_entered dragged=\(draggedID) target=\(targetID) destination=\(destinationIndex) order=\(currentOrderDescription())"
        )
    }

    func logDropPerformed(draggedID: String, targetID: String, destinationIndex: Int) {
        logger.log(
            "account_reorder_drop_performed dragged=\(draggedID) target=\(targetID) destination=\(destinationIndex) order=\(currentOrderDescription())"
        )
    }

    func logDropIgnored(draggedID: String?, targetID: String, reason: String) {
        logger.log(
            "account_reorder_drop_ignored reason=\(reason) dragged=\(draggedID ?? "nil") target=\(targetID) order=\(currentOrderDescription())"
        )
    }

    private func applyReorder(fromOffsets source: IndexSet, toOffset destination: Int) async {
        let originalRows = rows
        logger.log(
            "account_reorder_requested source=\(indexDescription(for: source)) destination=\(destination) order=\(orderDescription(for: originalRows.map(\.id)))"
        )
        let reorderedRows = reorderedRows(afterMoving: rows, fromOffsets: source, toOffset: destination)
        guard reorderedRows != originalRows else {
            logger.log(
                "account_reorder_noop source=\(indexDescription(for: source)) destination=\(destination) order=\(orderDescription(for: originalRows.map(\.id)))"
            )
            return
        }

        rows = reorderedRows
        await persistOrder(reorderedRows.map(\.id), originalRows: originalRows)
    }

    private func persistOrder(_ orderedIDs: [String], originalRows: [AccountManagementRowModel]) async {
        isReordering = true
        defer { isReordering = false }
        logger.log("account_reorder_persist_started order=\(orderDescription(for: orderedIDs))")

        do {
            try await service.saveManualOrder(idsInOrder: orderedIDs)
            logger.log("account_reorder_persist_succeeded order=\(orderDescription(for: orderedIDs))")
            await load()
        } catch {
            rows = originalRows
            lastErrorMessage = error.localizedDescription
            logger.log(
                "account_reorder_persist_failed error=\(error.localizedDescription) reverted_order=\(orderDescription(for: originalRows.map(\.id)))"
            )
        }
    }

    private func reorderedRows(
        afterMoving rows: [AccountManagementRowModel],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [AccountManagementRowModel] {
        guard !source.isEmpty else {
            return rows
        }
        guard let maxSourceIndex = source.max(), maxSourceIndex < rows.count else {
            return rows
        }

        let movingRows = source.sorted().map { rows[$0] }
        var remainingRows: [AccountManagementRowModel] = []
        remainingRows.reserveCapacity(rows.count - movingRows.count)

        for (index, row) in rows.enumerated() where !source.contains(index) {
            remainingRows.append(row)
        }

        let insertionIndex = max(0, min(destination, remainingRows.count))

        remainingRows.insert(contentsOf: movingRows, at: insertionIndex)
        return remainingRows
    }

    private func currentOrderDescription() -> String {
        orderDescription(for: rows.map(\.id))
    }

    private func orderDescription(for ids: [String]) -> String {
        ids.isEmpty ? "empty" : ids.joined(separator: ",")
    }

    private func indexDescription(for source: IndexSet) -> String {
        source.map(String.init).joined(separator: ",")
    }

    private func addAccountErrorMessage(for action: AccountManagementAddAction, error: Error) -> String {
        guard let authError = error as? CodexAuthError else {
            return error.localizedDescription
        }

        switch action {
        case .importCurrentAccount:
            switch authError {
            case .currentAuthFileMissing, .authFileUnreadable:
                return MenuBarStrings.text(.cannotImportCurrentAccountNoAuth)
            case .apiKeyModeDetected, .idTokenMissing:
                return MenuBarStrings.text(.cannotImportCurrentAccountNoSession)
            case .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarStrings.text(.cannotImportCurrentAccountInvalid)
            case .archiveWriteFailed:
                return MenuBarStrings.text(.cannotImportCurrentAccountArchive)
            default:
                return MenuBarStrings.text(.cannotImportCurrentAccountGeneric)
            }
        case .importBackupAuth:
            switch authError {
            case .authFileUnreadable:
                return MenuBarStrings.text(.cannotImportBackupAuthUnreadable)
            case .apiKeyModeDetected, .idTokenMissing, .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarStrings.text(.cannotImportBackupAuthInvalid)
            case .archiveWriteFailed:
                return MenuBarStrings.text(.cannotImportBackupAuthArchive)
            default:
                return MenuBarStrings.text(.cannotImportBackupAuthGeneric)
            }
        case .loginInBrowser:
            switch authError {
            case .browserLaunchFailed:
                return MenuBarStrings.text(.browserCouldNotOpenMessage)
            case .loginCancelled:
                return MenuBarStrings.text(.browserLoginCancelledMessage)
            case .loginTimedOut:
                return MenuBarStrings.text(.browserLoginTimedOutMessage)
            case .currentAuthFileMissing, .idTokenMissing, .authJSONInvalid, .jwtPayloadInvalid:
                return MenuBarStrings.text(.browserLoginNoSessionMessage)
            case .loginFailed:
                return MenuBarStrings.text(.browserLoginFailedMessage)
            default:
                return MenuBarStrings.text(.browserLoginGenericMessage)
            }
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

    func performAddAccountAction(_ action: AccountManagementAddAction) async throws -> Account? {
        nil
    }
}
