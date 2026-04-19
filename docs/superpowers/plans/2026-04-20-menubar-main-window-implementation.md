# 状态栏快切与统一主窗口 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前状态栏长列表重构为“一级菜单 + 快切浮层”，并引入一个承载账号、Provider Sync、设置、状态页的统一主窗口。

**Architecture:** 现有 `NSStatusItem + NSPopover` 宿主继续保留，但状态栏内容被拆分为根菜单与 hover 激活的快切浮层。账号顺序通过显式持久化字段沉淀在账号元数据中，主窗口 `账号` Tab 成为排序真源，主窗口使用顶部 `segmented tabs` 承载现有多窗口页面。

**Tech Stack:** SwiftUI、AppKit、Swift Concurrency、XCTest、`NSHostingController`、`NSWindowController`、`xcodebuild`

---

## Proposed File Structure

### Shared routing and main window shell

- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowTab.swift`
  责任：定义主窗口一级 Tab 及其稳定标识。
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowRoute.swift`
  责任：定义“打开主窗口并定位到某个 Tab”的跨模块路由。
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowPresenter.swift`
  责任：复用单一主窗口控制器，处理首次创建、再次展示与目标 Tab 更新。
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowView.swift`
  责任：顶部 `segmented tabs` 容器和内容区承载。
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowViewModel.swift`
  责任：维护当前选中的 Tab、默认入口与路由变更。

### Account ordering and management

- Modify: `apps/mac-client/CodexSwitch/Accounts/Account.swift`
  责任：为账号模型增加显式顺序字段。
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthModels.swift`
  责任：为归档账号元数据缓存增加顺序字段。
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthImporter.swift`
  责任：导入新账号时为其追加顺序值。
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexArchivedAccountStore.swift`
  责任：按显式顺序加载账号，并提供顺序保存能力。
- Create: `apps/mac-client/CodexSwitch/Accounts/AccountManagementService.swift`
  责任：组合加载、排序、删除、激活等账号管理操作，供账号页使用。
- Create: `apps/mac-client/CodexSwitch/Accounts/AccountManagementViewModel.swift`
  责任：管理账号页状态、上移/下移、删除、激活、刷新排序。
- Create: `apps/mac-client/CodexSwitch/Accounts/AccountManagementView.swift`
  责任：主窗口 `账号` Tab 视图，作为快切顺序真源。

### Menu bar quick switch

- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarActions.swift`
  责任：将旧的多窗口动作收敛为主窗口路由动作。
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarModels.swift`
  责任：补充快切行所需的紧凑展示字段与标识状态。
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift`
  责任：输出根菜单项、快切列表、设置页直达、主窗口打开动作。
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarPanelView.swift`
  责任：根菜单 UI 改造为“摘要 + 快速切换入口 + 打开主窗口 + 工具项”。
- Create: `apps/mac-client/CodexSwitch/MenuBar/QuickSwitchOverlayView.swift`
  责任：可滚动的二级快切浮层。
- Create: `apps/mac-client/CodexSwitch/MenuBar/CompactAccountRowView.swift`
  责任：单行账号快切项，展示邮箱、类型角标、`5H/7D` 胶囊与当前账号标识。

### Reusable page content

- Create: `apps/mac-client/CodexSwitch/Settings/SettingsContentView.swift`
  责任：拆出可嵌入主窗口的设置内容，保留 `SettingsView` 作为窗口包装层过渡。
- Create: `apps/mac-client/CodexSwitch/ProviderSync/ProviderSyncContentView.swift`
  责任：拆出可嵌入主窗口的 Provider Sync 内容。
- Create: `apps/mac-client/CodexSwitch/Diagnostics/StatusContentView.swift`
  责任：拆出可嵌入主窗口的状态页内容。
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`
- Modify: `apps/mac-client/CodexSwitch/ProviderSync/ProviderSyncView.swift`
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusWindowView.swift`
  责任：将窗口专属 frame 包装与可复用内容分离。

### App wiring

- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
  责任：统一向主窗口提供账号页、设置页、同步页、状态页所需依赖。
- Modify: `apps/mac-client/CodexSwitchApp/App/AppDelegate.swift`
  责任：从“多个窗口 presenter”切换到“单一主窗口 presenter + 状态栏入口”。

### Tests

