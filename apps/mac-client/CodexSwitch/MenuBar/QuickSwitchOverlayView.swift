import AppKit
import SwiftUI

public struct QuickSwitchOverlayView: View {
    private static let minWidth: CGFloat = 320
    private static let maxWidth: CGFloat = 520
    private static let minHeight: CGFloat = 120
    private static let maxHeight: CGFloat = 320
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

    public static func preferredWidth(for rows: [QuickSwitchRowModel]) -> CGFloat {
        let emailFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let metaFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)

        let widestRow = rows.map { row -> CGFloat in
            let emailWidth = row.emailText.size(withAttributes: [.font: emailFont]).width
            let tierWidth = row.tierBadgeText.size(withAttributes: [.font: metaFont]).width + 20
            let fiveHourWidth = row.fiveHourLabel.size(withAttributes: [.font: metaFont]).width
            let weeklyWidth = row.weeklyLabel.size(withAttributes: [.font: metaFont]).width
            let checkWidth: CGFloat = row.isActive ? 14 : 0
            return emailWidth + tierWidth + fiveHourWidth + weeklyWidth + checkWidth + 68
        }.max() ?? minWidth

        return min(max(widestRow, minWidth), maxWidth)
    }

    public static func preferredHeight(for rowCount: Int) -> CGFloat {
        let contentHeight = CGFloat(rowCount) * 34 + 24
        return min(max(contentHeight, minHeight), maxHeight)
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
        .frame(
            width: Self.preferredWidth(for: rows),
            height: Self.preferredHeight(for: rows.count)
        )
        .onHover { isHovering in
            onHoverChanged?(isHovering)
        }
    }
}
