use crate::accounts::AccountsService;
use crate::diagnostics::DiagnosticsService;
use crate::login::LoginService;
use crate::paths::{AppPaths, CodexPaths};
use crate::provider_sync::ProviderSyncService;
use crate::settings::SettingsStore;
use crate::usage::UsageService;

pub const EVENT_ACCOUNTS_CHANGED: &str = "accounts://changed";
pub const EVENT_USAGE_UPDATED: &str = "usage://updated";
pub const EVENT_SETTINGS_CHANGED: &str = "settings://changed";
pub const EVENT_DIAGNOSTICS_APPENDED: &str = "diagnostics://appended";
#[derive(Debug, Clone)]
pub struct AppState {
    pub accounts: AccountsService,
    pub usage: UsageService,
    pub provider_sync: ProviderSyncService,
    pub settings: SettingsStore,
    pub diagnostics: DiagnosticsService,
    pub login: LoginService,
}

impl AppState {
    pub fn new() -> Self {
        let codex_paths = CodexPaths::default();
        Self {
            accounts: AccountsService::new(codex_paths.clone()),
            usage: UsageService::new(codex_paths.clone()),
            provider_sync: ProviderSyncService::new(codex_paths.clone()),
            settings: SettingsStore::new(AppPaths::default()),
            diagnostics: DiagnosticsService::new(codex_paths.clone()),
            login: LoginService::new(codex_paths),
        }
    }
}
