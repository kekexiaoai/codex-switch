use crate::error::{AppError, AppResult};
use crate::models::{AccountMetadataCache, UsageCache};
use crate::paths::CodexPaths;
use serde_json::Value;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct AuthStore {
    pub paths: CodexPaths,
}

impl AuthStore {
    pub fn new(paths: CodexPaths) -> Self {
        Self { paths }
    }

    pub fn read_current_auth_data(&self) -> AppResult<Vec<u8>> {
        let path = self.paths.auth_file();
        if !path.exists() {
            return Err(AppError::CurrentAuthMissing);
        }
        fs::read(path).map_err(|_| AppError::AuthUnreadable)
    }

    pub fn read_auth_data(&self, path: &Path) -> AppResult<Vec<u8>> {
        fs::read(path).map_err(|_| AppError::AuthUnreadable)
    }

    pub fn write_archive(&self, data: &[u8], filename: &str) -> AppResult<()> {
        fs::create_dir_all(self.paths.accounts_dir())?;
        let output = self.paths.accounts_dir().join(filename);
        let formatted = format_auth_data(data)?;
        atomic_write(&output, &formatted).map_err(|_| AppError::ArchiveWriteFailed)
    }

    pub fn list_archived_auth_files(&self) -> AppResult<Vec<PathBuf>> {
        let dir = self.paths.accounts_dir();
        if !dir.exists() {
            return Ok(vec![]);
        }
        let mut files = vec![];
        for entry in fs::read_dir(dir)? {
            let path = entry?.path();
            if path.extension().and_then(|s| s.to_str()) == Some("json") {
                let name = path
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or_default();
                if name != "metadata.json" && name != "usage-cache.json" {
                    files.push(path);
                }
            }
        }
        files.sort();
        Ok(files)
    }

    pub fn replace_active_auth(&self, data: &[u8]) -> AppResult<()> {
        fs::create_dir_all(&self.paths.base_directory)?;
        let temp = self.paths.base_directory.join(".auth.json.tmp");
        let formatted = format_auth_data(data)?;
        atomic_write(&temp, &formatted).map_err(|_| AppError::ActiveAuthReplacementFailed)?;
        let target = self.paths.auth_file();
        if target.exists() {
            fs::remove_file(&target).map_err(|_| AppError::ActiveAuthReplacementFailed)?;
        }
        fs::rename(temp, target).map_err(|_| AppError::ActiveAuthReplacementFailed)
    }

    pub fn load_metadata_cache(&self) -> AppResult<AccountMetadataCache> {
        let path = self.paths.metadata_cache();
        if !path.exists() {
            return Ok(AccountMetadataCache::default());
        }
        Ok(serde_json::from_slice(&fs::read(path)?)?)
    }

    pub fn save_metadata_cache(&self, cache: &AccountMetadataCache) -> AppResult<()> {
        fs::create_dir_all(self.paths.accounts_dir())?;
        let bytes = serde_json::to_vec_pretty(cache)?;
        atomic_write(&self.paths.metadata_cache(), &bytes).map_err(|_| AppError::ArchiveWriteFailed)
    }

    pub fn load_usage_cache(&self) -> AppResult<UsageCache> {
        let path = self.paths.usage_cache();
        if !path.exists() {
            return Ok(UsageCache::default());
        }
        Ok(serde_json::from_slice(&fs::read(path)?)?)
    }

    pub fn save_usage_cache(&self, cache: &UsageCache) -> AppResult<()> {
        fs::create_dir_all(self.paths.accounts_dir())?;
        let bytes = serde_json::to_vec_pretty(cache)?;
        atomic_write(&self.paths.usage_cache(), &bytes).map_err(|_| AppError::ArchiveWriteFailed)
    }
}

pub fn atomic_write(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let temp = path.with_extension("tmp");
    fs::write(&temp, bytes)?;
    if path.exists() {
        fs::remove_file(path)?;
    }
    fs::rename(temp, path)
}

fn format_auth_data(data: &[u8]) -> AppResult<Vec<u8>> {
    let value: Value = serde_json::from_slice(data).map_err(|_| AppError::AuthJsonInvalid)?;
    Ok(serde_json::to_vec_pretty(&value)?)
}

#[cfg(test)]
mod tests {
    use super::AuthStore;
    use crate::paths::CodexPaths;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn saves_metadata_and_usage_cache_separately() {
        let temp = tempdir().unwrap();
        let store = AuthStore::new(CodexPaths::new(temp.path().join(".codex")));
        let metadata = store.load_metadata_cache().unwrap();
        assert!(metadata.entries.is_empty());
        store
            .write_archive(br#"{"tokens":{"id_token":"abc"}}"#, "alice.json")
            .unwrap();
        assert!(fs::metadata(store.paths.accounts_dir().join("alice.json")).is_ok());
    }
}
