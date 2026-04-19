import AppKit
import CodexSwitchKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, MenuBarActionHandling {
    private var statusItemController: StatusItemController?
    private var mainWindowPresenter: (any MainWindowPresenting)?

    init(mainWindowPresenter: (any MainWindowPresenting)? = nil) {
        self.mainWindowPresenter = mainWindowPresenter
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let configuration = RuntimeConfiguration()
        let environment = (try? AppEnvironment.live(configuration: configuration)) ?? .preview
        let controller = StatusItemController(environment: environment, actionHandler: self)
        controller.install()
        statusItemController = controller

        if mainWindowPresenter == nil {
            mainWindowPresenter = makeMainWindowPresenter(environment: environment)
        }
    }

    func handle(_ action: MenuBarAction) {
        if let mainWindowPresenter {
            let dispatcher = MainWindowActionDispatcher(mainWindowPresenter: mainWindowPresenter)
            if dispatcher.handle(action) {
                return
            }
        }

        NSApp.terminate(nil)
    }

    private func makeMainWindowPresenter(environment: AppEnvironment) -> MainWindowPresenter {
        let statusLoader = environment.makeStatusSnapshotLoader()

        func rootView(viewModel: MainWindowViewModel) -> MainWindowView {
            MainWindowView(
                viewModel: viewModel,
                accountsContent: AnyView(AccountManagementView(viewModel: environment.makeAccountManagementViewModel())),
                providerSyncContent: AnyView(ProviderSyncContentView(viewModel: environment.makeProviderSyncViewModel())),
                settingsContent: AnyView(SettingsContentView(viewModel: environment.makeSettingsViewModel())),
                statusContent: AnyView(StatusContentView(snapshotLoader: statusLoader))
            )
        }

        return MainWindowPresenter(
            makeViewModel: { route in
                MainWindowViewModel(selectedTab: route.selectedTab)
            },
            makeWindowController: { viewModel in
                let hostingController = NSHostingController(rootView: rootView(viewModel: viewModel))
                let window = NSWindow(contentViewController: hostingController)
                window.title = "Codex Switch"
                window.setContentSize(NSSize(width: 960, height: 640))
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
                return NSWindowController(window: window)
            },
            updateWindowController: { windowController, viewModel in
                if let hostingController = windowController.window?.contentViewController as? NSHostingController<MainWindowView> {
                    hostingController.rootView = rootView(viewModel: viewModel)
                } else {
                    windowController.window?.contentViewController = NSHostingController(rootView: rootView(viewModel: viewModel))
                }
                windowController.window?.title = "Codex Switch"
                windowController.window?.setContentSize(NSSize(width: 960, height: 640))
                windowController.window?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            },
            presentWindowController: { windowController in
                windowController.showWindow(nil)
                windowController.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        )
    }
}
