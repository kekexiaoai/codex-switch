import SwiftUI

public struct QuickSwitchOverlayView: View {
    private let rows: [QuickSwitchRowModel]
    private let onSelect: (String) -> Void

    public init(rows: [QuickSwitchRowModel], onSelect: @escaping (String) -> Void) {
        self.rows = rows
        self.onSelect = onSelect
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
    }
}
