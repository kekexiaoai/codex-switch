import { act, fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AppSnapshot, CodexSessionDetail, CodexSessionListItem } from "@/lib/tauri";

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

const sessionItem: CodexSessionListItem = {
  id: "11111111-1111-1111-1111-111111111111",
  display: "实现 Sessions 页面",
  timestamp: "2026-05-02T10:00:00Z",
  project: "/repo/codex-switch",
  projectName: "codex-switch",
  filePath: "/repo/.codex/sessions/rollout.jsonl",
  messageCount: 2,
};

const sessionDetail: CodexSessionDetail = {
  session: sessionItem,
  messages: [
    {
      role: "user",
      kind: "message",
      text: "hello",
      timestamp: "2026-05-02T10:00:01Z",
    },
  ],
};

vi.mock("@/lib/tauri", () => ({
  getAppSnapshot: vi.fn(),
  getSessionDetail: vi.fn(),
  accountsImportBackup: vi.fn(),
  importCurrentAccount: vi.fn(),
  listSessionProjects: vi.fn(),
  listSessions: vi.fn(),
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
import { getAppSnapshot, getSessionDetail, listSessionProjects, listSessions, saveSettings } from "@/lib/tauri";

describe("App", () => {
  beforeEach(() => {
    vi.useRealTimers();
    vi.mocked(getAppSnapshot).mockReset();
    vi.mocked(getAppSnapshot).mockResolvedValue(snapshot);
    vi.mocked(listSessions).mockReset();
    vi.mocked(listSessions).mockResolvedValue([sessionItem]);
    vi.mocked(listSessionProjects).mockReset();
    vi.mocked(listSessionProjects).mockResolvedValue(["/repo/codex-switch"]);
    vi.mocked(getSessionDetail).mockReset();
    vi.mocked(getSessionDetail).mockResolvedValue(sessionDetail);
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
    expect(screen.getByTestId("global-feedback")).toHaveAttribute("role", "alert");
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

  it("shows Codex historical sessions in a dedicated workspace", async () => {
    render(<App />);

    await screen.findByText("仪表盘");
    fireEvent.click(screen.getByTitle("Sessions"));

    expect(await screen.findByText("会话索引")).toBeInTheDocument();
    expect(screen.getAllByText("实现 Sessions 页面").length).toBeGreaterThan(0);
    expect(screen.getByText("hello")).toBeInTheDocument();
    expect(screen.getByText("来自 ~/.codex/history.jsonl 与 sessions 目录")).toBeInTheDocument();
  });

  it("collapses Codex bootstrap context blocks by default", async () => {
    vi.mocked(getSessionDetail).mockResolvedValueOnce({
      session: sessionItem,
      messages: [
        {
          role: "user",
          kind: "message",
          text: "<permissions instructions>\nFilesystem sandboxing...\n</permissions instructions>",
          timestamp: "2026-05-02T10:00:01Z",
        },
      ],
    });

    render(<App />);

    await screen.findByText("仪表盘");
    fireEvent.click(screen.getByTitle("Sessions"));

    const bootstrapBlock = await screen.findByTestId("codex-bootstrap-context");
    expect(bootstrapBlock).not.toHaveAttribute("open");
    expect(screen.getByText("Codex 内置上下文")).toBeInTheDocument();
  });
});
