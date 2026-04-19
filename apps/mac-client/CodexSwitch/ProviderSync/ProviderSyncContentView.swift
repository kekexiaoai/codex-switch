import SwiftUI

public struct ProviderSyncContentView: View {
    private let viewModel: ProviderSyncViewModel

    public init(viewModel: ProviderSyncViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ProviderSyncView(viewModel: viewModel)
    }
}