- Create: `apps/mac-client/CodexSwitchTests/MainWindow/MainWindowPresenterTests.swift`
- Create: `apps/mac-client/CodexSwitchTests/MainWindow/MainWindowViewTests.swift`
- Create: `apps/mac-client/CodexSwitchTests/Accounts/AccountManagementViewModelTests.swift`
- Create: `apps/mac-client/CodexSwitchTests/Accounts/AccountManagementViewTests.swift`
- Create: `apps/mac-client/CodexSwitchTests/MenuBar/QuickSwitchOverlayViewTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarActionTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarViewModelTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexArchivedAccountStoreTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexAuthImporterTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/Accounts/AccountRepositoryTests.swift`

## Task 1: 建立主窗口路由契约并收敛菜单动作

**Files:**
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowTab.swift`
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowRoute.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarActions.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift`
- Modify: `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarActionTests.swift`

- [ ] **Step 1: 写失败测试，固定新的主窗口动作契约**

```swift
func testOpenMainWindowDelegatesToActionHandler() {
    let handler = RecordingMenuBarActionHandler()
    let viewModel = MenuBarViewModel(service: MockMenuBarService(), actionHandler: handler)

    viewModel.openMainWindow()

    XCTAssertEqual(handler.recordedActions, [.openMainWindow(.accounts)])
}

func testOpenSettingsDelegatesToSettingsTabRoute() {
    let handler = RecordingMenuBarActionHandler()
    let viewModel = MenuBarViewModel(service: MockMenuBarService(), actionHandler: handler)

    viewModel.openSettings()

    XCTAssertEqual(handler.recordedActions, [.openMainWindow(.settings)])
}
```

- [ ] **Step 2: 运行测试，确认旧动作模型无法通过**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MenuBarActionTests`
Expected: FAIL，提示 `MenuBarAction` 不包含 `openMainWindow` 或断言与旧 `.openSettings` 不匹配。

- [ ] **Step 3: 实现最小主窗口路由类型与动作收敛**

```swift
public enum MainWindowTab: String, CaseIterable, Equatable {
    case accounts
    case providerSync
    case settings
    case status
}

public enum MenuBarAction: Equatable {
    case openMainWindow(MainWindowTab)
    case quit
}
```

```swift
public func openMainWindow() {
    actionHandler?.handle(.openMainWindow(.accounts))
}

public func openSettings() {
    actionHandler?.handle(.openMainWindow(.settings))
}
```

- [ ] **Step 4: 运行测试，确认新动作契约通过**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MenuBarActionTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add apps/mac-client/CodexSwitch/MainWindow/MainWindowTab.swift \
        apps/mac-client/CodexSwitch/MainWindow/MainWindowRoute.swift \
        apps/mac-client/CodexSwitch/MenuBar/MenuBarActions.swift \
        apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift \
        apps/mac-client/CodexSwitchTests/MenuBar/MenuBarActionTests.swift
git commit -m "refactor: 收敛菜单动作到主窗口路由"
```

## Task 2: 为归档账号引入显式顺序字段

**Files:**
- Modify: `apps/mac-client/CodexSwitch/Accounts/Account.swift`
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthModels.swift`
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthImporter.swift`
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexArchivedAccountStore.swift`
- Modify: `apps/mac-client/CodexSwitch/Accounts/AccountRepository.swift`
- Modify: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexAuthImporterTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexArchivedAccountStoreTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/Accounts/AccountRepositoryTests.swift`

- [ ] **Step 1: 写失败测试，固定顺序字段语义**

```swift
func testImporterAppendsNewAccountToEndOfManualOrder() throws {
    let first = try importer.importAuthData(sampleAuthData(email: "a@example.com"), source: .currentAuth)
    let second = try importer.importAuthData(sampleAuthData(email: "b@example.com"), source: .backupImport)

    XCTAssertEqual(first.manualOrder, 0)
    XCTAssertEqual(second.manualOrder, 1)
}

func testArchivedAccountStoreLoadsAccountsByManualOrder() async throws {
    let accounts = try await store.loadAccounts()
    XCTAssertEqual(accounts.map(\.id), ["acct-2", "acct-1", "acct-3"])
}
```

