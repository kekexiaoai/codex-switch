import SwiftUI

enum ProviderSyncStrings {
    enum Key {
        case title
        case windowTitle
        case loading
        case currentStatus
        case activeProvider
        case configuredProviders
        case sessionDistribution
        case rolloutFiles
        case database
        case noSessionData
        case sync
        case target
        case syncNow
        case switchTo
        case switchAndSync
        case syncing
        case backups
        case noBackups
        case restoreSelected
        case pruneOld
        case loadFailedTitle
        case syncCompleteTitle
        case syncFailedTitle
        case switchCompleteTitle
        case switchFailedTitle
        case restoreCompleteTitle
        case restoreFailedTitle
        case pruneCompleteTitle
        case pruneFailedTitle
        case sessions
        case archived
    }

    static func text(_ key: Key, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return englishText(for: key)
        case .simplifiedChinese:
            return simplifiedChineseText(for: key)
        }
    }

    static func syncCompleteMessage(
        targetProvider: String,
        filesChanged: Int,
        rowsChanged: Int,
        preferredLanguages: [String]? = nil
    ) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Synced to '\(targetProvider)': \(filesChanged) files, \(rowsChanged) database rows updated."
        case .simplifiedChinese:
            return "已同步到 '\(targetProvider)'：更新了 \(filesChanged) 个文件、\(rowsChanged) 条数据库记录。"
        }
    }

    static func switchCompleteMessage(
        targetProvider: String,
        filesChanged: Int,
        rowsChanged: Int,
        preferredLanguages: [String]? = nil
    ) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Switched to '\(targetProvider)': \(filesChanged) files, \(rowsChanged) database rows updated."
        case .simplifiedChinese:
            return "已切换到 '\(targetProvider)'：更新了 \(filesChanged) 个文件、\(rowsChanged) 条数据库记录。"
        }
    }

    static func restoreCompleteMessage(_ backupID: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Restored from backup '\(backupID)'."
        case .simplifiedChinese:
            return "已从备份 '\(backupID)' 恢复。"
        }
    }

    static func pruneCompleteMessage(preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Old backups removed."
        case .simplifiedChinese:
            return "旧备份已移除。"
        }
    }

    static func backupsSummary(_ count: Int, totalSize: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "\(count) backups (\(totalSize))"
        case .simplifiedChinese:
            return "\(count) 个备份（\(totalSize)）"
        }
    }

    static func sessionsLabel(_ count: Int, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "sessions: \(count)"
        case .simplifiedChinese:
            return "会话：\(count)"
        }
    }

    static func archivedLabel(_ count: Int, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "archived: \(count)"
        case .simplifiedChinese:
            return "归档：\(count)"
        }
    }

    static func errorDescription(_ error: ProviderSyncError, preferredLanguages: [String]? = nil) -> String {
        switch error {
        case .configFileNotFound:
            return localized(
                english: "config.toml not found at ~/.codex/config.toml",
                chinese: "未在 ~/.codex/config.toml 找到 config.toml",
                preferredLanguages: preferredLanguages
            )
        case .configParseError(let detail):
            return localized(
                english: "Failed to parse config.toml: \(detail)",
                chinese: "解析 config.toml 失败：\(detail)",
                preferredLanguages: preferredLanguages
            )
        case .sqliteDatabaseNotFound:
            return localized(
                english: "state_5.sqlite not found at ~/.codex/state_5.sqlite",
                chinese: "未在 ~/.codex/state_5.sqlite 找到 state_5.sqlite",
                preferredLanguages: preferredLanguages
            )
        case .sqliteError(let detail):
            return localized(
                english: "SQLite error: \(detail)",
                chinese: "SQLite 错误：\(detail)",
                preferredLanguages: preferredLanguages
            )
        case .syncFailed(let detail):
            return localized(
                english: "Sync failed: \(detail)",
                chinese: "同步失败：\(detail)",
                preferredLanguages: preferredLanguages
            )
        case .backupFailed(let detail):
            return localized(
                english: "Backup failed: \(detail)",
                chinese: "备份失败：\(detail)",
                preferredLanguages: preferredLanguages
            )
        case .restoreFailed(let detail):
            return localized(
                english: "Restore failed: \(detail)",
                chinese: "恢复失败：\(detail)",
                preferredLanguages: preferredLanguages
            )
        case .providerNotConfigured(let provider, let available):
            return localized(
                english: "Provider '\(provider)' is not configured. Available: \(available.joined(separator: ", "))",
                chinese: "Provider '\(provider)' 尚未配置。可用项：\(available.joined(separator: "、"))",
                preferredLanguages: preferredLanguages
            )
        case .lockAcquisitionFailed:
            return localized(
                english: "Could not acquire lock. Another sync operation may be in progress.",
                chinese: "无法获取锁，可能已有其他同步操作正在进行。",
                preferredLanguages: preferredLanguages
            )
        }
    }

    private static func localized(
        english: String,
        chinese: String,
        preferredLanguages: [String]? = nil
    ) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return english
        case .simplifiedChinese:
            return chinese
        }
    }

    private static func englishText(for key: Key) -> String {
        switch key {
        case .title: return "Provider Sync"
        case .windowTitle: return "Provider Sync"
        case .loading: return "Loading..."
        case .currentStatus: return "Current Status"
        case .activeProvider: return "Active Provider"
        case .configuredProviders: return "Configured Providers"
        case .sessionDistribution: return "Session Distribution"
        case .rolloutFiles: return "Rollout Files"
        case .database: return "Database"
        case .noSessionData: return "No session data found."
        case .sync: return "Sync"
        case .target: return "Target:"
        case .syncNow: return "Sync Now"
        case .switchTo: return "Switch to:"
        case .switchAndSync: return "Switch & Sync"
        case .syncing: return "Syncing..."
        case .backups: return "Backups"
        case .noBackups: return "No backups found."
        case .restoreSelected: return "Restore Selected"
        case .pruneOld: return "Prune Old"
        case .loadFailedTitle: return "Load Failed"
        case .syncCompleteTitle: return "Sync Complete"
        case .syncFailedTitle: return "Sync Failed"
        case .switchCompleteTitle: return "Switch Complete"
        case .switchFailedTitle: return "Switch Failed"
        case .restoreCompleteTitle: return "Restore Complete"
        case .restoreFailedTitle: return "Restore Failed"
        case .pruneCompleteTitle: return "Prune Complete"
        case .pruneFailedTitle: return "Prune Failed"
        case .sessions: return "sessions"
        case .archived: return "archived"
        }
    }

    private static func simplifiedChineseText(for key: Key) -> String {
        switch key {
        case .title: return "Provider 同步"
        case .windowTitle: return "Provider 同步"
        case .loading: return "加载中..."
        case .currentStatus: return "当前状态"
        case .activeProvider: return "当前 Provider"
        case .configuredProviders: return "已配置的 Provider"
        case .sessionDistribution: return "会话分布"
        case .rolloutFiles: return "Rollout 文件"
        case .database: return "数据库"
        case .noSessionData: return "未找到会话数据。"
        case .sync: return "同步"
        case .target: return "目标："
        case .syncNow: return "立即同步"
        case .switchTo: return "切换到："
        case .switchAndSync: return "切换并同步"
        case .syncing: return "同步中..."
        case .backups: return "备份"
        case .noBackups: return "未找到备份。"
        case .restoreSelected: return "恢复所选备份"
        case .pruneOld: return "清理旧备份"
        case .loadFailedTitle: return "加载失败"
        case .syncCompleteTitle: return "同步完成"
        case .syncFailedTitle: return "同步失败"
        case .switchCompleteTitle: return "切换完成"
        case .switchFailedTitle: return "切换失败"
        case .restoreCompleteTitle: return "恢复完成"
        case .restoreFailedTitle: return "恢复失败"
        case .pruneCompleteTitle: return "清理完成"
        case .pruneFailedTitle: return "清理失败"
        case .sessions: return "会话"
        case .archived: return "归档"
        }
    }
}

