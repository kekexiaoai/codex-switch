use crate::error::{AppError, AppResult};
use crate::jwt::JwtDecoder;
use crate::models::{
    AccountListItem, AccountMetadataEntry, AccountRecord, AccountSource, CurrentAuthMode,
    JwtClaims,
};
use crate::paths::CodexPaths;
use crate::store::AuthStore;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine as _;
use chrono::Utc;
use serde_json::Value;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone)]
pub struct AccountsService {
    pub store: AuthStore,
    pub jwt: JwtDecoder,
}

impl AccountsService {
    pub fn new(paths: CodexPaths) -> Self {
        Self {
            store: AuthStore::new(paths),
            jwt: JwtDecoder,
        }
    }

    pub fn list(&self) -> AppResult<Vec<AccountListItem>> {
        let metadata = self.store.load_metadata_cache()?;
        let active = self.current_claims().ok().map(|claims| claims.account_id);
        let mut accounts = vec![];
        for path in self.store.list_archived_auth_files()? {
            let Ok(data) = fs::read(&path) else {
                continue;
            };
            let Ok(claims) = self.claims_from_auth(&data) else {
                continue;
            };
            let filename = path
                .file_name()
                .and_then(|s| s.to_str())
                .unwrap_or_default()
                .to_string();
            let meta = metadata
                .entries
                .get(&filename)
                .cloned()
                .unwrap_or(AccountMetadataEntry {
                    source: AccountSource::CurrentAuth,
                    last_imported_at: Utc::now(),
                    manual_order: 0,
                });
            accounts.push(AccountListItem {
                record: AccountRecord {
                    id: claims.account_id.clone(),
                    email_mask: claims.email_mask,
                    email: Some(claims.email),
                    tier: claims.tier,
                    manual_order: meta.manual_order,
                    archive_filename: filename,
                    source: meta.source,
                    last_imported_at: meta.last_imported_at,
                },
                is_active: active.as_deref() == Some(claims.account_id.as_str()),
            });
        }
        accounts.sort_by(|a, b| {
            a.record
                .manual_order
                .cmp(&b.record.manual_order)
                .then_with(|| a.record.email_mask.cmp(&b.record.email_mask))
        });
        Ok(accounts)
    }

    pub fn import_current(&self) -> AppResult<AccountListItem> {
        let data = self.store.read_current_auth_data()?;
        self.import_auth_data(&data, AccountSource::CurrentAuth)
    }

    pub fn import_backup(&self, backup_path: &str) -> AppResult<AccountListItem> {
        let data = self.store.read_auth_data(Path::new(backup_path))?;
        self.import_auth_data(&data, AccountSource::BackupImport)
    }

    pub fn switch(&self, account_id: &str) -> AppResult<AccountListItem> {
        if self.current_auth_mode() == CurrentAuthMode::OpenAIApiKey {
            return Err(AppError::ApiKeyModeBlocksSwitch);
        }

        let target = self
            .list()?
            .into_iter()
            .find(|account| account.record.id == account_id)
            .ok_or_else(|| AppError::NotFound(format!("account {account_id}")))?;
        let path = self
            .store
            .paths
            .accounts_dir()
            .join(&target.record.archive_filename);
        let data = self.store.read_auth_data(&path)?;
        self.store.replace_active_auth(&data)?;
        Ok(AccountListItem {
            is_active: true,
            ..target
        })
    }

    pub fn current_claims(&self) -> AppResult<JwtClaims> {
        let data = self.store.read_current_auth_data()?;
        self.claims_from_auth(&data)
    }

    pub fn current_auth_mode(&self) -> CurrentAuthMode {
        let data = match self.store.read_current_auth_data() {
            Ok(data) => data,
            Err(AppError::CurrentAuthMissing) => return CurrentAuthMode::Missing,
            Err(_) => return CurrentAuthMode::Invalid,
        };
        let Ok(value) = serde_json::from_slice::<Value>(&data) else {
            return CurrentAuthMode::Invalid;
        };
        if auth_value_has_api_key(&value) {
            return CurrentAuthMode::OpenAIApiKey;
        }
        if self.claims_from_value(&value).is_ok() {
            return CurrentAuthMode::OAuth;
        }
        CurrentAuthMode::Invalid
    }

    fn import_auth_data(&self, data: &[u8], source: AccountSource) -> AppResult<AccountListItem> {
        let claims = self.claims_from_auth(data)?;
        let archive_filename = archive_filename_for_email(&claims.email);
        self.store.write_archive(data, &archive_filename)?;
        let mut cache = self.store.load_metadata_cache()?;
        let next_manual_order = cache
            .entries
            .values()
            .map(|entry| entry.manual_order)
            .max()
            .unwrap_or(-1)
            + 1;
        let imported_at = Utc::now();
        cache.entries.insert(
            archive_filename.clone(),
            AccountMetadataEntry {
                source: source.clone(),
                last_imported_at: imported_at,
                manual_order: next_manual_order,
            },
        );
        self.store.save_metadata_cache(&cache)?;
        Ok(AccountListItem {
            record: AccountRecord {
                id: claims.account_id,
                email_mask: claims.email_mask,
                email: Some(claims.email),
                tier: claims.tier,
                manual_order: next_manual_order,
                archive_filename,
                source,
                last_imported_at: imported_at,
            },
            is_active: false,
        })
    }