- [ ] **Step 2: 运行测试，确认当前实现只按文件名/导入时间推导顺序**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/CodexAuthImporterTests -only-testing:CodexSwitchTests/CodexArchivedAccountStoreTests -only-testing:CodexSwitchTests/AccountRepositoryTests`
Expected: FAIL，提示 `manualOrder` 缺失或加载顺序不符合预期。

- [ ] **Step 3: 实现显式顺序字段与默认追加逻辑**

```swift
public struct Account: Codable, Equatable, Identifiable {
    public let manualOrder: Int
    // ...
}

public struct CodexAccountMetadataEntry: Codable, Equatable {
    public let source: AccountSource
    public let lastImportedAt: Date
    public let manualOrder: Int
}
```

```swift
let nextOrder = (metadataCache.entries.values.map(\.manualOrder).max() ?? -1) + 1
metadataCache.entries[archiveFilename] = CodexAccountMetadataEntry(
    source: source,
    lastImportedAt: importedAt,
    manualOrder: nextOrder
)
```

```swift
return loadedAccounts.sorted {
    if $0.manualOrder != $1.manualOrder { return $0.manualOrder < $1.manualOrder }
    return $0.lastImportedAt < $1.lastImportedAt
}
```

```swift
public protocol AccountOrderPersisting {
    func saveManualOrder(idsInOrder: [String]) async throws
}
```

- [ ] **Step 4: 运行测试，确认账号顺序稳定持久化**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/CodexAuthImporterTests -only-testing:CodexSwitchTests/CodexArchivedAccountStoreTests -only-testing:CodexSwitchTests/AccountRepositoryTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add apps/mac-client/CodexSwitch/Accounts/Account.swift \
        apps/mac-client/CodexSwitch/CodexAuth/CodexAuthModels.swift \
        apps/mac-client/CodexSwitch/CodexAuth/CodexAuthImporter.swift \
        apps/mac-client/CodexSwitch/CodexAuth/CodexArchivedAccountStore.swift \
        apps/mac-client/CodexSwitch/Accounts/AccountRepository.swift \
        apps/mac-client/CodexSwitchTests/CodexAuth/CodexAuthImporterTests.swift \
        apps/mac-client/CodexSwitchTests/CodexAuth/CodexArchivedAccountStoreTests.swift \
        apps/mac-client/CodexSwitchTests/Accounts/AccountRepositoryTests.swift
git commit -m "feat: 为归档账号增加显式排序字段"
```

## Task 3: 创建账号管理服务与 `账号` Tab

**Files:**
- Create: `apps/mac-client/CodexSwitch/Accounts/AccountManagementService.swift`
- Create: `apps/mac-client/CodexSwitch/Accounts/AccountManagementViewModel.swift`
- Create: `apps/mac-client/CodexSwitch/Accounts/AccountManagementView.swift`
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Create: `apps/mac-client/CodexSwitchTests/Accounts/AccountManagementViewModelTests.swift`
- Create: `apps/mac-client/CodexSwitchTests/Accounts/AccountManagementViewTests.swift`

- [ ] **Step 1: 写失败测试，固定“账号页决定顺序真源”**

```swift
func testMoveDownPersistsManualOrderAndReloadsRows() async throws {
    let service = InMemoryAccountManagementService(accounts: [
        .fixture(id: "acct-1", order: 0),
        .fixture(id: "acct-2", order: 1),
    ])
    let viewModel = AccountManagementViewModel(service: service)

    await viewModel.load()
    await viewModel.moveDown(id: "acct-1")

    XCTAssertEqual(viewModel.rows.map(\.id), ["acct-2", "acct-1"])
    XCTAssertEqual(service.savedOrderIDs, ["acct-2", "acct-1"])
}
```

```swift
func testAccountManagementViewShowsMoveControlsAndUsageColumns() {
    let view = AccountManagementView(viewModel: .preview)
    XCTAssertTrue(view.columnTitles.contains("5H"))
    XCTAssertTrue(view.columnTitles.contains("7D"))
}
```

- [ ] **Step 2: 运行测试，确认账号管理页尚不存在**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/AccountManagementViewModelTests -only-testing:CodexSwitchTests/AccountManagementViewTests`
Expected: FAIL，提示类型不存在。

- [ ] **Step 3: 实现最小账号管理服务、ViewModel 与视图**

```swift
protocol AccountManagementServicing {
    func loadAccounts() async throws -> [Account]
    func saveOrder(ids: [String]) async throws
    func removeAccount(id: String) async throws
    func activateAccount(id: String) async throws
}
```

```swift
@MainActor
final class AccountManagementViewModel: ObservableObject {
    @Published private(set) var rows: [AccountManagementRowModel] = []

