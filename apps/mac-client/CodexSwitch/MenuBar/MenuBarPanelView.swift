import SwiftUI

public struct MenuBarPanelView: View {
    @ObservedObject private var viewModel: MenuBarViewModel

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
                actionRow(title: "Import Current Account") {
                    Task {
                        try? await viewModel.importCurrentAccount()
                    }
                }
                actionRow(title: "Import Backup Auth") {
                    Task {
                        try? await viewModel.importBackupAccount()
                    }
                }
                actionRow(title: "Login in Browser") {
                    Task {
                        try? await viewModel.loginInBrowser()
                    }
                }
                actionRow(title: "Status Page") {
                    viewModel.openStatusPage()
                }
                actionRow(title: viewModel.showEmails ? "Hide Emails" : "Show Emails") {
                    Task {
                        await viewModel.toggleShowEmails()
                    }
                }
                actionRow(title: "Settings") {
                    viewModel.openSettings()
                }
                actionRow(title: "Quit") {
                    viewModel.quit()
                }
            }
        }
        .padding(20)
        .frame(width: 360)
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

    private func actionRow(title: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
