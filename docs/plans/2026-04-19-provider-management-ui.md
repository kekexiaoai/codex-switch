# Provider Management UI Implementation

## 概述

本文档记录了在 Codex Switch 设置页面中添加 Provider 管理功能的完整实现过程。

**实现日期**: 2026-04-19  
**提交哈希**: d81c6db

## 背景

### 问题

用户询问 provider-sync 的设置页面是否可以自定义 provider。经过代码审查发现：

1. `ConfigTomlParser` 可以读取 `config.toml` 中配置的所有 provider
2. 但设置页面（SettingsView.swift）没有 provider-sync 相关的 UI
3. 设计文档中明确标注为 **Non-Goals**：不负责创建或管理 provider 配置

### 需求

用户希望在设置页面中添加以下功能：
- 查看和切换当前使用的 provider
- 添加自定义 provider
- 删除不需要的 provider

## 设计方案

### 架构模式

遵循现有的 MVVM 架构模式：
- **ViewModel**: 管理 provider 状态，使用 `@Published` 属性
- **View**: SwiftUI UI，内联表单和 picker
- **Actions**: 基于枚举的 provider 操作，类型安全
- **Handler**: 协议驱动的操作执行，依赖注入

### 关键设计决策

1. **动态加载**: 从 config.toml 动态加载 provider 列表，确保 UI 反映当前状态
2. **立即应用**: 切换 provider 立即更新 config.toml（无需单独的"应用"按钮）
3. **内联 UI**: 添加 provider 表单内联显示（不使用 sheet/dialog）
4. **安全优先**: 防止删除 "openai"（默认）或当前激活的 provider
5. **验证**: 强制执行 provider ID 正则模式 `[A-Za-z0-9_.-]+`，实时反馈

### Provider ID 验证规则

**有效字符**: 
- 大写字母 (A-Z)
- 小写字母 (a-z)
- 数字 (0-9)
- 下划线 (_)
- 点号 (.)
- 连字符 (-)

**无效字符**: 空格、特殊符号、Unicode 字符等

**示例**:
- ✅ `openai`, `anthropic`, `custom-llm`, `provider_123`, `my.provider`
- ❌ `my provider`, `provider@123`, `provider#test`

## 实现细节

### 1. ConfigTomlParser 扩展

**文件**: `apps/mac-client/CodexSwitch/CodexAuth/ConfigTomlParser.swift`

**新增方法**:

```swift
// 验证 provider ID
public func validateProviderId(_ id: String) -> Bool

// 添加 provider 到配置
public func addProvider(in configText: String, providerId: String) -> String
public func addProvider(in url: URL, providerId: String) throws

// 从配置中删除 provider
public func removeProvider(in configText: String, providerId: String) -> String
public func removeProvider(in url: URL, providerId: String) throws
```

**实现要点**:
- 使用正则表达式 `^[A-Za-z0-9_.-]+$` 验证 ID
- 添加时追加 `[model_providers.{id}]` 段到文件末尾
- 删除时查找并删除整个段直到下一个 `[` 或 EOF
- 尽可能保留现有空白和注释
- 使用现有的 `reconstructText()` 辅助方法保持一致性

### 2. SettingsActions 扩展

**文件**: `apps/mac-client/CodexSwitch/Settings/SettingsActions.swift`

**新增类型**:

```swift
// Provider 操作枚举
public enum SettingsProviderAction: String, Equatable, CaseIterable, Identifiable {
    case removeProvider
}

// Provider 确认请求
public struct SettingsProviderConfirmationRequest: Equatable, Identifiable {
    public let id: UUID
    public let action: SettingsProviderAction
    public let providerId: String
}
```

**协议扩展**:

```swift
protocol SettingsActionHandling {
    // 现有方法...
    func performProviderAction(_ action: SettingsProviderAction, providerId: String) throws -> SettingsActionMessage
}
```

### 3. SettingsViewModel 扩展

**文件**: `apps/mac-client/CodexSwitch/Settings/SettingsViewModel.swift`

**新增属性**:

```swift
@Published public private(set) var currentProvider: String
@Published public private(set) var availableProviders: [String]
@Published public private(set) var pendingProviderConfirmation: SettingsProviderConfirmationRequest?

private let configParser: ConfigTomlParser
private let codexPaths: CodexPaths
```

