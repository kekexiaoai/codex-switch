import SwiftUI

public struct AccountManagementView: View {
    @ObservedObject private var viewModel: AccountManagementViewModel

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
            List {
                ForEach(viewModel.rows) { row in
                    accountCard(row)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    Task {
                        await viewModel.moveRows(fromOffsets: source, toOffset: destination)
                    }
                }
                .moveDisabled(viewModel.isReordering)
            }
            .listStyle(.plain)
            .background(Color.clear)
        }
        .padding(20)
        .task {
            if viewModel.rows.isEmpty {
                await viewModel.load()
            }
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
}
