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
        Button(action: { onSelect?() }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(account.emailMask)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(account.tierLabel)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text(account.isActive ? "Current" : "Switch")
                                        .font(.caption2.weight(.semibold))
                                    Image(systemName: account.isActive ? "checkmark.circle.fill" : "chevron.right.circle.fill")
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundColor(account.isActive ? Color(nsColor: .systemGreen) : .secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            metric(label: "5h", percent: account.fiveHourPercent)
                            metric(label: "wk", percent: account.weeklyPercent)
                        }
                    }

                    if let onRemove {
                        Button(role: .destructive, action: onRemove) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Remove Account")
                    }
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
        }
        .buttonStyle(.plain)
    }

    private func metric(label: String, percent: Int) -> some View {
        HStack(spacing: 6) {
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
}
