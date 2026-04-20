use crate::accounts::AccountsService;
use crate::error::{AppError, AppResult};
use crate::models::{
    AccountRecord, SettingsDto, UsageCache, UsageSnapshot, UsageSourceMode, UsageWindow,
};
use crate::paths::CodexPaths;
use crate::store::AuthStore;
use chrono::{DateTime, Utc};
use reqwest::header::{ACCEPT, AUTHORIZATION};
use serde_json::Value;
use std::fs;
use walkdir::WalkDir;

#[derive(Debug, Clone)]
pub struct UsageService {
    pub paths: CodexPaths,
    pub store: AuthStore,
    pub accounts: AccountsService,
    pub client: reqwest::Client,
}

impl UsageService {
    pub fn new(paths: CodexPaths) -> Self {
        Self {
            store: AuthStore::new(paths.clone()),
            accounts: AccountsService::new(paths.clone()),
            paths,
            client: reqwest::Client::new(),
        }
    }

    pub async fn refresh_active_usage(&self, settings: &SettingsDto) -> AppResult<UsageSnapshot> {
        let active = self.accounts.current_claims()?;
        let account = AccountRecord {
            id: active.account_id.clone(),
            email_mask: active.email_mask,
            email: Some(active.email),
            tier: active.tier,
            manual_order: 0,
            archive_filename: String::new(),
            source: crate::models::AccountSource::CurrentAuth,
            last_imported_at: Utc::now(),
        };
        if matches!(settings.usage_source_mode, UsageSourceMode::Automatic) {
            if let Ok(snapshot) = self.fetch_remote(&account).await {
                self.save_cache(snapshot.clone())?;
                return Ok(snapshot);
            }
        }
        if let Ok(snapshot) = self.scan_local(&account) {
            self.save_cache(snapshot.clone())?;
            return Ok(snapshot);
        }
        self.load_cached(&account.id)?.ok_or(AppError::NoUsageData)
    }

    fn scan_local(&self, account: &AccountRecord) -> AppResult<UsageSnapshot> {
        for entry in WalkDir::new(self.paths.sessions_dir())
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| {
                entry.file_type().is_file()
                    && entry.file_name().to_string_lossy().starts_with("rollout-")
                    && entry.path().extension().and_then(|s| s.to_str()) == Some("jsonl")
            })
        {
            let content = fs::read_to_string(entry.path())?;
            for line in content.lines().rev() {
                if let Some(snapshot) =
                    parse_line(line, account, self.accounts.current_claims().ok().as_ref())?
                {
                    return Ok(snapshot);
                }
            }
        }
        Err(AppError::NoUsageData)
    }

    async fn fetch_remote(&self, account: &AccountRecord) -> AppResult<UsageSnapshot> {
        let data = self.store.read_current_auth_data()?;
        let value: Value = serde_json::from_slice(&data).map_err(|_| AppError::AuthJsonInvalid)?;
        let tokens = value
            .get("tokens")
            .and_then(|v| v.as_object())
            .ok_or(AppError::AuthJsonInvalid)?;
        let access_token = tokens
            .get("access_token")
            .and_then(|v| v.as_str())
            .ok_or(AppError::NoUsageData)?;
        let account_header = tokens.get("account_id").and_then(|v| v.as_str());
        let mut request = self
            .client
            .get("https://chatgpt.com/backend-api/wham/usage")
            .header(ACCEPT, "application/json")
            .header(AUTHORIZATION, format!("Bearer {access_token}"));
        if let Some(account_header) = account_header {
            request = request.header("ChatGPT-Account-Id", account_header);
        }
        let response = request.send().await?;
        let response = response.error_for_status()?;
        let value: Value = response.json().await?;
        let rate_limit = value
            .get("rate_limit")
            .or_else(|| value.get("rate_limits"))
            .ok_or(AppError::NoUsageData)?;
        let primary = rate_limit
            .get("primary_window")
            .or_else(|| rate_limit.get("primary"))
            .or_else(|| rate_limit.get("five_hour"))
            .ok_or(AppError::NoUsageData)?;
        let secondary = rate_limit
            .get("secondary_window")
            .or_else(|| rate_limit.get("secondary"))
            .or_else(|| rate_limit.get("weekly"))
            .ok_or(AppError::NoUsageData)?;
        Ok(UsageSnapshot {
            account_id: account.id.clone(),
            updated_at: value
                .get("updated_at")
                .or_else(|| value.get("timestamp"))
                .and_then(parse_datetime_value)
                .unwrap_or_else(Utc::now),
            source_label: Some("API".into()),
            five_hour: parse_usage_window(primary)?,
            weekly: parse_usage_window(secondary)?,
        })
    }

    fn save_cache(&self, snapshot: UsageSnapshot) -> AppResult<()> {
        let mut cache = self.store.load_usage_cache()?;
        cache.entries.insert(snapshot.account_id.clone(), snapshot);
        self.store.save_usage_cache(&cache)
    }

    pub fn load_cached(&self, account_id: &str) -> AppResult<Option<UsageSnapshot>> {
        let UsageCache { entries } = self.store.load_usage_cache()?;
        Ok(entries.get(account_id).cloned())
    }
}

