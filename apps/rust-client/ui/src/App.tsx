import { AlertTriangle } from "lucide-react";
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
  removeAccount,
  restoreProviderBackup,
  runProviderSync,
  saveSettings,
  setAutostartEnabled,
  showMainWindow,
  startBrowserLogin,
  switchAccount,
  switchProvider,
  type AccountListItem,
  type AppSnapshot,
  type BackupImportResult,
  type CodexSessionDetail,
  type CodexSessionListItem,
  type LoginJobState,
} from "@/lib/tauri";
import { Button } from "@/components/ui/button";
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

type UsageRefreshStatus = {
  kind: "success" | "error";
  message: string;
};

type PendingAccountRemoval = {
  id: string;
  label: string;
  account: AccountListItem;
};

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
  const [usageRefreshStatus, setUsageRefreshStatus] = useState<UsageRefreshStatus | null>(null);
  const [pendingAccountRemoval, setPendingAccountRemoval] = useState<PendingAccountRemoval | null>(null);
  const refreshInFlight = useRef<Promise<boolean> | null>(null);
  const search = useMemo(() => new URLSearchParams(window.location.search), []);
  const isTray = search.get("panel") === "tray";

  const refreshAll = useCallback((options?: { reportErrors?: boolean }) => {
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
        if (options?.reportErrors !== false) {
          setFeedback({
            kind: "error",
            message: error instanceof Error ? error.message : String(error),
          });
        }
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
    options?: { showErrorFeedback?: boolean },
  ) => {
    try {
      setFeedback({ kind: "info", message: pendingMessage });
      const result = await action();
      setFeedback({
        kind: "success",
        message: typeof successMessage === "function" ? successMessage(result) : successMessage,
      });
      void refreshAll({ reportErrors: false });
      return result;
    } catch (error) {
      if (options?.showErrorFeedback === false) {
        setFeedback(null);
      } else {
        setFeedback({
          kind: "error",
          message: error instanceof Error ? error.message : String(error),
        });
      }
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
        onSwitch={(id) => void switchAccount(id).then(() => refreshAll())}
        onRefresh={() => void refreshUsage().then(() => refreshAll())}
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
              usageRefreshStatus={usageRefreshStatus}
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
                setUsageRefreshStatus(null);
                void runAction("正在切换账号…", () => switchAccount(id), "账号已切换。").catch(() =>
                  setSnapshot(previousSnapshot),
                );
              }}
              onRemove={(id) => {
                const target = snapshot.accounts.find((account) => account.id === id);
                if (!target) {
                  return;
                }
                if (target.isActive) {
                  setFeedback({
                    kind: "error",
                    message: "当前正在使用的账号不能清除，请先切换到其他账号。",
                  });
                  return;
                }
                const label = target.email ?? target.emailMask;
                setPendingAccountRemoval({ id, label, account: target });
              }}
              onRefreshUsage={() => {
                void runAction(
                  "正在刷新 Usage…",
                  () => refreshUsage(),
                  (snapshot) => {
                    const source = snapshot.sourceLabel ?? "未知来源";
                    return `Usage 已刷新，来源：${source}。`;
                  },
                  { showErrorFeedback: false },
                )
                  .then((snapshot) => {
                    setUsageRefreshStatus({
                      kind: "success",
                      message: `已刷新，来源：${snapshot.sourceLabel ?? "未知来源"}`,
                    });
                  })
                  .catch((error) => {
                    setUsageRefreshStatus({
                      kind: "error",
                      message: error instanceof Error ? error.message : String(error),
                    });
                  });
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
        {pendingAccountRemoval ? (
          <AccountRemovalDialog
            account={pendingAccountRemoval.account}
            label={pendingAccountRemoval.label}
            onCancel={() => setPendingAccountRemoval(null)}
            onConfirm={() => {
              const { id } = pendingAccountRemoval;
              setPendingAccountRemoval(null);
              void runAction("正在清除账号…", () => removeAccount(id), "账号已清除。");
            }}
          />
        ) : null}
      </main>
    </div>
  );
}

function AccountRemovalDialog({
  account,
  label,
  onCancel,
  onConfirm,
}: {
  account: AccountListItem;
  label: string;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <div className="absolute inset-0 z-40 grid place-items-center bg-slate-950/18 px-4 backdrop-blur-sm">
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby="account-removal-title"
        className="w-full max-w-[420px] rounded-2xl border border-rose-200/80 bg-white/96 p-5 shadow-[0_24px_60px_rgba(67,88,116,0.24)]"
      >
        <div className="flex items-start gap-3">
          <div className="grid h-9 w-9 shrink-0 place-items-center rounded-xl border border-rose-200 bg-rose-50 text-rose-600">
            <AlertTriangle className="h-4 w-4" />
          </div>
          <div className="min-w-0">
            <h2 id="account-removal-title" className="m-0 text-[16px] font-black tracking-[-0.03em] text-slate-950">
              清除归档账号
            </h2>
            <div className="mt-1 truncate text-[13px] font-bold text-slate-700">{label}</div>
          </div>
        </div>
        <div className="mt-4 rounded-xl border border-slate-200/80 bg-slate-50/80 px-3 py-2.5 text-[12px] leading-5 text-slate-600">
          这只会删除本地归档记录，不会注销远程账号，也不会删除当前 auth.json。
        </div>
        <div className="mt-3 grid grid-cols-2 gap-2 text-[11px] font-semibold text-slate-500">
          <div className="truncate rounded-xl bg-white/80 px-3 py-2">来源：{account.source}</div>
          <div className="truncate rounded-xl bg-white/80 px-3 py-2">归档：{account.archiveFilename}</div>
        </div>
        <div className="mt-5 flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={onCancel}>
            取消
          </Button>
          <Button type="button" variant="danger" onClick={onConfirm}>
            确认清除
          </Button>
        </div>
      </section>
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
