import SwiftUI

@MainActor
public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
    }

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2.weight(.semibold))

            Toggle(
                "Show full account emails",
                isOn: Binding(
                    get: { viewModel.showEmails },
                    set: { viewModel.setShowEmails($0) }
                )
            )

            Divider()

            StatusView()
        }
        .padding(20)
        .frame(width: 360)
    }
}
