import SwiftUI

enum StatusStrings {
    enum Key {
        case statusPageTitle
        case statusWindowTitle
        case operations
        case usage
        case accounts
        case diagnostics
        case paths
        case activeAccount
        case tier
        case source
        case archive
        case archivedAccounts
        case usageSource
        case usageUpdated
        case noUsageData
        case noArchivedAccounts
        case runtimeMode
        case currentHost
        case preferredHost
        case status
        case recentEvents
        case auth
        case accountsPath
        case diagnosticsDirectory
        case browserLoginLog
        case usageRefreshLog
        case noActiveAccount
        case noDiagnosticsYet
        case recentDiagnosticsActivity
        case fixture
        case currentAuth
        case backupImport
        case browserLogin
    }

    static func text(_ key: Key, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return englishText(for: key)
        case .simplifiedChinese:
            return simplifiedChineseText(for: key)
        }
    }

    static func accountInventoryStatusText(_ count: Int, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            guard count > 0 else {
                return text(.noArchivedAccounts, preferredLanguages: preferredLanguages)
            }
            let suffix = count == 1 ? "" : "s"
            return "\(count) archived account\(suffix)"
        case .simplifiedChinese:
            guard count > 0 else {
                return text(.noArchivedAccounts, preferredLanguages: preferredLanguages)
            }
            return "\(count) 个归档账号"
        }
    }

    static func diagnosticsStatus(hasEvents: Bool, preferredLanguages: [String]? = nil) -> String {
        hasEvents
            ? text(.recentDiagnosticsActivity, preferredLanguages: preferredLanguages)
            : text(.noDiagnosticsYet, preferredLanguages: preferredLanguages)
    }

    static func sourceLabel(for source: AccountSource, preferredLanguages: [String]? = nil) -> String {
        switch source {
        case .fixture:
            return text(.fixture, preferredLanguages: preferredLanguages)
        case .currentAuth:
            return text(.currentAuth, preferredLanguages: preferredLanguages)
        case .backupImport:
            return text(.backupImport, preferredLanguages: preferredLanguages)
        case .browserLogin:
            return text(.browserLogin, preferredLanguages: preferredLanguages)
        }
    }

    static func accountUsageBreakdown(
        fiveHourPercent: Int,
        weeklyPercent: Int,
        preferredLanguages: [String]? = nil
    ) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "5h \(fiveHourPercent)%  •  Weekly \(weeklyPercent)%"
        case .simplifiedChinese:
            return "5小时 \(fiveHourPercent)%  •  每周 \(weeklyPercent)%"
        }
    }

    private static func englishText(for key: Key) -> String {
        switch key {
        case .statusPageTitle: return "Status Page"
        case .statusWindowTitle: return "Codex Switch Status"
        case .operations: return "Operations"
        case .usage: return "Usage"
        case .accounts: return "Accounts"
        case .diagnostics: return "Diagnostics"
        case .paths: return "Paths"
        case .activeAccount: return "Active account"
        case .tier: return "Tier"
        case .source: return "Source"
        case .archive: return "Archive"
        case .archivedAccounts: return "Accounts"
        case .usageSource: return "Usage Source"
        case .usageUpdated: return "Usage Updated"
        case .noUsageData: return "No usage data"
        case .noArchivedAccounts: return "No archived accounts"
        case .runtimeMode: return "Runtime mode"
        case .currentHost: return "Current host"
        case .preferredHost: return "Preferred host"
        case .status: return "Status"
        case .recentEvents: return "Recent events"
        case .auth: return "Auth"
        case .accountsPath: return "Accounts"
        case .diagnosticsDirectory: return "Diagnostics Directory"
        case .browserLoginLog: return "Browser Login Log"
        case .usageRefreshLog: return "Usage Refresh Log"
        case .noActiveAccount: return "No active account"
        case .noDiagnosticsYet: return "No diagnostics yet"
        case .recentDiagnosticsActivity: return "Recent diagnostics activity"
        case .fixture: return "Fixture"
        case .currentAuth: return "Current Auth"
        case .backupImport: return "Backup Import"
        case .browserLogin: return "Browser Login"
        }
    }

    private static func simplifiedChineseText(for key: Key) -> String {
        switch key {
        case .statusPageTitle: return "状态页"
        case .statusWindowTitle: return "Codex Switch 状态"
        case .operations: return "运行状态"
        case .usage: return "用量"
        case .accounts: return "账号"
        case .diagnostics: return "诊断"
        case .paths: return "路径"
        case .activeAccount: return "激活账号"
        case .tier: return "套餐"
        case .source: return "来源"
        case .archive: return "归档文件"
        case .archivedAccounts: return "归档账号"
        case .usageSource: return "用量来源"
        case .usageUpdated: return "用量更新时间"
        case .noUsageData: return "暂无用量数据"
        case .noArchivedAccounts: return "暂无归档账号"
        case .runtimeMode: return "运行模式"
        case .currentHost: return "当前宿主"
        case .preferredHost: return "首选宿主"
        case .status: return "状态"
        case .recentEvents: return "最近事件"
        case .auth: return "认证文件"
        case .accountsPath: return "账号目录"
        case .diagnosticsDirectory: return "诊断目录"
        case .browserLoginLog: return "浏览器登录日志"
        case .usageRefreshLog: return "用量刷新日志"
        case .noActiveAccount: return "暂无激活账号"
        case .noDiagnosticsYet: return "暂无诊断信息"
        case .recentDiagnosticsActivity: return "最近有诊断活动"
        case .fixture: return "示例数据"
        case .currentAuth: return "当前 Auth"
        case .backupImport: return "备份导入"
        case .browserLogin: return "浏览器登录"
        }
    }
}

