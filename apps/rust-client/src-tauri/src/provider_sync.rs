use crate::error::{AppError, AppResult};
use crate::models::{ProviderDistribution, ProviderSyncStatus, SyncResult};
use crate::paths::CodexPaths;
use chrono::Utc;
use rusqlite::Connection;
use serde_json::Value;
use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use walkdir::WalkDir;

#[derive(Debug, Clone)]
pub struct ProviderSyncService {
    pub paths: CodexPaths,
}

impl ProviderSyncService {
    pub fn new(paths: CodexPaths) -> Self {
        Self { paths }
    }

    pub fn load_status(&self) -> AppResult<ProviderSyncStatus> {
        let config_text = fs::read_to_string(self.paths.config_file()).unwrap_or_default();
        Ok(ProviderSyncStatus {
            current_provider: read_current_provider(&config_text).0,
            configured_providers: list_configured_provider_ids(&config_text),
            rollout_distribution: self.scan_rollout_distribution()?,
            sqlite_distribution: self.sqlite_distribution()?,
            backup_count: count_dirs(self.paths.provider_sync_backups_dir())? as i32,
            backup_total_size: dir_size(self.paths.provider_sync_backups_dir())?,
        })
    }

    pub fn sync(&self, target_provider: Option<String>) -> AppResult<SyncResult> {
        let status = self.load_status()?;
        let provider = target_provider.unwrap_or(status.current_provider);
        let backup_dir = self.create_backup(&provider)?;
        let changes = self.rewrite_rollouts(&provider)?;
        let rows_changed = self.update_sqlite(&provider)?;
        let _ = backup_dir;
        Ok(SyncResult {
            target_provider: provider,
            files_changed: changes,
            rows_changed,
            config_updated: false,
        })
    }

    pub fn switch_provider(&self, provider: String) -> AppResult<SyncResult> {
        let config_path = self.paths.config_file();
        let config_text = fs::read_to_string(&config_path).unwrap_or_default();
        let updated = set_root_provider(&config_text, &provider);
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&config_path, updated)?;
        let mut result = self.sync(Some(provider))?;
        result.config_updated = true;
        Ok(result)
    }

    fn create_backup(&self, provider: &str) -> AppResult<PathBuf> {
        let timestamp = Utc::now().format("%Y%m%dT%H%M%S").to_string();
        let dir = self.paths.provider_sync_backups_dir().join(timestamp);
        fs::create_dir_all(dir.join("db"))?;
        if self.paths.config_file().exists() {
            fs::copy(self.paths.config_file(), dir.join("config.toml"))?;
        }
        if self.paths.sqlite_database().exists() {
            fs::copy(
                self.paths.sqlite_database(),
                dir.join("db").join("state_5.sqlite"),
            )?;
        }
        fs::write(
            dir.join("metadata.json"),
            serde_json::to_vec_pretty(&serde_json::json!({ "targetProvider": provider }))?,
        )?;
        Ok(dir)
    }

    fn scan_rollout_distribution(&self) -> AppResult<Vec<ProviderDistribution>> {
        let mut map: BTreeMap<String, i32> = BTreeMap::new();
        for entry in WalkDir::new(self.paths.sessions_dir())
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| {
                entry.file_type().is_file()
                    && entry.file_name().to_string_lossy().starts_with("rollout-")
            })
        {
            let Some(first) = fs::read_to_string(entry.path())
                .ok()
                .and_then(|text| text.lines().next().map(str::to_string))
            else {
                continue;
            };
            let Ok(value) = serde_json::from_str::<Value>(&first) else {
                continue;
            };
            let provider = value
                .get("payload")
                .and_then(|payload| payload.get("model_provider"))
                .and_then(|value| value.as_str())
                .unwrap_or("(missing)");
            *map.entry(provider.to_string()).or_default() += 1;
        }
        Ok(map
            .into_iter()
            .map(|(provider, count)| ProviderDistribution {
                provider,
                session_count: count,
                archived_count: 0,
            })
            .collect())
    }

    fn sqlite_distribution(&self) -> AppResult<Vec<ProviderDistribution>> {
        let path = self.paths.sqlite_database();
        if !path.exists() {
            return Ok(vec![]);
        }
        let connection = Connection::open(path)?;
        let mut statement = connection.prepare(
            "SELECT COALESCE(model_provider, '(missing)') AS model_provider, COUNT(*) AS count FROM threads GROUP BY model_provider",
        )?;
        let rows = statement.query_map([], |row| {
            Ok(ProviderDistribution {
                provider: row.get::<_, String>(0)?,
                session_count: row.get::<_, i64>(1)? as i32,
                archived_count: 0,
            })
        })?;
        Ok(rows.filter_map(Result::ok).collect())
    }

    fn rewrite_rollouts(&self, provider: &str) -> AppResult<i32> {
        let mut changed = 0;
        for entry in WalkDir::new(self.paths.sessions_dir())
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| {
                entry.file_type().is_file()
                    && entry.file_name().to_string_lossy().starts_with("rollout-")
            })
        {
            let content = fs::read_to_string(entry.path())?;
            let mut lines = content.lines();
            let Some(first_line) = lines.next() else {
                continue;
            };
            let Ok(mut value) = serde_json::from_str::<Value>(first_line) else {
                continue;
            };
            let current_provider = value
                .get("payload")
                .and_then(|payload| payload.get("model_provider"))
                .and_then(|value| value.as_str());
            if current_provider == Some(provider) {
                continue;
            }
            if let Some(payload) = value
                .get_mut("payload")
                .and_then(|payload| payload.as_object_mut())
            {
                payload.insert("model_provider".into(), Value::String(provider.to_string()));
                let mut rebuilt = serde_json::to_string(&value)?;
                for line in lines {
                    rebuilt.push('\n');
                    rebuilt.push_str(line);
                }
                fs::write(entry.path(), rebuilt)?;
                changed += 1;
            }
        }
        Ok(changed)
    }

    fn update_sqlite(&self, provider: &str) -> AppResult<i32> {
        let path = self.paths.sqlite_database();
        if !path.exists() {
            return Ok(0);
        }
        let connection = Connection::open(path)?;
        let changed = connection.execute("UPDATE threads SET model_provider = ?1", [provider])?;
        Ok(changed as i32)
    }
}