    func moveDown(id: String) async {
        // 调整 rows 顺序 -> 持久化 ids -> 重新加载
    }
}
```

```swift
struct AccountManagementService: AccountManagementServicing {
    let catalog: any AccountCatalog
    let orderStore: any AccountOrderPersisting
    let remover: (any AccountRemoving)?
    let activator: ActiveAccountController?
}
```

- [ ] **Step 4: 运行测试，确认账号页可加载、移动并展示必要列**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/AccountManagementViewModelTests -only-testing:CodexSwitchTests/AccountManagementViewTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add apps/mac-client/CodexSwitch/Accounts/AccountManagementService.swift \
        apps/mac-client/CodexSwitch/Accounts/AccountManagementViewModel.swift \
        apps/mac-client/CodexSwitch/Accounts/AccountManagementView.swift \
        apps/mac-client/CodexSwitch/App/AppEnvironment.swift \
        apps/mac-client/CodexSwitchTests/Accounts/AccountManagementViewModelTests.swift \
        apps/mac-client/CodexSwitchTests/Accounts/AccountManagementViewTests.swift
git commit -m "feat: 添加账号管理页与排序能力"
```

## Task 4: 构建统一主窗口并嵌入现有页面内容

**Files:**
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowPresenter.swift`
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowView.swift`
- Create: `apps/mac-client/CodexSwitch/MainWindow/MainWindowViewModel.swift`
- Create: `apps/mac-client/CodexSwitch/Settings/SettingsContentView.swift`
- Create: `apps/mac-client/CodexSwitch/ProviderSync/ProviderSyncContentView.swift`
- Create: `apps/mac-client/CodexSwitch/Diagnostics/StatusContentView.swift`
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`
- Modify: `apps/mac-client/CodexSwitch/ProviderSync/ProviderSyncView.swift`
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusWindowView.swift`
- Create: `apps/mac-client/CodexSwitchTests/MainWindow/MainWindowPresenterTests.swift`
- Create: `apps/mac-client/CodexSwitchTests/MainWindow/MainWindowViewTests.swift`

- [ ] **Step 1: 写失败测试，固定主窗口复用与 Tab 切换行为**

```swift
func testMainWindowPresenterReusesWindowAndUpdatesSelectedTab() {
    let presenter = MainWindowPresenter(
        makeViewModel: { MainWindowViewModel(selectedTab: .accounts) },
        // ...
    )

    presenter.present(route: .tab(.accounts))
    presenter.present(route: .tab(.settings))

    XCTAssertEqual(renderedTabs, [.accounts, .settings])
    XCTAssertEqual(makeCount, 1)
}
```

```swift
func testMainWindowViewExposesExpectedTabs() {
    let view = MainWindowView(viewModel: MainWindowViewModel(selectedTab: .accounts))
    XCTAssertEqual(view.tabLabels, ["账号", "Provider Sync", "设置", "状态"])
}
```

- [ ] **Step 2: 运行测试，确认主窗口容器尚未存在**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MainWindowPresenterTests -only-testing:CodexSwitchTests/MainWindowViewTests`
Expected: FAIL，提示主窗口类型缺失。

- [ ] **Step 3: 实现主窗口容器和可嵌入内容视图**

```swift
struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(MainWindowTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            currentContent
        }
    }
}
```

```swift
struct SettingsView: View {
    var body: some View {
        SettingsContentView(viewModel: viewModel)
            .frame(width: 440, height: 560)
    }
}
```

- [ ] **Step 4: 运行测试，确认主窗口和页面复用内容可工作**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MainWindowPresenterTests -only-testing:CodexSwitchTests/MainWindowViewTests -only-testing:CodexSwitchTests/SettingsViewTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add apps/mac-client/CodexSwitch/MainWindow/MainWindowPresenter.swift \
        apps/mac-client/CodexSwitch/MainWindow/MainWindowView.swift \
        apps/mac-client/CodexSwitch/MainWindow/MainWindowViewModel.swift \
        apps/mac-client/CodexSwitch/Settings/SettingsContentView.swift \
        apps/mac-client/CodexSwitch/ProviderSync/ProviderSyncContentView.swift \
        apps/mac-client/CodexSwitch/Diagnostics/StatusContentView.swift \
        apps/mac-client/CodexSwitch/Settings/SettingsView.swift \
        apps/mac-client/CodexSwitch/ProviderSync/ProviderSyncView.swift \
        apps/mac-client/CodexSwitch/Diagnostics/StatusWindowView.swift \
        apps/mac-client/CodexSwitchTests/MainWindow/MainWindowPresenterTests.swift \
        apps/mac-client/CodexSwitchTests/MainWindow/MainWindowViewTests.swift
git commit -m "feat: 添加统一主窗口与顶部标签导航"
```