public struct StatusView: View {
    private let snapshot: StatusSnapshot
    private let preferredLanguages: [String]?

    public init() {
        self.snapshot = .preview
        self.preferredLanguages = nil
    }

    public init(snapshot: StatusSnapshot, preferredLanguages: [String]? = nil) {
        self.snapshot = snapshot
        self.preferredLanguages = preferredLanguages
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            operationsSection
            usageSection
            accountsSection
            diagnosticsSection
            pathsSection
        }
        .font(.subheadline)
    }

    private var operationsSection: some View {
        statusCard(title: StatusStrings.text(.operations, preferredLanguages: preferredLanguages), systemImage: "person.crop.circle") {
            infoRow(label: StatusStrings.text(.activeAccount, preferredLanguages: preferredLanguages), value: snapshot.activeAccountStatusText)
            if let activeAccount = snapshot.activeAccount {
                infoRow(label: StatusStrings.text(.tier, preferredLanguages: preferredLanguages), value: activeAccount.tierLabel)
                infoRow(label: StatusStrings.text(.source, preferredLanguages: preferredLanguages), value: activeAccount.sourceLabel)
                infoRow(label: StatusStrings.text(.archive, preferredLanguages: preferredLanguages), value: activeAccount.archiveFilename)
            }
            infoRow(label: StatusStrings.text(.archivedAccounts, preferredLanguages: preferredLanguages), value: snapshot.accountInventoryStatusText)
            infoRow(label: StatusStrings.text(.usageSource, preferredLanguages: preferredLanguages), value: snapshot.usageStatusText)
            infoRow(label: StatusStrings.text(.usageUpdated, preferredLanguages: preferredLanguages), value: snapshot.updatedText)
        }
    }

    private var usageSection: some View {
        statusCard(title: StatusStrings.text(.usage, preferredLanguages: preferredLanguages), systemImage: "gauge.with.dots.needle.67percent") {
            if snapshot.summaries.isEmpty {
                Text(StatusStrings.text(.noUsageData, preferredLanguages: preferredLanguages))
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.summaries) { summary in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(summary.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(summary.percentUsed)%")
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: Double(summary.percentUsed), total: 100)
                        Text(summary.resetText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var accountsSection: some View {
        statusCard(title: StatusStrings.text(.accounts, preferredLanguages: preferredLanguages), systemImage: "person.2") {
            if snapshot.accountRows.isEmpty {
                Text(StatusStrings.text(.noArchivedAccounts, preferredLanguages: preferredLanguages))
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.accountRows) { account in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(account.emailMask)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(account.tierLabel)
                                .foregroundColor(.secondary)
                        }
                        Text(
                            StatusStrings.accountUsageBreakdown(
                                fiveHourPercent: account.fiveHourPercent,
                                weeklyPercent: account.weeklyPercent,
                                preferredLanguages: preferredLanguages
                            )
                        )
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        statusCard(title: StatusStrings.text(.diagnostics, preferredLanguages: preferredLanguages), systemImage: "waveform.path.ecg") {
            infoRow(label: StatusStrings.text(.runtimeMode, preferredLanguages: preferredLanguages), value: snapshot.runtimeModeLabel)
            infoRow(label: StatusStrings.text(.currentHost, preferredLanguages: preferredLanguages), value: snapshot.currentHostLabel)
            infoRow(label: StatusStrings.text(.preferredHost, preferredLanguages: preferredLanguages), value: snapshot.preferredHostLabel)
            infoRow(label: StatusStrings.text(.status, preferredLanguages: preferredLanguages), value: snapshot.diagnostics.statusText)

            if !snapshot.diagnostics.recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(StatusStrings.text(.recentEvents, preferredLanguages: preferredLanguages))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(snapshot.diagnostics.recentEvents, id: \.self) { event in
                        Text(event)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var pathsSection: some View {
        statusCard(title: StatusStrings.text(.paths, preferredLanguages: preferredLanguages), systemImage: "folder") {
            pathRow(label: StatusStrings.text(.auth, preferredLanguages: preferredLanguages), value: snapshot.paths.authFilePath)
            pathRow(label: StatusStrings.text(.accountsPath, preferredLanguages: preferredLanguages), value: snapshot.paths.accountsDirectoryPath)
            pathRow(label: StatusStrings.text(.diagnosticsDirectory, preferredLanguages: preferredLanguages), value: snapshot.paths.diagnosticsDirectoryPath)
            pathRow(label: StatusStrings.text(.browserLoginLog, preferredLanguages: preferredLanguages), value: snapshot.paths.browserLoginLogPath)
            pathRow(label: StatusStrings.text(.usageRefreshLog, preferredLanguages: preferredLanguages), value: snapshot.paths.usageRefreshLogPath)
        }
    }

    private func statusCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func pathRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
