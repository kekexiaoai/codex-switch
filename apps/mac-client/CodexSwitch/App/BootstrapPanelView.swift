import SwiftUI

public struct BootstrapPanelView: View {
    private let environment: AppEnvironment
    @State private var usageText = Self.defaultLoadingText()

    public init(environment: AppEnvironment = .preview) {
        self.environment = environment
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Codex Switch")
                .font(.headline)
            Text(bootstrapShellTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("\(hostTitle): \(String(describing: MenuBarHostKind.current))")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(usageTitle): \(usageText)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 240)
        .task {
            usageText = await environment.usageService.refreshUsage()
        }
    }

    private var bootstrapShellTitle: String {
        switch MenuBarStrings.language() {
        case .english:
            return "Bootstrap shell"
        case .simplifiedChinese:
            return "启动壳层"
        }
    }

    private var hostTitle: String {
        switch MenuBarStrings.language() {
        case .english:
            return "Host"
        case .simplifiedChinese:
            return "宿主"
        }
    }

    private var usageTitle: String {
        switch MenuBarStrings.language() {
        case .english:
            return "Usage"
        case .simplifiedChinese:
            return "用量"
        }
    }

    private static func defaultLoadingText() -> String {
        switch MenuBarStrings.language() {
        case .english:
            return "Loading..."
        case .simplifiedChinese:
            return "加载中..."
        }
    }
}
