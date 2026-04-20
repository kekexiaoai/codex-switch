import SwiftUI
import AppKit

enum SettingsStrings {
    enum Key {
        case settingsTitle
        case settingsWindowTitle
        case general
        case privacy
        case usage
        case providerManagement
        case advanced
        case enableAccountReorderDiagnostics
        case launchAtLogin
        case menuBarIcon
        case showFullAccountEmails
        case enableUsageRefresh
        case usageSourceMode
        case usageRiskTitle
        case usageRiskBody
        case currentProvider
        case addCustomProvider
        case providerIDPlaceholder
        case addProvider
        case confirmAction
        case cancel
        case ok
        case removeProviderTitle
        case actionFailed
        case automatic
        case localOnly
        case highContrast
        case highContrastBold
        case clearDiagnosticsLog
        case clearUsageCache
        case removeArchivedAccounts
        case openCodexDirectory
        case openDiagnosticsFolder
        case exportDiagnosticsSummary
        case clearDiagnosticsLogConfirmationTitle
        case clearUsageCacheConfirmationTitle
        case removeArchivedAccountsConfirmationTitle
        case clearDiagnosticsLogConfirmationMessage
        case clearUsageCacheConfirmationMessage
        case removeArchivedAccountsConfirmationMessage
        case diagnosticsClearedTitle
        case diagnosticsClearedMessage
        case usageCacheClearedTitle
        case usageCacheClearedMessage
        case accountsRemovedTitle
        case accountsRemovedMessage
        case codexDirectoryOpenedTitle
        case codexDirectoryOpenedMessage
        case diagnosticsFolderOpenedTitle
        case diagnosticsFolderOpenedMessage
        case diagnosticsExportedTitle
        case diagnosticsExportedMessage
        case providerRemovedTitle
        case providerAddedTitle
        case providerSwitchFailedTitle
        case launchAtLoginUnchangedTitle
        case resourceOpenFailed
        case exportFailed
        case unsupportedLaunchAtLogin
        case invalidProviderID
        case diagnosticsSummaryTitle
        case diagnosticsSummaryGenerated
        case diagnosticsSummaryCodexDirectory
        case diagnosticsSummaryDiagnosticsDirectory
        case diagnosticsSummaryRecentEvents
        case diagnosticsSummaryNoEvents
    }

