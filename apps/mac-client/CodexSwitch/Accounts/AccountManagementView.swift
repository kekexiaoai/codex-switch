import SwiftUI

public struct AccountManagementView: View {
    @ObservedObject private var viewModel: AccountManagementViewModel

    public init(viewModel: AccountManagementViewModel) {
        self.viewModel = viewModel
    }

    public var columnTitles: [String] {
        ["账号", "类型", "5H", "7D", "排序"]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.rows) { row in
                        HStack(spacing: 12) {
                            Text(row.emailText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.tierText)
                                .foregroundColor(.secondary)
                            Text(row.fiveHourText)
                                .font(.caption.weight(.semibold))
                            Text(row.weeklyText)
                                .font(.caption.weight(.semibold))
                            HStack(spacing: 6) {
                                Button("↑") {
                                    Task {
                                        await viewModel.moveUp(id: row.id)
                                    }
                                }
                                .disabled(!row.canMoveUp)
                                Button("↓") {
                                    Task {
                                        await viewModel.moveDown(id: row.id)
                                    }
                                }
                                .disabled(!row.canMoveDown)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(20)
        .task {
            if viewModel.rows.isEmpty {
                await viewModel.load()
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Text(columnTitles[0])
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(columnTitles[1])
            Text(columnTitles[2])
            Text(columnTitles[3])
            Text(columnTitles[4])
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.secondary)
    }
}