## Task 5: 重构状态栏根菜单和快切浮层

**Files:**
- Create: `apps/mac-client/CodexSwitch/MenuBar/QuickSwitchOverlayView.swift`
- Create: `apps/mac-client/CodexSwitch/MenuBar/CompactAccountRowView.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarModels.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarPanelView.swift`
- Create: `apps/mac-client/CodexSwitchTests/MenuBar/QuickSwitchOverlayViewTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarViewModelTests.swift`

- [ ] **Step 1: 写失败测试，固定根菜单与快切行表现**

```swift
func testQuickSwitchRowsPreserveRepositoryOrderAndMarkActiveAccount() async {
    let viewModel = MenuBarViewModel(service: orderedSnapshotService)
    await viewModel.refresh()

    XCTAssertEqual(viewModel.quickSwitchRows.map(\.id), ["acct-3", "acct-1", "acct-2"])
    XCTAssertEqual(viewModel.quickSwitchRows.first?.tierBadgeText, "TEAM")
    XCTAssertEqual(viewModel.quickSwitchRows.first?.fiveHourLabel, "5H 42%")
}
```

```swift
func testQuickSwitchOverlayHasScrollableRowsAndNoManagementAction() {
    let view = QuickSwitchOverlayView(rows: sampleRows, onSelect: { _ in })
    XCTAssertFalse(view.actionLabels.contains("打开账号管理窗口"))
}
```

- [ ] **Step 2: 运行测试，确认当前菜单仍直接渲染长账号卡片**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MenuBarViewModelTests -only-testing:CodexSwitchTests/QuickSwitchOverlayViewTests`
Expected: FAIL，提示 `quickSwitchRows`/`QuickSwitchOverlayView` 不存在或旧断言失败。

- [ ] **Step 3: 实现紧凑快切行与根菜单改造**

```swift
public struct QuickSwitchRowModel: Identifiable, Equatable {
    public let id: String
    public let emailText: String
    public let tierBadgeText: String
    public let fiveHourLabel: String
    public let weeklyLabel: String
    public let isActive: Bool
}
```

```swift
VStack(alignment: .leading, spacing: 8) {
    headerSection
    actionRow(title: "快速切换", systemImage: "arrow.left.arrow.right")
        .onHover { isHovering in updateQuickSwitchHover(isHovering) }
    actionRow(title: "打开主窗口", systemImage: "rectangle.on.rectangle")
    actionRow(title: "设置", systemImage: "gearshape")
    actionRow(title: "退出", systemImage: "power")
}
```

- [ ] **Step 4: 运行测试，确认快切列表单行展示且不带管理入口**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MenuBarViewModelTests -only-testing:CodexSwitchTests/QuickSwitchOverlayViewTests -only-testing:CodexSwitchTests/MenuBarActionTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add apps/mac-client/CodexSwitch/MenuBar/QuickSwitchOverlayView.swift \
        apps/mac-client/CodexSwitch/MenuBar/CompactAccountRowView.swift \
        apps/mac-client/CodexSwitch/MenuBar/MenuBarModels.swift \
        apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift \
        apps/mac-client/CodexSwitch/MenuBar/MenuBarPanelView.swift \
        apps/mac-client/CodexSwitchTests/MenuBar/QuickSwitchOverlayViewTests.swift \
        apps/mac-client/CodexSwitchTests/MenuBar/MenuBarViewModelTests.swift
git commit -m "feat: 添加状态栏快切浮层"
```

