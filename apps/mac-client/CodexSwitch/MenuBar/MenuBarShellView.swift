import SwiftUI

@MainActor
public struct MenuBarShellView: View {
    @StateObject private var viewModel: MenuBarViewModel
    private let onQuickSwitchAnchorFrameChange: ((CGRect) -> Void)?
    private let onQuickSwitchHoverChange: ((Bool) -> Void)?

    public init(
        viewModel: MenuBarViewModel? = nil,
        onQuickSwitchAnchorFrameChange: ((CGRect) -> Void)? = nil,
        onQuickSwitchHoverChange: ((Bool) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel ?? .preview)
        self.onQuickSwitchAnchorFrameChange = onQuickSwitchAnchorFrameChange
        self.onQuickSwitchHoverChange = onQuickSwitchHoverChange
    }

    public init(environment: AppEnvironment) {
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
        self.onQuickSwitchAnchorFrameChange = nil
        self.onQuickSwitchHoverChange = nil
    }

    public var body: some View {
        MenuBarPanelView(
            viewModel: viewModel,
            onQuickSwitchAnchorFrameChange: onQuickSwitchAnchorFrameChange,
            onQuickSwitchHoverChange: onQuickSwitchHoverChange
        )
    }
}
