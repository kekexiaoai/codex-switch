import SwiftUI
import UniformTypeIdentifiers

public struct AccountManagementView: View {
    @ObservedObject private var viewModel: AccountManagementViewModel
    @State private var draggedRowID: String?

    public init(viewModel: AccountManagementViewModel) {
        self.viewModel = viewModel
    }

    public var columnTitles: [String] {
        ["账号", "类型", "5H", "7D", "拖拽"]
    }

    public var pageTitle: String {
        "账号"
    }

    public var reorderInstructionText: String {
        viewModel.isReordering ? "正在保存最新排序..." : "拖动卡片即可调整顺序。"
    }

    public var summaryLabels: [String] {
        ["当前账号", "归档账号", "排序来源"]
    }

    public var emailVisibilityButtonLabel: String {
        viewModel.showEmails ? "隐藏邮箱" : "显示邮箱"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader
            summaryStrip
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    topInsertionDropZone
                    ForEach(viewModel.rows) { row in
                        accountCard(row)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onDrag {
                                draggedRowID = row.id
                                viewModel.logDragStarted(id: row.id)
                                return NSItemProvider(object: row.id as NSString)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: AccountManagementInsertionDropDelegate(
                                    targetLabel: row.id,
                                    destinationIndex: destinationIndex(for: row.id),
                                    draggedRowID: $draggedRowID,
                                    logDropEntered: { draggedID, targetID, destinationIndex in
                                        viewModel.logDropEntered(
                                            draggedID: draggedID,
                                            targetID: targetID,
                                            destinationIndex: destinationIndex
                                        )
                                    },
                                    logDropPerformed: { draggedID, targetID, destinationIndex in
                                        viewModel.logDropPerformed(
                                            draggedID: draggedID,
                                            targetID: targetID,
                                            destinationIndex: destinationIndex
                                        )
                                    },
                                    logDropIgnored: { draggedID, targetID, reason in
                                        viewModel.logDropIgnored(
                                            draggedID: draggedID,
                                            targetID: targetID,
                                            reason: reason
                                        )
                                    },
                                    moveRow: { draggedID, destinationIndex in
                                        Task {
                                            await viewModel.moveRow(id: draggedID, to: destinationIndex)
                                        }
                                    }
                                )
                            )
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

    @ViewBuilder
    private var topInsertionDropZone: some View {
        if !viewModel.rows.isEmpty {
            Color.clear
                .frame(height: 18)
                .contentShape(Rectangle())
                .onDrop(
                    of: [UTType.text],
                    delegate: AccountManagementInsertionDropDelegate(
                        targetLabel: "__top__",
                        destinationIndex: 0,
                        draggedRowID: $draggedRowID,
                        logDropEntered: { draggedID, targetID, destinationIndex in
                            viewModel.logDropEntered(
                                draggedID: draggedID,
                                targetID: targetID,
                                destinationIndex: destinationIndex
                            )
                        },
                        logDropPerformed: { draggedID, targetID, destinationIndex in
                            viewModel.logDropPerformed(
                                draggedID: draggedID,
                                targetID: targetID,
                                destinationIndex: destinationIndex
                            )
                        },
                        logDropIgnored: { draggedID, targetID, reason in
                            viewModel.logDropIgnored(
                                draggedID: draggedID,
                                targetID: targetID,
                                reason: reason
                            )
                        },
                        moveRow: { draggedID, destinationIndex in
                            Task {
                                await viewModel.moveRow(id: draggedID, to: destinationIndex)
                            }
                        }
                    )
                )
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pageTitle)
                    .font(.title2.weight(.semibold))
                Text("这里的排序会直接同步到状态栏快速切换菜单。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(reorderInstructionText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(emailVisibilityButtonLabel) {
                Task {
                    await viewModel.toggleShowEmails()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            summaryCard(title: summaryLabels[0], value: viewModel.rows.first(where: \.isActive)?.emailText ?? "暂无")
            summaryCard(title: summaryLabels[1], value: "\(viewModel.rows.count)")
            summaryCard(title: summaryLabels[2], value: "手动排序")
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func accountCard(_ row: AccountManagementRowModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.tierText.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(Color.accentColor.opacity(0.12)))

                Text(row.emailText)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if row.isActive {
                    Label("当前", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(nsColor: .systemGreen))
                }
            }

            HStack(spacing: 10) {
                metricCard(title: "5H", percent: row.fiveHourPercent, resetText: row.fiveHourResetText)
                metricCard(title: "7D", percent: row.weeklyPercent, resetText: row.weeklyResetText)
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3.weight(.semibold))
                    Text("拖拽")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(.secondary)
                .frame(width: 44)
                .help("拖动调整顺序")
            }

            if let lastErrorMessage = viewModel.lastErrorMessage, !lastErrorMessage.isEmpty {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(row.isActive ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(row.isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func metricCard(title: String, percent: Int, resetText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(resetText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(.caption.weight(.semibold))
            }
            ProgressView(value: Double(percent), total: 100)
                .tint(Color(nsColor: .systemTeal))
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func destinationIndex(for targetRowID: String) -> Int {
        viewModel.rows.firstIndex(where: { $0.id == targetRowID }) ?? 0
    }
}

private struct AccountManagementInsertionDropDelegate: DropDelegate {
    let targetLabel: String
    let destinationIndex: Int
    @Binding var draggedRowID: String?
    let logDropEntered: (String, String, Int) -> Void
    let logDropPerformed: (String, String, Int) -> Void
    let logDropIgnored: (String?, String, String) -> Void
    let moveRow: (String, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard
            let draggedRowID,
            draggedRowID != targetLabel
        else {
            return
        }

        logDropEntered(draggedRowID, targetLabel, destinationIndex)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedRowID = nil }

        guard let draggedRowID else {
            logDropIgnored(nil, targetLabel, "missing_dragged_row")
            return false
        }
        guard draggedRowID != targetLabel else {
            logDropIgnored(draggedRowID, targetLabel, "same_target")
            return false
        }

        logDropPerformed(draggedRowID, targetLabel, destinationIndex)
        moveRow(draggedRowID, destinationIndex)
        return true
    }
}
