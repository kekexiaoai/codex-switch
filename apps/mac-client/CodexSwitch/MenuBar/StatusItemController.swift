import AppKit
import SwiftUI

@MainActor
public final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let viewModel: MenuBarViewModel
    private let environment: AppEnvironment

    public init(
        environment: AppEnvironment = .preview,
        actionHandler: (any MenuBarActionHandling)? = nil
    ) {
        self.environment = environment
        self.viewModel = MenuBarViewModel(
            service: EnvironmentMenuBarService(environment: environment),
            accountRepository: environment.accountRepository,
            activeAccountController: environment.activeAccountController,
            accountImporter: environment.accountImporter,
            loginCoordinator: environment.loginCoordinator,
            backupAuthPicker: OpenPanelBackupAuthPicker(),
            emailVisibilityStore: environment.emailVisibilityProvider as? any EmailVisibilityMutating,
            actionHandler: actionHandler
        )
        super.init()
    }

    public func install() {
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
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
