import SwiftUI
import AppKit

@MainActor
public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var presentedMessage: SettingsActionMessage?
    @State private var showAddProviderForm: Bool = false
    @State private var newProviderId: String = ""
    @State private var providerIdError: String = ""

    public init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
    }

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isProviderIdValid: Bool {
        viewModel.validateProviderId(newProviderId) && !viewModel.availableProviders.contains(newProviderId)
    }

    private var removableProviders: [String] {
        viewModel.availableProviders.filter { viewModel.canRemoveProvider($0) }
    }

    public var sectionTitles: [String] {
        ["General", "Privacy", "Usage", "Provider Management", "Advanced"]
    }

    public var generalControlLabels: [String] {
        ["Launch at Login", "Menu Bar Icon"] + MenuBarIconStyle.allCases.map { style in
            Self.label(for: style)
        }
    }

    public var menuBarIconPreviewResourceNames: [String] {
        MenuBarIconStyle.allCases.map { StatusItemController.resourceName(for: $0) }
    }

    public var privacyControlLabels: [String] {
        ["Show full account emails"] + SettingsDestructiveAction.allCases.map { action in
            Self.label(for: action)
        }
    }

    public var usageControlLabels: [String] {
        ["Enable Usage Refresh", "Usage Source Mode"] + CodexUsageSourceMode.allCases.map { mode in
            Self.label(for: mode)
        }
    }

    public var usageRiskTitle: String {
        "Usage Risk Notice"
    }

    public var usageRiskBody: String {
        "Automatic mode requests usage from the ChatGPT web backend first, then falls back to local Codex session logs. Local Only skips the remote request and reads only ~/.codex/sessions/YYYY/MM/DD/ rollout logs and cache."
    }

    public var advancedControlLabels: [String] {
        SettingsUtilityAction.allCases.map { action in
            Self.label(for: action)
        }
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                settingsSection("General") {
                    Toggle(
                        "Launch at Login",
                        isOn: Binding(
                            get: { viewModel.launchAtLogin },
                            set: { viewModel.setLaunchAtLogin($0) }
                        )
                    )

                    Divider()

                    Picker(
                        "Menu Bar Icon",
                        selection: Binding(
                            get: { viewModel.menuBarIconStyle },
                            set: { viewModel.setMenuBarIconStyle($0) }
                        )
                    ) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            Text(Self.label(for: style)).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    HStack(spacing: 12) {
                        ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                            menuBarIconPreview(for: style)
                        }
                    }
                }

                settingsSection("Privacy") {
                    Toggle(
                        "Show full account emails",
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

                settingsSection("Usage") {
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
                        "Enable Usage Refresh",
                        isOn: Binding(
                            get: { viewModel.usageRefreshEnabled },
                            set: { viewModel.setUsageRefreshEnabled($0) }
                        )
                    )

                    Picker(
                        "Usage Source Mode",
                        selection: Binding(
                            get: { viewModel.usageSourceMode },
                            set: { viewModel.setUsageSourceMode($0) }
                        )
                    ) {
                        ForEach(CodexUsageSourceMode.allCases, id: \.self) { mode in
                            Text(Self.label(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                settingsSection("Provider Management") {
                    Picker(
                        "Current Provider",
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

                    Toggle("Add Custom Provider", isOn: $showAddProviderForm)

                    if showAddProviderForm {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Provider ID (e.g., anthropic, custom-llm)", text: $newProviderId)
                                .textFieldStyle(.roundedBorder)

                            if !providerIdError.isEmpty {
                                Text(providerIdError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Button("Add Provider") {
                                addProviderAction()
                            }
                            .disabled(!isProviderIdValid)
                        }
                        .padding(.leading, 20)
                    }

                    if !removableProviders.isEmpty {
                        Divider()

                        ForEach(removableProviders, id: \.self) { provider in
                            Button("Remove \(provider)", role: .destructive) {
                                viewModel.requestRemoveProvider(provider)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                settingsSection("Advanced") {
                    utilityButton(for: .openCodexDirectory)
                    utilityButton(for: .openDiagnosticsLog)
                    utilityButton(for: .exportDiagnosticsSummary)
                }
            }
            .padding(20)
        }
        .frame(width: 440, height: 560)
        .confirmationDialog(
            viewModel.pendingConfirmation.map { Self.confirmationTitle(for: $0.action) } ?? "Confirm Action",
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
                Button(Self.label(for: action), role: .destructive) {
                    runAction {
                        try viewModel.confirmPendingAction()
                    }
                }

                Button("Cancel", role: .cancel) {
                    viewModel.cancelPendingAction()
                }
            }
        } message: {
            if let action = viewModel.pendingConfirmation?.action {
                Text(Self.confirmationMessage(for: action))
            }
        }
        .alert(
            presentedMessage?.title ?? "Settings",
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
            Button("OK", role: .cancel) {
                presentedMessage = nil
            }
        } message: { message in
            Text(message.message)
        }
        .onChange(of: viewModel.lastActionMessage?.id) { _ in
            presentedMessage = viewModel.lastActionMessage
        }
        .confirmationDialog(
            "Remove Provider?",
            isPresented: Binding(
                get: { viewModel.pendingProviderConfirmation != nil },
                set: { if !$0 { viewModel.cancelPendingProviderAction() } }
            ),
            titleVisibility: .visible
        ) {
            if let confirmation = viewModel.pendingProviderConfirmation {
                Button("Remove \(confirmation.providerId)", role: .destructive) {
                    runAction { try viewModel.confirmPendingProviderAction() }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelPendingProviderAction()
                }
            }
        } message: {
            if let confirmation = viewModel.pendingProviderConfirmation {
                Text("This will remove '\(confirmation.providerId)' from your configuration. Session history will not be deleted.")
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
        Button(Self.label(for: action), role: .destructive) {
            viewModel.requestDestructiveAction(action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func utilityButton(for action: SettingsUtilityAction) -> some View {
        Button(Self.label(for: action)) {
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
                title: "Action Failed",
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
                    .fill(Color(nsColor: .windowBackgroundColor))

                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.18))

                if let image = StatusItemController.statusItemImage(style: style) {
                    Image(nsImage: image)
                        .interpolation(.high)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 56, height: 36)

            Text(Self.label(for: style))
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private static func label(for mode: CodexUsageSourceMode) -> String {
        switch mode {
        case .automatic:
            return "Automatic"
        case .localOnly:
            return "Local Only"
        }
    }

    private static func label(for style: MenuBarIconStyle) -> String {
        switch style {
        case .highContrastLight:
            return "High Contrast"
        case .highContrastLightBold:
            return "High Contrast Bold"
        }
    }

    private static func label(for action: SettingsDestructiveAction) -> String {
        switch action {
        case .clearDiagnosticsLog:
            return "Clear Diagnostics Log"
        case .clearUsageCache:
            return "Clear Usage Cache"
        case .removeArchivedAccounts:
            return "Remove Archived Accounts"
        }
    }

    private static func label(for action: SettingsUtilityAction) -> String {
        switch action {
        case .openCodexDirectory:
            return "Open ~/.codex"
        case .openDiagnosticsLog:
            return "Open Diagnostics Folder"
        case .exportDiagnosticsSummary:
            return "Export Diagnostics Summary"
        }
    }

    private static func confirmationTitle(for action: SettingsDestructiveAction) -> String {
        switch action {
        case .clearDiagnosticsLog:
            return "Clear Diagnostics Log?"
        case .clearUsageCache:
            return "Clear Usage Cache?"
        case .removeArchivedAccounts:
            return "Remove Archived Accounts?"
        }
    }

    private static func confirmationMessage(for action: SettingsDestructiveAction) -> String {
        switch action {
        case .clearDiagnosticsLog:
            return "This removes the local diagnostics log files."
        case .clearUsageCache:
            return "This clears cached usage snapshots stored on this Mac."
        case .removeArchivedAccounts:
            return "This permanently removes archived account files from this Mac."
        }
    }
}
