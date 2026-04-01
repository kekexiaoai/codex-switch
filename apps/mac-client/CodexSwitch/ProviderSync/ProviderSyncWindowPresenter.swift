import AppKit
import SwiftUI

@MainActor
public final class ProviderSyncWindowPresenter {
    private let makeViewModel: @MainActor () -> ProviderSyncViewModel
    private let makeWindowController: @MainActor (ProviderSyncViewModel) -> NSWindowController
    private let updateWindowController: @MainActor (NSWindowController, ProviderSyncViewModel) -> Void
    private let presentWindowController: @MainActor (NSWindowController) -> Void

    private var windowController: NSWindowController?

    public init(
        makeViewModel: @escaping @MainActor () -> ProviderSyncViewModel,
        makeWindowController: (@MainActor (ProviderSyncViewModel) -> NSWindowController)? = nil,
        updateWindowController: (@MainActor (NSWindowController, ProviderSyncViewModel) -> Void)? = nil,
        presentWindowController: (@MainActor (NSWindowController) -> Void)? = nil
    ) {
        self.makeViewModel = makeViewModel
        self.makeWindowController = makeWindowController ?? Self.defaultWindowController(viewModel:)
        self.updateWindowController = updateWindowController ?? Self.update(windowController:viewModel:)
        self.presentWindowController = presentWindowController ?? Self.present(windowController:)
    }

    public func present() {
        let viewModel = makeViewModel()

        if let windowController {
            updateWindowController(windowController, viewModel)
            presentWindowController(windowController)
            return
        }

        let controller = makeWindowController(viewModel)
        windowController = controller
        presentWindowController(controller)
    }

    private static func defaultWindowController(viewModel: ProviderSyncViewModel) -> NSWindowController {
        let hostingController = NSHostingController(rootView: ProviderSyncView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Provider Sync"
        window.setContentSize(NSSize(width: 520, height: 640))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        return NSWindowController(window: window)
    }

    private static func update(windowController: NSWindowController, viewModel: ProviderSyncViewModel) {
        if let hostingController = windowController.window?.contentViewController as? NSHostingController<ProviderSyncView> {
            hostingController.rootView = ProviderSyncView(viewModel: viewModel)
        } else {
            windowController.window?.contentViewController = NSHostingController(rootView: ProviderSyncView(viewModel: viewModel))
        }

        windowController.window?.title = "Provider Sync"
        windowController.window?.setContentSize(NSSize(width: 520, height: 640))
        windowController.window?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    }

    private static func present(windowController: NSWindowController) {
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
