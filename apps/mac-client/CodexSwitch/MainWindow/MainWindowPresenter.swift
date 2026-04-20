import AppKit
import SwiftUI

@MainActor
public protocol MainWindowPresenting {
    func present(route: MainWindowRoute)
}

@MainActor
public final class MainWindowPresenter: MainWindowPresenting {
    public static let defaultContentSize = NSSize(width: 640, height: 640)
    public static let minimumContentSize = NSSize(width: 640, height: 560)
    private let makeViewModel: @MainActor (MainWindowRoute) -> MainWindowViewModel
    private let makeWindowController: @MainActor (MainWindowViewModel) -> NSWindowController
    private let updateWindowController: @MainActor (NSWindowController, MainWindowViewModel) -> Void
    private let presentWindowController: @MainActor (NSWindowController) -> Void

    private var windowController: NSWindowController?

    public init(
        makeViewModel: @escaping @MainActor (MainWindowRoute) -> MainWindowViewModel,
        makeWindowController: (@MainActor (MainWindowViewModel) -> NSWindowController)? = nil,
        updateWindowController: (@MainActor (NSWindowController, MainWindowViewModel) -> Void)? = nil,
        presentWindowController: (@MainActor (NSWindowController) -> Void)? = nil
    ) {
        self.makeViewModel = makeViewModel
        self.makeWindowController = makeWindowController ?? Self.defaultWindowController(viewModel:)
        self.updateWindowController = updateWindowController ?? Self.update(windowController:viewModel:)
        self.presentWindowController = presentWindowController ?? Self.present(windowController:)
    }

    public func present(route: MainWindowRoute) {
        let viewModel = makeViewModel(route)

        if let windowController {
            updateWindowController(windowController, viewModel)
            presentWindowController(windowController)
            return
        }

        let controller = makeWindowController(viewModel)
        windowController = controller
        presentWindowController(controller)
    }

    private static func defaultWindowController(viewModel: MainWindowViewModel) -> NSWindowController {
        let hostingController = NSHostingController(rootView: MainWindowView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Codex Switch"
        window.setContentSize(defaultContentSize)
        window.minSize = minimumContentSize
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        return NSWindowController(window: window)
    }

    private static func update(windowController: NSWindowController, viewModel: MainWindowViewModel) {
        if let hostingController = windowController.window?.contentViewController as? NSHostingController<MainWindowView> {
            hostingController.rootView = MainWindowView(viewModel: viewModel)
        } else {
            windowController.window?.contentViewController = NSHostingController(rootView: MainWindowView(viewModel: viewModel))
        }

        windowController.window?.title = "Codex Switch"
        windowController.window?.setContentSize(defaultContentSize)
        windowController.window?.minSize = minimumContentSize
        windowController.window?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    }

    private static func present(windowController: NSWindowController) {
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
