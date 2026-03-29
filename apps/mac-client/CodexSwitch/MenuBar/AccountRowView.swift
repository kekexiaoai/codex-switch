import SwiftUI

public struct AccountRowView: View {
    private let account: AccountRowModel
    private let onSelect: (() -> Void)?

    public init(account: AccountRowModel, onSelect: (() -> Void)? = nil) {
        self.account = account
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: { onSelect?() }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(account.emailMask)
                        .font(.headline)
                    Spacer()
                    Text(account.tierLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    metric(label: "5h", percent: account.fiveHourPercent)
                    metric(label: "wk", percent: account.weeklyPercent)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
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
