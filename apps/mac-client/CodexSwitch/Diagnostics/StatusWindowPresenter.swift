import AppKit
import SwiftUI

@MainActor
public final class StatusWindowPresenter {
    private let loadSnapshot: @Sendable () async -> StatusSnapshot
    private let makeWindowController: @MainActor (StatusSnapshot) -> NSWindowController
    private let updateWindowController: @MainActor (NSWindowController, StatusSnapshot) -> Void
    private let presentWindowController: @MainActor (NSWindowController) -> Void

    private var windowController: NSWindowController?

    public init(
        loadSnapshot: @escaping @Sendable () async -> StatusSnapshot,
        makeWindowController: (@MainActor (StatusSnapshot) -> NSWindowController)? = nil,
        updateWindowController: (@MainActor (NSWindowController, StatusSnapshot) -> Void)? = nil,
        presentWindowController: (@MainActor (NSWindowController) -> Void)? = nil
    ) {
        self.loadSnapshot = loadSnapshot
        self.makeWindowController = makeWindowController ?? Self.defaultWindowController(snapshot:)
        self.updateWindowController = updateWindowController ?? Self.update(windowController:snapshot:)
        self.presentWindowController = presentWindowController ?? Self.present(windowController:)
    }

    public func present() async {
        let snapshot = await loadSnapshot()

        if let windowController {
            updateWindowController(windowController, snapshot)
            presentWindowController(windowController)
            return
        }

        let controller = makeWindowController(snapshot)
        windowController = controller
        presentWindowController(controller)
    }

    private static func defaultWindowController(snapshot: StatusSnapshot) -> NSWindowController {
        let hostingController = NSHostingController(rootView: StatusWindowView(snapshot: snapshot))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Codex Switch Status"
        window.setContentSize(NSSize(width: 640, height: 640))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        return NSWindowController(window: window)
    }

    private static func update(windowController: NSWindowController, snapshot: StatusSnapshot) {
        if let hostingController = windowController.window?.contentViewController as? NSHostingController<StatusWindowView> {
            hostingController.rootView = StatusWindowView(snapshot: snapshot)
        } else {
            windowController.window?.contentViewController = NSHostingController(rootView: StatusWindowView(snapshot: snapshot))
        }

        windowController.window?.title = "Codex Switch Status"
        windowController.window?.setContentSize(NSSize(width: 640, height: 640))
        windowController.window?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    }

    private static func present(windowController: NSWindowController) {
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
