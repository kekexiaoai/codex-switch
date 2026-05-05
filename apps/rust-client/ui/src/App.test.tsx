import { act, fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AccountListItem, AppSnapshot, CodexSessionDetail, CodexSessionListItem } from "@/lib/tauri";

const snapshot: AppSnapshot = {
  accounts: [],
  currentAuthMode: "missing",
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
  accountsImportBackups: vi.fn(),
  importCurrentAccount: vi.fn(),
  listSessionProjects: vi.fn(),
  listSessions: vi.fn(),
  pickAuthBackupDirectory: vi.fn(),
  pickAuthBackupFiles: vi.fn(),
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
import {
  accountsImportBackups,
  getAppSnapshot,
  getSessionDetail,
  listSessionProjects,
  listSessions,
  pickAuthBackupDirectory,
  pickAuthBackupFiles,
  saveSettings,
  switchAccount,
} from "@/lib/tauri";

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((innerResolve, innerReject) => {
    resolve = innerResolve;
    reject = innerReject;
  });
  return { promise, resolve, reject };
}

function account(overrides: Partial<AccountListItem>): AccountListItem {
  return {
    id: "account-1",
    emailMask: "one@example.com",
    email: "one@example.com",
    tier: "team",
    authMode: "oauth",
    manualOrder: 0,
    archiveFilename: "one.json",
    source: "fixture",
    lastImportedAt: "2026-05-02T10:00:00Z",
    isActive: false,
    ...overrides,
  };
}

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
    vi.mocked(accountsImportBackups).mockReset();
    vi.mocked(accountsImportBackups).mockResolvedValue({ accounts: [account({})], skippedCount: 0 });
    vi.mocked(pickAuthBackupFiles).mockReset();
    vi.mocked(pickAuthBackupFiles).mockResolvedValue([]);
    vi.mocked(pickAuthBackupDirectory).mockReset();
    vi.mocked(pickAuthBackupDirectory).mockResolvedValue(null);
    vi.mocked(switchAccount).mockReset();
    vi.mocked(switchAccount).mockResolvedValue(account({ isActive: true }));
  });

  it("renders a devtools-style desktop shell instead of a floating dock", async () => {
    render(<App />);
    expect(await screen.findByText("仪表盘")).toBeInTheDocument();
    expect(screen.getByTestId("glass-shell")).toBeInTheDocument();
    expect(screen.getByRole("main")).toHaveClass("flex-1");
    expect(screen.getByTestId("desktop-sidebar")).toBeInTheDocument();
    expect(screen.getByText("Codex Switch")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "折叠侧栏" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Accounts" })).toBeInTheDocument();
    expect(screen.queryByText("Ready")).not.toBeInTheDocument();
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

  it("collapses and expands the desktop sidebar", async () => {
    render(<App />);

    await screen.findByText("仪表盘");
    fireEvent.click(screen.getByRole("button", { name: "折叠侧栏" }));

    expect(screen.getByTestId("desktop-sidebar")).toHaveAttribute("data-collapsed", "true");
    expect(screen.getByRole("button", { name: "展开侧栏" })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "展开侧栏" }));

    expect(screen.getByTestId("desktop-sidebar")).toHaveAttribute("data-collapsed", "false");
    expect(screen.getByRole("button", { name: "折叠侧栏" })).toBeInTheDocument();
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

  it("updates settings switches optimistically while saving", async () => {
    const pendingSave = deferred<typeof snapshot.settings>();
    vi.mocked(saveSettings).mockReturnValueOnce(pendingSave.promise);

    render(<App />);

    await screen.findByText("仪表盘");
    fireEvent.click(screen.getByTitle("Settings"));

    const usageSwitch = screen.getByRole("switch", { name: "启用 Usage 刷新" });
    expect(usageSwitch).toHaveAttribute("aria-checked", "true");

    fireEvent.click(usageSwitch);

    expect(usageSwitch).toHaveAttribute("aria-checked", "false");
    expect(screen.getByText("正在保存设置…")).toBeInTheDocument();

    await act(async () => {
      pendingSave.resolve({ ...snapshot.settings, usageRefreshEnabled: false });
      await pendingSave.promise;
    });
  });

  it("imports every backup in a selected folder", async () => {
    vi.mocked(pickAuthBackupDirectory).mockResolvedValueOnce("/repo/backups");
    vi.mocked(accountsImportBackups).mockResolvedValueOnce({
      accounts: [account({ id: "account-1" }), account({ id: "account-2", email: "two@example.com" })],
      skippedCount: 1,
    });

    render(<App />);

    await screen.findByText("账号工作台");
    fireEvent.click(screen.getByRole("button", { name: "导入文件夹" }));

    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(pickAuthBackupDirectory).toHaveBeenCalled();
    expect(accountsImportBackups).toHaveBeenCalledWith(["/repo/backups"]);
    expect(screen.getByText("已导入 2 个备份账号，跳过 1 个不可导入项。")).toBeInTheDocument();
  });

  it("marks the selected account active while switching", async () => {
    const accounts = [
      account({ id: "account-1", emailMask: "one@example.com", isActive: true }),
      account({
        id: "account-2",
        emailMask: "two@example.com",
        email: "two@example.com",
        archiveFilename: "two.json",
        manualOrder: 1,
      }),
    ];
    vi.mocked(getAppSnapshot).mockResolvedValueOnce({ ...snapshot, accounts });
    const pendingSwitch = deferred<AccountListItem>();
    vi.mocked(switchAccount).mockReturnValueOnce(pendingSwitch.promise);

    render(<App />);

    await screen.findByText("账号工作台");
    const targetRow = screen.getAllByText("two@example.com")[0].closest("button");
    expect(targetRow).not.toBeNull();

    fireEvent.click(targetRow!);

    expect(targetRow).toHaveClass("bg-white/46");
    expect(screen.getByText("正在切换账号…")).toBeInTheDocument();

    await act(async () => {
      pendingSwitch.resolve({ ...accounts[1], isActive: true });
      await pendingSwitch.promise;
    });
  });

  it("shows OPENAI_API_KEY mode and allows switching after backup", async () => {
    const accounts = [
      account({ id: "account-1", emailMask: "one@example.com", isActive: false }),
    ];
    vi.mocked(getAppSnapshot).mockResolvedValueOnce({
      ...snapshot,
      accounts,
      currentAuthMode: "openaiApiKey",
    });

    render(<App />);

    await screen.findByText("账号工作台");

    expect(screen.getAllByText("OPENAI_API_KEY 模式").length).toBeGreaterThan(0);
    expect(screen.getByText("当前 Codex auth.json 使用 API Key 配置，切换账号前会自动备份，之后可从列表切回。")).toBeInTheDocument();

    await act(async () => {
      fireEvent.click(screen.getAllByText("one@example.com")[0].closest("button")!);
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(switchAccount).toHaveBeenCalledWith("account-1");
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