## Task 6: 用单一主窗口 presenter 替换现有多窗口入口

**Files:**
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Modify: `apps/mac-client/CodexSwitchApp/App/AppDelegate.swift`
- Create: `apps/mac-client/CodexSwitchTests/MainWindow/AppDelegateMainWindowTests.swift`

- [ ] **Step 1: 写失败测试，固定“状态栏入口打开单一主窗口”的最终 wiring**

```swift
func testAppDelegateOpensSharedMainWindowForSettingsAndAccountsRoutes() {
    let delegate = AppDelegate()
    delegate.handle(.openMainWindow(.accounts))
    delegate.handle(.openMainWindow(.settings))

    XCTAssertEqual(presentedRoutes, [.accounts, .settings])
    XCTAssertEqual(makeMainWindowCount, 1)
}
```

- [ ] **Step 2: 运行测试，确认当前 AppDelegate 仍持有多个窗口 presenter**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/AppDelegateMainWindowTests`
Expected: FAIL，提示 `AppDelegate` 仍按 `.openSettings` / `.openProviderSync` / `.openStatusPage` 分散处理。

- [ ] **Step 3: 实现单一主窗口 presenter wiring**

```swift
final class AppDelegate: NSObject, NSApplicationDelegate, MenuBarActionHandling {
    private var mainWindowPresenter: MainWindowPresenter?

    func handle(_ action: MenuBarAction) {
        switch action {
        case .openMainWindow(let tab):
            mainWindowPresenter?.present(route: .tab(tab))
        case .quit:
            NSApp.terminate(nil)
        }
    }
}
```

- [ ] **Step 4: 运行回归测试，确认菜单动作、主窗口和账号排序链路联通**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/AppDelegateMainWindowTests -only-testing:CodexSwitchTests/MainWindowPresenterTests -only-testing:CodexSwitchTests/MenuBarActionTests -only-testing:CodexSwitchTests/AccountManagementViewModelTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add apps/mac-client/CodexSwitch/App/AppEnvironment.swift \
        apps/mac-client/CodexSwitchApp/App/AppDelegate.swift \
        apps/mac-client/CodexSwitchTests/MainWindow/AppDelegateMainWindowTests.swift
git commit -m "refactor: 用统一主窗口替换多窗口入口"
```

## Task 7: 做端到端回归并更新完成状态

**Files:**
- Modify: `docs/superpowers/plans/2026-04-20-menubar-main-window-implementation.md`
- Optional Modify: `docs/usage-refresh.md`（如果入口文案变化需要同步说明）

- [ ] **Step 1: 运行主回归测试集**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS'`
Expected: PASS，全量单元测试和现有集成测试通过。

- [ ] **Step 2: 手工验证关键交互**

Run:

```bash
xcodebuild build -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS'
```

Expected:
- 状态栏一级菜单不再展示长账号卡片列表。
- hover `快速切换` 后出现可滚动浮层。
- 点击快切行成功切换账号并关闭菜单。
- `打开主窗口` 默认进入 `账号` Tab。
- 主窗口顶部 tabs 可切换 `账号` / `Provider Sync` / `设置` / `状态`。

- [ ] **Step 3: 将本计划所有复选框更新为完成状态**

```markdown
- [x] Step ...
```

- [ ] **Step 4: 如有必要，补充用户文档**

```markdown
在 `docs/usage-refresh.md` 或对应 README 中补充：
- 状态栏现在只负责快速切换
- 完整管理入口统一迁移到主窗口
```

- [ ] **Step 5: 提交**

```bash
git add docs/superpowers/plans/2026-04-20-menubar-main-window-implementation.md docs/usage-refresh.md
git commit -m "docs: 更新主窗口与快切实现计划状态"
```

## Notes for Execution

- 先做 Task 1 和 Task 2，再开始 UI 改造；否则快切列表和账号页会缺少稳定顺序真源。
- Task 4 完成前，不要急着删除旧窗口 presenter；先让主窗口能承载内容，再切换入口。
- Task 5 的 hover 行为需要配合短延迟和可达区域，避免浮层闪烁；实现时优先在 view 层封装，不要把 hover 定时器塞进数据层。
- 如果某一步需要把 `SettingsView` / `ProviderSyncView` / `StatusWindowView` 拆成内容层和窗口包装层，先补视图测试再动结构。
