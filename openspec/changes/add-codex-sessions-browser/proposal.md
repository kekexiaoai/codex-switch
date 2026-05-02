# Change: 新增 Codex 历史会话浏览

## Why
Codex Switch 已经读取 `~/.codex` 中的账号、usage、rollout 和 provider 数据，但缺少对 Codex CLI 历史会话的直接浏览能力。用户当前需要依赖 `codex-run` 启动单独 Web 服务查看历史会话，这与桌面客户端的本地工具定位不一致。

## What Changes
- 新增独立 `Sessions` 页面，用于浏览 `~/.codex/history.jsonl` 与 `~/.codex/sessions/**/*.jsonl`。
- Rust 后端提供会话列表、项目筛选数据、会话详情读取命令。
- 前端提供项目筛选、关键字搜索、会话列表和会话详情预览。
- Provider Sync 保持 provider 维护职责，不承载完整会话浏览流程。

## Impact
- Affected specs: `codex-sessions`
- Affected code: `apps/rust-client/src-tauri/src/*`, `apps/rust-client/ui/src/*`
