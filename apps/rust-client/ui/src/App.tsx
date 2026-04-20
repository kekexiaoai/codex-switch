import { useEffect, useMemo, useState } from "react";
import {
  events,
  getAppSnapshot,
  importCurrentAccount,
  onEvent,
  refreshUsage,
  runProviderSync,
  saveSettings,
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
  },
};

export function App() {
  const [snapshot, setSnapshot] = useState<AppSnapshot>(emptySnapshot);
  const [view, setView] = useState<AppView>("accounts");
  const [loginState, setLoginState] = useState<LoginJobState | null>(null);
  const [targetProvider, setTargetProvider] = useState("openai");
  const search = useMemo(() => new URLSearchParams(window.location.search), []);
  const isTray = search.get("panel") === "tray";

  const refreshAll = async () => {
    const next = await getAppSnapshot();
    setSnapshot(next);
    setTargetProvider(next.providerStatus.currentProvider || "openai");
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
    };
    void bind();
    return () => cleanups.forEach((cleanup) => cleanup());
  }, []);

  if (isTray) {
    return (
      <TrayView
        accounts={snapshot.accounts}
        usage={snapshot.activeUsage}
        onSwitch={(id) => void switchAccount(id).then(refreshAll)}
        onRefresh={() => void refreshUsage().then(refreshAll)}
        onOpenMain={() => void showMainWindow()}
      />
    );
  }

  return (
    <div className="app-window">
      <Sidebar activeView={view} onChange={setView} />
      <main className="flex min-w-0 flex-col gap-4 overflow-hidden">
        <Topbar view={view} />
        <div className="min-h-0 flex-1 overflow-hidden">
          {view === "accounts" ? (
            <AccountsView
              accounts={snapshot.accounts}
              usage={snapshot.activeUsage}
              loginState={loginState}
              onImportCurrent={() => void importCurrentAccount().then(refreshAll)}
              onSwitch={(id) => void switchAccount(id).then(refreshAll)}
              onRefreshUsage={() => void refreshUsage().then(refreshAll)}
              onLogin={() => void startBrowserLogin().then(setLoginState)}
            />
          ) : null}
          {view === "usage" ? <UsageView usage={snapshot.activeUsage} /> : null}
          {view === "provider-sync" ? (
            <ProviderSyncView
              status={snapshot.providerStatus}
              targetProvider={targetProvider}
              onTargetProviderChange={setTargetProvider}
              onSync={() => void runProviderSync(targetProvider).then(refreshAll)}
              onSwitch={() => void switchProvider(targetProvider).then(refreshAll)}
            />
          ) : null}
          {view === "diagnostics" ? <DiagnosticsView diagnostics={snapshot.diagnostics} /> : null}
          {view === "settings" ? (
            <SettingsView
              settings={snapshot.settings}
              onChange={(settings) => void saveSettings(settings).then(refreshAll)}
            />
          ) : null}
        </div>
      </main>
    </div>
  );
}