    fn claims_from_auth(&self, data: &[u8]) -> AppResult<JwtClaims> {
        let value: Value = serde_json::from_slice(data).map_err(|_| AppError::AuthJsonInvalid)?;
        if auth_value_has_api_key(&value) {
            return Err(AppError::ApiKeyModeDetected);
        }
        self.claims_from_value(&value)
    }

    fn claims_from_value(&self, value: &Value) -> AppResult<JwtClaims> {
        let id_token = value
            .get("tokens")
            .and_then(|tokens| tokens.get("id_token"))
            .and_then(|value| value.as_str())
            .filter(|value| !value.is_empty())
            .ok_or(AppError::IdTokenMissing)?;
        self.jwt.decode(id_token)
    }
}

fn auth_value_has_api_key(value: &Value) -> bool {
    value
        .get("OPENAI_API_KEY")
        .and_then(|v| v.as_str())
        .filter(|v| !v.is_empty())
        .is_some()
        || value
            .get("api_key")
            .and_then(|v| v.as_str())
            .filter(|v| !v.is_empty())
            .is_some()
}

fn archive_filename_for_email(email: &str) -> String {
    let encoded = URL_SAFE_NO_PAD.encode(email.trim().to_lowercase().as_bytes());
    format!("{encoded}.json")
}

#[cfg(test)]
mod tests {
    use super::AccountsService;
    use crate::paths::CodexPaths;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn imports_current_auth_into_archive_and_lists_account() {
        let temp = tempdir().unwrap();
        let base = temp.path().join(".codex");
        fs::create_dir_all(&base).unwrap();
        fs::write(
            base.join("auth.json"),
            r#"{"tokens":{"id_token":"header.eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoiYWNjdC0xIiwicGxhbiI6InRlYW0ifQ.sig"}}"#,
        )
        .unwrap();
        let service = AccountsService::new(CodexPaths::new(base));
        service.import_current().unwrap();
        let accounts = service.list().unwrap();
        assert_eq!(accounts.len(), 1);
        assert_eq!(
            accounts[0].record.email.as_deref(),
            Some("alice@example.com")
        );
    }

    #[test]
    fn skips_archived_auth_files_that_cannot_describe_chatgpt_accounts() {
        let temp = tempdir().unwrap();
        let base = temp.path().join(".codex");
        let accounts_dir = base.join("accounts");
        fs::create_dir_all(&accounts_dir).unwrap();
        fs::write(base.join("auth.json"), r#"{"OPENAI_API_KEY":"sk-test"}"#).unwrap();
        fs::write(
            accounts_dir.join("valid.json"),
            r#"{"tokens":{"id_token":"header.eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoiYWNjdC0xIiwicGxhbiI6InRlYW0ifQ.sig"}}"#,
        )
        .unwrap();
        fs::write(accounts_dir.join("missing-token.json"), r#"{"tokens":{}}"#).unwrap();

        let service = AccountsService::new(CodexPaths::new(base));
        let accounts = service.list().unwrap();

        assert_eq!(accounts.len(), 1);
        assert_eq!(
            accounts[0].record.email.as_deref(),
            Some("alice@example.com")
        );
        assert!(!accounts[0].is_active);
    }

    #[test]
    fn switches_archived_account_into_active_auth_file() {
        let temp = tempdir().unwrap();
        let base = temp.path().join(".codex");
        fs::create_dir_all(&base).unwrap();
        fs::write(
            base.join("auth.json"),
            r#"{"tokens":{"id_token":"header.eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoiYWNjdC0xIiwicGxhbiI6InRlYW0ifQ.sig"}}"#,
        )
        .unwrap();

        let service = AccountsService::new(CodexPaths::new(base.clone()));
        service.import_current().unwrap();
        fs::write(
            base.join("auth.json"),
            r#"{"tokens":{"id_token":"header.eyJlbWFpbCI6ImJvYkBleGFtcGxlLmNvbSIsInN1YiI6ImFjY3QtMiIsInBsYW4iOiJwbHVzIn0.sig"}}"#,
        )
        .unwrap();
        service.import_current().unwrap();

        let archived = service
            .list()
            .unwrap()
            .into_iter()
            .find(|account| account.record.email.as_deref() == Some("alice@example.com"))
            .unwrap();

        service.switch(&archived.record.id).unwrap();

        let active = service.current_claims().unwrap();
        assert_eq!(active.email, "alice@example.com");
    }

    #[test]
    fn refuses_to_overwrite_current_api_key_auth_when_switching_accounts() {
        let temp = tempdir().unwrap();
        let base = temp.path().join(".codex");
        let accounts_dir = base.join("accounts");
        fs::create_dir_all(&accounts_dir).unwrap();
        fs::write(base.join("auth.json"), r#"{"OPENAI_API_KEY":"sk-test"}"#).unwrap();
        fs::write(
            accounts_dir.join("alice.json"),
            r#"{"tokens":{"id_token":"header.eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoiYWNjdC0xIiwicGxhbiI6InRlYW0ifQ.sig"}}"#,
        )
        .unwrap();

        let service = AccountsService::new(CodexPaths::new(base.clone()));
        let archived = service.list().unwrap().remove(0);

        let error = service.switch(&archived.record.id).unwrap_err().to_string();

        assert!(error.contains("OPENAI_API_KEY 模式"));
        assert_eq!(
            fs::read_to_string(base.join("auth.json")).unwrap(),
            r#"{"OPENAI_API_KEY":"sk-test"}"#
        );
    }
}
