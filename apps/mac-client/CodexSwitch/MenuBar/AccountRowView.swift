import SwiftUI

public struct AccountRowView: View {
    private let account: AccountRowModel
    private let pendingRemovalMessage: String?
    private let inlineFeedback: MenuBarInlineMessage?
    private let onSelect: (() -> Void)?
    private let onRemove: (() -> Void)?
    private let onConfirmRemove: (() -> Void)?
    private let onCancelRemove: (() -> Void)?

    public init(
        account: AccountRowModel,
        pendingRemovalMessage: String? = nil,
        inlineFeedback: MenuBarInlineMessage? = nil,
        onSelect: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil,
        onConfirmRemove: (() -> Void)? = nil,
        onCancelRemove: (() -> Void)? = nil
    ) {
        self.account = account
        self.pendingRemovalMessage = pendingRemovalMessage
        self.inlineFeedback = inlineFeedback
        self.onSelect = onSelect
        self.onRemove = onRemove
        self.onConfirmRemove = onConfirmRemove
        self.onCancelRemove = onCancelRemove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(account.emailMask)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text(account.tierLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 10) {
                    metric(label: "5h", percent: account.fiveHourPercent)
                    metric(label: "wk", percent: account.weeklyPercent)
                }
                Spacer()
                iconButton(
                    systemName: account.isActive ? "checkmark.circle.fill" : "arrow.left.arrow.right.circle.fill",
                    help: account.isActive ? "Current Account" : "Switch Account",
                    tint: account.isActive ? Color(nsColor: .systemGreen) : .secondary,
                    action: { onSelect?() }
                )
                if let onRemove {
                    iconButton(
                        systemName: "trash.circle",
                        help: "Remove Account",
                        tint: .secondary,
                        role: .destructive,
                        action: onRemove
                    )
                }
            }

            if let pendingRemovalMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pendingRemovalMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if let onConfirmRemove {
                            Button("Remove", role: .destructive, action: onConfirmRemove)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        if let onCancelRemove {
                            Button("Cancel", action: onCancelRemove)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }

            if let inlineFeedback {
                inlineFeedbackContent(inlineFeedback)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(account.isActive ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(account.isActive ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            guard pendingRemovalMessage == nil else {
                return
            }
            onSelect?()
        }
    }

    private func metric(label: String, percent: Int) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .leading)

            ProgressView(value: Double(percent), total: 100)
                .tint(Color(nsColor: .systemTeal))

            Text("\(percent)%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func iconButton(
        systemName: String,
        help: String,
        tint: Color,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func inlineFeedbackContent(_ feedback: MenuBarInlineMessage) -> some View {
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
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
