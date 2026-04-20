import SwiftUI

public struct SettingsContentView: View {
    private let viewModel: SettingsViewModel
    private let preferredLanguages: [String]?

    public init(viewModel: SettingsViewModel, preferredLanguages: [String]? = nil) {
        self.viewModel = viewModel
        self.preferredLanguages = preferredLanguages
    }

    public var body: some View {
        SettingsView(
            viewModel: viewModel,
            preferredLanguages: preferredLanguages,
            layoutMode: .embeddedMainWindow
        )
    }
}
