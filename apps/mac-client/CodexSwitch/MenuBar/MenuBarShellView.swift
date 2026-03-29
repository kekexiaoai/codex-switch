import SwiftUI

public struct MenuBarShellView: View {
    @StateObject private var viewModel: MenuBarViewModel

    public init(viewModel: MenuBarViewModel = .preview) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public init(environment: AppEnvironment) {
        _viewModel = StateObject(
            wrappedValue: MenuBarViewModel(
                service: EnvironmentMenuBarService(environment: environment),
                accountRepository: environment.accountRepository,
                activeAccountController: environment.activeAccountController
            )
        )
    }

    public var body: some View {
        MenuBarPanelView(viewModel: viewModel)
            .task {
                await viewModel.refresh()
            }
    }
}
