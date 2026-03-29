import SwiftUI

public struct MenuBarShellView: View {
    @StateObject private var viewModel: MenuBarViewModel
    private let onPreferredHeightChange: ((CGFloat) -> Void)?

    public init(
        viewModel: MenuBarViewModel = .preview,
        onPreferredHeightChange: ((CGFloat) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onPreferredHeightChange = onPreferredHeightChange
    }

    public init(environment: AppEnvironment) {
        self.onPreferredHeightChange = nil
        _viewModel = StateObject(
            wrappedValue: MenuBarViewModel(
                service: EnvironmentMenuBarService(environment: environment),
                accountRepository: environment.accountRepository,
                activeAccountController: environment.activeAccountController,
                accountImporter: environment.accountImporter,
                accountRemover: environment.codexPaths.map { CodexArchivedAccountStore(fileStore: CodexAuthFileStore(paths: $0)) },
                loginCoordinator: environment.loginCoordinator,
                backupAuthPicker: OpenPanelBackupAuthPicker(),
                emailVisibilityStore: environment.emailVisibilityProvider as? any EmailVisibilityMutating
            )
        )
    }

    public var body: some View {
        MenuBarPanelView(
            viewModel: viewModel,
            onPreferredHeightChange: onPreferredHeightChange
        )
            .task {
                await viewModel.refresh()
            }
    }
}
