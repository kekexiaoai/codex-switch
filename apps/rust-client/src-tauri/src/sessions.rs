use crate::error::{AppError, AppResult};
use crate::models::{CodexSessionDetail, CodexSessionListItem, CodexSessionMessage};
use crate::paths::CodexPaths;
use chrono::{DateTime, TimeZone, Utc};
use rusqlite::{Connection, OpenFlags};
use serde_json::Value;
use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

const DEFAULT_DISPLAY: &str = "(no prompt text)";
const DISPLAY_LIMIT: usize = 240;

#[derive(Debug, Clone)]
pub struct SessionsService {
    pub paths: CodexPaths,
}

#[derive(Debug, Clone)]
struct SessionFileMeta {
    id: String,
    cwd: String,
    timestamp: Option<DateTime<Utc>>,
    file_path: PathBuf,
    display: Option<String>,
    message_count: i32,
}

#[derive(Debug, Clone)]
struct HistoryEntry {
    timestamp: DateTime<Utc>,
    text: String,
}

#[derive(Debug, Clone)]
struct ThreadEntry {
    title: String,
    cwd: String,
    timestamp: DateTime<Utc>,
    file_path: Option<PathBuf>,
}

impl SessionsService {
    pub fn new(paths: CodexPaths) -> Self {
        Self { paths }
    }

    pub fn list(&self) -> AppResult<Vec<CodexSessionListItem>> {
        let threads = self.load_threads();
        let history = self.load_history();
        let files = self.collect_session_file_meta();
        let mut ids: BTreeSet<String> = threads.keys().cloned().collect();
        ids.extend(history.keys().cloned());
        ids.extend(files.keys().cloned());

        let mut sessions = ids
            .into_iter()
            .map(|id| {
                let thread = threads.get(&id);
                let file = files.get(&id);
                let history_entry = history.get(&id);
                let timestamp = thread
                    .map(|entry| entry.timestamp)
                    .or_else(|| history_entry.map(|entry| entry.timestamp))
                    .or_else(|| file.and_then(|meta| meta.timestamp))
                    .or_else(|| file.and_then(|meta| file_modified_at(&meta.file_path)))
                    .unwrap_or_else(|| Utc.timestamp_opt(0, 0).single().unwrap());
                let display = thread
                    .map(|entry| normalize_display_text(&entry.title))
                    .filter(|title| title != DEFAULT_DISPLAY)
                    .or_else(|| history_entry.map(|entry| normalize_display_text(&entry.text)))
                    .or_else(|| file.and_then(|meta| meta.display.clone()))
                    .unwrap_or_else(|| DEFAULT_DISPLAY.to_string());
                let project = thread
                    .map(|entry| entry.cwd.clone())
                    .filter(|cwd| !cwd.is_empty())
                    .or_else(|| file.map(|meta| meta.cwd.clone()))
                    .unwrap_or_default();
                let file_path = file
                    .map(|meta| meta.file_path.clone())
                    .or_else(|| thread.and_then(|entry| entry.file_path.clone()));
                CodexSessionListItem {
                    id,
                    display,
                    timestamp,
                    project_name: project_name(&project),
                    project,
                    file_path: file_path.map(|path| path.to_string_lossy().to_string()),
                    message_count: file.map(|meta| meta.message_count).unwrap_or_default(),
                }
            })
            .collect::<Vec<_>>();

        sessions.sort_by(|left, right| right.timestamp.cmp(&left.timestamp));
        Ok(sessions)
    }

