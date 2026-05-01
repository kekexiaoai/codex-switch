import { describe, expect, it } from "vitest";
import type { SettingsDto } from "@/lib/tauri";
import { settingsFeedbackMessage } from "./settings-feedback";

const base: SettingsDto = {
  usageRefreshEnabled: true,
  usageSourceMode: "automatic",
  showFullEmail: false,
  launchAtLogin: false,
};

describe("settingsFeedbackMessage", () => {
  it("describes full email changes without mentioning launch at login", () => {
    expect(settingsFeedbackMessage(base, { ...base, showFullEmail: true })).toBe("已显示完整邮箱。");
    expect(settingsFeedbackMessage({ ...base, showFullEmail: true }, base)).toBe("已恢复邮箱掩码。");
  });

  it("describes launch at login changes only when that setting changed", () => {
    expect(settingsFeedbackMessage(base, { ...base, launchAtLogin: true })).toBe("已启用开机启动。");
    expect(settingsFeedbackMessage({ ...base, launchAtLogin: true }, base)).toBe("已关闭开机启动。");
  });
});
