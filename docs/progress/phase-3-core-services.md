# Phase 3: 核心服务迁移

- [x] 迁移 `.codex` 路径与 auth 文件服务
- [x] 迁移 JWT 解码、账号仓库、导入/归档流程
- [x] 迁移账号切换与 active account 状态
- [x] 迁移 usage scanner、usage cache、API fallback
- [x] 迁移 diagnostics 与 settings 服务

## Notes

- 先写 Rust 测试，再接 Tauri commands。
- 当前已有 8 个 Rust 单元测试覆盖路径、JWT、导入、Usage、Provider 配置、设置与存储。
