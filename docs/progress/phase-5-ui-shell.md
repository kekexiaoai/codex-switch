# Phase 5: 主窗口与托盘 UI

- [x] 实现 Accounts / Usage / Provider Sync / Diagnostics / Settings 页面
- [x] 实现托盘快切与快速操作
- [x] 完成主窗口、托盘、对话框和提示的桌面化收口
- [x] 完成错误态、空态、任务反馈和 loading 体验

## Notes

- 禁止出现 SaaS dashboard 或 marketing hero 风格。
- 当前已完成桌面化壳层、托盘导航、反馈提示与备份管理面板。
- 账号页已补上“导入备份”入口，并通过桌面文件选择器接入 `accounts_import_backup`。
- 2026-04-30 根据 UI 反馈完成一次纠偏：收紧全局 token、窗口壳层、侧栏、工具栏、卡片、列表、托盘浮层和各功能页信息密度，移除明显网页后台式说明文案与大圆角漂浮感。
