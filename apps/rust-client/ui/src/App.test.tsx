import { act, fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AppSnapshot } from "@/lib/tauri";

const snapshot: AppSnapshot = {
  accounts: [],
  settings: {
    usageRefreshEnabled: true,
    usageSourceMode: "automatic",
    showFullEmail: false,
    launchAtLogin: false,
  },
  diagnostics: [],
  providerStatus: {
    currentProvider: "openai",
    configuredProviders: ["openai"],
    rolloutDistribution: [],
    sqliteDistribution: [],
    backupCount: 0,
    backupTotalSize: 0,
    backups: [],
  },
};

vi.mock("@/lib/tauri", () => ({
  getAppSnapshot: vi.fn(),
  accountsImportBackup: vi.fn(),
  importCurrentAccount: vi.fn(),
  pickAuthBackupFile: vi.fn(),
  getAutostartEnabled: vi.fn().mockResolvedValue(false),
  switchAccount: vi.fn(),
  refreshUsage: vi.fn(),
  runProviderSync: vi.fn(),
  switchProvider: vi.fn(),
  saveSettings: vi.fn(),
  setAutostartEnabled: vi.fn(),
  showMainWindow: vi.fn(),
  startBrowserLogin: vi.fn(),
  events: {
    accountsChanged: "accounts://changed",
    usageUpdated: "usage://updated",
    settingsChanged: "settings://changed",
    diagnosticsAppended: "diagnostics://appended",
    jobsChanged: "jobs://state-changed",
    shellNavigate: "shell://navigate",
  },
  onEvent: vi.fn().mockResolvedValue(() => {}),
}));

import { App } from "./App";
import { getAppSnapshot, saveSettings } from "@/lib/tauri";

describe("App", () => {
  beforeEach(() => {
    vi.useRealTimers();
    vi.mocked(getAppSnapshot).mockReset();
    vi.mocked(getAppSnapshot).mockResolvedValue(snapshot);
    vi.mocked(saveSettings).mockReset();
    vi.mocked(saveSettings).mockResolvedValue(snapshot.settings);
  });

  it("renders a glass desktop shell instead of a web navbar", async () => {
    render(<App />);
    expect(await screen.findByText("仪表盘")).toBeInTheDocument();
    expect(screen.getByTestId("glass-shell")).toBeInTheDocument();
    expect(screen.getByTestId("floating-dock")).toBeInTheDocument();
    expect(screen.getAllByText("Accounts").length).toBeGreaterThan(0);
    expect(screen.getByText("账号工作台")).toBeInTheDocument();
    expect(screen.getByText("Usage 自动")).toBeInTheDocument();
    expect(screen.getAllByText("导入备份").length).toBeGreaterThan(0);
    expect(screen.queryByText("Welcome")).not.toBeInTheDocument();
    expect(screen.queryByText("Local")).not.toBeInTheDocument();
    expect(screen.queryByText("Local Desktop")).not.toBeInTheDocument();
    expect(screen.queryByText("搜索账号...")).not.toBeInTheDocument();
    expect(screen.queryByText("Codex Account Hub")).not.toBeInTheDocument();
    expect(screen.queryByText("Codex 布局")).not.toBeInTheDocument();
    expect(screen.queryByText("更新")).not.toBeInTheDocument();
  });

  it("shows a startup error when the desktop snapshot cannot load", async () => {
    vi.mocked(getAppSnapshot).mockRejectedValueOnce(new Error("id_token 缺失"));

    render(<App />);

    expect(await screen.findByText("id_token 缺失")).toBeInTheDocument();
  });

  it("automatically hides successful settings feedback", async () => {
    render(<App />);

    await screen.findByText("仪表盘");
    fireEvent.click(screen.getByTitle("Settings"));
    vi.useFakeTimers();
    fireEvent.click(screen.getByRole("switch", { name: "启用 Usage 刷新" }));

    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(screen.getByText("已暂停 Usage 刷新。")).toBeInTheDocument();

    await act(async () => {
      vi.advanceTimersByTime(3_500);
    });

    expect(screen.queryByText("已暂停 Usage 刷新。")).not.toBeInTheDocument();
  });

  it("lets the dashboard toggle full email display", async () => {
    render(<App />);

    await screen.findByText("仪表盘");
    fireEvent.click(screen.getByRole("button", { name: "显示完整邮箱" }));

    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(saveSettings).toHaveBeenCalledWith(expect.objectContaining({ showFullEmail: true }));
    expect(screen.getByText("已显示完整邮箱。")).toBeInTheDocument();
  });
});
