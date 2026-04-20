# Codex Switch Tauri 重构项目概览

## 当前状态

仓库当前主实现位于 `apps/mac-client`，技术栈为 SwiftUI + AppKit + XCTest，围绕 macOS 菜单栏应用构建。现有功能已经覆盖：

- 账号导入、归档、切换
- 浏览器登录与本地认证协调
- Usage 刷新、本地日志解析、远端回退
- Provider Sync
- 设置、诊断、主窗口、菜单栏快切

仓库里已经存在未跟踪的 `apps/rust-client/src-tauri/Cargo.toml`，说明 Rust/Tauri 重构已经开始预留目录，但尚未形成真正可运行的工程骨架。

## 重构目标

在当前分支 `feat/rust-tauri-rewrite` 上，将桌面端主实现迁移为：

- Tauri 2
- Rust 1.91+
- React + TypeScript
- Tailwind CSS + shadcn/ui

新实现必须保持与现有 `.codex` 数据布局兼容：

- `~/.codex/auth.json`
- `~/.codex/accounts/*.json`
- `~/.codex/accounts/usage-cache.json`
- `~/.codex/sessions/**/rollout-*.jsonl`
- `~/.codex/config.toml`
- `~/.codex/state_5.sqlite`
- `~/.codex/codex-switch/*.log`

## 目标架构

### 后端

Rust 后端承担所有业务与平台集成：

- 账号、导入、归档、切换
- JWT 解析
- Usage 解析、缓存、远端 API 回退
- Provider Sync
- 设置持久化与旧配置迁移
- 诊断日志
- 托盘、多窗口、自启动、浏览器打开

### 前端

React/TypeScript 仅负责桌面界面：

- 主窗口
- 托盘面板
- 表单与反馈
- 状态订阅与任务进度展示

前端不直接读取文件系统或操作 `.codex` 目录，所有读写经由 Tauri commands/events 完成。

## 产品交互契约

- 主窗口为主入口
- 托盘为快速入口
- UI 去 Web 化，强调桌面工具质感
- 不保留独立 Web 发布目标

## 实施原则

- 先落盘规格与计划，再实现
- Swift 代码保留为行为基线
- TDD 优先，至少对核心 Rust 能力坚持“先测后写”
- 分阶段提交本地中文规范 commit
