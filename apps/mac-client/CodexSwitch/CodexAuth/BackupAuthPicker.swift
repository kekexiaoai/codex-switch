import Foundation

@MainActor
public protocol BackupAuthPicking {
    func pickBackupAuthURL() async -> URL?
}

public struct StubBackupAuthPicker: BackupAuthPicking {
    private let selectedURL: URL?

    public init(selectedURL: URL?) {
        self.selectedURL = selectedURL
    }

    public func pickBackupAuthURL() async -> URL? {
        selectedURL
    }
}

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

@MainActor
public final class OpenPanelBackupAuthPicker: BackupAuthPicking {
    public init() {}

    public static func makePanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.prompt = "Import"
        return panel
    }

    public func pickBackupAuthURL() async -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = Self.makePanel()
        return panel.runModal() == .OK ? panel.url : nil
    }
}
#endif
