import SwiftUI

public struct CompactAccountRowView: View {
    private let row: QuickSwitchRowModel
    private let onSelect: (() -> Void)?

    public init(row: QuickSwitchRowModel, onSelect: (() -> Void)? = nil) {
        self.row = row
        self.onSelect = onSelect
    }

    public var body: some View {
        Button {
            onSelect?()
        } label: {
            HStack(spacing: 8) {
                Text(row.emailText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(row.tierBadgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.08)))
                Text(row.fiveHourLabel)
                    .font(.caption2.weight(.semibold))
                Text(row.weeklyLabel)
                    .font(.caption2.weight(.semibold))
                if row.isActive {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(nsColor: .systemGreen))
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