@MainActor
public struct ProviderSyncView: View {
    public enum LayoutMode {
        case standaloneWindow
        case embeddedMainWindow
    }

    @ObservedObject private var viewModel: ProviderSyncViewModel
    private let preferredLanguages: [String]?
    private let layoutMode: LayoutMode

    public init(
        viewModel: ProviderSyncViewModel,
        preferredLanguages: [String]? = nil,
        layoutMode: LayoutMode = .standaloneWindow
    ) {
        self.preferredLanguages = preferredLanguages
        self.viewModel = viewModel
        self.layoutMode = layoutMode
    }

    var titleText: String {
        ProviderSyncStrings.text(.title, preferredLanguages: preferredLanguages)
    }

    var sectionTitles: [String] {
        [
            ProviderSyncStrings.text(.currentStatus, preferredLanguages: preferredLanguages),
            ProviderSyncStrings.text(.sessionDistribution, preferredLanguages: preferredLanguages),
            ProviderSyncStrings.text(.sync, preferredLanguages: preferredLanguages),
            ProviderSyncStrings.text(.backups, preferredLanguages: preferredLanguages),
        ]
    }

    var lastAlertTitle: String? {
        viewModel.lastMessage?.title
    }

    var lastAlertMessage: String? {
        viewModel.lastMessage?.message
    }

