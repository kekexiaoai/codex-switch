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
                actionRow(title: "Add Account") {
                    viewModel.startAddingAccount()
                }
                actionRow(title: "Status Page")
                actionRow(title: viewModel.showEmails ? "Hide Emails" : "Show Emails") {
                    Task {
                        await viewModel.toggleShowEmails()
                    }
                }
                actionRow(title: "Settings")
                actionRow(title: "Quit")
            }

            if viewModel.isPresentingAddAccount {
                Divider()
                addAccountForm
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

    private var addAccountForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Account")
                .font(.headline)

            TextField("Email", text: $viewModel.draftEmail)
                .textFieldStyle(.roundedBorder)

            SecureField("Secret", text: $viewModel.draftSecret)
                .textFieldStyle(.roundedBorder)

            Picker("Tier", selection: $viewModel.draftTier) {
                Text("Plus").tag(AccountTier.plus)
                Text("Pro").tag(AccountTier.pro)
                Text("Team").tag(AccountTier.team)
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") {
                    viewModel.cancelAddingAccount()
                }

                Spacer()

                Button("Save") {
                    Task {
                        try? await viewModel.submitNewAccount()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
