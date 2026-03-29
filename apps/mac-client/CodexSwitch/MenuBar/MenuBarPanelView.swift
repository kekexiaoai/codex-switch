import SwiftUI

public struct MenuBarPanelView: View {
    @ObservedObject private var viewModel: MenuBarViewModel
    @State private var isShowingAddAccountOptions = false

    public init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            Divider()

            ForEach(viewModel.summaries) { summary in
                UsageSummaryCard(summary: summary)
            }

            Divider()

            Text("Switch Account")
                .font(.headline)

            ForEach(viewModel.accountRows) { account in
                AccountRowView(account: account) {
                    Task {
                        try? await viewModel.switchToAccount(id: account.id)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                addAccountMenu
                actionRow(title: "Refresh Usage", systemImage: "arrow.clockwise") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                actionRow(title: "Status Page", systemImage: "waveform.path.ecg") {
                    viewModel.openStatusPage()
                }
                actionRow(
                    title: viewModel.showEmails ? "Hide Emails" : "Show Emails",
                    systemImage: viewModel.showEmails ? "eye" : "eye.slash"
                ) {
                    Task {
                        await viewModel.toggleShowEmails()
                    }
                }
                actionRow(title: "Settings", systemImage: "gearshape") {
                    viewModel.openSettings()
                }
                actionRow(title: "Quit", systemImage: "power") {
                    viewModel.quit()
                }
            }
        }
        .padding(20)
        .frame(width: 360)
        .alert(item: Binding(
            get: { viewModel.alertMessage },
            set: { _ in viewModel.dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    viewModel.dismissAlert()
                }
            )
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Codex")
                    .font(.title2.weight(.semibold))
                Text(viewModel.updatedText)
                    .foregroundColor(.secondary)
                Text(viewModel.headerEmail)
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 2)
            }

            Spacer()

            Text(viewModel.headerTier)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

    private func actionRow(
        title: String,
        systemImage: String,
        trailingSystemImage: String? = nil,
        isIndented: Bool = false,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                    .foregroundColor(.secondary)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, isIndented ? 20 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarActionRowButtonStyle())
    }

    private var addAccountMenu: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                actionRow(
                    title: "Add Account",
                    systemImage: "person.crop.circle.badge.plus",
                    trailingSystemImage: isShowingAddAccountOptions ? "chevron.down" : "chevron.right"
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isShowingAddAccountOptions.toggle()
                    }
                }

                if isShowingAddAccountOptions {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(MenuBarViewModel.AddAccountAction.allCases, id: \.title) { action in
                            actionRow(
                                title: action.title,
                                systemImage: action.systemImageName,
                                isIndented: true
                            ) {
                                viewModel.startAddAccountAction(action)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress = viewModel.addAccountProgress, isShowingAddAccountOptions {
                addAccountProgressOverlay(progress)
            }
        }
    }

    private func addAccountProgressOverlay(_ progress: MenuBarViewModel.AddAccountProgressState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(progress.title)
                    .font(.subheadline.weight(.semibold))
            }

            Text(progress.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if progress.showsCancelButton {
                Button("Cancel Login") {
                    viewModel.cancelAddAccountAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct MenuBarActionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.12) : Color.clear)
            )
    }
}
