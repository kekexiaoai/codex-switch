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

@MainActor
public final class OpenPanelBackupAuthPicker: BackupAuthPicking {
    public init() {}

    public func pickBackupAuthURL() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.prompt = "Import"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
#endif
