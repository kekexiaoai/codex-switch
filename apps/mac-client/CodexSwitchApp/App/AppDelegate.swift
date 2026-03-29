import AppKit
import CodexSwitchKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, MenuBarActionHandling {
    private var statusItemController: StatusItemController?
    private var statusWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let environment = (try? AppEnvironment.live(configuration: RuntimeConfiguration())) ?? .preview
        let controller = StatusItemController(environment: environment, actionHandler: self)
        controller.install()
        statusItemController = controller
    }

    func handle(_ action: MenuBarAction) {
        switch action {
        case .openSettings:
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case .openStatusPage:
            openStatusWindow()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private func openStatusWindow() {
        let hostingController = NSHostingController(rootView: StatusWindowView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Codex Switch Status"
        window.setContentSize(NSSize(width: 440, height: 280))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        statusWindowController = controller
    }
}
