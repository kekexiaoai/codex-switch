use crate::models::{
    AppSnapshot, DiagnosticsEvent, LoginJobState, ProviderSyncStatus, SettingsDto, SyncResult,
    UsageSnapshot,
};
use crate::state::{
    AppState, EVENT_ACCOUNTS_CHANGED, EVENT_DIAGNOSTICS_APPENDED, EVENT_SETTINGS_CHANGED,
    EVENT_USAGE_UPDATED,
};
use tauri::{AppHandle, Emitter, Manager, State, WebviewWindow};

type CmdResult<T> = Result<T, String>;

#[tauri::command]
pub fn app_show_main_window(app: AppHandle) -> CmdResult<()> {
    let window = app
        .get_webview_window("main")
        .ok_or_else(|| "主窗口不存在".to_string())?;
    show_window(&window)
}

#[tauri::command]
pub fn app_snapshot(state: State<'_, AppState>) -> CmdResult<AppSnapshot> {
    let settings = state.settings.load().map_err(|e| e.to_string())?;
    let accounts = state.accounts.list().map_err(|e| e.to_string())?;
    let provider_status = state.provider_sync.load_status().unwrap_or_default();
    let diagnostics = state.diagnostics.recent(6).unwrap_or_default();
    let active_usage = state
        .usage
        .load_cached(
            &accounts
                .iter()
                .find(|account| account.is_active)
                .map(|account| account.record.id.clone())
                .unwrap_or_default(),
        )
        .unwrap_or(None);
    Ok(AppSnapshot {
        active_account_id: accounts
            .iter()
            .find(|account| account.is_active)
            .map(|account| account.record.id.clone()),
        accounts,
        active_usage,
        settings,
        diagnostics,
        provider_status,
    })
}

#[tauri::command]
pub fn accounts_list(state: State<'_, AppState>) -> CmdResult<Vec<crate::models::AccountListItem>> {
    state.accounts.list().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn accounts_import_current(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<crate::models::AccountListItem> {
    let account = state.accounts.import_current().map_err(|e| e.to_string())?;
    let _ = app.emit(EVENT_ACCOUNTS_CHANGED, true);
    Ok(account)
}

#[tauri::command]
pub fn accounts_import_backup(
    app: AppHandle,
    state: State<'_, AppState>,
    path: String,
) -> CmdResult<crate::models::AccountListItem> {
    let account = state
        .accounts
        .import_backup(&path)
        .map_err(|e| e.to_string())?;
    let _ = app.emit(EVENT_ACCOUNTS_CHANGED, true);
    Ok(account)
}

#[tauri::command]
pub fn accounts_switch(
    app: AppHandle,
    state: State<'_, AppState>,
    account_id: String,
) -> CmdResult<crate::models::AccountListItem> {
    let account = state
        .accounts
        .switch(&account_id)
        .map_err(|e| e.to_string())?;
    let _ = app.emit(EVENT_ACCOUNTS_CHANGED, true);
    Ok(account)
}

#[tauri::command]
pub fn accounts_login_start(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<LoginJobState> {
    let job = state.login.start(app).map_err(|e| e.to_string())?;
    Ok(job)
}

#[tauri::command]
pub async fn usage_refresh(app: AppHandle, state: State<'_, AppState>) -> CmdResult<UsageSnapshot> {
    let settings = state.settings.load().map_err(|e| e.to_string())?;
    let snapshot = state
        .usage
        .refresh_active_usage(&settings)
        .await
        .map_err(|e| e.to_string())?;
    let _ = app.emit(EVENT_USAGE_UPDATED, &snapshot);
    Ok(snapshot)
}

#[tauri::command]
pub fn provider_sync_status(state: State<'_, AppState>) -> CmdResult<ProviderSyncStatus> {
    state.provider_sync.load_status().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn provider_sync_run(
    app: AppHandle,
    state: State<'_, AppState>,
    target_provider: Option<String>,
) -> CmdResult<SyncResult> {
    let result = state
        .provider_sync
        .sync(target_provider)
        .map_err(|e| e.to_string())?;
    let _ = app.emit(EVENT_DIAGNOSTICS_APPENDED, true);
    Ok(result)
}

#[tauri::command]
pub fn provider_switch(
    app: AppHandle,
    state: State<'_, AppState>,
    provider: String,
) -> CmdResult<SyncResult> {
    let result = state
        .provider_sync
        .switch_provider(provider)
        .map_err(|e| e.to_string())?;
    let _ = app.emit(EVENT_DIAGNOSTICS_APPENDED, true);
    Ok(result)
}

#[tauri::command]
pub fn settings_get(state: State<'_, AppState>) -> CmdResult<SettingsDto> {
    state.settings.load().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn settings_update(
    app: AppHandle,
    state: State<'_, AppState>,
    settings: SettingsDto,
) -> CmdResult<SettingsDto> {
    let saved = state.settings.save(&settings).map_err(|e| e.to_string())?;
    let _ = app.emit(EVENT_SETTINGS_CHANGED, &saved);
    Ok(saved)
}

#[tauri::command]
pub fn diagnostics_recent(
    state: State<'_, AppState>,
    limit: Option<usize>,
) -> CmdResult<Vec<DiagnosticsEvent>> {
    state
        .diagnostics
        .recent(limit.unwrap_or(8))
        .map_err(|e| e.to_string())
}

fn show_window(window: &WebviewWindow) -> CmdResult<()> {
    window.show().map_err(|e| e.to_string())?;
    window.unminimize().map_err(|e| e.to_string())?;
    window.set_focus().map_err(|e| e.to_string())
}
