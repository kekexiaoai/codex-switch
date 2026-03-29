import SwiftUI

public struct StatusView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics")
                .font(.headline)
            statusRow(label: "Active host", value: hostLabel)
            statusRow(label: "Preferred host", value: preferredHostLabel)
            statusRow(label: "Runtime mode", value: "mock")
        }
        .font(.subheadline)
    }

    private var hostLabel: String {
        label(for: MenuBarHostKind.current)
    }

    private var preferredHostLabel: String {
        label(for: MenuBarHostKind.preferred)
    }

    private func label(for host: MenuBarHostKind) -> String {
        switch host {
        case .statusItemPopover:
            return "NSStatusItem + NSPopover"
        case .menuBarExtra:
            return "MenuBarExtra"
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}