    static func text(_ key: Key, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return englishText(for: key)
        case .simplifiedChinese:
            return simplifiedChineseText(for: key)
        }
    }

    static func providerAddedMessage(_ providerID: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Added provider '\(providerID)' to configuration."
        case .simplifiedChinese:
            return "已将 Provider '\(providerID)' 添加到配置中。"
        }
    }

    static func providerRemovedMessage(_ providerID: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Removed provider '\(providerID)' from configuration."
        case .simplifiedChinese:
            return "已从配置中移除 Provider '\(providerID)'。"
        }
    }

    static func providerRemovedNoConfigMessage(_ providerID: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Removed provider '\(providerID)'."
        case .simplifiedChinese:
            return "已移除 Provider '\(providerID)'。"
        }
    }

    static func duplicateProviderMessage(_ providerID: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Provider '\(providerID)' already exists"
        case .simplifiedChinese:
            return "Provider '\(providerID)' 已存在"
        }
    }

    static func removeProviderButtonTitle(_ providerID: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "Remove \(providerID)"
        case .simplifiedChinese:
            return "移除 \(providerID)"
        }
    }

    static func removeProviderConfirmationMessage(_ providerID: String, preferredLanguages: [String]? = nil) -> String {
        switch MenuBarStrings.language(preferredLanguages: preferredLanguages) {
        case .english:
            return "This will remove '\(providerID)' from your configuration. Session history will not be deleted."
        case .simplifiedChinese:
            return "这会从你的配置中移除 '\(providerID)'。会话历史不会被删除。"
        }
    }

    static func diagnosticsSummaryBody(
        currentTime: String,
        codexDirectory: String,
        diagnosticsDirectory: String,
        events: [String],
        preferredLanguages: [String]? = nil
    ) -> String {
        let title = text(.diagnosticsSummaryTitle, preferredLanguages: preferredLanguages)
        let generated = text(.diagnosticsSummaryGenerated, preferredLanguages: preferredLanguages)
        let codexDirectoryTitle = text(.diagnosticsSummaryCodexDirectory, preferredLanguages: preferredLanguages)
        let diagnosticsDirectoryTitle = text(.diagnosticsSummaryDiagnosticsDirectory, preferredLanguages: preferredLanguages)
        let recentEventsTitle = text(.diagnosticsSummaryRecentEvents, preferredLanguages: preferredLanguages)
        let recentEventsBody = events.isEmpty
            ? "- " + text(.diagnosticsSummaryNoEvents, preferredLanguages: preferredLanguages)
            : events.map { "- \($0)" }.joined(separator: "\n")

        return """
        \(title)
        \(generated): \(currentTime)
        \(codexDirectoryTitle): \(codexDirectory)
        \(diagnosticsDirectoryTitle): \(diagnosticsDirectory)

        \(recentEventsTitle):
        \(recentEventsBody)
        """
    }

    private static func englishText(for key: Key) -> String {
        switch key {
        case .settingsTitle: return "Settings"
        case .settingsWindowTitle: return "Codex Switch Settings"
        case .general: return "General"
        case .privacy: return "Privacy"
        case .usage: return "Usage"
        case .providerManagement: return "Provider Management"
        case .advanced: return "Advanced"
        case .enableAccountReorderDiagnostics: return "Enable Account Reorder Debug Log"
        case .launchAtLogin: return "Launch at Login"
        case .menuBarIcon: return "Menu Bar Icon"
        case .showFullAccountEmails: return "Show full account emails"
        case .enableUsageRefresh: return "Enable Usage Refresh"
        case .usageSourceMode: return "Usage Source Mode"
        case .usageRiskTitle: return "Usage Risk Notice"
        case .usageRiskBody: return "Automatic mode requests usage from the ChatGPT web backend first, then falls back to local Codex session logs. Local Only skips the remote request and reads only ~/.codex/sessions/YYYY/MM/DD/ rollout logs and cache."
        case .currentProvider: return "Current Provider"
        case .addCustomProvider: return "Add Custom Provider"
        case .providerIDPlaceholder: return "Provider ID (e.g., anthropic, custom-llm)"
        case .addProvider: return "Add Provider"
        case .confirmAction: return "Confirm Action"
        case .cancel: return "Cancel"
        case .ok: return "OK"
        case .removeProviderTitle: return "Remove Provider?"
        case .actionFailed: return "Action Failed"
        case .automatic: return "Automatic"
        case .localOnly: return "Local Only"
        case .highContrast: return "High Contrast"
        case .highContrastBold: return "High Contrast Bold"
        case .clearDiagnosticsLog: return "Clear Diagnostics Log"
        case .clearUsageCache: return "Clear Usage Cache"
        case .removeArchivedAccounts: return "Remove Archived Accounts"
        case .openCodexDirectory: return "Open ~/.codex"
        case .openDiagnosticsFolder: return "Open Diagnostics Folder"
        case .exportDiagnosticsSummary: return "Export Diagnostics Summary"
        case .clearDiagnosticsLogConfirmationTitle: return "Clear Diagnostics Log?"
        case .clearUsageCacheConfirmationTitle: return "Clear Usage Cache?"
        case .removeArchivedAccountsConfirmationTitle: return "Remove Archived Accounts?"
        case .clearDiagnosticsLogConfirmationMessage: return "This removes the local diagnostics log files."
        case .clearUsageCacheConfirmationMessage: return "This clears cached usage snapshots stored on this Mac."
        case .removeArchivedAccountsConfirmationMessage: return "This permanently removes archived account files from this Mac."
        case .diagnosticsClearedTitle: return "Diagnostics Cleared"
        case .diagnosticsClearedMessage: return "Removed local diagnostics logs."
        case .usageCacheClearedTitle: return "Usage Cache Cleared"
        case .usageCacheClearedMessage: return "Removed cached usage data."
        case .accountsRemovedTitle: return "Accounts Removed"
        case .accountsRemovedMessage: return "Removed archived accounts."
        case .codexDirectoryOpenedTitle: return "Codex Directory Opened"
        case .codexDirectoryOpenedMessage: return "Opened ~/.codex."
        case .diagnosticsFolderOpenedTitle: return "Diagnostics Folder Opened"
        case .diagnosticsFolderOpenedMessage: return "Opened the local diagnostics folder."
        case .diagnosticsExportedTitle: return "Diagnostics Exported"
        case .diagnosticsExportedMessage: return "Exported a sanitized diagnostics summary."
        case .providerRemovedTitle: return "Provider Removed"
        case .providerAddedTitle: return "Provider Added"
        case .providerSwitchFailedTitle: return "Provider Switch Failed"
        case .launchAtLoginUnchangedTitle: return "Launch at Login Unchanged"
        case .resourceOpenFailed: return "The requested resource could not be opened."
        case .exportFailed: return "The diagnostics summary could not be exported."
        case .unsupportedLaunchAtLogin: return "Launch at Login requires macOS 13 or newer."
        case .invalidProviderID: return "Provider ID must contain only letters, numbers, dots, hyphens, and underscores"
        case .diagnosticsSummaryTitle: return "Codex Switch Diagnostics Summary"
        case .diagnosticsSummaryGenerated: return "Generated"
        case .diagnosticsSummaryCodexDirectory: return "Codex Directory"
        case .diagnosticsSummaryDiagnosticsDirectory: return "Diagnostics Directory"
        case .diagnosticsSummaryRecentEvents: return "Recent Safe Events"
        case .diagnosticsSummaryNoEvents: return "No diagnostics events captured."
        }
    }

    private static func simplifiedChineseText(for key: Key) -> String {
        switch key {
        case .settingsTitle: return "设置"
        case .settingsWindowTitle: return "Codex Switch 设置"
        case .general: return "通用"
        case .privacy: return "隐私"
        case .usage: return "用量"
        case .providerManagement: return "Provider 管理"
        case .advanced: return "高级"
        case .enableAccountReorderDiagnostics: return "启用账号排序调试日志"
        case .launchAtLogin: return "开机启动"
        case .menuBarIcon: return "菜单栏图标"
        case .showFullAccountEmails: return "显示完整账号邮箱"
        case .enableUsageRefresh: return "启用用量刷新"
        case .usageSourceMode: return "用量来源模式"
        case .usageRiskTitle: return "用量风险提示"
        case .usageRiskBody: return "自动模式会优先从 ChatGPT Web 后端请求用量信息，失败后再回退到本地 Codex 会话日志。仅本地模式会跳过远端请求，只读取 ~/.codex/sessions/YYYY/MM/DD/ 下的 rollout 日志与缓存。"
        case .currentProvider: return "当前 Provider"
        case .addCustomProvider: return "添加自定义 Provider"
        case .providerIDPlaceholder: return "Provider ID（例如 anthropic、custom-llm）"
        case .addProvider: return "添加 Provider"
        case .confirmAction: return "确认操作"
        case .cancel: return "取消"
        case .ok: return "确定"
        case .removeProviderTitle: return "移除 Provider？"
        case .actionFailed: return "操作失败"
        case .automatic: return "自动"
        case .localOnly: return "仅本地"
        case .highContrast: return "高对比度"
        case .highContrastBold: return "高对比度粗体"
        case .clearDiagnosticsLog: return "清理诊断日志"
        case .clearUsageCache: return "清理用量缓存"
        case .removeArchivedAccounts: return "移除归档账号"
        case .openCodexDirectory: return "打开 ~/.codex"
        case .openDiagnosticsFolder: return "打开诊断目录"
        case .exportDiagnosticsSummary: return "导出诊断摘要"
        case .clearDiagnosticsLogConfirmationTitle: return "清理诊断日志？"
        case .clearUsageCacheConfirmationTitle: return "清理用量缓存？"
        case .removeArchivedAccountsConfirmationTitle: return "移除归档账号？"
        case .clearDiagnosticsLogConfirmationMessage: return "这会删除本机上的本地诊断日志文件。"
        case .clearUsageCacheConfirmationMessage: return "这会清除保存在这台 Mac 上的用量缓存快照。"
        case .removeArchivedAccountsConfirmationMessage: return "这会永久删除保存在这台 Mac 上的归档账号文件。"
        case .diagnosticsClearedTitle: return "诊断日志已清理"
        case .diagnosticsClearedMessage: return "已移除本地诊断日志。"
        case .usageCacheClearedTitle: return "用量缓存已清理"
        case .usageCacheClearedMessage: return "已移除缓存的用量数据。"
        case .accountsRemovedTitle: return "归档账号已移除"
        case .accountsRemovedMessage: return "已移除归档账号。"
        case .codexDirectoryOpenedTitle: return "Codex 目录已打开"
        case .codexDirectoryOpenedMessage: return "已打开 ~/.codex。"
        case .diagnosticsFolderOpenedTitle: return "诊断目录已打开"
        case .diagnosticsFolderOpenedMessage: return "已打开本地诊断目录。"
        case .diagnosticsExportedTitle: return "诊断摘要已导出"
        case .diagnosticsExportedMessage: return "已导出脱敏后的诊断摘要。"
        case .providerRemovedTitle: return "Provider 已移除"
        case .providerAddedTitle: return "Provider 已添加"
        case .providerSwitchFailedTitle: return "Provider 切换失败"
        case .launchAtLoginUnchangedTitle: return "开机启动未变更"
        case .resourceOpenFailed: return "无法打开请求的资源。"
        case .exportFailed: return "无法导出诊断摘要。"
        case .unsupportedLaunchAtLogin: return "开机启动需要 macOS 13 或更高版本。"
        case .invalidProviderID: return "Provider ID 只能包含字母、数字、点、连字符和下划线"
        case .diagnosticsSummaryTitle: return "Codex Switch 诊断摘要"
        case .diagnosticsSummaryGenerated: return "生成时间"
        case .diagnosticsSummaryCodexDirectory: return "Codex 目录"
        case .diagnosticsSummaryDiagnosticsDirectory: return "诊断目录"
        case .diagnosticsSummaryRecentEvents: return "最近安全事件"
        case .diagnosticsSummaryNoEvents: return "尚未记录到诊断事件。"
        }
    }
}

