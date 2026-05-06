import { act, fireEvent, render, screen, within } from "@testing-library/react";
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
  removeAccount: vi.fn(),
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
  refreshUsage,
  removeAccount,
  saveSettings,
  startBrowserLogin,
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
    vi.mocked(refreshUsage).mockReset();
    vi.mocked(refreshUsage).mockRejectedValue(new Error("无法刷新 Usage。远程 API：HTTP 401，登录态已过期"));
    vi.mocked(switchAccount).mockReset();
    vi.mocked(switchAccount).mockResolvedValue(account({ isActive: true }));
    vi.mocked(removeAccount).mockReset();
    vi.mocked(removeAccount).mockResolvedValue(account({}));
    vi.mocked(startBrowserLogin).mockReset();
    vi.mocked(startBrowserLogin).mockResolvedValue({
      active: true,
      message: "浏览器登录已启动，请在浏览器完成认证",
    });
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
    expect(screen.getByRole("button", { name: "导入文件夹" })).toBeInTheDocument();
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

  it("shows detailed Usage refresh errors on the current account panel", async () => {
    render(<App />);

    await screen.findByText("账号工作台");
    fireEvent.click(screen.getByRole("button", { name: "刷新 Usage" }));

    expect(await screen.findByText("无法刷新 Usage。远程 API：HTTP 401，登录态已过期")).toBeInTheDocument();
    expect(screen.getByText("异常")).toBeInTheDocument();
    expect(screen.queryByTestId("global-feedback")).not.toBeInTheDocument();
  });

  it("disables browser login while the launch request is pending", async () => {
    const pendingLogin = deferred<{ active: boolean; message: string }>();
    vi.mocked(startBrowserLogin).mockReturnValueOnce(pendingLogin.promise);

    render(<App />);

    await screen.findByText("账号工作台");
    const button = screen.getByRole("button", { name: "浏览器登录" });
    fireEvent.click(button);
    fireEvent.click(button);

    expect(button).toBeDisabled();
    expect(startBrowserLogin).toHaveBeenCalledTimes(1);

    await act(async () => {
      pendingLogin.resolve({
        active: true,
        message: "浏览器登录已启动，请在浏览器完成认证",
      });
      await pendingLogin.promise;
    });
  });

  it("shows a browser login launch error and enables retry", async () => {
    vi.mocked(startBrowserLogin).mockRejectedValueOnce(new Error("无法打开浏览器: No application found"));

    render(<App />);

    await screen.findByText("账号工作台");
    const button = screen.getByRole("button", { name: "浏览器登录" });
    fireEvent.click(button);

    expect(button).toBeDisabled();
    expect(await screen.findByText("无法打开浏览器: No application found")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "浏览器登录" })).not.toBeDisabled();
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
    vi.mocked(getAppSnapshot).mockReset();
    vi.mocked(getAppSnapshot).mockResolvedValueOnce(snapshot).mockRejectedValue(new Error("refresh failed"));
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
    expect(screen.queryByText("refresh failed")).not.toBeInTheDocument();
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
    const switchButton = screen.getByRole("button", { name: "切换到 two@example.com" });

    fireEvent.click(switchButton);

    expect(screen.getByRole("button", { name: "当前账号 two@example.com" })).toBeDisabled();
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
      fireEvent.click(screen.getByRole("button", { name: "切换到 one@example.com" }));
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(switchAccount).toHaveBeenCalledWith("account-1");
  });

  it("does not show the active account usage on every archived account row", async () => {
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
    vi.mocked(getAppSnapshot).mockResolvedValueOnce({
      ...snapshot,
      accounts,
      activeAccountId: "account-1",
      activeUsage: {
        accountId: "account-1",
        updatedAt: "2026-05-02T10:00:00Z",
        sourceLabel: "API",
        fiveHour: {
          percentUsed: 42,
          resetsAt: "2026-05-02T15:00:00Z",
        },
        weekly: {
          percentUsed: 18,
          resetsAt: "2026-05-09T10:00:00Z",
        },
      },
    });

    render(<App />);

    await screen.findByText("账号工作台");
    const inactiveAccountRow = screen.getByRole("button", { name: "切换到 two@example.com" }).closest("div.grid");

    expect(inactiveAccountRow).not.toBeNull();
    expect(within(inactiveAccountRow as HTMLElement).queryByText("42%")).not.toBeInTheDocument();
    expect(within(inactiveAccountRow as HTMLElement).queryByText("18%")).not.toBeInTheDocument();
  });

  it("clears an inactive archived account after confirmation", async () => {
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
    vi.mocked(removeAccount).mockResolvedValueOnce(accounts[1]);
    const confirm = vi.spyOn(window, "confirm");

    render(<App />);

    await screen.findByText("账号工作台");
    fireEvent.click(screen.getByRole("button", { name: "清除 two@example.com" }));

    const dialog = await screen.findByRole("dialog", { name: "清除归档账号" });
    expect(dialog).toBeInTheDocument();
    expect(within(dialog).getByText("two@example.com")).toBeInTheDocument();
    expect(within(dialog).getByText("这只会删除本地归档记录，不会注销远程账号，也不会删除当前 auth.json。")).toBeInTheDocument();
    expect(confirm).not.toHaveBeenCalled();
    expect(removeAccount).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "取消" }));
    expect(screen.queryByRole("dialog", { name: "清除归档账号" })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "清除 two@example.com" }));
    fireEvent.click(await screen.findByRole("button", { name: "确认清除" }));

    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();
    });

    expect(removeAccount).toHaveBeenCalledWith("account-2");
    expect(screen.getByText("账号已清除。")).toBeInTheDocument();
    expect(screen.queryByRole("dialog", { name: "清除归档账号" })).not.toBeInTheDocument();
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

  it("displays Windows verbatim session projects with their folder name", async () => {
    vi.mocked(listSessionProjects).mockResolvedValueOnce([String.raw`\\?\D:\Clear-Bill`]);

    render(<App />);

    await screen.findByText("仪表盘");
    fireEvent.click(screen.getByTitle("Sessions"));

    expect(await screen.findByRole("option", { name: "Clear-Bill" })).toBeInTheDocument();
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