    fn load_threads(&self) -> HashMap<String, ThreadEntry> {
        let path = self.paths.sqlite_database();
        if !path.exists() {
            return HashMap::new();
        }

        let Ok(connection) = Connection::open_with_flags(
            path,
            OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
        ) else {
            return HashMap::new();
        };

        let Ok(mut statement) = connection.prepare(
            r#"
            SELECT id,
                   title,
                   cwd,
                   rollout_path,
                   COALESCE(updated_at_ms, updated_at * 1000, created_at_ms, created_at * 1000) AS sort_at_ms
            FROM threads
            WHERE archived = 0
            "#,
        ) else {
            return HashMap::new();
        };

        let Ok(rows) = statement.query_map([], |row| {
            let id = row.get::<_, String>(0).unwrap_or_default();
            let rollout_path = row
                .get::<_, String>(3)
                .ok()
                .filter(|value| !value.is_empty());
            let timestamp_ms = row.get::<_, i64>(4).unwrap_or_default();
            Ok((
                id,
                ThreadEntry {
                    title: row.get::<_, String>(1).unwrap_or_default(),
                    cwd: row.get::<_, String>(2).unwrap_or_default(),
                    timestamp: datetime_from_millis(timestamp_ms),
                    file_path: rollout_path.map(PathBuf::from).filter(|path| path.exists()),
                },
            ))
        }) else {
            return HashMap::new();
        };

        rows.filter_map(Result::ok)
            .filter(|(id, _)| !id.is_empty())
            .collect()
    }

    pub fn projects(&self) -> AppResult<Vec<String>> {
        let mut projects = self
            .list()?
            .into_iter()
            .filter_map(|session| {
                if session.project.is_empty() {
                    None
                } else {
                    Some(session.project)
                }
            })
            .collect::<Vec<_>>();
        projects.sort();
        projects.dedup();
        Ok(projects)
    }

    pub fn get(&self, session_id: &str) -> AppResult<CodexSessionDetail> {
        let session = self
            .list()?
            .into_iter()
            .find(|item| item.id == session_id)
            .ok_or_else(|| AppError::NotFound(format!("session {session_id}")))?;
        let Some(file_path) = session.file_path.clone() else {
            return Ok(CodexSessionDetail {
                session,
                messages: vec![],
            });
        };
        let messages = parse_conversation_file(Path::new(&file_path))?;
        Ok(CodexSessionDetail { session, messages })
    }

    fn collect_session_file_meta(&self) -> HashMap<String, SessionFileMeta> {
        let mut output = HashMap::new();
        let root = self.paths.sessions_dir();
        if !root.exists() {
            return output;
        }

        for entry in WalkDir::new(root)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| {
                entry.file_type().is_file()
                    && entry.path().extension().is_some_and(|ext| ext == "jsonl")
            })
        {
            if let Some(meta) = read_session_file_meta(entry.path()) {
                output.insert(meta.id.clone(), meta);
            }
        }
        output
    }

    fn load_history(&self) -> HashMap<String, HistoryEntry> {
        let mut output = HashMap::new();
        let Ok(content) = fs::read_to_string(self.paths.history_file()) else {
            return output;
        };
        for line in content.lines().filter(|line| !line.trim().is_empty()) {
            let Ok(value) = serde_json::from_str::<Value>(line) else {
                continue;
            };
            let Some(session_id) = value
                .get("session_id")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|id| !id.is_empty())
            else {
                continue;
            };
            let Some(timestamp) = value.get("ts").and_then(parse_timestamp) else {
                continue;
            };
            let text = value
                .get("text")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let replace = output
                .get(session_id)
                .map(|entry: &HistoryEntry| timestamp > entry.timestamp)
                .unwrap_or(true);
            if replace {
                output.insert(session_id.to_string(), HistoryEntry { timestamp, text });
            }
        }
        output
    }
}

