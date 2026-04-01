import SwiftUI

public struct MenuBarPanelView: View {
    @ObservedObject private var viewModel: MenuBarViewModel
    @State private var isShowingAddAccountOptions = false

    public init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            panelContent
        }
        .frame(width: 360)
        .overlay(alignment: .bottom) {
            if let removalFeedback = viewModel.removalFeedback {
                feedbackBanner(removalFeedback)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
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

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            Divider()

            ForEach(viewModel.summaries) { summary in
                UsageSummaryCard(summary: summary)
            }

            Divider()

            Text("Switch Account")
                .font(.headline)

            ForEach(viewModel.accountRows) { account in
                AccountRowView(
                    account: account,
                    pendingRemovalMessage: pendingRemovalMessage(for: account.id),
                    onSelect: {
                        Task {
                            try? await viewModel.switchToAccount(id: account.id)
                        }
                    },
                    onRemove: {
                        viewModel.requestRemoveAccount(id: account.id)
                    },
                    onConfirmRemove: {
                        Task {
                            await viewModel.performPendingAccountRemoval()
                        }
                    },
                    onCancelRemove: {
                        viewModel.cancelPendingAccountRemoval()
                    }
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                addAccountMenu
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
                actionRow(title: "Provider Sync", systemImage: "arrow.triangle.2.circlepath") {
                    viewModel.openProviderSync()
                }
                actionRow(title: "Settings", systemImage: "gearshape") {
                    viewModel.openSettings()
                }
                actionRow(title: "Quit", systemImage: "power") {
                    viewModel.quit()
                }
            }
        }
        .padding(16)
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Codex")
                        .font(.title2.weight(.semibold))
                    Text(viewModel.headerEmail)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                HStack(spacing: 6) {
                    Label("Updated \(viewModel.updatedText)", systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    if !viewModel.usageSourceText.isEmpty {
                        Text(viewModel.usageSourceText)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }

                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Usage")
                }
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
            HStack(spacing: 8) {
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

    private func feedbackBanner(_ feedback: MenuBarInlineMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(feedback.tone == .success ? Color(nsColor: .systemGreen) : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.caption.weight(.semibold))
                Text(feedback.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.dismissRemovalFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func pendingRemovalMessage(for accountID: String) -> String? {
        guard viewModel.pendingAccountRemoval?.accountID == accountID else {
            return nil
        }

        return viewModel.pendingAccountRemoval?.message
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
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.12) : Color.clear)
            )
    }
}
