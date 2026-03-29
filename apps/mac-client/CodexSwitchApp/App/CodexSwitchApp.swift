import SwiftUI
import CodexSwitchKit

@main
struct CodexSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let settingsEnvironment: AppEnvironment

    init() {
        let configuration = RuntimeConfiguration()
        settingsEnvironment = (try? AppEnvironment.live(configuration: configuration)) ?? .preview
    }

    var body: some Scene {
        Settings {
            SettingsView(viewModel: settingsEnvironment.makeSettingsViewModel())
        }
    }
}
