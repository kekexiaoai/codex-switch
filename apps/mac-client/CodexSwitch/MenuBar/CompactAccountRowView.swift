import SwiftUI

public struct CompactAccountRowView: View {
    enum Segment: Equatable {
        case tierBadge
        case email
        case fiveHour
        case weekly
        case activeCheckmark
    }

    private let row: QuickSwitchRowModel
    private let onSelect: (() -> Void)?
    @State private var isHovered = false

    public init(row: QuickSwitchRowModel, onSelect: (() -> Void)? = nil) {
        self.row = row
        self.onSelect = onSelect
    }

    var segmentOrder: [Segment] {
        var segments: [Segment] = [.tierBadge, .email, .fiveHour, .weekly]
        if row.isActive {
            segments.append(.activeCheckmark)
        }
        return segments
    }

    static func backgroundOpacity(isHovered: Bool, isPressed: Bool) -> Double {
        if isPressed {
            return 0.14
        }
        if isHovered {
            return 0.10
        }
        return 0.0
    }

    public var body: some View {
        Button {
            onSelect?()
        } label: {
            HStack(spacing: 8) {
                Text(row.tierBadgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.08)))
                Text(row.emailText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuickSwitchRowButtonStyle(isHovered: isHovered))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct QuickSwitchRowButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(
                        CompactAccountRowView.backgroundOpacity(
                            isHovered: isHovered,
                            isPressed: configuration.isPressed
                        )
                    ))
            )
    }
}
