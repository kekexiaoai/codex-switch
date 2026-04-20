# rust-client

`apps/rust-client` 是 Codex Switch 的当前桌面端主实现目录。

## Structure

- `src-tauri/`: Rust + Tauri 运行时、commands、核心服务、托盘与窗口壳
- `ui/`: React + TypeScript + Tailwind + shadcn/ui 主窗口与托盘面板

## Commands

前端主要通过以下 Tauri commands 调用后端能力：

- `app_show_main_window`
- `app_open_view`
- `app_quit`
- `accounts_list`
- `accounts_import_current`
- `accounts_import_backup`
- `accounts_login_start`
- `accounts_switch`
- `usage_refresh`
- `provider_sync_status`
- `provider_sync_run`
- `provider_switch`
- `provider_sync_backups`
- `provider_sync_restore`
- `provider_sync_prune`
- `settings_get`
- `settings_update`
- `diagnostics_recent`

## Design Direction

- 去 Web 化
- 主窗口为主，托盘为辅
- UI 使用 shadcn/ui 原语，但统一收口为桌面工具风格
- 所有 `.codex` 文件读写都在 Rust 后端中完成
