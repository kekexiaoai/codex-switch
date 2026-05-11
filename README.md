# Codex Switch

Codex Switch 是一个桌面端 Codex 账号管理器，用来在多套 Codex 登录态之间切换、查看用量、同步 provider 配置，并保留对现有 `~/.codex` 数据结构的兼容。

当前主线实现是 `Rust + Tauri 2 + React + Tailwind/shadcn-ui`。旧的 Swift/macOS 客户端仍保留在仓库中，主要作为迁移参考和行为基线。

## 功能概览

- 管理多个 Codex 账号归档，并一键切换当前 `auth.json`
- 从当前登录态或备份文件导入账号
- 刷新并查看 Codex usage 摘要
- 扫描 Codex sessions，按项目浏览历史会话
- 同步和切换 `~/.codex/config.toml` 中的 provider 配置
- 提供主窗口和托盘快速入口
- 支持诊断日志、设置项和测试目录覆盖

## 安装包

通过 GitHub Release 发布的版本会附带以下产物：

- macOS arm64：DMG
- macOS x86_64：DMG
- Windows x64：NSIS 安装包
- Linux x64：DEB 与 AppImage

Linux 产物在 Ubuntu 22.04 runner 上构建，面向 22.04 及更新的 LTS 版本使用。Ubuntu/Debian 用户优先选择 DEB；其他发行版可尝试 AppImage。

## 发版

推送 `v*` tag 会触发 `Release` workflow，并发布跨平台安装包：

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

也可以在 GitHub Actions 手动运行 `Package` workflow，对指定分支或 commit 生成临时构建产物。

## 本地开发

安装前端依赖：

```bash
cd apps/rust-client/ui
npm install
```

运行前端测试和构建：

```bash
cd apps/rust-client/ui
npm test
npm run build
```

运行 Rust 后端测试：

```bash
cd apps/rust-client/src-tauri
cargo fmt --check
cargo test
```

构建本机桌面应用：

```bash
cd apps/rust-client/ui
npm run tauri build
```

按平台指定安装包类型：

```bash
# macOS
npm run tauri build -- --bundles dmg

# Windows
npm run tauri build -- --bundles nsis

# Linux
npm run tauri build -- --bundles deb,appimage
```

## 测试目录覆盖

为了做本地回归或端到端验收，可以把应用指向临时 `.codex` 目录，避免修改真实用户数据：

```bash
export CODEX_SWITCH_CODEX_DIR=/path/to/test/.codex
export CODEX_SWITCH_CONFIG_DIR=/path/to/test/config
```

应用启动和 `AppState::new()` 会优先使用这些路径。

## 仓库结构

- `apps/rust-client/`：当前 Tauri 桌面端主实现
- `apps/rust-client/src-tauri/`：Rust 后端、Tauri commands、托盘与窗口壳
- `apps/rust-client/ui/`：React 前端
- `apps/mac-client/`：旧 Swift/macOS 实现
- `docs/`：分析、计划、进度和发布文档
- `openspec/`：规格和变更记录
- `tests/`：仓库级辅助测试

## 数据兼容

Codex Switch 读写现有 Codex 数据位置：

- `~/.codex/auth.json`
- `~/.codex/accounts/*.json`
- `~/.codex/accounts/usage-cache.json`
- `~/.codex/sessions/**/rollout-*.jsonl`
- `~/.codex/config.toml`
- `~/.codex/state_5.sqlite`
- `~/.codex/codex-switch/*.log`

修改账号、provider 或配置前，应用会尽量通过归档和备份保留可恢复路径。
