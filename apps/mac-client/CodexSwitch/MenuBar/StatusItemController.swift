import AppKit
import SwiftUI

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
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let viewModel: MenuBarViewModel
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

    public func install() {
        popover.delegate = self
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarShellView(viewModel: viewModel)
        )

        if let button = statusItem.button {
            button.title = "Codex"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        Task {
            await viewModel.refresh()
        }

        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            closePopover(sender)
        } else {
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

    public func popoverDidClose(_ notification: Notification) {
        outsideClickMonitor.stop()
    }

    private func closePopover(_ sender: AnyObject? = nil) {
        popover.performClose(sender)
        outsideClickMonitor.stop()
    }
}