fn parse_line(
    line: &str,
    account: &AccountRecord,
    current: Option<&crate::models::JwtClaims>,
) -> AppResult<Option<UsageSnapshot>> {
    let value: Value = match serde_json::from_str(line) {
        Ok(value) => value,
        Err(_) => return Ok(None),
    };
    let timestamp = value
        .get("timestamp")
        .and_then(parse_datetime_value)
        .or_else(|| {
            value
                .get("event_msg")
                .and_then(|msg| msg.get("timestamp"))
                .and_then(parse_datetime_value)
        });
    let email = value.get("email").and_then(|v| v.as_str()).or_else(|| {
        value
            .get("event_msg")
            .and_then(|msg| msg.get("email"))
            .and_then(|v| v.as_str())
    });
    let token_count = value
        .get("payload")
        .filter(|payload| payload.get("type").and_then(|v| v.as_str()) == Some("token_count"));
    let rate_limits = token_count
        .and_then(|payload| payload.get("rate_limits"))
        .or_else(|| value.get("rate_limits"))
        .or_else(|| {
            value
                .get("event_msg")
                .and_then(|msg| msg.get("token_count"))
                .and_then(|tc| tc.get("rate_limits"))
        });
    let Some(rate_limits) = rate_limits else {
        return Ok(None);
    };

    let email_matches = email
        .map(|email| account.email.as_deref() == Some(&email.to_lowercase()))
        .unwrap_or_else(|| {
            current
                .map(|claims| claims.account_id == account.id)
                .unwrap_or(false)
        });
    if !email_matches {
        return Ok(None);
    }

    let five = rate_limits
        .get("five_hour")
        .or_else(|| rate_limits.get("primary"))
        .or_else(|| rate_limits.get("primary_window"))
        .or_else(|| rate_limits.get("primary").and_then(|v| v.get("five_hour")));
    let weekly = rate_limits
        .get("weekly")
        .or_else(|| rate_limits.get("secondary"))
        .or_else(|| rate_limits.get("secondary_window"))
        .or_else(|| rate_limits.get("secondary").and_then(|v| v.get("weekly")));
    let (Some(five), Some(weekly), Some(updated_at)) = (five, weekly, timestamp) else {
        return Ok(None);
    };
    Ok(Some(UsageSnapshot {
        account_id: account.id.clone(),
        updated_at,
        source_label: Some("Local Logs".into()),
        five_hour: parse_usage_window(five)?,
        weekly: parse_usage_window(weekly)?,
    }))
}

fn parse_usage_window(value: &Value) -> AppResult<UsageWindow> {
    let percent_used = value
        .get("used_percent")
        .and_then(|v| v.as_i64())
        .or_else(|| {
            let used = value.get("used")?.as_f64()?;
            let limit = value.get("limit")?.as_f64()?;
            Some(((used / limit) * 100.0).round() as i64)
        })
        .ok_or(AppError::NoUsageData)? as i32;
    let resets_at = value
        .get("resets_at")
        .or_else(|| value.get("reset_at"))
        .or_else(|| value.get("reset_time"))
        .and_then(parse_datetime_value)
        .ok_or(AppError::NoUsageData)?;
    Ok(UsageWindow {
        percent_used,
        resets_at,
    })
}

fn parse_datetime_value(value: &Value) -> Option<DateTime<Utc>> {
    if let Some(string) = value.as_str() {
        DateTime::parse_from_rfc3339(string)
            .ok()
            .map(|date| date.with_timezone(&Utc))
    } else if let Some(int) = value.as_i64() {
        DateTime::<Utc>::from_timestamp(int, 0)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::UsageService;
    use crate::paths::CodexPaths;
    use std::fs;
    use tempfile::tempdir;

    #[tokio::test]
    async fn falls_back_to_local_rollout_logs() {
        let temp = tempdir().unwrap();
        let base = temp.path().join(".codex");
        let sessions = base.join("sessions/2026/04/21");
        fs::create_dir_all(&sessions).unwrap();
        fs::create_dir_all(&base).unwrap();
        fs::write(
            base.join("auth.json"),
            r#"{"tokens":{"id_token":"header.eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoiYWNjdC0xIiwicGxhbiI6InRlYW0ifQ.sig"}}"#,
        )
        .unwrap();
        fs::write(
            sessions.join("rollout-1.jsonl"),
            r#"{"timestamp":"2026-04-21T10:00:00Z","email":"alice@example.com","rate_limits":{"five_hour":{"used_percent":42,"resets_at":"2026-04-21T15:00:00Z"},"weekly":{"used_percent":13,"resets_at":"2026-04-28T10:00:00Z"}}}"#,
        )
        .unwrap();
        let service = UsageService::new(CodexPaths::new(base));
        let snapshot = service
            .refresh_active_usage(&crate::models::SettingsDto::default())
            .await
            .unwrap();
        assert_eq!(snapshot.five_hour.percent_used, 42);
    }
}
