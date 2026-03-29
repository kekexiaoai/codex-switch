import AppKit
import XCTest
@testable import CodexSwitchKit

@MainActor
final class SettingsWindowPresenterTests: XCTestCase {
    func testSettingsWindowPresenterReusesWindowControllerAndRefreshesViewModel() {
        let firstViewModel = SettingsViewModel(
            defaults: makeDefaults(suiteName: "CodexSwitchTests.SettingsWindowPresenter.First")
        )
        let secondDefaults = makeDefaults(suiteName: "CodexSwitchTests.SettingsWindowPresenter.Second")
        secondDefaults.set(true, forKey: SettingsViewModel.launchAtLoginKey)
        let secondViewModel = SettingsViewModel(defaults: secondDefaults)

        var makeCount = 0
        var renderedLaunchAtLoginValues: [Bool] = []
        var presentedControllers: [NSWindowController] = []
        let viewModels = [firstViewModel, secondViewModel]
        var index = 0

        let presenter = SettingsWindowPresenter(
            makeViewModel: {
                defer { index += 1 }
                return viewModels[min(index, viewModels.count - 1)]
            },
            makeWindowController: { viewModel in
                makeCount += 1
                renderedLaunchAtLoginValues.append(viewModel.launchAtLogin)
                return NSWindowController(window: NSWindow())
            },
            updateWindowController: { _, viewModel in
                renderedLaunchAtLoginValues.append(viewModel.launchAtLogin)
            },
            presentWindowController: { controller in
                presentedControllers.append(controller)
            }
        )

        presenter.present()
        presenter.present()

        XCTAssertEqual(makeCount, 1)
        XCTAssertEqual(renderedLaunchAtLoginValues, [false, true])
        XCTAssertEqual(presentedControllers.count, 2)
        XCTAssertTrue(presentedControllers[0] === presentedControllers[1])
    }

    private func makeDefaults(suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
