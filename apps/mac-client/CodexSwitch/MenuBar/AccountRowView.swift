import SwiftUI

public struct AccountRowView: View {
    private let account: AccountRowModel
    private let onSelect: (() -> Void)?
    private let onRemove: (() -> Void)?

    public init(
        account: AccountRowModel,
        onSelect: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.account = account
        self.onSelect = onSelect
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: { onSelect?() }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(account.emailMask)
                            .font(.headline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(account.tierLabel)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Text(account.isActive ? "Current" : "Switch")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: account.isActive ? "checkmark.circle.fill" : "chevron.right.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundColor(account.isActive ? Color(nsColor: .systemGreen) : .secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        metric(label: "5h", percent: account.fiveHourPercent)
                        metric(label: "wk", percent: account.weeklyPercent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Remove Account")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(account.isActive ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(account.isActive ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func metric(label: String, percent: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 18, alignment: .leading)

            ProgressView(value: Double(percent), total: 100)
                .tint(Color(nsColor: .systemTeal))

            Text("\(percent)%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
