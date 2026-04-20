# Codex Switch Tauri 重构任务拆解

## 阶段 1：规格与计划落盘

### Lane A：文档与追踪

- P0 / S：补齐 `docs/analysis/*`
- P0 / S：补齐 `docs/plan/*`
- P0 / S：补齐 `docs/progress/*`
- P0 / S：创建 `openspec/changes/refactor-desktop-to-tauri-rust/*`

验收：

- 文档可直接指导后续实施
- `openspec validate refactor-desktop-to-tauri-rust --strict` 通过

## 阶段 2：工程骨架

### Lane A：Tauri 后端骨架

- P0 / M：建立 `src-tauri/src/{core,infra,platform,commands,state}` 模块
- P0 / S：定义统一错误模型、DTO、事件名
- P0 / S：建立 Tauri app 启动、窗口和托盘壳

### Lane B：前端骨架

- P0 / M：建立 React + TypeScript + Tailwind + shadcn/ui 工程
- P0 / S：建立 design tokens 与桌面壳层
- P0 / S：建立导航、布局、空状态和 loading 基础组件

验收：

- 应用能启动主窗口
- 托盘可打开基础面板
- 前端具备桌面化壳层而不是默认网页布局

## 阶段 3：核心服务迁移

### Lane A：账号与 auth

- P0 / M：迁移 paths、auth 文件读写、JWT 解码、归档导入
- P0 / M：迁移账号切换与 active account 流程

### Lane B：usage 与 diagnostics

- P0 / M：迁移 usage scanner、usage cache、远端 API fallback
- P1 / S：迁移 diagnostics log reader/writer

### Lane C：settings

- P1 / S：实现新 `settings.json`
- P1 / S：实现旧设置迁移

验收：

- Rust 单元/集成测试通过
- 可列出账号、导入当前 auth、切换账号、刷新 usage、读取诊断

## 阶段 4：Provider Sync 与桌面登录

### Lane A：Provider Sync

- P0 / M：迁移 config parser
- P0 / M：迁移 session scanner 与重写
- P0 / M：迁移 SQLite updater
- P0 / M：迁移 backup/restore/prune 与 lock

### Lane B：Desktop Login

- P0 / M：实现桌面浏览器登录 broker
- P0 / S：实现 auth 文件变化监听与超时/取消
- P0 / S：复用导入与激活管线

验收：

- Provider Sync 可运行并具备回滚
- 浏览器登录可从应用内发起并完成导入

## 阶段 5：主窗口与托盘 UI

### Lane A：主窗口

- P0 / M：Accounts 页面
- P0 / M：Usage 页面
- P0 / M：Provider Sync 页面
- P1 / S：Diagnostics 页面
- P1 / S：Settings 页面

### Lane B：托盘

- P0 / S：当前账号与 usage 摘要
- P0 / S：快速切换列表
- P1 / S：快速操作区

验收：

- 主要操作可在主窗口完成
- 托盘只承担快速入口
- UI 满足去 Web 化要求

## 阶段 6：打包、回归、收口

### Lane A：打包与文档

- P1 / S：Tauri bundler 配置
- P1 / S：README 与发布文档更新

### Lane B：回归

- P0 / M：端到端验收
- P0 / M：Swift 基线对照检查

验收：

- 主流程端到端通过
- 文档可用于后续迭代与交接
