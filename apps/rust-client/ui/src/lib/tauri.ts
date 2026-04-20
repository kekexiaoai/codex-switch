import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";

export type UsageSourceMode = "automatic" | "localOnly";

export interface AccountListItem {
  id: string;
  emailMask: string;
  email?: string | null;
  tier: "plus" | "pro" | "team" | "unknown";
  manualOrder: number;
  archiveFilename: string;
  source: "currentAuth" | "backupImport" | "browserLogin" | "fixture";
  lastImportedAt: string;
  isActive: boolean;
}

export interface UsageWindow {
  percentUsed: number;
  resetsAt: string;
}

export interface UsageSnapshot {
  accountId: string;
  updatedAt: string;
  sourceLabel?: string | null;
  fiveHour: UsageWindow;
  weekly: UsageWindow;
}

export interface ProviderDistribution {
  provider: string;
  sessionCount: number;
  archivedCount: number;
}

export interface ProviderSyncStatus {
  currentProvider: string;
  configuredProviders: string[];
  rolloutDistribution: ProviderDistribution[];
  sqliteDistribution: ProviderDistribution[];
  backupCount: number;
  backupTotalSize: number;
}

export interface SettingsDto {
  usageRefreshEnabled: boolean;
  usageSourceMode: UsageSourceMode;
  showFullEmail: boolean;
  launchAtLogin: boolean;
}

export interface DiagnosticsEvent {
  category: string;
  message: string;
  raw: string;
}

export interface AppSnapshot {
  accounts: AccountListItem[];
  activeAccountId?: string | null;
  activeUsage?: UsageSnapshot | null;
  settings: SettingsDto;
  diagnostics: DiagnosticsEvent[];
  providerStatus: ProviderSyncStatus;
}

export interface SyncResult {
  targetProvider: string;
  filesChanged: number;
  rowsChanged: number;
  configUpdated: boolean;
}

export interface LoginJobState {
  active: boolean;
  message: string;
}

export const events = {
  accountsChanged: "accounts://changed",
  usageUpdated: "usage://updated",
  settingsChanged: "settings://changed",
  diagnosticsAppended: "diagnostics://appended",
  jobsChanged: "jobs://state-changed",
} as const;

export function onEvent<T>(event: string, handler: (payload: T) => void): Promise<UnlistenFn> {
  return listen<T>(event, (entry) => handler(entry.payload));
}

export function getAppSnapshot() {
  return invoke<AppSnapshot>("app_snapshot");
}

export function showMainWindow() {
  return invoke("app_show_main_window");
}

export function importCurrentAccount() {
  return invoke<AccountListItem>("accounts_import_current");
}

export function switchAccount(accountId: string) {
  return invoke<AccountListItem>("accounts_switch", { accountId });
}

export function startBrowserLogin() {
  return invoke<LoginJobState>("accounts_login_start");
}

export function refreshUsage() {
  return invoke<UsageSnapshot>("usage_refresh");
}

export function loadProviderStatus() {
  return invoke<ProviderSyncStatus>("provider_sync_status");
}

export function runProviderSync(targetProvider?: string) {
  return invoke<SyncResult>("provider_sync_run", { targetProvider });
}

export function switchProvider(provider: string) {
  return invoke<SyncResult>("provider_switch", { provider });
}

export function getSettings() {
  return invoke<SettingsDto>("settings_get");
}

export function saveSettings(settings: SettingsDto) {
  return invoke<SettingsDto>("settings_update", { settings });
}

export function loadDiagnostics(limit = 8) {
  return invoke<DiagnosticsEvent[]>("diagnostics_recent", { limit });
}