fn read_session_file_meta(path: &Path) -> Option<SessionFileMeta> {
    let content = fs::read_to_string(path).ok()?;
    let fallback_id = extract_session_id_from_path(path);
    let mut id = fallback_id.unwrap_or_default();
    let mut cwd = String::new();
    let mut timestamp = None;
    let mut display = None;
    let mut message_count = 0;

    for line in content.lines().filter(|line| !line.trim().is_empty()) {
        let Ok(value) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        if value.get("type").and_then(Value::as_str) == Some("session_meta") {
            if let Some(payload) = value.get("payload") {
                if let Some(meta_id) = payload.get("id").and_then(Value::as_str) {
                    id = meta_id.trim().to_string();
                }
                cwd = payload
                    .get("cwd")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .trim()
                    .to_string();
                timestamp = payload.get("timestamp").and_then(parse_timestamp);
            }
            continue;
        }
        if let Some(message) = parse_message_record(&value) {
            message_count += 1;
            if display.is_none() && message.role == "user" && !message.text.trim().is_empty() {
                display = Some(normalize_display_text(&message.text));
            }
        }
    }

    if id.is_empty() {
        return None;
    }
    Some(SessionFileMeta {
        id,
        cwd,
        timestamp,
        file_path: path.to_path_buf(),
        display,
        message_count,
    })
}

fn parse_conversation_file(path: &Path) -> AppResult<Vec<CodexSessionMessage>> {
    let content = fs::read_to_string(path)?;
    Ok(content
        .lines()
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| serde_json::from_str::<Value>(line).ok())
        .filter_map(|value| parse_message_record(&value))
        .collect())
}

fn parse_message_record(value: &Value) -> Option<CodexSessionMessage> {
    let timestamp = value.get("timestamp").and_then(parse_timestamp);
    let payload = value.get("payload")?;
    match payload.get("type").and_then(Value::as_str) {
        Some("message") => {
            let role = payload
                .get("role")
                .and_then(Value::as_str)
                .unwrap_or("unknown")
                .to_string();
            let text = extract_message_text(payload);
            if text.trim().is_empty() {
                return None;
            }
            Some(CodexSessionMessage {
                role,
                kind: "message".to_string(),
                text,
                timestamp,
            })
        }
        Some("function_call") => Some(CodexSessionMessage {
            role: "tool".to_string(),
            kind: "functionCall".to_string(),
            text: payload
                .get("name")
                .and_then(Value::as_str)
                .map(|name| format!("调用工具: {name}"))
                .unwrap_or_else(|| "调用工具".to_string()),
            timestamp,
        }),
        Some("function_call_output") => {
            payload
                .get("output")
                .and_then(Value::as_str)
                .map(|output| CodexSessionMessage {
                    role: "tool".to_string(),
                    kind: "functionOutput".to_string(),
                    text: normalize_tool_output(output),
                    timestamp,
                })
        }
        _ => None,
    }
}

fn extract_message_text(payload: &Value) -> String {
    let Some(content) = payload.get("content").and_then(Value::as_array) else {
        return String::new();
    };
    content
        .iter()
        .filter_map(|item| {
            item.get("text")
                .or_else(|| item.get("input_text"))
                .and_then(Value::as_str)
        })
        .collect::<Vec<_>>()
        .join("\n\n")
}

fn normalize_tool_output(output: &str) -> String {
    let text = output.replace("\r\n", "\n").trim().to_string();
    if text.chars().count() > 2_000 {
        format!("{}...", text.chars().take(2_000).collect::<String>())
    } else {
        text
    }
}

fn normalize_display_text(text: &str) -> String {
    let normalized = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if normalized.is_empty() {
        return DEFAULT_DISPLAY.to_string();
    }
    if normalized.chars().count() > DISPLAY_LIMIT {
        format!(
            "{}...",
            normalized.chars().take(DISPLAY_LIMIT).collect::<String>()
        )
    } else {
        normalized
    }
}

fn project_name(project: &str) -> String {
    project
        .split('/')
        .filter(|part| !part.is_empty())
        .last()
        .unwrap_or(project)
        .to_string()
}

