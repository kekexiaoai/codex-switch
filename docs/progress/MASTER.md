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
- [x] Phase 2: 工程骨架 (3/3 tasks) [details](./phase-2-app-scaffold.md)
- [x] Phase 3: 核心服务迁移 (5/5 tasks) [details](./phase-3-core-services.md)
- [x] Phase 4: Provider Sync 与桌面登录 (4/4 tasks) [details](./phase-4-provider-sync-and-login.md)
- [x] Phase 5: 主窗口与托盘 UI (4/4 tasks) [details](./phase-5-ui-shell.md)
- [ ] Phase 6: 打包与验收 (0/3 tasks) [details](./phase-6-release-and-validation.md)

## Current Status

- 当前正在执行：Phase 6 / 打包、README、autostart 与更完整验收收口

## Next Steps

1. 提交当前实现 commit
2. 继续更新 README 与打包说明
3. 继续补端到端验收和更细的桌面体验
