# Codex Switch 模块盘点

## Swift 现有模块

### Accounts

- `Account.swift`
- `AccountRepository.swift`
- `ApplicationSupportAccountStore.swift`
- `KeychainCredentialStore.swift`
- `AccountManagement*.swift`

职责：

- 账号元数据、归档索引、显示字段
- 应用内账号管理与持久化

迁移策略：

- Rust `core/accounts` + `infra/storage`
- 前端保留列表/详情/操作视图，但不复刻 Swift 结构

### CodexAuth / Switching

- `CodexAuthFileStore.swift`
- `CodexAuthImporter.swift`
- `CodexJWTDecoder.swift`
- `CodexPaths.swift`
- `CodexUsage*.swift`
- `CodexLoginCoordinator.swift`
- `DesktopCodexLoginBroker.swift`
- `ActiveAccountController.swift`
- `CodexAccountSwitcher.swift`

职责：

- `.codex` 路径解析
- 当前 auth 导入、备份 auth 导入
- JWT claims 提取
- 账号切换
- Usage 解析与回退
- 桌面浏览器登录

迁移策略：

- 作为第一优先级迁移到 Rust
- 与 `.codex` 的兼容性视为外部契约

### ProviderSync

- `CodexConfigParser.swift`
- `CodexSessionScanner.swift`
- `CodexProviderSQLite.swift`
- `ProviderSyncBackupManager.swift`
- `ProviderSyncService.swift`

职责：

- 解析/改写 `config.toml`
- 扫描并重写 rollout session meta
- 更新 `state_5.sqlite`
- 创建/恢复/清理备份

迁移策略：

- 原样迁移核心行为到 Rust
- UI 以主窗口工具页重新表达

### MenuBar / MainWindow / Settings / Diagnostics

- `MenuBar*.swift`
- `MainWindow*.swift`
- `Settings*.swift`
- `Status*.swift`

职责：

- 菜单栏快切
- 主窗口导航与分区
- 设置与偏好
- 状态页与日志诊断

迁移策略：

- 统一重构为 Tauri 多窗口/托盘 + React 桌面壳
- 不再维持 SwiftUI 窗口 presenter 结构

## 新 Tauri 模块规划

### Rust

- `src-tauri/src/core/accounts`
- `src-tauri/src/core/auth`
- `src-tauri/src/core/usage`
- `src-tauri/src/core/provider_sync`
- `src-tauri/src/core/settings`
- `src-tauri/src/core/diagnostics`
- `src-tauri/src/infra/*`
- `src-tauri/src/platform/*`
- `src-tauri/src/commands/*`
- `src-tauri/src/state/*`

### React

- `ui/src/features/accounts`
- `ui/src/features/usage`
- `ui/src/features/provider-sync`
- `ui/src/features/diagnostics`
- `ui/src/features/settings`
- `ui/src/components/shell`
- `ui/src/components/primitives`
- `ui/src/lib/tauri`

## 复杂度评估

- 账号与 auth 流程：高
- Usage 解析与远端回退：高
- Provider Sync：高
- 主窗口 UI 重构：中高
- 托盘壳与多窗口：中
- 设置/诊断：中
