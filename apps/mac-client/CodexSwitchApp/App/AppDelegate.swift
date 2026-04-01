import AppKit
import CodexSwitchKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, MenuBarActionHandling {
    private var statusItemController: StatusItemController?
    private var statusWindowPresenter: StatusWindowPresenter?
    private var settingsWindowPresenter: SettingsWindowPresenter?
    private var providerSyncWindowPresenter: ProviderSyncWindowPresenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let configuration = RuntimeConfiguration()
        let environment = (try? AppEnvironment.live(configuration: configuration)) ?? .preview
        let controller = StatusItemController(environment: environment, actionHandler: self)
        controller.install()
        statusItemController = controller
        settingsWindowPresenter = SettingsWindowPresenter(
            makeViewModel: {
                environment.makeSettingsViewModel()
            }
        )
        providerSyncWindowPresenter = ProviderSyncWindowPresenter(
            makeViewModel: {
                environment.makeProviderSyncViewModel()
            }
        )
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
            settingsWindowPresenter?.present()
        case .openStatusPage:
            openStatusWindow()
        case .openProviderSync:
            providerSyncWindowPresenter?.present()
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
