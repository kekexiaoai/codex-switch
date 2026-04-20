# Phase 4: Provider Sync 与桌面登录

- [x] 迁移 config parser 与 provider 列表读写
- [x] 迁移 rollout session rewrite、SQLite update、backup/rollback
- [x] 实现桌面浏览器登录 broker
- [x] 复用导入与激活流程，形成完整登录闭环

## Notes

- 该阶段对 `.codex` 兼容性要求最高。
- 当前已完成同步、切换、备份创建、恢复、清理与登录后自动导入。
