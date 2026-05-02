use chrono::{DateTime, Utc};
use serde::{Deserialize, Deserializer, Serialize};
use std::collections::BTreeMap;

const SWIFT_REFERENCE_UNIX_OFFSET_SECONDS: f64 = 978_307_200.0;
const UNIX_TIMESTAMP_LOWER_BOUND_SECONDS: f64 = 1_000_000_000.0;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "lowercase")]
pub enum AccountTier {
    Plus,
    Pro,
    Team,
    #[default]
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "camelCase")]
pub enum AccountSource {
    #[default]
    CurrentAuth,
    BackupImport,
    BrowserLogin,
    Fixture,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AccountRecord {
    pub id: String,
    pub email_mask: String,
    pub email: Option<String>,
    pub tier: AccountTier,
    pub manual_order: i32,
    pub archive_filename: String,
    pub source: AccountSource,
    pub last_imported_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AccountListItem {
    #[serde(flatten)]
    pub record: AccountRecord,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct JwtClaims {
    pub account_id: String,
    pub email: String,
    pub email_mask: String,
    pub tier: AccountTier,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "camelCase")]
pub struct AccountMetadataEntry {
    pub source: AccountSource,
    #[serde(deserialize_with = "deserialize_cache_datetime")]
    pub last_imported_at: DateTime<Utc>,
    pub manual_order: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "camelCase")]
pub struct AccountMetadataCache {
    pub entries: BTreeMap<String, AccountMetadataEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct UsageWindow {
    pub percent_used: i32,
    #[serde(deserialize_with = "deserialize_cache_datetime")]
    pub resets_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct UsageSnapshot {
    pub account_id: String,
    #[serde(deserialize_with = "deserialize_cache_datetime")]
    pub updated_at: DateTime<Utc>,
    pub source_label: Option<String>,
    pub five_hour: UsageWindow,
    pub weekly: UsageWindow,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "camelCase")]
pub struct UsageCache {
    pub entries: BTreeMap<String, UsageSnapshot>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct DiagnosticsEvent {
    pub category: String,
    pub message: String,
    pub raw: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProviderDistribution {
    pub provider: String,
    pub session_count: i32,
    pub archived_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BackupEntry {
    pub id: String,
    pub target_provider: String,
    pub total_size: u64,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "camelCase")]
pub struct ProviderSyncStatus {
    pub current_provider: String,
    pub configured_providers: Vec<String>,
    pub rollout_distribution: Vec<ProviderDistribution>,
    pub sqlite_distribution: Vec<ProviderDistribution>,
    pub backup_count: i32,
    pub backup_total_size: u64,
    pub backups: Vec<BackupEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct SyncResult {
    pub target_provider: String,
    pub files_changed: i32,
    pub rows_changed: i32,
    pub config_updated: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum UsageSourceMode {
    Automatic,
    LocalOnly,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct SettingsDto {
    pub usage_refresh_enabled: bool,
    pub usage_source_mode: UsageSourceMode,
    pub show_full_email: bool,
    pub launch_at_login: bool,
}

impl Default for SettingsDto {
    fn default() -> Self {
        Self {
            usage_refresh_enabled: true,
            usage_source_mode: UsageSourceMode::Automatic,
            show_full_email: false,
            launch_at_login: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AppSnapshot {
    pub accounts: Vec<AccountListItem>,
    pub active_account_id: Option<String>,
    pub active_usage: Option<UsageSnapshot>,
    pub settings: SettingsDto,
    pub diagnostics: Vec<DiagnosticsEvent>,
    pub provider_status: ProviderSyncStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LoginJobState {
    pub active: bool,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct CodexSessionListItem {
    pub id: String,
    pub display: String,
    pub timestamp: DateTime<Utc>,
    pub project: String,
    pub project_name: String,
    pub file_path: Option<String>,
    pub message_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct CodexSessionMessage {
    pub role: String,
    pub kind: String,
    pub text: String,
    pub timestamp: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct CodexSessionDetail {
    pub session: CodexSessionListItem,
    pub messages: Vec<CodexSessionMessage>,
}

pub fn masked_email(email: &str) -> String {
    let email = email.trim().to_lowercase();
    let parts: Vec<&str> = email.splitn(2, '@').collect();
    if parts.len() != 2 {
        return email;
    }
    let local = parts[0];
    let domain = parts[1];
    let mut chars = local.chars();
    let first = chars.next().unwrap_or_default();
    let rest_len = local.chars().count().saturating_sub(1);
    format!("{}{}@{}", first, "•".repeat(rest_len), domain)
}

fn deserialize_cache_datetime<'de, D>(deserializer: D) -> Result<DateTime<Utc>, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::String(value) => DateTime::parse_from_rfc3339(&value)
            .map(|date| date.with_timezone(&Utc))
            .map_err(serde::de::Error::custom),
        serde_json::Value::Number(value) => datetime_from_cache_number(&value).ok_or_else(|| {
            serde::de::Error::custom(format!("date number is out of range: {value}"))
        }),
        other => Err(serde::de::Error::custom(format!(
            "unsupported date value: {other}"
        ))),
    }
}

fn datetime_from_cache_number(number: &serde_json::Number) -> Option<DateTime<Utc>> {
    let raw = number.to_string();
    let (whole, nanos) = parse_decimal_seconds(&raw)?;
    let whole = if (whole as f64).abs() < UNIX_TIMESTAMP_LOWER_BOUND_SECONDS
        || (whole as f64) < -UNIX_TIMESTAMP_LOWER_BOUND_SECONDS
    {
        whole.checked_add(SWIFT_REFERENCE_UNIX_OFFSET_SECONDS as i64)?
    } else {
        whole
    };
    DateTime::<Utc>::from_timestamp(whole, nanos)
}

fn parse_decimal_seconds(raw: &str) -> Option<(i64, u32)> {
    let negative = raw.starts_with('-');
    let unsigned = raw.strip_prefix('-').unwrap_or(raw);
    let mut parts = unsigned.splitn(2, '.');
    let whole_abs = parts.next()?.parse::<i64>().ok()?;
    let fraction = parts.next().unwrap_or_default();
    let mut nanos_text = fraction.chars().take(9).collect::<String>();
    while nanos_text.len() < 9 {
        nanos_text.push('0');
    }
    let nanos = if nanos_text.is_empty() {
        0
    } else {
        nanos_text.parse::<u32>().ok()?
    };

    if negative && nanos > 0 {
        Some((
            whole_abs.checked_neg()?.checked_sub(1)?,
            1_000_000_000 - nanos,
        ))
    } else {
        Some((
            if negative {
                whole_abs.checked_neg()?
            } else {
                whole_abs
            },
            nanos,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::{masked_email, AccountMetadataCache, UsageCache};

    #[test]
    fn masks_email_like_desktop_client() {
        assert_eq!(masked_email("alice@example.com"), "a••••@example.com");
    }

    #[test]
    fn decodes_swift_json_encoder_date_numbers_in_metadata_cache() {
        let cache: AccountMetadataCache = serde_json::from_str(
            r#"{"entries":{"alice.json":{"source":"currentAuth","lastImportedAt":-63114076800,"manualOrder":0}}}"#,
        )
        .unwrap();

        let imported_at = cache.entries.get("alice.json").unwrap().last_imported_at;

        assert_eq!(imported_at.timestamp(), -62135769600);
    }

    #[test]
    fn decodes_swift_json_encoder_date_numbers_in_usage_cache() {
        let cache: UsageCache = serde_json::from_str(
            r#"{"entries":{"acct-1":{"accountId":"acct-1","updatedAt":797152288.379534,"sourceLabel":"Cache","fiveHour":{"percentUsed":42,"resetsAt":797152300},"weekly":{"percentUsed":18,"resetsAt":798705787}}}}"#,
        )
        .unwrap();

        let snapshot = cache.entries.get("acct-1").unwrap();

        assert_eq!(snapshot.updated_at.timestamp(), 1775459488);
        assert_eq!(snapshot.updated_at.timestamp_subsec_nanos(), 379534000);
        assert_eq!(snapshot.five_hour.resets_at.timestamp(), 1775459500);
    }
}
