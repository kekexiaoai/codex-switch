# Codex Switch Rust + Tauri 重构进度

## 任务说明

将现有 Swift/macOS 实现重构为 Rust + Tauri + React + shadcn/ui 桌面应用，保持 `.codex` 数据兼容，并实现去 Web 化的桌面软件质感。

## 关联文档

- [项目概览](../analysis/project-overview.md)
- [模块盘点](../analysis/module-inventory.md)
- [风险评估](../analysis/risk-assessment.md)
- [任务拆解](../plan/task-breakdown.md)
- [依赖图](../plan/dependency-graph.md)
- [里程碑](../plan/milestones.md)

## 阶段总览

- [x] Phase 1: 规格与计划落盘 (4/4 tasks) [details](./phase-1-spec-and-planning.md)
- [ ] Phase 2: 工程骨架 (0/3 tasks) [details](./phase-2-app-scaffold.md)
- [ ] Phase 3: 核心服务迁移 (0/5 tasks) [details](./phase-3-core-services.md)
- [ ] Phase 4: Provider Sync 与桌面登录 (0/4 tasks) [details](./phase-4-provider-sync-and-login.md)
- [ ] Phase 5: 主窗口与托盘 UI (0/4 tasks) [details](./phase-5-ui-shell.md)
- [ ] Phase 6: 打包与验收 (0/3 tasks) [details](./phase-6-release-and-validation.md)

## Current Status

- 当前正在执行：Phase 2 / 搭建 Tauri 2 + React + shadcn/ui 工程骨架

## Next Steps

1. 提交文档 commit
2. 初始化 Tauri 2 + React + shadcn/ui 工程骨架
3. 开始 Rust 核心服务与测试迁移
