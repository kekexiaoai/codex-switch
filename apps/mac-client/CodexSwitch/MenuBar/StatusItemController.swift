import AppKit
import SwiftUI

@MainActor
final class MenuBarHostingController: NSHostingController<MenuBarShellView> {
    private let onSizeChange: (NSSize) -> Void
    private var lastReportedSize: NSSize = .zero

    init(
        rootView: MenuBarShellView,
        onSizeChange: @escaping (NSSize) -> Void
    ) {
        self.onSizeChange = onSizeChange
        super.init(rootView: rootView)
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredContentSize: NSSize {
        didSet {
            reportPreferredSize(preferredContentSize)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        reportMeasuredHeight()
    }

    func refreshHeightNow() {
        view.invalidateIntrinsicContentSize()
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        reportMeasuredHeight()
    }

    func scheduleHeightRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshHeightNow()
        }
    }

    private func reportMeasuredHeight() {
        let measuredSize = preferredContentSize.width > 0 && preferredContentSize.height > 0
            ? preferredContentSize
            : NSSize(width: view.fittingSize.width, height: view.fittingSize.height)
        reportPreferredSize(measuredSize)
    }

    private func reportPreferredSize(_ size: NSSize) {
        guard size.width > 0, size.height > 0 else {
            return
        }
        guard abs(size.width - lastReportedSize.width) > 0.5 || abs(size.height - lastReportedSize.height) > 0.5 else {
            return
        }
        lastReportedSize = size
        onSizeChange(size)
    }
}

