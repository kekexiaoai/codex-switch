import Foundation

public struct CodexAccountSwitcher: SwitchCommandRunning {
    private let archivedAccountStore: CodexArchivedAccountStore
    private let fileStore: CodexAuthFileStore

    public init(
        archivedAccountStore: CodexArchivedAccountStore,
        fileStore: CodexAuthFileStore
    ) {
        self.archivedAccountStore = archivedAccountStore
        self.fileStore = fileStore
    }

    public func activateAccount(id: String) async throws {
        let data = try archivedAccountStore.loadArchivedAuthData(for: id)
        try fileStore.replaceActiveAuth(with: data)
    }
}