pub fn read_current_provider(config_text: &str) -> (String, bool) {
    for line in config_text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        if trimmed.starts_with('[') {
            break;
        }
        if let Some(value) = trimmed.strip_prefix("model_provider") {
            if let Some(provider) = value.split('=').nth(1) {
                return (provider.trim().trim_matches('"').to_string(), false);
            }
        }
    }
    ("openai".into(), true)
}

pub fn list_configured_provider_ids(config_text: &str) -> Vec<String> {
    let mut providers: BTreeMap<String, ()> = BTreeMap::new();
    providers.insert("openai".into(), ());
    for line in config_text.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("[model_providers.") && trimmed.ends_with(']') {
            let provider = trimmed
                .trim_start_matches("[model_providers.")
                .trim_end_matches(']')
                .to_string();
            providers.insert(provider, ());
        }
    }
    providers.into_keys().collect()
}

pub fn set_root_provider(config_text: &str, provider: &str) -> String {
    let mut lines: Vec<String> = config_text.lines().map(ToString::to_string).collect();
    for line in &mut lines {
        if line.trim().starts_with("model_provider") {
            *line = format!("model_provider = \"{provider}\"");
            return lines.join("\n");
        }
    }
    let insert_at = lines
        .iter()
        .position(|line| line.trim().starts_with('['))
        .unwrap_or(lines.len());
    lines.insert(insert_at, format!("model_provider = \"{provider}\""));
    lines.join("\n")
}

fn count_dirs(path: PathBuf) -> AppResult<usize> {
    if !path.exists() {
        return Ok(0);
    }
    Ok(fs::read_dir(path)?
        .filter_map(Result::ok)
        .filter(|entry| entry.path().is_dir())
        .count())
}

fn dir_size(path: PathBuf) -> AppResult<u64> {
    if !path.exists() {
        return Ok(0);
    }
    let mut size = 0;
    for entry in WalkDir::new(path)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file())
    {
        size += entry
            .metadata()
            .map_err(|error| AppError::Message(error.to_string()))?
            .len();
    }
    Ok(size)
}

#[cfg(test)]
mod tests {
    use super::{list_configured_provider_ids, read_current_provider, set_root_provider};

    #[test]
    fn reads_and_updates_root_provider() {
        let config = "model_provider = \"openai\"\n\n[model_providers.custom]\n";
        assert_eq!(read_current_provider(config).0, "openai");
        assert_eq!(
            set_root_provider(config, "custom"),
            "model_provider = \"custom\"\n\n[model_providers.custom]"
        );
        assert_eq!(
            list_configured_provider_ids(config),
            vec!["custom".to_string(), "openai".to_string()]
        );
    }
}
