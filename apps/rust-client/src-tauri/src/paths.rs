use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct CodexPaths {
    pub base_directory: PathBuf,
}

impl CodexPaths {
    pub fn new(base_directory: PathBuf) -> Self {
        Self { base_directory }
    }

    pub fn auth_file(&self) -> PathBuf {
        self.base_directory.join("auth.json")
    }

    pub fn accounts_dir(&self) -> PathBuf {
        self.base_directory.join("accounts")
    }

    pub fn metadata_cache(&self) -> PathBuf {
        self.accounts_dir().join("metadata.json")
    }

    pub fn usage_cache(&self) -> PathBuf {
        self.accounts_dir().join("usage-cache.json")
    }

    pub fn sessions_dir(&self) -> PathBuf {
        self.base_directory.join("sessions")
    }

    pub fn history_file(&self) -> PathBuf {
        self.base_directory.join("history.jsonl")
    }

    pub fn config_file(&self) -> PathBuf {
        self.base_directory.join("config.toml")
    }

    pub fn sqlite_database(&self) -> PathBuf {
        self.base_directory.join("state_5.sqlite")
    }

    pub fn provider_sync_backups_dir(&self) -> PathBuf {
        self.base_directory
            .join("backups_state")
            .join("provider-sync")
    }

    pub fn provider_sync_lock_file(&self) -> PathBuf {
        self.base_directory.join("tmp").join("provider-sync.lock")
    }

    pub fn diagnostics_dir(&self) -> PathBuf {
        self.base_directory.join("codex-switch")
    }

    pub fn browser_login_log(&self) -> PathBuf {
        self.diagnostics_dir().join("browser-login.log")
    }

    pub fn usage_refresh_log(&self) -> PathBuf {
        self.diagnostics_dir().join("usage-refresh.log")
    }

    pub fn account_reorder_log(&self) -> PathBuf {
        self.diagnostics_dir().join("account-reorder.log")
    }

    pub fn from_home(home: PathBuf) -> Self {
        Self::new(home.join(".codex"))
    }

    pub fn default() -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
        Self::from_home(home)
    }
}

#[derive(Debug, Clone)]
pub struct AppPaths {
    pub config_dir: PathBuf,
}

impl AppPaths {
    pub fn default() -> Self {
        let base = dirs::config_dir()
            .or_else(dirs::home_dir)
            .unwrap_or_else(|| PathBuf::from("."));
        Self {
            config_dir: base.join("codex-switch"),
        }
    }

    pub fn settings_file(&self) -> PathBuf {
        self.config_dir.join("settings.json")
    }
}

#[cfg(test)]
mod tests {
    use super::CodexPaths;
    use std::path::PathBuf;

    #[test]
    fn derives_codex_paths_from_base_directory() {
        let paths = CodexPaths::new(PathBuf::from("/tmp/.codex"));
        assert_eq!(paths.auth_file(), PathBuf::from("/tmp/.codex/auth.json"));
        assert_eq!(
            paths.usage_cache(),
            PathBuf::from("/tmp/.codex/accounts/usage-cache.json")
        );
        assert_eq!(
            paths.sqlite_database(),
            PathBuf::from("/tmp/.codex/state_5.sqlite")
        );
    }

    #[test]
    fn derives_codex_paths_from_user_home_on_windows_style_paths() {
        let paths = CodexPaths::from_home(PathBuf::from(r"C:\Users\alice"));
        assert_eq!(
            paths.base_directory,
            PathBuf::from(r"C:\Users\alice").join(".codex")
        );
        assert_eq!(
            paths.auth_file(),
            PathBuf::from(r"C:\Users\alice")
                .join(".codex")
                .join("auth.json")
        );
    }
}