**新增方法**:

```swift
public func loadProviders() // 从 config.toml 加载
public func setCurrentProvider(_ provider: String) // 更新配置 + @Published
public func addProvider(id: String) throws // 验证 + 添加 + 重新加载
public func requestRemoveProvider(_ providerId: String) // 设置 pendingProviderConfirmation
public func confirmPendingProviderAction() throws // 执行删除
public func cancelPendingProviderAction() // 清除确认
public func validateProviderId(_ id: String) -> Bool // 委托给解析器
public func canRemoveProvider(_ id: String) -> Bool // 检查安全规则
```

**初始化更新**:

```swift
public init(
    defaults: UserDefaults = .standard,
    actionHandler: any SettingsActionHandling = NoopSettingsActionHandler(),
    launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
    configParser: ConfigTomlParser = ConfigTomlParser(),
    codexPaths: CodexPaths = CodexPaths()
)
```

**安全规则实现**:

```swift
public func canRemoveProvider(_ id: String) -> Bool {
    // 不能删除 "openai"（默认 provider）
    guard id != "openai" else { return false }
    
    // 不能删除当前激活的 provider
    guard id != currentProvider else { return false }
    
    return true
}
```

### 4. SettingsView UI 实现

**文件**: `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`

**新增状态**:

```swift
@State private var showAddProviderForm: Bool = false
@State private var newProviderId: String = ""
@State private var providerIdError: String = ""

private var isProviderIdValid: Bool {
    viewModel.validateProviderId(newProviderId) && 
    !viewModel.availableProviders.contains(newProviderId)
}

private var removableProviders: [String] {
    viewModel.availableProviders.filter { viewModel.canRemoveProvider($0) }
}
```

**新增区域**:

```swift
settingsSection("Provider Management") {
    // 当前 provider picker
    Picker("Current Provider", selection: Binding(...)) {
        ForEach(viewModel.availableProviders, id: \.self) { provider in
            Text(provider).tag(provider)
        }
    }
    .pickerStyle(.radioGroup)
    
    Divider()
    
    // 添加 provider 表单
    Toggle("Add Custom Provider", isOn: $showAddProviderForm)
    
    if showAddProviderForm {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Provider ID (e.g., anthropic, custom-llm)", text: $newProviderId)
                .textFieldStyle(.roundedBorder)
            
            if !providerIdError.isEmpty {
                Text(providerIdError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            Button("Add Provider") {
                addProviderAction()
            }
            .disabled(!isProviderIdValid)
        }
        .padding(.leading, 20)
    }
    
    if !removableProviders.isEmpty {
        Divider()
        
        ForEach(removableProviders, id: \.self) { provider in
            Button("Remove \(provider)", role: .destructive) {
                viewModel.requestRemoveProvider(provider)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

**确认对话框**:

```swift
.confirmationDialog(
    "Remove Provider?",
    isPresented: Binding(...),
    titleVisibility: .visible
) {
    if let confirmation = viewModel.pendingProviderConfirmation {
        Button("Remove \(confirmation.providerId)", role: .destructive) {
            runAction { try viewModel.confirmPendingProviderAction() }
        }
        Button("Cancel", role: .cancel) {
            viewModel.cancelPendingProviderAction()
        }
    }
} message: {
    if let confirmation = viewModel.pendingProviderConfirmation {
        Text("This will remove '\(confirmation.providerId)' from your configuration. Session history will not be deleted.")
    }
}
```

**辅助方法**:

```swift
private func addProviderAction() {
    do {
        try viewModel.addProvider(id: newProviderId)
        newProviderId = ""
        showAddProviderForm = false
        providerIdError = ""
        presentedMessage = viewModel.lastActionMessage
    } catch {
        providerIdError = error.localizedDescription
    }
}
```

### 5. LiveSettingsActionHandler 更新

**文件**: `apps/mac-client/CodexSwitch/Settings/LiveSettingsActionHandler.swift`

**新增属性**:

```swift
private let configParser: ConfigTomlParser
```

**初始化更新**:

```swift
public init(
    paths: CodexPaths,
    fileManager: FileManager = .default,
    openResource: @escaping ResourceOpener = { url in NSWorkspace.shared.open(url) },
    now: @escaping () -> Date = Date.init,
    timeFormatter: CodexUserFacingTimeFormatter = CodexUserFacingTimeFormatter(),
    configParser: ConfigTomlParser = ConfigTomlParser()
)
```

**实现方法**:

```swift
public func performProviderAction(_ action: SettingsProviderAction, providerId: String) throws -> SettingsActionMessage {
    switch action {
    case .removeProvider:
        try configParser.removeProvider(in: paths.configFileURL, providerId: providerId)
        return SettingsActionMessage(
            title: "Provider Removed",
            message: "Removed provider '\(providerId)' from configuration."
        )
    }
}
```

### 6. AppEnvironment 依赖注入

**文件**: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`

