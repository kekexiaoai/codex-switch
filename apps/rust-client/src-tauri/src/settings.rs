use crate::error::{AppError, AppResult};
use crate::models::SettingsDto;
use crate::paths::AppPaths;
use crate::store::atomic_write;
use std::fs;

#[derive(Debug, Clone)]
pub struct SettingsStore {
    pub paths: AppPaths,
}

impl SettingsStore {
    pub fn new(paths: AppPaths) -> Self {
        Self { paths }
    }

    pub fn load(&self) -> AppResult<SettingsDto> {
        let path = self.paths.settings_file();
        if !path.exists() {
            return Ok(SettingsDto::default());
        }
        let data = fs::read(path)?;
        Ok(serde_json::from_slice(&data)?)
    }

    pub fn save(&self, settings: &SettingsDto) -> AppResult<SettingsDto> {
        let bytes = serde_json::to_vec_pretty(settings)?;
        atomic_write(&self.paths.settings_file(), &bytes)
            .map_err(|_| AppError::SettingsWriteFailed)?;
        Ok(settings.clone())
    }
}

#[cfg(test)]
mod tests {
    use super::SettingsStore;
    use crate::models::UsageSourceMode;
    use crate::paths::AppPaths;
    use tempfile::tempdir;

    #[test]
    fn persists_settings_to_app_directory() {
        let temp = tempdir().unwrap();
        let store = SettingsStore::new(AppPaths {
            config_dir: temp.path().join("config"),
        });
        let mut settings = store.load().unwrap();
        settings.show_full_email = true;
        settings.usage_source_mode = UsageSourceMode::LocalOnly;
        store.save(&settings).unwrap();
        let loaded = store.load().unwrap();
        assert!(loaded.show_full_email);
        assert!(matches!(
            loaded.usage_source_mode,
            UsageSourceMode::LocalOnly
        ));
    }
}
