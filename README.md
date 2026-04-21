# Codex Switch

Codex Switch 是一个以桌面软件体验为目标的多账号 Codex 管理器，当前主线实现正在迁移到 `Rust + Tauri + React + shadcn/ui`。

## Current Status

仓库已经完成第一轮 Tauri 重构骨架，当前可用内容包括：

- `apps/rust-client/src-tauri/` 下的 Tauri 2 + Rust 后端
- `apps/rust-client/ui/` 下的 React + TypeScript + Tailwind + shadcn/ui 前端
- 主窗口 + 托盘面板双壳层
- `.codex` 路径、auth 导入/归档/切换、JWT 解码、usage 刷新、diagnostics、settings、Provider Sync 基础闭环
- OpenSpec、分析文档、实施计划与进度跟踪

Swift 版本仍保留在 `apps/mac-client/`，当前仅作为行为基线和迁移参考，不再是主实施方向。

## Product Direction

- 主窗口为主入口，托盘为快速入口
- UI 去 Web 化，强调桌面软件质感，而不是网页式 SaaS 后台
- 保持 `.codex` 数据兼容：
  - `~/.codex/auth.json`
  - `~/.codex/accounts/*.json`
  - `~/.codex/accounts/usage-cache.json`
  - `~/.codex/sessions/**/rollout-*.jsonl`
  - `~/.codex/config.toml`
  - `~/.codex/state_5.sqlite`
  - `~/.codex/codex-switch/*.log`

## Repository Layout

- `apps/rust-client/`: Tauri 桌面端主实现
- `apps/mac-client/`: 旧 Swift/macOS 基线实现
- `docs/analysis/`: 重构分析文档
- `docs/plan/`: 分阶段实施计划
- `docs/progress/`: 持续进度追踪
- `openspec/changes/refactor-desktop-to-tauri-rust/`: 当前重构规格
- `tests/`: 仓库级辅助测试

## Local Development

### Frontend

```bash
cd apps/rust-client/ui
npm install
npm test
npm run build
```

### Rust / Tauri Backend

```bash
cd apps/rust-client/src-tauri
cargo fmt --check
cargo test
```

### Tauri App

正式联调时由 Tauri 使用：

- `apps/rust-client/ui` 作为前端工作区
- `apps/rust-client/src-tauri` 作为桌面运行时

本地构建 macOS app bundle：

```bash
cd apps/rust-client/ui
npm run tauri build -- --bundles app
```

输出路径：

- `apps/rust-client/src-tauri/target/release/bundle/macos/Codex Switch.app`

## Verification

当前已验证：

- `openspec validate refactor-desktop-to-tauri-rust --strict`
- `npm test`
- `npm run build`
- `cargo test`
- `cargo build`
- `npm run tauri build -- --bundles app`

## Migration Notes

- 当前实现已经覆盖主要骨架和核心服务，但仍在继续收口高级能力与完整验收。
- 浏览器登录已经切换到桌面 broker：本地 callback server + PKCE 授权 URL + token exchange + `auth.json` 写回。
- `Launch at login` 已开始接入 Tauri autostart 插件，不再只是本地偏好位。
- 账号页已经支持通过原生文件选择器导入备份 `auth.json`。
- Swift 代码暂不删除，等 Tauri 版本进一步达到更高对等度后再进行最终清理。
