import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import {
  disable as disableAutostart,
  enable as enableAutostart,
  isEnabled as isAutostartEnabled,
} from "@tauri-apps/plugin-autostart";
import { open } from "@tauri-apps/plugin-dialog";

export type UsageSourceMode = "automatic" | "localOnly";

export interface AccountListItem {
  id: string;
  emailMask: string;
  email?: string | null;
  tier: "plus" | "pro" | "team" | "unknown";
  authMode: CurrentAuthMode;
  manualOrder: number;
  archiveFilename: string;
  source: "currentAuth" | "backupImport" | "browserLogin" | "fixture";
  lastImportedAt: string;
  isActive: boolean;
}

export type CurrentAuthMode = "missing" | "oauth" | "openaiApiKey" | "invalid";

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

export interface BackupEntry {
  id: string;
  targetProvider: string;
  totalSize: number;
  createdAt: string;
}

export interface ProviderSyncStatus {
  currentProvider: string;
  configuredProviders: string[];
  rolloutDistribution: ProviderDistribution[];
  sqliteDistribution: ProviderDistribution[];
  backupCount: number;
  backupTotalSize: number;
  backups: BackupEntry[];
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
  currentAuthMode: CurrentAuthMode;
  activeUsage?: UsageSnapshot | null;
  settings: SettingsDto;
  diagnostics: DiagnosticsEvent[];
  providerStatus: ProviderSyncStatus;
}

export interface BackupImportResult {
  accounts: AccountListItem[];
  skippedCount: number;
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
  authUrl?: string | null;
}

export interface CodexRestartResult {
  attempted: boolean;
  success: boolean;
  message: string;
}

export interface CodexSessionListItem {
  id: string;
  display: string;
  timestamp: string;
  project: string;
  projectName: string;
  filePath?: string | null;
  messageCount: number;
}

export interface CodexSessionMessage {
  role: string;
  kind: string;
  text: string;
  timestamp?: string | null;
}

export interface CodexSessionDetail {
  session: CodexSessionListItem;
  messages: CodexSessionMessage[];
}

export const events = {
  accountsChanged: "accounts://changed",
  usageUpdated: "usage://updated",
  settingsChanged: "settings://changed",
  diagnosticsAppended: "diagnostics://appended",
  jobsChanged: "jobs://state-changed",
  shellNavigate: "shell://navigate",
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

export function openView(view: "accounts" | "usage" | "provider-sync" | "sessions" | "diagnostics" | "settings") {
  return invoke("app_open_view", { view });
}

export function quitApp() {
  return invoke("app_quit");
}

export function restartCodexApp() {
  return invoke<CodexRestartResult>("app_restart_codex");
}

export function getAutostartEnabled() {
  return isAutostartEnabled();
}

export async function setAutostartEnabled(enabled: boolean) {
  if (enabled) {
    await enableAutostart();
    return;
  }
  await disableAutostart();
}

export function importCurrentAccount() {
  return invoke<AccountListItem>("accounts_import_current");
}

export function accountsImportBackup(path: string) {
  return invoke<AccountListItem>("accounts_import_backup", { path });
}

export function accountsImportBackups(paths: string[]) {
  return invoke<BackupImportResult>("accounts_import_backups", { paths });
}

export async function pickAuthBackupFiles() {
  const selected = await open({
    multiple: true,
    directory: false,
    filters: [
      {
        name: "Codex Auth JSON",
        extensions: ["json"],
      },
    ],
  });
  if (!selected) {
    return [];
  }
  return Array.isArray(selected) ? selected : [selected];
}

export async function pickAuthBackupDirectory() {
  const selected = await open({
    multiple: false,
    directory: true,
  });
  return typeof selected === "string" ? selected : null;
}

export function switchAccount(accountId: string) {
  return invoke<AccountListItem>("accounts_switch", { accountId });
}

export function removeAccount(accountId: string) {
  return invoke<AccountListItem>("accounts_remove", { accountId });
}

export function startBrowserLogin() {
  return invoke<LoginJobState>("accounts_login_start");
}

export function cancelBrowserLogin() {
  return invoke<LoginJobState>("accounts_login_cancel");
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

export function loadProviderBackups() {
  return invoke<BackupEntry[]>("provider_sync_backups");
}

export function restoreProviderBackup(backupId: string) {
  return invoke("provider_sync_restore", { backupId });
}

export function pruneProviderBackups(keep = 5) {
  return invoke("provider_sync_prune", { keep });
}

export function listSessions() {
  return invoke<CodexSessionListItem[]>("sessions_list");
}

export function listSessionProjects() {
  return invoke<string[]>("sessions_projects");
}

export function getSessionDetail(sessionId: string) {
  return invoke<CodexSessionDetail>("sessions_get", { sessionId });
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
