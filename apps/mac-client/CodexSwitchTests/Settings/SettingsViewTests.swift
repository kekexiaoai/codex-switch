import XCTest
@testable import CodexSwitchKit

@MainActor
final class SettingsViewTests: XCTestCase {
    func testSettingsViewExposesGroupedSectionsAndControls() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.View")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.View")

        let view = SettingsView(viewModel: SettingsViewModel(defaults: defaults))

        XCTAssertEqual(view.sectionTitles, ["General", "Privacy", "Usage", "Provider Management", "Advanced"])
        XCTAssertEqual(
            view.generalControlLabels,
            ["Launch at Login", "Menu Bar Icon", "High Contrast", "High Contrast Bold"]
        )
        XCTAssertEqual(
            view.menuBarIconPreviewResourceNames,
            ["StatusBarIconLightHighContrast", "StatusBarIconLightHighContrastBold"]
        )
        XCTAssertTrue(view.menuBarIconPreviewUsesDarkBackground)
        XCTAssertEqual(view.privacyControlLabels, [
            "Show full account emails",
            "Clear Diagnostics Log",
            "Clear Usage Cache",
            "Remove Archived Accounts",
        ])
        XCTAssertEqual(view.usageControlLabels, ["Enable Usage Refresh", "Usage Source Mode", "Automatic", "Local Only"])
        XCTAssertEqual(view.usageRiskTitle, "Usage Risk Notice")
        XCTAssertEqual(
            view.usageRiskBody,
            "Automatic mode requests usage from the ChatGPT web backend first, then falls back to local Codex session logs. Local Only skips the remote request and reads only ~/.codex/sessions/YYYY/MM/DD/ rollout logs and cache."
        )
        XCTAssertEqual(view.advancedControlLabels, [
            "Enable Account Reorder Debug Log",
            "Open ~/.codex",
            "Open Diagnostics Folder",
            "Export Diagnostics Summary",
        ])
    }

    func testSettingsViewUsesChineseLabelsWhenPreferredLanguageIsChinese() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.View.Chinese")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.View.Chinese")

        let view = SettingsView(
            viewModel: SettingsViewModel(defaults: defaults),
            preferredLanguages: ["zh-Hans"]
        )

        XCTAssertEqual(view.sectionTitles, ["通用", "隐私", "用量", "Provider 管理", "高级"])
        XCTAssertEqual(
            view.generalControlLabels,
            ["开机启动", "菜单栏图标", "高对比度", "高对比度粗体"]
        )
        XCTAssertEqual(view.privacyControlLabels, [
            "显示完整账号邮箱",
            "清理诊断日志",
            "清理用量缓存",
            "移除归档账号",
        ])
        XCTAssertEqual(view.usageControlLabels, ["启用用量刷新", "用量来源模式", "自动", "仅本地"])
        XCTAssertEqual(view.usageRiskTitle, "用量风险提示")
        XCTAssertEqual(
            view.advancedControlLabels,
            ["启用账号排序调试日志", "打开 ~/.codex", "打开诊断目录", "导出诊断摘要"]
        )
    }

    func testSettingsViewUsesFlexibleFrameWhenEmbeddedInMainWindow() {
        let defaults = UserDefaults(suiteName: "CodexSwitchTests.Settings.View.Embedded")!
        defaults.removePersistentDomain(forName: "CodexSwitchTests.Settings.View.Embedded")

        let view = SettingsView(
            viewModel: SettingsViewModel(defaults: defaults),
            layoutMode: .embeddedMainWindow
        )

        XCTAssertNil(view.fixedFrameSize)
    }
}
