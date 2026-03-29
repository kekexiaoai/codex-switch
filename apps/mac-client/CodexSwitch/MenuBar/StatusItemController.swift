import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarPopoverDiagnosticsLogger {
    private let logFileURL: URL
    private let fileManager: FileManager
    private let timeFormatter: CodexUserFacingTimeFormatter
    private let lock = NSLock()

    init(
        paths: CodexPaths,
        fileManager: FileManager = .default,
        timeFormatter: CodexUserFacingTimeFormatter = CodexUserFacingTimeFormatter()
    ) {
        self.logFileURL = paths.diagnosticsDirectoryURL.appendingPathComponent("menubar-popover.log")
        self.fileManager = fileManager
        self.timeFormatter = timeFormatter
    }

    func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        do {
            try fileManager.createDirectory(
                at: logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let line = "\(timeFormatter.logTimestamp(from: Date())) \(message)\n"
            let data = Data(line.utf8)

            if !fileManager.fileExists(atPath: logFileURL.path) {
                try data.write(to: logFileURL, options: .atomic)
                return
            }

            let handle = try FileHandle(forWritingTo: logFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Diagnostics logging must never break the product flow.
        }
    }
}

@MainActor
final class MenuBarHostingController: NSHostingController<MenuBarShellView> {
    private let diagnosticsLogger: MenuBarPopoverDiagnosticsLogger?

    init(
        rootView: MenuBarShellView,
        diagnosticsLogger: MenuBarPopoverDiagnosticsLogger? = nil
    ) {
        self.diagnosticsLogger = diagnosticsLogger
        super.init(rootView: rootView)
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        diagnosticsLogger?.log("hostingController viewDidAppear frameHeight=\(view.frame.height)")
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
            return window === sourceWindow
        }
    }
}

@MainActor
struct MenuBarPopoverPresenter {
    let activateApp: () -> Void
    let showPopover: () -> Void
    let makePopoverInteractive: () -> Void
    let startOutsideClickMonitor: () -> Void

    func present() {
        activateApp()
        showPopover()
        makePopoverInteractive()
        startOutsideClickMonitor()
    }
}

@MainActor
public final class StatusItemController: NSObject, NSPopoverDelegate {
    static let popoverWidth: CGFloat = 360
    static let minPopoverHeight: CGFloat = 380
    static let maxPopoverHeight: CGFloat = 720
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
    private let viewModel: MenuBarViewModel
    private let settingsDefaults: UserDefaults
    private let diagnosticsLogger: MenuBarPopoverDiagnosticsLogger?
    private var preferredContentHeight: CGFloat = StatusItemController.minPopoverHeight
    private lazy var outsideClickMonitor = PopoverOutsideClickMonitor(
        watchedWindows: { [weak self] in
            [
                self?.statusItem.button?.window,
                self?.popover.contentViewController?.view.window,
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
        if environment.settingsDefaults.bool(forKey: SettingsViewModel.menuBarDiagnosticsEnabledKey),
           let paths = environment.codexPaths {
            self.diagnosticsLogger = MenuBarPopoverDiagnosticsLogger(paths: paths)
        } else {
            self.diagnosticsLogger = nil
        }
        self.viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment),
            accountRepository: environment.accountRepository,
            activeAccountController: environment.activeAccountController,
            accountImporter: environment.accountImporter,
            accountRemover: environment.codexPaths.map { CodexArchivedAccountStore(fileStore: CodexAuthFileStore(paths: $0)) },
            loginCoordinator: environment.loginCoordinator,
            backupAuthPicker: OpenPanelBackupAuthPicker(),
            emailVisibilityStore: environment.emailVisibilityProvider as? any EmailVisibilityMutating,
            actionHandler: actionHandler
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
        popover.contentSize = Self.preferredPopoverContentSize(forContentHeight: preferredContentHeight)
        let hostingController = MenuBarHostingController(
            rootView: MenuBarShellView(
                viewModel: viewModel,
                onPreferredHeightChange: { [weak self] height in
                    self?.diagnosticsLogger?.log("swiftui preferredHeight=\(height)")
                    self?.updatePopoverContentSize(forContentHeight: height)
                }
            ),
            diagnosticsLogger: diagnosticsLogger
        )
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = [.preferredContentSize]
        }
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
            Task { [weak self] in
                guard let self else {
                    return
                }
                self.diagnosticsLogger?.log("togglePopover open requested currentPopoverHeight=\(self.popover.contentSize.height)")
                await self.viewModel.refresh()
                guard !self.popover.isShown else {
                    return
                }
                MenuBarPopoverPresenter(
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
                    }
                ).present()
            }
        }
    }

    public func popoverDidClose(_ notification: Notification) {
        outsideClickMonitor.stop()
    }

    private func closePopover(_ sender: AnyObject? = nil) {
        popover.performClose(sender)
        outsideClickMonitor.stop()
    }

    private func updatePopoverContentSize(forContentHeight height: CGFloat) {
        guard abs(height - preferredContentHeight) >= 1 || !popover.isShown else {
            return
        }
        let nextSize = Self.preferredPopoverContentSize(forContentHeight: height)
        let sizeChanged = popover.contentSize != nextSize
        preferredContentHeight = height
        guard sizeChanged else {
            return
        }
        diagnosticsLogger?.log("updatePopoverContentSize requested contentHeight=\(height) clampedHeight=\(nextSize.height) currentPopoverHeight=\(popover.contentSize.height)")
        popover.contentViewController?.preferredContentSize = nextSize
        popover.contentSize = nextSize

        if let window = popover.contentViewController?.view.window {
            let targetFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: nextSize))
            var nextFrame = window.frame
            let deltaHeight = targetFrame.height - nextFrame.height
            nextFrame.origin.y -= deltaHeight
            nextFrame.size = targetFrame.size
            diagnosticsLogger?.log("updatePopoverContentSize applyingWindowFrame oldHeight=\(window.frame.height) newHeight=\(nextFrame.height)")
            window.setFrame(nextFrame, display: true)
            window.layoutIfNeeded()
        }
    }

    private func currentStatusItemImage() -> NSImage? {
        let style = UserDefaultsMenuBarIconStyleStore(defaults: settingsDefaults).menuBarIconStyle()
        return Self.statusItemImage(style: style)
    }

    @objc
    private func handleMenuBarIconStyleDidChange(_ notification: Notification) {
        statusItem.button?.image = currentStatusItemImage()
    }

    static func preferredPopoverContentSize(forContentHeight height: CGFloat) -> NSSize {
        let clampedHeight = min(max(height, minPopoverHeight), maxPopoverHeight)
        return NSSize(width: popoverWidth, height: clampedHeight)
    }
}
