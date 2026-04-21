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
        Self::from_environment()
    }

    pub fn from_environment() -> Self {
        let codex_paths = std::env::var("CODEX_SWITCH_CODEX_DIR")
            .map(std::path::PathBuf::from)
            .map(CodexPaths::new)
            .unwrap_or_else(|_| CodexPaths::default());
        let app_paths = std::env::var("CODEX_SWITCH_CONFIG_DIR")
            .map(std::path::PathBuf::from)
            .map(|config_dir| AppPaths { config_dir })
            .unwrap_or_else(|_| AppPaths::default());
        Self::from_paths(codex_paths, app_paths)
    }

    pub fn from_paths(codex_paths: CodexPaths, app_paths: AppPaths) -> Self {
        Self {
            accounts: AccountsService::new(codex_paths.clone()),
            usage: UsageService::new(codex_paths.clone()),
            provider_sync: ProviderSyncService::new(codex_paths.clone()),
            settings: SettingsStore::new(app_paths),
            diagnostics: DiagnosticsService::new(codex_paths.clone()),
            login: LoginService::new(codex_paths),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::AppState;
    use crate::models::{SettingsDto, UsageSourceMode};
    use crate::paths::{AppPaths, CodexPaths};
    use std::fs;
    use tempfile::tempdir;

    #[tokio::test]
    async fn builds_state_from_custom_paths_and_runs_smoke_flow() {
        let temp = tempdir().unwrap();
        let codex_base = temp.path().join(".codex");
        let config_base = temp.path().join("config");
        let sessions_dir = codex_base.join("sessions/2026/04/21");

        fs::create_dir_all(&sessions_dir).unwrap();
        fs::write(
            codex_base.join("auth.json"),
            r#"{"tokens":{"access_token":"access-token","id_token":"header.eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoiYWNjdC0xIiwicGxhbiI6InRlYW0ifQ.sig"}}"#,
        )
        .unwrap();
        fs::write(
            codex_base.join("config.toml"),
            "model_provider = \"openai\"\n\n[model_providers.custom]\n",
        )
        .unwrap();
        fs::write(
            sessions_dir.join("rollout-1.jsonl"),
            r#"{"timestamp":"2026-04-21T10:00:00Z","email":"alice@example.com","rate_limits":{"five_hour":{"used_percent":42,"resets_at":"2026-04-21T15:00:00Z"},"weekly":{"used_percent":13,"resets_at":"2026-04-28T10:00:00Z"}}}"#,
        )
        .unwrap();

        let state = AppState::from_paths(
            CodexPaths::new(codex_base),
            AppPaths { config_dir: config_base },
        );

        let imported = state.accounts.import_current().unwrap();
        assert_eq!(imported.record.email.as_deref(), Some("alice@example.com"));

        let settings = state
            .settings
            .save(&SettingsDto {
                usage_refresh_enabled: true,
                usage_source_mode: UsageSourceMode::LocalOnly,
                show_full_email: true,
                launch_at_login: false,
            })
            .unwrap();
        let usage = state.usage.refresh_active_usage(&settings).await.unwrap();
        let provider_status = state.provider_sync.load_status().unwrap();

        assert_eq!(usage.five_hour.percent_used, 42);
        assert_eq!(provider_status.current_provider, "openai");
    }

    #[test]
    fn reads_paths_from_environment_overrides() {
        let temp = tempdir().unwrap();
        let codex_base = temp.path().join("fixture-codex");
        let config_base = temp.path().join("fixture-config");

        unsafe {
            std::env::set_var("CODEX_SWITCH_CODEX_DIR", &codex_base);
            std::env::set_var("CODEX_SWITCH_CONFIG_DIR", &config_base);
        }

        let state = AppState::from_environment();

        assert_eq!(state.accounts.store.paths.base_directory, codex_base);
        assert_eq!(state.settings.paths.config_dir, config_base);

        unsafe {
            std::env::remove_var("CODEX_SWITCH_CODEX_DIR");
            std::env::remove_var("CODEX_SWITCH_CONFIG_DIR");
        }
    }
}
