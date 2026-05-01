# Phase 6: 打包与验收

- [x] 完成 Tauri bundler 与跨平台打包配置
- [x] 更新 README、发布说明与重构后开发文档
- [ ] 完成端到端回归与 Swift 基线对照

## Notes

- Swift 代码在此阶段之后再考虑最终清理。
- README 已切换到 Rust + Tauri 主线，设置页也已接入真实 autostart 插件。
- 当前桌面端已经支持通过原生文件选择器导入备份 auth 文件。
- 本地 `npm run tauri build -- --bundles app` 已验证可产出 `Codex Switch.app`。
- `scripts/package-macos-app.sh` 已切换并验证为新的 Tauri bundle 打包入口。
- `AppState::new()` 已支持通过环境变量切到临时 fixture 目录，方便后续回归验收。
- 2026-04-30 排查首屏无数据问题：当前 `auth.json` 可能是 API Key 模式，同时归档目录中单个缺失 `id_token` 的 JSON 会导致整个账号列表失败；已改为跳过不可描述 ChatGPT 账号的归档文件，并在前端显示首屏加载错误。
- 2026-04-30 继续修复旧 Swift 缓存兼容：`metadata.json` 和 `usage-cache.json` 中的 `Date` 可能是 JSONEncoder 默认的 2001 参考时间数字，Rust 端已支持同时读取该数字格式与 RFC3339 字符串。