@MainActor
final class PopoverOutsideClickMonitor {
    typealias LocalMonitorInstaller = (NSEvent.EventTypeMask, @escaping (NSEvent) -> NSEvent?) -> Any?
    typealias GlobalMonitorInstaller = (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Any?
    typealias MonitorRemover = (Any) -> Void
    typealias EventWindowResolver = (NSEvent) -> NSWindow?

    private let watchedWindows: () -> [NSWindow?]
    private let addLocalMonitor: LocalMonitorInstaller
    private let addGlobalMonitor: GlobalMonitorInstaller
    private let removeMonitor: MonitorRemover
    private let eventWindow: EventWindowResolver
    private let onOutsideClick: @MainActor () -> Void
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(
        watchedWindows: @escaping () -> [NSWindow?],
        addLocalMonitor: @escaping LocalMonitorInstaller = { mask, handler in
            NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
        },
        addGlobalMonitor: @escaping GlobalMonitorInstaller = { mask, handler in
            NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        },
        removeMonitor: @escaping MonitorRemover = { monitor in
            NSEvent.removeMonitor(monitor)
        },
        eventWindow: @escaping EventWindowResolver = { event in
            event.window
        },
        onOutsideClick: @escaping @MainActor () -> Void
    ) {
        self.watchedWindows = watchedWindows
        self.addLocalMonitor = addLocalMonitor
        self.addGlobalMonitor = addGlobalMonitor
        self.removeMonitor = removeMonitor
        self.eventWindow = eventWindow
        self.onOutsideClick = onOutsideClick
    }

    func start() {
        guard localMonitor == nil, globalMonitor == nil else {
            return
        }

        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = addLocalMonitor(eventMask) { [weak self] event in
            guard let self else {
                return event
            }

            if self.shouldDismiss(for: event) {
                self.onOutsideClick()
            }
            return event
        }
        globalMonitor = addGlobalMonitor(eventMask) { [weak self] _ in
            guard let self else {
                return
            }

            if Thread.isMainThread {
                self.onOutsideClick()
            } else {
                DispatchQueue.main.async {
                    self.onOutsideClick()
                }
            }
        }
    }

    func stop() {
        if let localMonitor {
            removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func shouldDismiss(for event: NSEvent) -> Bool {
        guard let sourceWindow = eventWindow(event) else {
            return true
        }

        return !watchedWindows().contains { window in
            guard let window else {
                return false
            }
            return containsWindow(sourceWindow, in: window)
        }
    }

    private func containsWindow(_ sourceWindow: NSWindow, in watchedWindow: NSWindow) -> Bool {
        if watchedWindow === sourceWindow {
            return true
        }

        if let attachedSheet = watchedWindow.attachedSheet,
           containsWindow(sourceWindow, in: attachedSheet) {
            return true
        }

        return watchedWindow.childWindows?.contains(where: { childWindow in
            containsWindow(sourceWindow, in: childWindow)
        }) ?? false
    }
}

@MainActor
struct MenuBarPopoverPresenter {
    let preparePopover: () -> Void
    let activateApp: () -> Void
    let showPopover: () -> Void
    let makePopoverInteractive: () -> Void
    let startOutsideClickMonitor: () -> Void
    let refreshContent: (() -> Void)?

    func present() {
        preparePopover()
        activateApp()
        showPopover()
        makePopoverInteractive()
        startOutsideClickMonitor()
        refreshContent?()
    }
}

@MainActor
public final class StatusItemController: NSObject, NSPopoverDelegate {
    static let popoverWidth: CGFloat = 360
    static let minPopoverHeight: CGFloat = 380
    static let maxPopoverHeight: CGFloat = 720
    static let quickSwitchPopoverWidth: CGFloat = 320
    static let quickSwitchPopoverHeight: CGFloat = 280
    static let statusItemAccessibilityTitle = "Codex Switch"

    static func resourceName(for style: MenuBarIconStyle) -> String {
        switch style {
        case .highContrastLight:
            return "StatusBarIconLightHighContrast"
        case .highContrastLightBold:
            return "StatusBarIconLightHighContrastBold"
        }
    }

    static func statusItemImage(style: MenuBarIconStyle = .highContrastLightBold) -> NSImage? {
        let resourceName = resourceName(for: style)
        let image = resourceBundles()
            .lazy
            .compactMap { bundle in
                bundle.url(forResource: resourceName, withExtension: "png")
            }
            .compactMap { url in
                NSImage(contentsOf: url)
            }
            .first
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        return image
    }

    private static func resourceBundles() -> [Bundle] {
        var bundles = [Bundle.main, Bundle(for: StatusItemController.self)]

#if SWIFT_PACKAGE && !Xcode
        bundles.append(Bundle.module)
#endif

        return bundles
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let quickSwitchPopover = NSPopover()
    private let viewModel: MenuBarViewModel
    private let settingsDefaults: UserDefaults
    private var preferredContentSize: NSSize = NSSize(width: StatusItemController.popoverWidth, height: StatusItemController.minPopoverHeight)
    private weak var hostingController: MenuBarHostingController?
    private weak var quickSwitchHostingController: NSHostingController<QuickSwitchOverlayView>?
    private var quickSwitchAnchorFrame: CGRect = .zero
    private var quickSwitchDismissWorkItem: DispatchWorkItem?
    private var isHoveringQuickSwitchAnchor = false
    private var isHoveringQuickSwitchPopover = false
    private lazy var outsideClickMonitor = PopoverOutsideClickMonitor(
        watchedWindows: { [weak self] in
            [
                self?.statusItem.button?.window,
                self?.popover.contentViewController?.view.window,
                self?.quickSwitchPopover.contentViewController?.view.window,
            ]
        },
        onOutsideClick: { [weak self] in
            self?.closePopover()
        }
    )

    public init(
        environment: AppEnvironment = .preview,
        actionHandler: (any MenuBarActionHandling)? = nil
    ) {
        self.settingsDefaults = environment.settingsDefaults
        self.viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment),
            accountRepository: environment.accountRepository,
            activeAccountController: environment.activeAccountController,
            accountImporter: environment.accountImporter,
            accountRemover: environment.codexPaths.map { CodexArchivedAccountStore(fileStore: CodexAuthFileStore(paths: $0)) },
            loginCoordinator: environment.loginCoordinator,
            backupAuthPicker: OpenPanelBackupAuthPicker(),
            emailVisibilityStore: environment.emailVisibilityProvider as? any EmailVisibilityMutating,
            actionHandler: actionHandler,
            currentAuthUsesAPIKeyMode: environment.codexPaths.map { paths in
                let fileStore = CodexAuthFileStore(paths: paths)
                return {
                    guard let data = try? fileStore.readCurrentAuthData() else {
                        return false
                    }
                    return CodexAuthImporter.authDataUsesAPIKeyMode(data)
                }
            }
        )
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func install() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarIconStyleDidChange),
            name: SettingsViewModel.menuBarIconStyleDidChangeNotification,
            object: nil
        )
        popover.delegate = self
        popover.behavior = .transient
        popover.contentSize = Self.preferredPopoverContentSize(forContentSize: preferredContentSize)
        quickSwitchPopover.behavior = .applicationDefined
        quickSwitchPopover.animates = false
        let hostingController = MenuBarHostingController(
            rootView: MenuBarShellView(
                viewModel: viewModel,
                onQuickSwitchAnchorFrameChange: { [weak self] frame in
                    self?.quickSwitchAnchorFrame = frame
                    self?.refreshQuickSwitchPopoverPositionIfNeeded()
                },
                onQuickSwitchHoverChange: { [weak self] isHovering in
                    self?.handleQuickSwitchAnchorHoverChange(isHovering)
                }
            ),
            onSizeChange: { [weak self] size in
                    self?.updatePopoverContentSize(forContentSize: size)
            }
        )
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = [.preferredContentSize]
        }
        self.hostingController = hostingController
        popover.contentViewController = hostingController

