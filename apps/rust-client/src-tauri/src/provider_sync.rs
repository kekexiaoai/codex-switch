use crate::error::{AppError, AppResult};
use crate::models::{BackupEntry, ProviderDistribution, ProviderSyncStatus, SyncResult};
use crate::paths::CodexPaths;
use chrono::{DateTime, Utc};
use rusqlite::Connection;
use serde_json::Value;
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
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
        let backups = self.list_backups()?;
        Ok(ProviderSyncStatus {
            current_provider: read_current_provider(&config_text).0,
            configured_providers: list_configured_provider_ids(&config_text),
            rollout_distribution: self.scan_rollout_distribution()?,
            sqlite_distribution: self.sqlite_distribution()?,
            backup_count: backups.len() as i32,
            backup_total_size: backups.iter().map(|entry| entry.total_size).sum(),
            backups,
        })
    }

    pub fn sync(&self, target_provider: Option<String>) -> AppResult<SyncResult> {
        let status = self.load_status()?;
        let provider = target_provider.unwrap_or(status.current_provider);
        let changes = self.collect_rollout_changes(&provider)?;
        let backup_dir = self.create_backup(&provider, &changes)?;
        let result = self.apply_sync(&provider, &changes);
        if let Err(error) = result {
            self.restore_backup_dir(&backup_dir)?;
            return Err(error);
        }
        self.prune_backups(5)?;
        Ok(SyncResult {
            target_provider: provider,
            files_changed: changes.len() as i32,
            rows_changed: result?,
            config_updated: false,
        })
    }

    pub fn switch_provider(&self, provider: String) -> AppResult<SyncResult> {
        let config_path = self.paths.config_file();
        let config_text = fs::read_to_string(&config_path).unwrap_or_default();
        let changes = self.collect_rollout_changes(&provider)?;
        let backup_dir = self.create_backup(&provider, &changes)?;
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&config_path, set_root_provider(&config_text, &provider))?;
        let result = self.apply_sync(&provider, &changes);
        match result {
            Ok(rows_changed) => {
                self.prune_backups(5)?;
                Ok(SyncResult {
                    target_provider: provider,
                    files_changed: changes.len() as i32,
                    rows_changed,
                    config_updated: true,
                })
            }
            Err(error) => {
                self.restore_backup_dir(&backup_dir)?;
                Err(error)
            }
        }
    }

    pub fn list_backups(&self) -> AppResult<Vec<BackupEntry>> {
        let root = self.paths.provider_sync_backups_dir();
        if !root.exists() {
            return Ok(vec![]);
        }
        let mut backups = vec![];
        for entry in fs::read_dir(root)? {
            let entry = entry?;
            let path = entry.path();
            if !path.is_dir() {
                continue;
            }
            let id = path
                .file_name()
                .and_then(|value| value.to_str())
                .unwrap_or_default()
                .to_string();
            let metadata_path = path.join("metadata.json");
            let target_provider = if metadata_path.exists() {
                fs::read_to_string(&metadata_path)
                    .ok()
                    .and_then(|raw| serde_json::from_str::<Value>(&raw).ok())
                    .and_then(|value| {
                        value
                            .get("targetProvider")
                            .and_then(|value| value.as_str())
                            .map(str::to_string)
                    })
                    .unwrap_or_else(|| "unknown".into())
            } else {
                "unknown".into()
            };
            let created_at = parse_backup_timestamp(&id).unwrap_or_else(Utc::now);
            backups.push(BackupEntry {
                id,
                target_provider,
                total_size: dir_size(path)?,
                created_at,
            });
        }
        backups.sort_by(|left, right| right.id.cmp(&left.id));
        Ok(backups)
    }

    pub fn restore_backup(&self, backup_id: &str) -> AppResult<()> {
        let dir = self.paths.provider_sync_backups_dir().join(backup_id);
        if !dir.exists() {
            return Err(AppError::NotFound(format!("provider backup {backup_id}")));
        }
        self.restore_backup_dir(&dir)
    }

    pub fn prune_backups(&self, keep: usize) -> AppResult<()> {
        let backups = self.list_backups()?;
        for backup in backups.into_iter().skip(keep) {
            let dir = self.paths.provider_sync_backups_dir().join(backup.id);
            if dir.exists() {
                fs::remove_dir_all(dir)?;
            }
        }
        Ok(())
    }

    fn create_backup(&self, provider: &str, changes: &[RolloutChange]) -> AppResult<PathBuf> {
        let timestamp = Utc::now().format("%Y%m%dT%H%M%S").to_string();
        let dir = self.paths.provider_sync_backups_dir().join(timestamp);
        fs::create_dir_all(dir.join("db"))?;
        fs::create_dir_all(dir.join("sessions"))?;
        if self.paths.config_file().exists() {
            fs::copy(self.paths.config_file(), dir.join("config.toml"))?;
        }
        if self.paths.sqlite_database().exists() {
            fs::copy(
                self.paths.sqlite_database(),
                dir.join("db").join("state_5.sqlite"),
            )?;
        }
        for change in changes {
            let relative = change
                .path
                .strip_prefix(self.paths.sessions_dir())
                .unwrap_or(change.path.as_path());
            let target = dir.join("sessions").join(relative);
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)?;
            }
            fs::write(target, &change.original)?;
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

    fn update_sqlite(&self, provider: &str) -> AppResult<i32> {
        let path = self.paths.sqlite_database();
        if !path.exists() {
            return Ok(0);
        }
        let connection = Connection::open(path)?;
        let changed = connection.execute("UPDATE threads SET model_provider = ?1", [provider])?;
        Ok(changed as i32)
    }

    fn collect_rollout_changes(&self, provider: &str) -> AppResult<Vec<RolloutChange>> {
        let mut changes = vec![];
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
                changes.push(RolloutChange {
                    path: entry.path().to_path_buf(),
                    original: content,
                    updated: rebuilt,
                });
            }
        }
        Ok(changes)
    }

    fn apply_sync(&self, provider: &str, changes: &[RolloutChange]) -> AppResult<i32> {
        for change in changes {
            fs::write(&change.path, &change.updated)?;
        }
        self.update_sqlite(provider)
    }

    fn restore_backup_dir(&self, dir: &Path) -> AppResult<()> {
        let config = dir.join("config.toml");
        if config.exists() {
            if let Some(parent) = self.paths.config_file().parent() {
                fs::create_dir_all(parent)?;
            }
            fs::copy(config, self.paths.config_file())?;
        }

        let sqlite = dir.join("db").join("state_5.sqlite");
        if sqlite.exists() {
            if let Some(parent) = self.paths.sqlite_database().parent() {
                fs::create_dir_all(parent)?;
            }
            fs::copy(sqlite, self.paths.sqlite_database())?;
        }

        let sessions = dir.join("sessions");
        if sessions.exists() {
            for entry in WalkDir::new(&sessions)
                .into_iter()
                .filter_map(Result::ok)
                .filter(|entry| entry.file_type().is_file())
            {
                let relative = entry.path().strip_prefix(&sessions).unwrap_or(entry.path());
                let target = self.paths.sessions_dir().join(relative);
                if let Some(parent) = target.parent() {
                    fs::create_dir_all(parent)?;
                }
                fs::copy(entry.path(), target)?;
            }
        }
        Ok(())
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

fn parse_backup_timestamp(raw: &str) -> Option<DateTime<Utc>> {
    chrono::NaiveDateTime::parse_from_str(raw, "%Y%m%dT%H%M%S")
        .ok()
        .map(|time| DateTime::<Utc>::from_naive_utc_and_offset(time, Utc))
}

#[derive(Debug, Clone)]
struct RolloutChange {
    path: PathBuf,
    original: String,
    updated: String,
}

#[cfg(test)]
mod tests {
    use super::{
        list_configured_provider_ids, read_current_provider, set_root_provider, ProviderSyncService,
    };
    use crate::paths::CodexPaths;
    use rusqlite::Connection;
    use std::fs;
    use tempfile::tempdir;

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

    #[test]
    fn sync_creates_backup_and_restore_brings_provider_back() {
        let temp = tempdir().unwrap();
        let base = temp.path().join(".codex");
        let sessions_dir = base.join("sessions/2026/04/21");
        fs::create_dir_all(&sessions_dir).unwrap();
        fs::write(
            base.join("config.toml"),
            "model_provider = \"openai\"\n\n[model_providers.custom]\n",
        )
        .unwrap();
        fs::write(
            sessions_dir.join("rollout-1.jsonl"),
            "{\"payload\":{\"model_provider\":\"openai\"}}\n{\"type\":\"noop\"}\n",
        )
        .unwrap();
        let connection = Connection::open(base.join("state_5.sqlite")).unwrap();
        connection
            .execute("CREATE TABLE threads (model_provider TEXT)", [])
            .unwrap();
        connection
            .execute("INSERT INTO threads (model_provider) VALUES ('openai')", [])
            .unwrap();

        let service = ProviderSyncService::new(CodexPaths::new(base.clone()));
        let result = service.switch_provider("custom".into()).unwrap();
        assert_eq!(result.files_changed, 1);
        assert_eq!(
            fs::read_to_string(base.join("config.toml")).unwrap(),
            "model_provider = \"custom\"\n\n[model_providers.custom]"
        );
        assert!(fs::read_to_string(sessions_dir.join("rollout-1.jsonl"))
            .unwrap()
            .contains("\"model_provider\":\"custom\""));
        let backups = service.list_backups().unwrap();
        assert_eq!(backups.len(), 1);
        service.restore_backup(&backups[0].id).unwrap();
        assert!(fs::read_to_string(sessions_dir.join("rollout-1.jsonl"))
            .unwrap()
            .contains("\"model_provider\":\"openai\""));
        let restored_provider: String = connection
            .query_row("SELECT model_provider FROM threads LIMIT 1", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(restored_provider, "openai");
    }
}
