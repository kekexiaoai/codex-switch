use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

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
    pub resets_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct UsageSnapshot {
    pub account_id: String,
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

#[cfg(test)]
mod tests {
    use super::masked_email;

    #[test]
    fn masks_email_like_desktop_client() {
        assert_eq!(masked_email("alice@example.com"), "a••••@example.com");
    }
}
