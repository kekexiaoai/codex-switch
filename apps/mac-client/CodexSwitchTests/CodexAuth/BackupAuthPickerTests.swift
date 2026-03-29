#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import CodexSwitchKit

@MainActor
final class BackupAuthPickerTests: XCTestCase {
    func testOpenPanelPickerConfiguresJSONFileSelection() {
        let panel = OpenPanelBackupAuthPicker.makePanel()

        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertEqual(panel.allowedContentTypes.map(\.identifier), [UTType.json.identifier])
        XCTAssertEqual(panel.prompt, "Import")
    }
}
#endif
