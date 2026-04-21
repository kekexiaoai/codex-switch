# Phase 6: 打包与验收

- [ ] 完成 Tauri bundler 与跨平台打包配置
- [ ] 更新 README、发布说明与重构后开发文档
- [ ] 完成端到端回归与 Swift 基线对照

## Notes

- Swift 代码在此阶段之后再考虑最终清理。
- README 已切换到 Rust + Tauri 主线，设置页也已接入真实 autostart 插件。
- 当前桌面端已经支持通过原生文件选择器导入备份 auth 文件。
- 本地 `npm run tauri build -- --bundles app` 已验证可产出 `Codex Switch.app`。
- `scripts/package-macos-app.sh` 已切换并验证为新的 Tauri bundle 打包入口。
