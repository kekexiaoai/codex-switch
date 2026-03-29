import SwiftUI

public struct MenuBarShellView: View {
    @StateObject private var viewModel: MenuBarViewModel

    public init(viewModel: MenuBarViewModel = .preview) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        MenuBarPanelView(viewModel: viewModel)
            .task {
                await viewModel.refresh()
            }
    }
}
