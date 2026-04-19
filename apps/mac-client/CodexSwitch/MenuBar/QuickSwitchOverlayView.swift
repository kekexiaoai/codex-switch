import SwiftUI

public struct QuickSwitchOverlayView: View {
    private let rows: [QuickSwitchRowModel]
    private let onSelect: (String) -> Void
    private let onHoverChanged: ((Bool) -> Void)?

    public init(
        rows: [QuickSwitchRowModel],
        onSelect: @escaping (String) -> Void,
        onHoverChanged: ((Bool) -> Void)? = nil
    ) {
        self.rows = rows
        self.onSelect = onSelect
        self.onHoverChanged = onHoverChanged
    }

    public var rowIDs: [String] {
        rows.map(\.id)
    }

    public var actionLabels: [String] {
        []
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    CompactAccountRowView(row: row) {
                        onSelect(row.id)
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 320, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
        .onHover { isHovering in
            onHoverChanged?(isHovering)
        }
    }
}
