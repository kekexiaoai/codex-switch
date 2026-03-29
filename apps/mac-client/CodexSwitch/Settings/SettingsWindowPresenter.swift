import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowPresenter {
    private let makeViewModel: @MainActor () -> SettingsViewModel
    private let makeWindowController: @MainActor (SettingsViewModel) -> NSWindowController
    private let updateWindowController: @MainActor (NSWindowController, SettingsViewModel) -> Void
    private let presentWindowController: @MainActor (NSWindowController) -> Void

    private var windowController: NSWindowController?

    public init(
        makeViewModel: @escaping @MainActor () -> SettingsViewModel,
        makeWindowController: (@MainActor (SettingsViewModel) -> NSWindowController)? = nil,
        updateWindowController: (@MainActor (NSWindowController, SettingsViewModel) -> Void)? = nil,
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

    private static func defaultWindowController(viewModel: SettingsViewModel) -> NSWindowController {
        let hostingController = NSHostingController(rootView: SettingsView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Codex Switch Settings"
        window.setContentSize(NSSize(width: 440, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable]
        return NSWindowController(window: window)
    }

    private static func update(windowController: NSWindowController, viewModel: SettingsViewModel) {
        if let hostingController = windowController.window?.contentViewController as? NSHostingController<SettingsView> {
            hostingController.rootView = SettingsView(viewModel: viewModel)
        } else {
            windowController.window?.contentViewController = NSHostingController(rootView: SettingsView(viewModel: viewModel))
        }

        windowController.window?.title = "Codex Switch Settings"
        windowController.window?.setContentSize(NSSize(width: 440, height: 560))
        windowController.window?.styleMask = [.titled, .closable, .miniaturizable]
    }

    private static func present(windowController: NSWindowController) {
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
