import type { SettingsDto } from "@/lib/tauri";

export function settingsFeedbackMessage(previous: SettingsDto, next: SettingsDto) {
  if (previous.showFullEmail !== next.showFullEmail) {
    return next.showFullEmail ? "已显示完整邮箱。" : "已恢复邮箱掩码。";
  }
  if (previous.usageSourceMode !== next.usageSourceMode) {
    return next.usageSourceMode === "automatic" ? "已切换为自动 Usage 数据源。" : "已切换为本地 Usage 数据源。";
  }
  if (previous.usageRefreshEnabled !== next.usageRefreshEnabled) {
    return next.usageRefreshEnabled ? "已启用 Usage 刷新。" : "已暂停 Usage 刷新。";
  }
  if (previous.launchAtLogin !== next.launchAtLogin) {
    return next.launchAtLogin ? "已启用开机启动。" : "已关闭开机启动。";
  }
  return "设置已保存。";
}