@MainActor
public struct SettingsView: View {
    public enum LayoutMode {
        case standaloneWindow
        case embeddedMainWindow
    }

    @StateObject private var viewModel: SettingsViewModel
    private let preferredLanguages: [String]?
    private let layoutMode: LayoutMode
    @State private var presentedMessage: SettingsActionMessage?
    @State private var showAddProviderForm: Bool = false
    @State private var newProviderId: String = ""
    @State private var providerIdError: String = ""

    public init(preferredLanguages: [String]? = nil, layoutMode: LayoutMode = .standaloneWindow) {
        self.preferredLanguages = preferredLanguages
        self.layoutMode = layoutMode
        _viewModel = StateObject(wrappedValue: SettingsViewModel(preferredLanguages: preferredLanguages))
    }

    public init(viewModel: SettingsViewModel, preferredLanguages: [String]? = nil, layoutMode: LayoutMode = .standaloneWindow) {
        self.preferredLanguages = preferredLanguages
        self.layoutMode = layoutMode
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var fixedFrameSize: CGSize? {
        switch layoutMode {
        case .standaloneWindow:
            return CGSize(width: 440, height: 560)
        case .embeddedMainWindow:
            return nil
        }
    }

    private var isProviderIdValid: Bool {
        viewModel.validateProviderId(newProviderId) && !viewModel.availableProviders.contains(newProviderId)
    }

    private var removableProviders: [String] {
        viewModel.availableProviders.filter { viewModel.canRemoveProvider($0) }
    }

    public var sectionTitles: [String] {
        [
            SettingsStrings.text(.general, preferredLanguages: preferredLanguages),
            SettingsStrings.text(.privacy, preferredLanguages: preferredLanguages),
            SettingsStrings.text(.usage, preferredLanguages: preferredLanguages),
            SettingsStrings.text(.providerManagement, preferredLanguages: preferredLanguages),
            SettingsStrings.text(.advanced, preferredLanguages: preferredLanguages),
        ]
    }

    public var generalControlLabels: [String] {
        [
            SettingsStrings.text(.launchAtLogin, preferredLanguages: preferredLanguages),
            SettingsStrings.text(.menuBarIcon, preferredLanguages: preferredLanguages),
        ] + MenuBarIconStyle.allCases.map { style in
            label(for: style)
        }
    }

    public var menuBarIconPreviewResourceNames: [String] {
        MenuBarIconStyle.allCases.map { StatusItemController.resourceName(for: $0) }
    }

    public var menuBarIconPreviewUsesDarkBackground: Bool {
        true
    }

    public var privacyControlLabels: [String] {
        [SettingsStrings.text(.showFullAccountEmails, preferredLanguages: preferredLanguages)] + SettingsDestructiveAction.allCases.map { action in
            label(for: action)
        }
    }

    public var usageControlLabels: [String] {
        [
            SettingsStrings.text(.enableUsageRefresh, preferredLanguages: preferredLanguages),
            SettingsStrings.text(.usageSourceMode, preferredLanguages: preferredLanguages),
        ] + CodexUsageSourceMode.allCases.map { mode in
            label(for: mode)
        }
    }

    public var usageRiskTitle: String {
        SettingsStrings.text(.usageRiskTitle, preferredLanguages: preferredLanguages)
    }

    public var usageRiskBody: String {
        SettingsStrings.text(.usageRiskBody, preferredLanguages: preferredLanguages)
    }

    public var advancedControlLabels: [String] {
        [SettingsStrings.text(.enableAccountReorderDiagnostics, preferredLanguages: preferredLanguages)] + SettingsUtilityAction.allCases.map { action in
            label(for: action)
        }
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(SettingsStrings.text(.settingsTitle, preferredLanguages: preferredLanguages))
                    .font(.title2.weight(.semibold))

                settingsSection(SettingsStrings.text(.general, preferredLanguages: preferredLanguages)) {
                    Toggle(
                        SettingsStrings.text(.launchAtLogin, preferredLanguages: preferredLanguages),
                        isOn: Binding(
                            get: { viewModel.launchAtLogin },
                            set: { viewModel.setLaunchAtLogin($0) }
                        )
                    )

                    Divider()

                    Picker(
                        SettingsStrings.text(.menuBarIcon, preferredLanguages: preferredLanguages),
                        selection: Binding(
                            get: { viewModel.menuBarIconStyle },
                            set: { viewModel.setMenuBarIconStyle($0) }
                        )
                    ) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            Text(label(for: style)).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    HStack(spacing: 12) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            menuBarIconPreview(for: style)
                        }
                    }
                }