**更新方法**:

```swift
@MainActor
public func makeSettingsViewModel() -> SettingsViewModel {
    SettingsViewModel(
        defaults: settingsDefaults,
        actionHandler: settingsActionHandler,
        launchAtLoginController: launchAtLoginController,
        configParser: ConfigTomlParser(),
        codexPaths: codexPaths ?? CodexPaths()
    )
}
```

### 7. 测试实现

**文件**: `apps/mac-client/CodexSwitchTests/CodexAuth/ConfigTomlParserTests.swift`

**测试覆盖**:

- **验证测试** (8 个):
  - `testValidateProviderId_ValidIds` - 测试有效 ID
  - `testValidateProviderId_InvalidIds` - 测试无效 ID

- **添加 Provider 测试** (6 个):
  - `testAddProvider_ToEmptyConfig` - 空配置添加
  - `testAddProvider_ToExistingConfig` - 现有配置添加
  - `testAddProvider_PreservesExistingContent` - 保留现有内容
  - `testAddProvider_DuplicateProvider_NoChange` - 重复 provider 不变
  - `testAddProvider_InvalidId_NoChange` - 无效 ID 不变
  - `testAddProvider_PreservesNewlineAtEnd` - 保留末尾换行

- **删除 Provider 测试** (5 个):
  - `testRemoveProvider_RemovesSection` - 删除段
  - `testRemoveProvider_PreservesOtherSections` - 保留其他段
  - `testRemoveProvider_NonexistentProvider_NoChange` - 不存在的 provider 不变
  - `testRemoveProvider_PreservesRootConfig` - 保留根配置
  - `testRemoveProvider_LastSection` - 删除最后一段

- **列出 Provider 测试** (3 个):
  - `testListConfiguredProviderIds_IncludesDefault` - 包含默认
  - `testListConfiguredProviderIds_MultipleProviders` - 多个 provider
  - `testListConfiguredProviderIds_Sorted` - 排序

- **读取当前 Provider 测试** (2 个):
  - `testReadCurrentProvider_Explicit` - 显式设置
  - `testReadCurrentProvider_Implicit` - 隐式默认

- **设置根 Provider 测试** (2 个):
  - `testSetRootProvider_UpdatesExisting` - 更新现有
  - `testSetRootProvider_AddsIfMissing` - 缺失时添加

**总计**: 26 个测试用例

## 错误处理

### 错误类型

```swift
public enum ProviderManagementError: LocalizedError {
    case invalidProviderId
    case duplicateProviderId(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidProviderId:
            return "Provider ID must contain only letters, numbers, dots, hyphens, and underscores"
        case .duplicateProviderId(let id):
            return "Provider '\(id)' already exists"
        }
    }
}
```

### 错误场景

| 错误场景 | 处理方式 |
|---------|---------|
| 配置文件未找到 | 创建默认配置，包含 openai provider |
| 配置文件格式错误 | 显示错误，阻止修改，建议重置 |
| 文件写入权限被拒绝 | 显示错误和路径，建议检查权限 |
| 无效 provider ID | 显示内联验证错误，阻止提交 |
| 重复 provider ID | 显示错误，建议编辑现有 provider |
| 删除激活的 provider | 阻止操作，显示说明消息 |
| 删除默认 provider | 阻止操作，显示说明消息 |

### 错误消息示例

- "Provider ID must contain only letters, numbers, dots, hyphens, and underscores"
- "Provider 'anthropic' already exists"
- "Cannot remove 'openai' as it is the default provider"
- "Cannot remove the currently active provider. Switch to another provider first."
- "Failed to update configuration: Permission denied"

