import { useEffect, useMemo, useState } from "react";
import {
  events,
  getAppSnapshot,
  getAutostartEnabled,
  accountsImportBackup,
  importCurrentAccount,
  onEvent,
  openView,
  pickAuthBackupFile,
  pruneProviderBackups,
  quitApp,
  refreshUsage,
  restoreProviderBackup,
  runProviderSync,
  saveSettings,
  setAutostartEnabled,
  showMainWindow,
  startBrowserLogin,
  switchAccount,
  switchProvider,
  type AppSnapshot,
  type LoginJobState,
} from "@/lib/tauri";
import { Sidebar, type AppView } from "@/components/shell/sidebar";
import { Topbar } from "@/components/shell/topbar";
import { AccountsView } from "@/features/accounts/accounts-view";
import { UsageView } from "@/features/usage/usage-view";
import { ProviderSyncView } from "@/features/provider-sync/provider-sync-view";
import { DiagnosticsView } from "@/features/diagnostics/diagnostics-view";
import { SettingsView } from "@/features/settings/settings-view";
import { TrayView } from "@/features/tray/tray-view";

const emptySnapshot: AppSnapshot = {
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

export function App() {
  const [snapshot, setSnapshot] = useState<AppSnapshot>(emptySnapshot);
  const [view, setView] = useState<AppView>("accounts");
  const [loginState, setLoginState] = useState<LoginJobState | null>(null);
  const [targetProvider, setTargetProvider] = useState("openai");
  const [selectedBackupId, setSelectedBackupId] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ kind: "info" | "success" | "error"; message: string } | null>(null);
  const search = useMemo(() => new URLSearchParams(window.location.search), []);
  const isTray = search.get("panel") === "tray";

  const refreshAll = async () => {
    const [next, autostartEnabled] = await Promise.all([
      getAppSnapshot(),
      getAutostartEnabled().catch(() => false),
    ]);
    next.settings.launchAtLogin = autostartEnabled;
    setSnapshot(next);
    setTargetProvider(next.providerStatus.currentProvider || "openai");
    setSelectedBackupId(next.providerStatus.backups[0]?.id ?? null);
  };

  const runAction = async <T,>(
    pendingMessage: string,
    action: () => Promise<T>,
    successMessage: string,
  ) => {
    try {
      setFeedback({ kind: "info", message: pendingMessage });
      const result = await action();
      await refreshAll();
      setFeedback({ kind: "success", message: successMessage });
      return result;
    } catch (error) {
      setFeedback({
        kind: "error",
        message: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  };

  useEffect(() => {
    void refreshAll();
  }, []);

  useEffect(() => {
    const cleanups: Array<() => void> = [];
    const bind = async () => {
      cleanups.push(await onEvent(events.accountsChanged, refreshAll));
      cleanups.push(await onEvent(events.settingsChanged, refreshAll));
      cleanups.push(await onEvent(events.diagnosticsAppended, refreshAll));
      cleanups.push(await onEvent(events.usageUpdated, refreshAll));
      cleanups.push(await onEvent(events.jobsChanged, (payload: LoginJobState) => setLoginState(payload)));
      cleanups.push(await onEvent(events.shellNavigate, (payload: AppView) => setView(payload)));
    };
    void bind();
    return () => cleanups.forEach((cleanup) => cleanup());
  }, []);

  if (isTray) {
    return (
      <TrayView
        accounts={snapshot.accounts}
        usage={snapshot.activeUsage}
        showFullEmail={snapshot.settings.showFullEmail}
        onSwitch={(id) => void switchAccount(id).then(refreshAll)}
        onRefresh={() => void refreshUsage().then(refreshAll)}
        onOpenMain={() => void showMainWindow()}
        onOpenSettings={() => void openView("settings")}
        onQuit={() => void quitApp()}
      />
    );
  }

  return (
    <div className="app-window">
      <Sidebar activeView={view} onChange={setView} />
      <main className="flex min-w-0 flex-col gap-4 overflow-hidden">
        <Topbar view={view} />
        {feedback ? (
          <div
            className={[
              "rounded-2xl border px-4 py-3 text-sm shadow-panel",
              feedback.kind === "error"
                ? "border-rose-200 bg-rose-50 text-rose-700"
                : feedback.kind === "success"
                  ? "border-emerald-200 bg-emerald-50 text-emerald-700"
                  : "border-slate-200 bg-white/80 text-slate-700",
            ].join(" ")}
          >
            {feedback.message}
          </div>
        ) : null}
        <div className="min-h-0 flex-1 overflow-hidden">
          {view === "accounts" ? (
            <AccountsView
              accounts={snapshot.accounts}
              usage={snapshot.activeUsage}
              loginState={loginState}
              showFullEmail={snapshot.settings.showFullEmail}
              onImportCurrent={() => {
                void runAction("正在导入当前账号…", () => importCurrentAccount(), "当前账号已导入。");
              }}
              onImportBackup={() => {
                setFeedback({ kind: "info", message: "正在选择备份文件…" });
                void pickAuthBackupFile().then((selected) => {
                  if (!selected) {
                    setFeedback(null);
                    return;
                  }
                  void runAction(
                    "正在导入备份账号…",
                    () => accountsImportBackup(selected),
                    "备份账号已导入。",
                  );
                });
              }}
              onSwitch={(id) => {
                void runAction("正在切换账号…", () => switchAccount(id), "账号已切换。");
              }}
              onRefreshUsage={() => {
                void runAction("正在刷新 Usage…", () => refreshUsage(), "Usage 已刷新。");
              }}
              onLogin={() => {
                void runAction("正在启动浏览器登录…", () => startBrowserLogin(), "浏览器登录已启动。")
                  .then(setLoginState);
              }}
            />
          ) : null}
          {view === "usage" ? <UsageView usage={snapshot.activeUsage} /> : null}
          {view === "provider-sync" ? (
            <ProviderSyncView
              status={snapshot.providerStatus}
              targetProvider={targetProvider}
              selectedBackupId={selectedBackupId}
              onTargetProviderChange={setTargetProvider}
              onSync={() => {
                void runAction(
                  `正在同步到 ${targetProvider}…`,
                  () => runProviderSync(targetProvider),
                  "Provider Sync 已完成。",
                );
              }}
              onSwitch={() => {
                void runAction(
                  `正在切换并同步到 ${targetProvider}…`,
                  () => switchProvider(targetProvider),
                  "Provider 已切换并同步。",
                );
              }}
              onSelectBackup={setSelectedBackupId}
              onRestoreBackup={(backupId) => {
                setSelectedBackupId(backupId);
                void runAction(
                  "正在恢复备份…",
                  () => restoreProviderBackup(backupId),
                  "备份已恢复。",
                );
              }}
              onPruneBackups={() => {
                void runAction("正在清理旧备份…", () => pruneProviderBackups(5), "旧备份已清理。");
              }}
            />
          ) : null}
          {view === "diagnostics" ? <DiagnosticsView diagnostics={snapshot.diagnostics} /> : null}
          {view === "settings" ? (
            <SettingsView
              settings={snapshot.settings}
              onChange={(settings) => {
                void runAction(
                  "正在保存设置…",
                  async () => {
                    if (settings.launchAtLogin !== snapshot.settings.launchAtLogin) {
                      await setAutostartEnabled(settings.launchAtLogin);
                    }
                    return saveSettings(settings);
                  },
                  settings.launchAtLogin ? "已启用开机启动。" : "已关闭开机启动。",
                );
              }}
            />
          ) : null}
        </div>
      </main>
    </div>
  );
}