        if let button = statusItem.button {
            button.title = ""
            button.image = currentStatusItemImage()
            button.imagePosition = .imageOnly
            button.toolTip = Self.statusItemAccessibilityTitle
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            closePopover(sender)
        } else {
            MenuBarPopoverPresenter(
                preparePopover: { [weak self] in
                    self?.hostingController?.refreshHeightNow()
                },
                activateApp: { NSApp.activate(ignoringOtherApps: true) },
                showPopover: { [popover] in
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                },
                makePopoverInteractive: { [popover] in
                    guard let window = popover.contentViewController?.view.window else {
                        return
                    }
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(window.contentView)
                },
                startOutsideClickMonitor: { [outsideClickMonitor] in
                    outsideClickMonitor.start()
                },
                refreshContent: { [weak self] in
                    Task { [weak self] in
                        await self?.viewModel.refreshForPresentation()
                    }
                }
            ).present()
        }
    }

    public func popoverDidClose(_ notification: Notification) {
        closeQuickSwitchPopover()
        outsideClickMonitor.stop()
    }

    private func closePopover(_ sender: AnyObject? = nil) {
        closeQuickSwitchPopover()
        popover.performClose(sender)
        outsideClickMonitor.stop()
    }

    private func updatePopoverContentSize(forContentSize size: NSSize) {
        preferredContentSize = size
        guard let nextSize = Self.resolvedPopoverContentSize(
            currentSize: popover.contentSize,
            forContentSize: size,
            isPopoverShown: popover.isShown
        ) else {
            return
        }
        popover.contentViewController?.preferredContentSize = nextSize
        popover.contentSize = nextSize
    }

    private func currentStatusItemImage() -> NSImage? {
        let style = UserDefaultsMenuBarIconStyleStore(defaults: settingsDefaults).menuBarIconStyle()
        return Self.statusItemImage(style: style)
    }

    private func handleQuickSwitchAnchorHoverChange(_ isHovering: Bool) {
        isHoveringQuickSwitchAnchor = isHovering

        if isHovering {
            presentQuickSwitchPopoverIfNeeded()
        } else {
            scheduleQuickSwitchPopoverDismissIfNeeded()
        }
    }

    private func handleQuickSwitchPopoverHoverChange(_ isHovering: Bool) {
        isHoveringQuickSwitchPopover = isHovering

        if isHovering {
            quickSwitchDismissWorkItem?.cancel()
        } else {
            scheduleQuickSwitchPopoverDismissIfNeeded()
        }
    }

    private func presentQuickSwitchPopoverIfNeeded() {
        quickSwitchDismissWorkItem?.cancel()

        guard popover.isShown,
              !quickSwitchAnchorFrame.isEmpty,
              let anchorView = popover.contentViewController?.view
        else {
            return
        }

        let overlayView = QuickSwitchOverlayView(
            rows: viewModel.quickSwitchRows,
            onSelect: { [weak self] accountID in
                self?.closeQuickSwitchPopover()
                self?.closePopover()
                self?.viewModel.requestSwitchToAccount(id: accountID)
            },
            onHoverChanged: { [weak self] isHovering in
                self?.handleQuickSwitchPopoverHoverChange(isHovering)
            }
        )

        if let quickSwitchHostingController {
            quickSwitchHostingController.rootView = overlayView
        } else {
            let hostingController = NSHostingController(rootView: overlayView)
            quickSwitchHostingController = hostingController
            quickSwitchPopover.contentViewController = hostingController
        }

        quickSwitchPopover.contentSize = NSSize(
            width: Self.quickSwitchPopoverWidth,
            height: Self.quickSwitchPopoverHeight
        )

        if quickSwitchPopover.isShown {
            refreshQuickSwitchPopoverPositionIfNeeded()
            return
        }

        quickSwitchPopover.show(
            relativeTo: quickSwitchAnchorFrame,
            of: anchorView,
            preferredEdge: .maxX
        )
    }

    private func refreshQuickSwitchPopoverPositionIfNeeded() {
        guard quickSwitchPopover.isShown else {
            return
        }

        closeQuickSwitchPopover()

        if isHoveringQuickSwitchAnchor || isHoveringQuickSwitchPopover {
            presentQuickSwitchPopoverIfNeeded()
        }
    }

    private func scheduleQuickSwitchPopoverDismissIfNeeded() {
        quickSwitchDismissWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            if !self.isHoveringQuickSwitchAnchor && !self.isHoveringQuickSwitchPopover {
                self.closeQuickSwitchPopover()
            }
        }

        quickSwitchDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    private func closeQuickSwitchPopover() {
        quickSwitchDismissWorkItem?.cancel()
        isHoveringQuickSwitchPopover = false

        if quickSwitchPopover.isShown {
            quickSwitchPopover.performClose(nil)
        }
    }

    @objc
    private func handleMenuBarIconStyleDidChange(_ notification: Notification) {
        statusItem.button?.image = currentStatusItemImage()
    }

    static func preferredPopoverContentSize(forContentSize size: NSSize) -> NSSize {
        let clampedWidth = popoverWidth
        let clampedHeight = min(max(size.height, minPopoverHeight), maxPopoverHeight)
        return NSSize(width: clampedWidth, height: clampedHeight)
    }

    static func resolvedPopoverContentSize(
        currentSize: NSSize,
        forContentSize size: NSSize,
        isPopoverShown: Bool
    ) -> NSSize? {
        guard !isPopoverShown else {
            return nil
        }

        let nextSize = preferredPopoverContentSize(forContentSize: size)
        guard currentSize != nextSize else {
            return nil
        }

        return nextSize
    }
}