    var fixedFrameSize: CGSize? {
        switch layoutMode {
        case .standaloneWindow:
            return CGSize(width: 520, height: 640)
        case .embeddedMainWindow:
            return nil
        }
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(titleText)
                    .font(.title2.weight(.semibold))

                statusSection
                distributionSection
                syncSection
                backupsSection
            }
            .padding(20)
        }
        .modifier(ProviderSyncContainerFrameModifier(layoutMode: layoutMode))
        .overlay {
            if viewModel.isLoading {
                ProgressView(ProviderSyncStrings.text(.loading, preferredLanguages: preferredLanguages))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
            }
        }
        .alert(
            viewModel.lastMessage?.title ?? titleText,
            isPresented: Binding(
                get: { viewModel.lastMessage != nil },
                set: { if !$0 { viewModel.dismissMessage() } }
            ),
            presenting: viewModel.lastMessage
        ) { _ in
            Button(MenuBarStrings.text(.ok, preferredLanguages: preferredLanguages), role: .cancel) {
                viewModel.dismissMessage()
            }
        } message: { message in
            Text(message.message)
        }
        .task {
            await viewModel.loadStatus()
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        section(ProviderSyncStrings.text(.currentStatus, preferredLanguages: preferredLanguages)) {
            HStack {
                Text(ProviderSyncStrings.text(.activeProvider, preferredLanguages: preferredLanguages))
                    .font(.subheadline)
                Spacer()
                Text(viewModel.currentProvider)
                    .font(.body.weight(.semibold))
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(ProviderSyncStrings.text(.configuredProviders, preferredLanguages: preferredLanguages))
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    ForEach(viewModel.configuredProviders, id: \.self) { provider in
                        Text(provider)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(provider == viewModel.currentProvider
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.primary.opacity(0.06))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Distribution

    private var distributionSection: some View {
        section(ProviderSyncStrings.text(.sessionDistribution, preferredLanguages: preferredLanguages)) {
            if !viewModel.rolloutDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProviderSyncStrings.text(.rolloutFiles, preferredLanguages: preferredLanguages))
                        .font(.subheadline.weight(.medium))
                    distributionTable(viewModel.rolloutDistribution)
                }
            }

            if !viewModel.rolloutDistribution.isEmpty && !viewModel.sqliteDistribution.isEmpty {
                Divider()
            }

            if !viewModel.sqliteDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProviderSyncStrings.text(.database, preferredLanguages: preferredLanguages))
                        .font(.subheadline.weight(.medium))
                    distributionTable(viewModel.sqliteDistribution)
                }
            }

            if viewModel.rolloutDistribution.isEmpty && viewModel.sqliteDistribution.isEmpty {
                Text(ProviderSyncStrings.text(.noSessionData, preferredLanguages: preferredLanguages))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func distributionTable(_ items: [ProviderDistribution]) -> some View {
        VStack(spacing: 2) {
            ForEach(items, id: \.provider) { item in
                HStack {
                    Text(item.provider)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(ProviderSyncStrings.sessionsLabel(item.sessionCount, preferredLanguages: preferredLanguages))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                    Text(ProviderSyncStrings.archivedLabel(item.archivedCount, preferredLanguages: preferredLanguages))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        section(ProviderSyncStrings.text(.sync, preferredLanguages: preferredLanguages)) {
            HStack {
                Text(ProviderSyncStrings.text(.target, preferredLanguages: preferredLanguages))
                    .font(.subheadline)
                Picker("", selection: $viewModel.selectedSyncTarget) {
                    ForEach(allProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)

                Spacer()

                Button(ProviderSyncStrings.text(.syncNow, preferredLanguages: preferredLanguages)) {
                    Task { await viewModel.syncNow() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isSyncing)
            }

            Divider()

            HStack {
                Text(ProviderSyncStrings.text(.switchTo, preferredLanguages: preferredLanguages))
                    .font(.subheadline)
                Picker("", selection: $viewModel.selectedSwitchTarget) {
                    ForEach(viewModel.configuredProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)

                Spacer()

                Button(ProviderSyncStrings.text(.switchAndSync, preferredLanguages: preferredLanguages)) {
                    Task { await viewModel.switchAndSync() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isSyncing || viewModel.selectedSwitchTarget == viewModel.currentProvider)
            }

            if viewModel.isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(ProviderSyncStrings.text(.syncing, preferredLanguages: preferredLanguages))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Backups

    private var backupsSection: some View {
        section(ProviderSyncStrings.text(.backups, preferredLanguages: preferredLanguages)) {
            if viewModel.backups.isEmpty {
                Text(ProviderSyncStrings.text(.noBackups, preferredLanguages: preferredLanguages))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(
                    ProviderSyncStrings.backupsSummary(
                        viewModel.backups.count,
                        totalSize: formattedSize(viewModel.backupTotalSize),
                        preferredLanguages: preferredLanguages
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ForEach(viewModel.backups) { backup in
                        HStack {
                            Image(systemName: viewModel.selectedBackupID == backup.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.selectedBackupID == backup.id ? .accentColor : .secondary)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(formattedDate(backup.timestamp))
                                    .font(.caption.weight(.medium))
                                Text("\(backup.targetProvider) - \(formattedSize(backup.totalSize))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(viewModel.selectedBackupID == backup.id ? Color.accentColor.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectBackup(id: viewModel.selectedBackupID == backup.id ? nil : backup.id)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(ProviderSyncStrings.text(.restoreSelected, preferredLanguages: preferredLanguages)) {
                        Task { await viewModel.restoreSelectedBackup() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.selectedBackupID == nil || viewModel.isSyncing)

                    Button(ProviderSyncStrings.text(.pruneOld, preferredLanguages: preferredLanguages)) {
                        Task { await viewModel.pruneOldBackups() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.backups.count <= 5 || viewModel.isSyncing)
                }
            }
        }
    }

    // MARK: - Helpers

    private var allProviders: [String] {
        var providers = Set(viewModel.configuredProviders)
        for dist in viewModel.rolloutDistribution {
            providers.insert(dist.provider)
        }
        for dist in viewModel.sqliteDistribution {
            providers.insert(dist.provider)
        }
        providers.remove("(missing)")
        return Array(providers).sorted()
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } label: {
            Text(title)
                .font(.headline)
        }
    }

    private func formattedSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ProviderSyncContainerFrameModifier: ViewModifier {
    let layoutMode: ProviderSyncView.LayoutMode

    func body(content: Content) -> some View {
        switch layoutMode {
        case .standaloneWindow:
            content.frame(width: 520, height: 640)
        case .embeddedMainWindow:
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