fn parse_timestamp(value: &Value) -> Option<DateTime<Utc>> {
    if let Some(number) = value.as_i64() {
        return Utc.timestamp_opt(number, 0).single();
    }
    if let Some(number) = value.as_f64() {
        let seconds = number.trunc() as i64;
        let nanos = ((number.fract().abs()) * 1_000_000_000.0).round() as u32;
        return Utc.timestamp_opt(seconds, nanos).single();
    }
    let text = value.as_str()?;
    if let Ok(number) = text.parse::<i64>() {
        return Utc.timestamp_opt(number, 0).single();
    }
    DateTime::parse_from_rfc3339(text)
        .map(|date| date.with_timezone(&Utc))
        .ok()
}

fn datetime_from_millis(milliseconds: i64) -> DateTime<Utc> {
    Utc.timestamp_millis_opt(milliseconds)
        .single()
        .unwrap_or_else(|| Utc.timestamp_opt(0, 0).single().unwrap())
}

fn file_modified_at(path: &Path) -> Option<DateTime<Utc>> {
    fs::metadata(path)
        .ok()
        .and_then(|metadata| metadata.modified().ok())
        .map(DateTime::<Utc>::from)
}

fn extract_session_id_from_path(path: &Path) -> Option<String> {
    let stem = path.file_stem()?.to_string_lossy();
    let tail = stem.rsplit('-').take(5).collect::<Vec<_>>();
    if tail.len() != 5 {
        return None;
    }
    let uuid = tail.into_iter().rev().collect::<Vec<_>>().join("-");
    if uuid.len() == 36 && uuid.chars().all(|ch| ch.is_ascii_hexdigit() || ch == '-') {
        Some(uuid)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::SessionsService;
    use crate::paths::CodexPaths;
    use rusqlite::Connection;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn lists_sessions_from_history_and_rollout_files() {
        let temp = tempdir().unwrap();
        let codex = temp.path().join(".codex");
        let sessions = codex.join("sessions/2026/05/02");
        fs::create_dir_all(&sessions).unwrap();
        fs::write(
            codex.join("history.jsonl"),
            r#"{"session_id":"11111111-1111-1111-1111-111111111111","ts":1777651200,"text":"history title"}"#,
        )
        .unwrap();
        fs::write(
            sessions.join("rollout-2026-05-02T10-00-00-11111111-1111-1111-1111-111111111111.jsonl"),
            r#"{"timestamp":"2026-05-02T10:00:00Z","type":"session_meta","payload":{"id":"11111111-1111-1111-1111-111111111111","timestamp":"2026-05-02T10:00:00Z","cwd":"/repo/codex-switch"}}
{"timestamp":"2026-05-02T10:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"实现 Sessions 页面"}]}}
{"timestamp":"2026-05-02T10:00:02Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"可以"}]}}"#,
        )
        .unwrap();

        let service = SessionsService::new(CodexPaths::new(codex));
        let items = service.list().unwrap();

        assert_eq!(items.len(), 1);
        assert_eq!(items[0].display, "history title");
        assert_eq!(items[0].project_name, "codex-switch");
        assert_eq!(items[0].message_count, 2);
    }

    #[test]
    fn prefers_history_text_over_bootstrap_prompt_for_title() {
        let temp = tempdir().unwrap();
        let codex = temp.path().join(".codex");
        let sessions = codex.join("sessions/2026/05/02");
        fs::create_dir_all(&sessions).unwrap();
        fs::write(
            codex.join("history.jsonl"),
            r#"{"session_id":"33333333-3333-3333-3333-333333333333","ts":1777651200,"text":"真正的用户问题标题"}"#,
        )
        .unwrap();
        fs::write(
            sessions.join("rollout-2026-05-02T10-00-00-33333333-3333-3333-3333-333333333333.jsonl"),
            r##"{"timestamp":"2026-05-02T10:00:00Z","type":"session_meta","payload":{"id":"33333333-3333-3333-3333-333333333333","timestamp":"2026-05-02T10:00:00Z","cwd":"/repo/codex-switch"}}
{"timestamp":"2026-05-02T10:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"# AGENTS.md instructions for /repo/codex-switch\n\n<INSTRUCTIONS>..."}]}}"##,
        )
        .unwrap();

        let service = SessionsService::new(CodexPaths::new(codex));
        let items = service.list().unwrap();

        assert_eq!(items[0].display, "真正的用户问题标题");
    }

    #[test]
    fn prefers_sqlite_thread_title_over_history_and_rollout_text() {
        let temp = tempdir().unwrap();
        let codex = temp.path().join(".codex");
        let sessions = codex.join("sessions/2026/05/02");
        fs::create_dir_all(&sessions).unwrap();
        fs::write(
            codex.join("history.jsonl"),
            r#"{"session_id":"44444444-4444-4444-4444-444444444444","ts":1777651200,"text":"history title"}"#,
        )
        .unwrap();
        let rollout_path =
            sessions.join("rollout-2026-05-02T10-00-00-44444444-4444-4444-4444-444444444444.jsonl");
        fs::write(
            &rollout_path,
            r##"{"timestamp":"2026-05-02T10:00:00Z","type":"session_meta","payload":{"id":"44444444-4444-4444-4444-444444444444","timestamp":"2026-05-02T10:00:00Z","cwd":"/repo/from-rollout"}}
{"timestamp":"2026-05-02T10:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"# AGENTS.md instructions for /repo/from-rollout"}]}}"##,
        )
        .unwrap();

        let connection = Connection::open(codex.join("state_5.sqlite")).unwrap();
        connection
            .execute(
                "CREATE TABLE threads (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    cwd TEXT NOT NULL,
                    rollout_path TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL,
                    archived INTEGER NOT NULL,
                    created_at_ms INTEGER,
                    updated_at_ms INTEGER
                )",
                [],
            )
            .unwrap();
        connection
            .execute(
                "INSERT INTO threads
                 (id, title, cwd, rollout_path, created_at, updated_at, archived, created_at_ms, updated_at_ms)
                 VALUES (?1, ?2, ?3, ?4, 1777651200, 1777651300, 0, 1777651200000, 1777651300000)",
                (
                    "44444444-4444-4444-4444-444444444444",
                    "SQLite 里的会话标题",
                    "/repo/from-sqlite",
                    rollout_path.to_string_lossy().to_string(),
                ),
            )
            .unwrap();

        let service = SessionsService::new(CodexPaths::new(codex));
        let items = service.list().unwrap();

        assert_eq!(items[0].display, "SQLite 里的会话标题");
        assert_eq!(items[0].project, "/repo/from-sqlite");
        assert!(items[0].file_path.as_deref().is_some());
    }

    #[test]
    fn reads_session_detail_messages() {
        let temp = tempdir().unwrap();
        let codex = temp.path().join(".codex");
        let sessions = codex.join("sessions/2026/05/02");
        fs::create_dir_all(&sessions).unwrap();
        fs::write(
            sessions.join("rollout-2026-05-02T10-00-00-22222222-2222-2222-2222-222222222222.jsonl"),
            r#"{"timestamp":"2026-05-02T10:00:00Z","type":"session_meta","payload":{"id":"22222222-2222-2222-2222-222222222222","timestamp":"2026-05-02T10:00:00Z","cwd":"/repo/codex-switch"}}
{"timestamp":"2026-05-02T10:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"hello"}]}}
{"timestamp":"2026-05-02T10:00:02Z","type":"response_item","payload":{"type":"function_call","name":"shell"}}
{"timestamp":"2026-05-02T10:00:03Z","type":"response_item","payload":{"type":"function_call_output","output":"ok"}}"#,
        )
        .unwrap();

        let service = SessionsService::new(CodexPaths::new(codex));
        let detail = service.get("22222222-2222-2222-2222-222222222222").unwrap();

        assert_eq!(detail.messages.len(), 3);
        assert_eq!(detail.messages[0].text, "hello");
        assert_eq!(detail.messages[1].kind, "functionCall");
        assert_eq!(detail.messages[2].text, "ok");
    }
}