                settingsSection(SettingsStrings.text(.privacy, preferredLanguages: preferredLanguages)) {
                    Toggle(
                        SettingsStrings.text(.showFullAccountEmails, preferredLanguages: preferredLanguages),
                        isOn: Binding(
                            get: { viewModel.showEmails },
                            set: { viewModel.setShowEmails($0) }
                        )
                    )

                    Divider()

                    destructiveButton(for: .clearDiagnosticsLog)
                    destructiveButton(for: .clearUsageCache)
                    destructiveButton(for: .removeArchivedAccounts)
                }

                settingsSection(SettingsStrings.text(.usage, preferredLanguages: preferredLanguages)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(usageRiskTitle, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)

                        Text(usageRiskBody)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Toggle(
                        SettingsStrings.text(.enableUsageRefresh, preferredLanguages: preferredLanguages),
                        isOn: Binding(
                            get: { viewModel.usageRefreshEnabled },
                            set: { viewModel.setUsageRefreshEnabled($0) }
                        )
                    )

                    Picker(
                        SettingsStrings.text(.usageSourceMode, preferredLanguages: preferredLanguages),
                        selection: Binding(
                            get: { viewModel.usageSourceMode },
                            set: { viewModel.setUsageSourceMode($0) }
                        )
                    ) {
                        ForEach(CodexUsageSourceMode.allCases, id: \.self) { mode in
                            Text(label(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                settingsSection(SettingsStrings.text(.providerManagement, preferredLanguages: preferredLanguages)) {
                    Picker(
                        SettingsStrings.text(.currentProvider, preferredLanguages: preferredLanguages),
                        selection: Binding(
                            get: { viewModel.currentProvider },
                            set: { viewModel.setCurrentProvider($0) }
                        )
                    ) {
                        ForEach(viewModel.availableProviders, id: \.self) { provider in
                            Text(provider).tag(provider)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Divider()

                    Toggle(SettingsStrings.text(.addCustomProvider, preferredLanguages: preferredLanguages), isOn: $showAddProviderForm)

                    if showAddProviderForm {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(SettingsStrings.text(.providerIDPlaceholder, preferredLanguages: preferredLanguages), text: $newProviderId)
                                .textFieldStyle(.roundedBorder)

                            if !providerIdError.isEmpty {
                                Text(providerIdError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Button(SettingsStrings.text(.addProvider, preferredLanguages: preferredLanguages)) {
                                addProviderAction()
                            }
                            .disabled(!isProviderIdValid)
                        }
                        .padding(.leading, 20)
                    }

                    if !removableProviders.isEmpty {
                        Divider()

                        ForEach(removableProviders, id: \.self) { provider in
                            Button(SettingsStrings.removeProviderButtonTitle(provider, preferredLanguages: preferredLanguages), role: .destructive) {
                                viewModel.requestRemoveProvider(provider)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                settingsSection(SettingsStrings.text(.advanced, preferredLanguages: preferredLanguages)) {
                    Toggle(
                        SettingsStrings.text(.enableAccountReorderDiagnostics, preferredLanguages: preferredLanguages),
                        isOn: Binding(
                            get: { viewModel.accountReorderDiagnosticsEnabled },
                            set: { viewModel.setAccountReorderDiagnosticsEnabled($0) }
                        )
                    )

                    Divider()

                    utilityButton(for: .openCodexDirectory)
                    utilityButton(for: .openDiagnosticsLog)
                    utilityButton(for: .exportDiagnosticsSummary)
                }
            }
            .padding(20)
        }
        .modifier(SettingsContainerFrameModifier(layoutMode: layoutMode))
        .confirmationDialog(
            viewModel.pendingConfirmation.map { confirmationTitle(for: $0.action) }
                ?? SettingsStrings.text(.confirmAction, preferredLanguages: preferredLanguages),
            isPresented: Binding(
                get: { viewModel.pendingConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.cancelPendingAction()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let action = viewModel.pendingConfirmation?.action {
                Button(label(for: action), role: .destructive) {
                    runAction {
                        try viewModel.confirmPendingAction()
                    }
                }

                Button(SettingsStrings.text(.cancel, preferredLanguages: preferredLanguages), role: .cancel) {
                    viewModel.cancelPendingAction()
                }
            }
        } message: {
            if let action = viewModel.pendingConfirmation?.action {
                Text(confirmationMessage(for: action))
            }
        }
        .alert(
            presentedMessage?.title ?? SettingsStrings.text(.settingsTitle, preferredLanguages: preferredLanguages),
            isPresented: Binding(
                get: { presentedMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        presentedMessage = nil
                    }
                }
            ),
            presenting: presentedMessage
        ) { _ in
            Button(SettingsStrings.text(.ok, preferredLanguages: preferredLanguages), role: .cancel) {
                presentedMessage = nil
            }
        } message: { message in
            Text(message.message)
        }
        .onChange(of: viewModel.lastActionMessage?.id) { _ in
            presentedMessage = viewModel.lastActionMessage
        }
        .confirmationDialog(
            SettingsStrings.text(.removeProviderTitle, preferredLanguages: preferredLanguages),
            isPresented: Binding(
                get: { viewModel.pendingProviderConfirmation != nil },
                set: { if !$0 { viewModel.cancelPendingProviderAction() } }
            ),
            titleVisibility: .visible
        ) {
            if let confirmation = viewModel.pendingProviderConfirmation {
                Button(
                    SettingsStrings.removeProviderButtonTitle(confirmation.providerId, preferredLanguages: preferredLanguages),
                    role: .destructive
                ) {
                    runAction { try viewModel.confirmPendingProviderAction() }
                }
                Button(SettingsStrings.text(.cancel, preferredLanguages: preferredLanguages), role: .cancel) {
                    viewModel.cancelPendingProviderAction()
                }
            }
        } message: {
            if let confirmation = viewModel.pendingProviderConfirmation {
                Text(
                    SettingsStrings.removeProviderConfirmationMessage(
                        confirmation.providerId,
                        preferredLanguages: preferredLanguages
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func destructiveButton(for action: SettingsDestructiveAction) -> some View {
        Button(label(for: action), role: .destructive) {
            viewModel.requestDestructiveAction(action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func utilityButton(for action: SettingsUtilityAction) -> some View {
        Button(label(for: action)) {
            runAction {
                try viewModel.performUtilityAction(action)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runAction(_ operation: () throws -> Void) {
        do {
            try operation()
            presentedMessage = viewModel.lastActionMessage
        } catch {
            presentedMessage = SettingsActionMessage(
                title: SettingsStrings.text(.actionFailed, preferredLanguages: preferredLanguages),
                message: error.localizedDescription
            )
        }
    }

    private func addProviderAction() {
        do {
            try viewModel.addProvider(id: newProviderId)
            newProviderId = ""
            showAddProviderForm = false
            providerIdError = ""
            presentedMessage = viewModel.lastActionMessage
        } catch {
            providerIdError = error.localizedDescription
        }
    }

    private func menuBarIconPreview(for style: MenuBarIconStyle) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: NSColor(calibratedWhite: 0.16, alpha: 1)))

                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.14))

                if let image = StatusItemController.statusItemImage(style: style) {
                    Image(nsImage: image)
                        .interpolation(.high)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 56, height: 36)

            Text(label(for: style))
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func label(for mode: CodexUsageSourceMode) -> String {
        switch mode {
        case .automatic:
            return SettingsStrings.text(.automatic, preferredLanguages: preferredLanguages)
        case .localOnly:
            return SettingsStrings.text(.localOnly, preferredLanguages: preferredLanguages)
        }
    }

    private func label(for style: MenuBarIconStyle) -> String {
        switch style {
        case .highContrastLight:
            return SettingsStrings.text(.highContrast, preferredLanguages: preferredLanguages)
        case .highContrastLightBold:
            return SettingsStrings.text(.highContrastBold, preferredLanguages: preferredLanguages)
        }
    }

    private func label(for action: SettingsDestructiveAction) -> String {
        switch action {
        case .clearDiagnosticsLog:
            return SettingsStrings.text(.clearDiagnosticsLog, preferredLanguages: preferredLanguages)
        case .clearUsageCache:
            return SettingsStrings.text(.clearUsageCache, preferredLanguages: preferredLanguages)
        case .removeArchivedAccounts:
            return SettingsStrings.text(.removeArchivedAccounts, preferredLanguages: preferredLanguages)
        }
    }

    private func label(for action: SettingsUtilityAction) -> String {
        switch action {
        case .openCodexDirectory:
            return SettingsStrings.text(.openCodexDirectory, preferredLanguages: preferredLanguages)
        case .openDiagnosticsLog:
            return SettingsStrings.text(.openDiagnosticsFolder, preferredLanguages: preferredLanguages)
        case .exportDiagnosticsSummary:
            return SettingsStrings.text(.exportDiagnosticsSummary, preferredLanguages: preferredLanguages)
        }
    }

    private func confirmationTitle(for action: SettingsDestructiveAction) -> String {
        switch action {
        case .clearDiagnosticsLog:
            return SettingsStrings.text(.clearDiagnosticsLogConfirmationTitle, preferredLanguages: preferredLanguages)
        case .clearUsageCache:
            return SettingsStrings.text(.clearUsageCacheConfirmationTitle, preferredLanguages: preferredLanguages)
        case .removeArchivedAccounts:
            return SettingsStrings.text(.removeArchivedAccountsConfirmationTitle, preferredLanguages: preferredLanguages)
        }
    }

    private func confirmationMessage(for action: SettingsDestructiveAction) -> String {
        switch action {
        case .clearDiagnosticsLog:
            return SettingsStrings.text(.clearDiagnosticsLogConfirmationMessage, preferredLanguages: preferredLanguages)
        case .clearUsageCache:
            return SettingsStrings.text(.clearUsageCacheConfirmationMessage, preferredLanguages: preferredLanguages)
        case .removeArchivedAccounts:
            return SettingsStrings.text(.removeArchivedAccountsConfirmationMessage, preferredLanguages: preferredLanguages)
        }
    }
}

private struct SettingsContainerFrameModifier: ViewModifier {
    let layoutMode: SettingsView.LayoutMode

    func body(content: Content) -> some View {
        switch layoutMode {
        case .standaloneWindow:
            content.frame(width: 440, height: 560)
        case .embeddedMainWindow:
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
