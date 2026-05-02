# Design: Codex 历史会话浏览

## Context
`codex-run` 证明 Codex CLI 历史会话可以从 `~/.codex/history.jsonl` 与 `~/.codex/sessions/**/*.jsonl` 构建索引并展示。Codex Switch 的重构方向要求 Rust 负责本地文件系统读取，React 只负责视图状态，因此不能把 `codex-run` 的 Web server 直接嵌入。

## Goals
- 使用 Rust 原生读取 Codex 历史会话，不依赖全局 npm 包或 Node 运行时。
- 新增独立 Sessions 导航页，避免 Provider Sync 页面职责膨胀。
- 第一版提供可靠的只读浏览：列表、项目过滤、搜索、详情。

## Non-Goals
- 不实现 `codex-run` 的交互式 Codex bridge、发消息、停止生成、Plan mode。
- 不修改 `~/.codex` 会话文件。
- 不引入新的数据库索引，第一版使用按需扫描和轻量内存聚合。

## Data Model
- `SessionListItem`: `id`, `display`, `timestamp`, `project`, `projectName`, `filePath`, `messageCount`
- `SessionDetail`: `session`, `messages`
- `SessionMessage`: `role`, `kind`, `text`, `timestamp`

## Rust Modules
- 新增 `sessions.rs`，负责路径扫描、history 读取、jsonl 解析、DTO 构造。
- `commands.rs` 暴露 `sessions_list`、`sessions_projects`、`sessions_get`。
- `models.rs` 定义 DTO。

## UI
- `Sidebar` 新增 `Sessions`。
- `SessionsView` 使用桌面工具布局：左侧筛选与会话列表，右侧详情流。
- 详情展示优先压缩信息密度，避免长页面 marketing 风格。
