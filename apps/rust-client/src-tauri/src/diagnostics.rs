use crate::error::AppResult;
use crate::models::DiagnosticsEvent;
use crate::paths::CodexPaths;
use std::fs;

#[derive(Debug, Clone)]
pub struct DiagnosticsService {
    pub paths: CodexPaths,
}

impl DiagnosticsService {
    pub fn new(paths: CodexPaths) -> Self {
        Self { paths }
    }

    pub fn recent(&self, limit: usize) -> AppResult<Vec<DiagnosticsEvent>> {
        let candidates = [
            ("browser-login", self.paths.browser_login_log()),
            ("usage-refresh", self.paths.usage_refresh_log()),
            ("account-reorder", self.paths.account_reorder_log()),
        ];
        let mut events = vec![];
        for (category, path) in candidates {
            if !path.exists() {
                continue;
            }
            let content = fs::read_to_string(path)?;
            for line in content.lines() {
                let lower = line.to_lowercase();
                if [
                    "access_token",
                    "refresh_token",
                    "id_token",
                    "openai_api_key",
                    "bearer ",
                ]
                .iter()
                .any(|marker| lower.contains(marker))
                {
                    continue;
                }
                events.push(DiagnosticsEvent {
                    category: category.to_string(),
                    message: line.to_string(),
                    raw: line.to_string(),
                });
            }
        }
        events.sort_by(|a, b| a.message.cmp(&b.message));
        let start = events.len().saturating_sub(limit);
        Ok(events[start..].to_vec())
    }
}
