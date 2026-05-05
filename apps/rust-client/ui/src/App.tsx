import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  events,
  getSessionDetail,
  getAppSnapshot,
  getAutostartEnabled,
  accountsImportBackups,
  importCurrentAccount,
  listSessionProjects,
  listSessions,
  onEvent,
  openView,
  pickAuthBackupDirectory,
  pickAuthBackupFiles,
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
  type BackupImportResult,
  type CodexSessionDetail,
  type CodexSessionListItem,
  type LoginJobState,
} from "@/lib/tauri";
import { Sidebar, type AppView } from "@/components/shell/sidebar";
import { Topbar } from "@/components/shell/topbar";
import { AccountsView } from "@/features/accounts/accounts-view";
import { UsageView } from "@/features/usage/usage-view";
import { ProviderSyncView } from "@/features/provider-sync/provider-sync-view";
import { SessionsView } from "@/features/sessions/sessions-view";
import { DiagnosticsView } from "@/features/diagnostics/diagnostics-view";
import { SettingsView } from "@/features/settings/settings-view";
import { settingsFeedbackMessage } from "@/features/settings/settings-feedback";
import { TrayView } from "@/features/tray/tray-view";

const emptySnapshot: AppSnapshot = {
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

const SUCCESS_FEEDBACK_TIMEOUT_MS = 3_200;

function backupImportSuccessMessage(result: BackupImportResult) {
  const skipped = result.skippedCount > 0 ? `，跳过 ${result.skippedCount} 个不可导入项` : "";
  return `已导入 ${result.accounts.length} 个备份账号${skipped}。`;
}

export function App() {
  const [snapshot, setSnapshot] = useState<AppSnapshot>(emptySnapshot);
  const [view, setView] = useState<AppView>("accounts");
  const [loginState, setLoginState] = useState<LoginJobState | null>(null);
  const [targetProvider, setTargetProvider] = useState("openai");
  const [selectedBackupId, setSelectedBackupId] = useState<string | null>(null);
  const [sessions, setSessions] = useState<CodexSessionListItem[]>([]);
  const [sessionProjects, setSessionProjects] = useState<string[]>([]);
  const [selectedSession, setSelectedSession] = useState<CodexSessionDetail | null>(null);
  const [sessionsLoading, setSessionsLoading] = useState(false);
  const [feedback, setFeedback] = useState<{ kind: "info" | "success" | "error"; message: string } | null>(null);
  const refreshInFlight = useRef<Promise<boolean> | null>(null);
  const search = useMemo(() => new URLSearchParams(window.location.search), []);
  const isTray = search.get("panel") === "tray";

  const refreshAll = useCallback(() => {
    if (refreshInFlight.current) {
      return refreshInFlight.current;
    }

    const request = (async () => {
      try {
        const [next, autostartEnabled] = await Promise.all([
          getAppSnapshot(),
          getAutostartEnabled().catch(() => false),
        ]);
        next.settings.launchAtLogin = autostartEnabled;
        setSnapshot(next);
        setTargetProvider(next.providerStatus.currentProvider || "openai");
        setSelectedBackupId(next.providerStatus.backups[0]?.id ?? null);
        return true;
      } catch (error) {
        setFeedback({
          kind: "error",
          message: error instanceof Error ? error.message : String(error),
        });
        return false;
      } finally {
        refreshInFlight.current = null;
      }
    })();

    refreshInFlight.current = request;
    return request;
  }, []);

  const runAction = async <T,>(
    pendingMessage: string,
    action: () => Promise<T>,
    successMessage: string | ((result: T) => string),
  ) => {
    try {
      setFeedback({ kind: "info", message: pendingMessage });
      const result = await action();
      setFeedback({
        kind: "success",
        message: typeof successMessage === "function" ? successMessage(result) : successMessage,
      });
      void refreshAll();
      return result;
    } catch (error) {
      setFeedback({
        kind: "error",
        message: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  };

  const setSettingsOptimistically = (settings: AppSnapshot["settings"]) => {
    setSnapshot((current) => ({ ...current, settings }));
  };

  const setActiveAccountOptimistically = (accountId: string) => {
    setSnapshot((current) => ({
      ...current,
      activeAccountId: accountId,
      activeUsage: current.activeUsage?.accountId === accountId ? current.activeUsage : null,
      accounts: current.accounts.map((account) => ({
        ...account,
        isActive: account.id === accountId,
      })),
    }));
  };

  const loadSessionDetail = async (sessionId: string) => {
    try {
      const detail = await getSessionDetail(sessionId);
      setSelectedSession(detail);
    } catch (error) {
      setFeedback({
        kind: "error",
        message: error instanceof Error ? error.message : String(error),
      });
    }
  };

  const refreshSessions = async () => {
    try {
      setSessionsLoading(true);
      const [items, projects] = await Promise.all([listSessions(), listSessionProjects()]);
      setSessions(items);
      setSessionProjects(projects);

      const existingId = selectedSession?.session.id;
      const nextId = existingId && items.some((item) => item.id === existingId) ? existingId : items[0]?.id;
      if (nextId) {
        const detail = await getSessionDetail(nextId);
        setSelectedSession(detail);
      } else {
        setSelectedSession(null);
      }
    } catch (error) {
      setFeedback({
        kind: "error",
        message: error instanceof Error ? error.message : String(error),
      });
    } finally {
      setSessionsLoading(false);
    }
  };

  useEffect(() => {
    void refreshAll();
    void refreshSessions();
  }, [refreshAll]);

  useEffect(() => {
    if (feedback?.kind !== "success") {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      setFeedback((current) => (current === feedback ? null : current));
    }, SUCCESS_FEEDBACK_TIMEOUT_MS);

    return () => window.clearTimeout(timeoutId);
  }, [feedback]);

  useEffect(() => {
    const cleanups: Array<() => void> = [];
    const bind = async () => {
      cleanups.push(await onEvent(events.accountsChanged, () => void refreshAll()));
      cleanups.push(await onEvent(events.settingsChanged, () => void refreshAll()));
      cleanups.push(await onEvent(events.diagnosticsAppended, () => void refreshAll()));
      cleanups.push(await onEvent(events.usageUpdated, () => void refreshAll()));
      cleanups.push(await onEvent(events.jobsChanged, (payload: LoginJobState) => setLoginState(payload)));
      cleanups.push(await onEvent(events.shellNavigate, (payload: AppView) => setView(payload)));
    };
    void bind();
    return () => cleanups.forEach((cleanup) => cleanup());
  }, [refreshAll]);

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
    <div className="app-window" data-testid="glass-shell">
      <Sidebar activeView={view} onChange={setView} />
      <main className="glass-shell flex min-w-0 flex-1 flex-col overflow-hidden">
        <Topbar
          view={view}
          accountCount={snapshot.accounts.length}
          provider={snapshot.providerStatus.currentProvider || "OpenAI"}
          usageState={formatUsageState(snapshot.activeUsage)}
          usageSourceLabel={formatUsageSource(snapshot.settings.usageSourceMode)}
        />
        <div className="relative z-10 min-h-0 flex-1 overflow-hidden pt-4">
          {view === "accounts" ? (
            <AccountsView
              accounts={snapshot.accounts}
              usage={snapshot.activeUsage}
              loginState={loginState}
              currentAuthMode={snapshot.currentAuthMode}
              showFullEmail={snapshot.settings.showFullEmail}
              usageSourceMode={snapshot.settings.usageSourceMode}
              onShowFullEmailChange={(showFullEmail) => {
                const previousSettings = snapshot.settings;
                const nextSettings = { ...snapshot.settings, showFullEmail };
                const successMessage = settingsFeedbackMessage(snapshot.settings, nextSettings);
                setSettingsOptimistically(nextSettings);
                void runAction(
                  "正在保存设置…",
                  () => saveSettings(nextSettings),
                  successMessage,
                ).catch(() => setSettingsOptimistically(previousSettings));
              }}
              onImportCurrent={() => {
                void runAction("正在导入当前账号…", () => importCurrentAccount(), "当前账号已导入。");
              }}
              onImportBackup={() => {
                setFeedback({ kind: "info", message: "正在选择备份文件…" });
                void pickAuthBackupFiles().then((selected) => {
                  if (selected.length === 0) {
                    setFeedback(null);
                    return;
                  }
                  void runAction(
                    "正在导入备份账号…",
                    () => accountsImportBackups(selected),
                    backupImportSuccessMessage,
                  );
                });
              }}
              onImportBackupDirectory={() => {
                setFeedback({ kind: "info", message: "正在选择备份文件夹…" });
                void pickAuthBackupDirectory().then((selected) => {
                  if (!selected) {
                    setFeedback(null);
                    return;
                  }
                  void runAction(
                    "正在导入文件夹内的备份账号…",
                    () => accountsImportBackups([selected]),
                    backupImportSuccessMessage,
                  );
                });
              }}
              onSwitch={(id) => {
                const previousSnapshot = snapshot;
                setActiveAccountOptimistically(id);
                void runAction("正在切换账号…", () => switchAccount(id), "账号已切换。").catch(() =>
                  setSnapshot(previousSnapshot),
                );
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
          {view === "sessions" ? (
            <SessionsView
              sessions={sessions}
              projects={sessionProjects}
              selectedSession={selectedSession}
              loading={sessionsLoading}
              onRefresh={() => void refreshSessions()}
              onSelectSession={(sessionId) => void loadSessionDetail(sessionId)}
            />
          ) : null}
          {view === "diagnostics" ? <DiagnosticsView diagnostics={snapshot.diagnostics} /> : null}
          {view === "settings" ? (
            <SettingsView
              settings={snapshot.settings}
              onChange={(settings) => {
                const previousSettings = snapshot.settings;
                const successMessage = settingsFeedbackMessage(snapshot.settings, settings);
                setSettingsOptimistically(settings);
                void runAction(
                  "正在保存设置…",
                  async () => {
                    if (settings.launchAtLogin !== snapshot.settings.launchAtLogin) {
                      await setAutostartEnabled(settings.launchAtLogin);
                    }
                    return saveSettings(settings);
                  },
                  successMessage,
                ).catch(() => setSettingsOptimistically(previousSettings));
              }}
            />
          ) : null}
        </div>
        {feedback ? <GlobalFeedback kind={feedback.kind} message={feedback.message} /> : null}
      </main>
    </div>
  );
}

function GlobalFeedback({
  kind,
  message,
}: {
  kind: "info" | "success" | "error";
  message: string;
}) {
  return (
    <div className="pointer-events-none absolute inset-x-0 bottom-3 z-30 flex justify-center px-4">
      <div
        role={kind === "error" ? "alert" : "status"}
        data-testid="global-feedback"
        className={[
          "max-w-[720px] rounded-2xl border px-4 py-2.5 text-[12px] font-semibold shadow-[0_18px_40px_rgba(67,88,116,0.18)] backdrop-blur-xl",
          kind === "error"
            ? "border-rose-200/80 bg-rose-50/90 text-rose-700"
            : kind === "success"
              ? "border-emerald-200/80 bg-emerald-50/90 text-emerald-700"
              : "border-slate-300/70 bg-white/82 text-slate-700",
        ].join(" ")}
      >
        {message}
      </div>
    </div>
  );
}

function formatUsageState(usage: AppSnapshot["activeUsage"]) {
  if (!usage) {
    return "未刷新";
  }
  return `${usage.fiveHour.percentUsed}% / ${usage.weekly.percentUsed}%`;
}

function formatUsageSource(source: AppSnapshot["settings"]["usageSourceMode"]) {
  return source === "automatic" ? "自动" : "本地";
}
