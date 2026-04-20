import SwiftUI

public struct MenuBarPanelView: View {
    static let basePanelWidth: CGFloat = 360
    static let quickSwitchOverlayWidth: CGFloat = 320
    static let quickSwitchHorizontalSpacing: CGFloat = 12
    @ObservedObject private var viewModel: MenuBarViewModel
    private let onQuickSwitchAnchorFrameChange: ((CGRect) -> Void)?
    private let onQuickSwitchHoverChange: ((Bool) -> Void)?
    @State private var isShowingAddAccountOptions = false

    static let quickSwitchCoordinateSpaceName = "MenuBarPanelQuickSwitchCoordinateSpace"

    public init(
        viewModel: MenuBarViewModel,
        onQuickSwitchAnchorFrameChange: ((CGRect) -> Void)? = nil,
        onQuickSwitchHoverChange: ((Bool) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onQuickSwitchAnchorFrameChange = onQuickSwitchAnchorFrameChange
        self.onQuickSwitchHoverChange = onQuickSwitchHoverChange
    }

    public static func contentWidth(isShowingQuickSwitchOverlay: Bool) -> CGFloat {
        return basePanelWidth
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            panelContent
        }
        .frame(width: Self.basePanelWidth, alignment: .leading)
        .coordinateSpace(name: Self.quickSwitchCoordinateSpaceName)
        .overlay(alignment: .bottom) {
            if let removalFeedback = viewModel.removalFeedback {
                feedbackBanner(removalFeedback)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .onPreferenceChange(QuickSwitchAnchorFramePreferenceKey.self) { frame in
            onQuickSwitchAnchorFrameChange?(frame)
        }
        .alert(item: Binding(
            get: { viewModel.alertMessage },
            set: { _ in viewModel.dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(MenuBarStrings.text(.ok))) {
                    viewModel.dismissAlert()
                }
            )
        }
        .confirmationDialog(
            viewModel.pendingAccountActivationConfirmation?.title ?? MenuBarStrings.text(.confirmActivation),
            isPresented: Binding(
                get: { viewModel.pendingAccountActivationConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.cancelPendingAccountActivation()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if viewModel.pendingAccountActivationConfirmation != nil {
                Button(MenuBarStrings.text(.continueActivation)) {
                    Task {
                        await viewModel.performPendingAccountActivation()
                    }
                }
                Button(MenuBarStrings.text(.cancel), role: .cancel) {
                    viewModel.cancelPendingAccountActivation()
                }
            }
        } message: {
            if let confirmation = viewModel.pendingAccountActivationConfirmation {
                Text(confirmation.message)
            }
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            Divider()

            ForEach(viewModel.summaries) { summary in
                UsageSummaryCard(summary: summary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                quickSwitchAnchor
                actionRow(title: MenuBarStrings.text(.openMainWindow), systemImage: "rectangle.on.rectangle") {
                    viewModel.openMainWindow()
                }
                addAccountMenu
                actionRow(title: MenuBarStrings.text(.statusPage), systemImage: "waveform.path.ecg") {
                    viewModel.openStatusPage()
                }
                actionRow(
                    title: viewModel.showEmails ? MenuBarStrings.text(.hideEmails) : MenuBarStrings.text(.showEmails),
                    systemImage: viewModel.showEmails ? "eye" : "eye.slash"
                ) {
                    Task {
                        await viewModel.toggleShowEmails()
                    }
                }
                actionRow(title: MenuBarStrings.text(.providerSync), systemImage: "arrow.triangle.2.circlepath") {
                    viewModel.openProviderSync()
                }
                actionRow(title: MenuBarStrings.text(.settings), systemImage: "gearshape") {
                    viewModel.openSettings()
                }
                actionRow(title: MenuBarStrings.text(.quit), systemImage: "power") {
                    viewModel.quit()
                }
            }
        }
        .padding(16)
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(MenuBarStrings.text(.codex))
                        .font(.title2.weight(.semibold))
                    Text(viewModel.headerEmail)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                HStack(spacing: 6) {
                    Label(MenuBarStrings.updatedLabel(viewModel.updatedText), systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    if !viewModel.usageSourceText.isEmpty {
                        Text(viewModel.usageSourceText)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }

                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(MenuBarStrings.text(.refreshUsage))
                }
            }

            Spacer()

            Text(viewModel.headerTier)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

    private func actionRow(
        title: String,
        systemImage: String,
        trailingSystemImage: String? = nil,
        isIndented: Bool = false,
        onHoverChanged: ((Bool) -> Void)? = nil,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                    .foregroundColor(.secondary)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, isIndented ? 20 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarActionRowButtonStyle())
        .onHover { isHovering in
            onHoverChanged?(isHovering)
        }
    }

    private func feedbackBanner(_ feedback: MenuBarInlineMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(feedback.tone == .success ? Color(nsColor: .systemGreen) : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.caption.weight(.semibold))
                Text(feedback.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.dismissRemovalFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func pendingRemovalMessage(for accountID: String) -> String? {
        guard viewModel.pendingAccountRemoval?.accountID == accountID else {
            return nil
        }

        return viewModel.pendingAccountRemoval?.message
    }

    private var addAccountMenu: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                actionRow(
                    title: MenuBarStrings.text(.addAccount),
                    systemImage: "person.crop.circle.badge.plus",
                    trailingSystemImage: isShowingAddAccountOptions ? "chevron.down" : "chevron.right"
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isShowingAddAccountOptions.toggle()
                    }
                }

                if isShowingAddAccountOptions {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(MenuBarViewModel.AddAccountAction.allCases, id: \.title) { action in
                            actionRow(
                                title: action.title,
                                systemImage: action.systemImageName,
                                isIndented: true
                            ) {
                                viewModel.startAddAccountAction(action)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress = viewModel.addAccountProgress, isShowingAddAccountOptions {
                addAccountProgressOverlay(progress)
            }
        }
    }

    private func addAccountProgressOverlay(_ progress: MenuBarViewModel.AddAccountProgressState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(progress.title)
                    .font(.subheadline.weight(.semibold))
            }

            Text(progress.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if progress.showsCancelButton {
                Button(MenuBarStrings.text(.cancelLogin)) {
                    viewModel.cancelAddAccountAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var quickSwitchAnchor: some View {
        actionRow(
            title: MenuBarStrings.text(.quickSwitch),
            systemImage: "arrow.left.arrow.right",
            trailingSystemImage: "chevron.right",
            onHoverChanged: { isHovering in
                onQuickSwitchHoverChange?(isHovering)
            }
        ) {}
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: QuickSwitchAnchorFramePreferenceKey.self,
                    value: geometry.frame(in: .named(Self.quickSwitchCoordinateSpaceName))
                )
            }
        )
    }
}

private struct MenuBarActionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.12) : Color.clear)
            )
    }
}

enum MenuBarQuickSwitchOverlayLayout {
    static let horizontalSpacing: CGFloat = MenuBarPanelView.quickSwitchHorizontalSpacing

    static func overlayOrigin(for anchorFrame: CGRect) -> CGPoint {
        CGPoint(
            x: anchorFrame.maxX + horizontalSpacing,
            y: anchorFrame.minY
        )
    }
}

private struct QuickSwitchAnchorFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}
