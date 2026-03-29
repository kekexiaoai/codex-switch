import AppKit
import CodexSwitchKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, MenuBarActionHandling {
    private var statusItemController: StatusItemController?
    private var statusWindowPresenter: StatusWindowPresenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let configuration = RuntimeConfiguration()
        let environment = (try? AppEnvironment.live(configuration: configuration)) ?? .preview
        let controller = StatusItemController(environment: environment, actionHandler: self)
        controller.install()
        statusItemController = controller
        statusWindowPresenter = environment.makeStatusSnapshotLoader().map { loader in
            StatusWindowPresenter(
                loadSnapshot: {
                    await loader.loadSnapshot()
                }
            )
        } ?? StatusWindowPresenter(
            loadSnapshot: {
                StatusSnapshot.preview
            }
        )
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
        Task { @MainActor [statusWindowPresenter] in
            await statusWindowPresenter?.present()
        }
    }
}
