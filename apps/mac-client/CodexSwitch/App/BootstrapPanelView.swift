import SwiftUI

public struct BootstrapPanelView: View {
    private let environment: AppEnvironment

    public init(environment: AppEnvironment = .preview) {
        self.environment = environment
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Codex Switch")
                .font(.headline)
            Text("Bootstrap shell")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Host: \(String(describing: MenuBarHostKind.current))")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Usage: \(environment.usageService.refreshUsage())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 240)
    }
}