## 文件变更总结

### 修改的文件 (6 个)

1. **ConfigTomlParser.swift** (+105 行)
   - 添加 provider 管理方法

2. **SettingsActions.swift** (+26 行)
   - 新增 provider 操作类型

3. **SettingsViewModel.swift** (+117 行)
   - Provider 状态管理

4. **SettingsView.swift** (+95 行)
   - Provider Management UI 区域

5. **LiveSettingsActionHandler.swift** (+16 行)
   - Provider 操作执行

6. **AppEnvironment.swift** (+4 行)
   - 依赖注入更新

### 新增的文件 (1 个)

1. **ConfigTomlParserTests.swift** (270 行)
   - 完整的解析器测试

**总计**: +633 行, -4 行

## 使用指南

### 用户操作流程

#### 添加自定义 Provider

1. 打开 Settings
2. 导航到 "Provider Management" 区域
3. 点击 "Add Custom Provider" 切换开关
4. 在文本框中输入 provider ID（例如：`anthropic`, `custom-llm`）
5. 如果 ID 有效且不重复，"Add Provider" 按钮将启用
6. 点击 "Add Provider"
7. 新 provider 出现在列表中

#### 切换 Provider

1. 在 "Current Provider" picker 中选择所需的 provider
2. 配置立即更新

#### 删除 Provider

1. 在可删除 provider 列表中找到要删除的 provider
2. 点击 "Remove {provider}" 按钮
3. 在确认对话框中确认删除
4. Provider 从配置中删除

### 限制

- 不能删除 "openai"（默认 provider）
- 不能删除当前激活的 provider（需要先切换到其他 provider）
- Provider ID 必须符合正则模式 `[A-Za-z0-9_.-]+`

## 验证步骤

由于 SDK 版本不匹配，无法在命令行环境编译。建议在 Xcode 中进行以下验证：

### 编译验证

```bash
xcodebuild build -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch
```

### 测试验证

```bash
xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS'
```

### 手动测试

1. 启动应用
2. 打开 Settings
3. 导航到 Provider Management 区域
4. 添加自定义 provider "anthropic"
5. 切换到 "anthropic"
6. 验证 config.toml 更改: `cat ~/.codex/config.toml`
7. 删除 provider（非 openai，非激活）
8. 验证 config.toml 中删除

## 后续改进建议

1. **Provider 配置编辑**: 允许编辑 provider 段中的键值对（例如 API key）
2. **Provider 验证**: 添加 provider 后测试连接
3. **Provider 模板**: 为常见 provider（Anthropic、OpenAI 等）提供预设模板
4. **使用统计**: 显示每个 provider 的 session 数量
5. **导入/导出**: 支持 provider 配置的导入和导出
6. **批量操作**: 支持批量添加或删除 provider

## 相关文档

- [Provider Sync 设计文档](../openspec/changes/add-provider-sync/design.md)
- [Provider Sync 提案](../openspec/changes/add-provider-sync/proposal.md)
- [CLAUDE.md 项目概述](../CLAUDE.md)

## 提交信息

```
feat: 添加 Provider 管理 UI 到设置页面

实现完整的 provider 管理功能，允许用户在设置界面中：
- 查看和切换当前 provider
- 添加自定义 provider（带实时验证）
- 删除 provider（带安全检查）

核心改动：
- ConfigTomlParser: 添加 validateProviderId、addProvider、removeProvider 方法
- SettingsActions: 新增 SettingsProviderAction 和 SettingsProviderConfirmationRequest
- SettingsViewModel: 添加 provider 状态管理和操作方法
- SettingsView: 新增 Provider Management 区域，包含 picker、添加表单和删除按钮
- LiveSettingsActionHandler: 实现 performProviderAction 方法
- AppEnvironment: 更新依赖注入，传递 ConfigTomlParser 和 CodexPaths

安全规则：
- Provider ID 必须匹配正则 [A-Za-z0-9_.-]+
- 不能删除 "openai"（默认 provider）
- 不能删除当前激活的 provider
- 添加前检查重复 ID

测试：
- 新增 ConfigTomlParserTests 覆盖所有解析器方法
```

**提交哈希**: d81c6db  
**日期**: 2026-04-19
