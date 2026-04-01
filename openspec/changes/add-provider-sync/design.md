## Context
Codex stores `model_provider` in two separate locations:
1. The first line of every `rollout-*.jsonl` session file (`payload.model_provider` in the `session_meta` JSON)
2. The `threads.model_provider` column in `~/.codex/state_5.sqlite`

When a user changes their active provider in `~/.codex/config.toml`, historical sessions become invisible because their stored provider no longer matches. The codex-provider-sync project (Node.js/C#) solves this with CLI/GUI tools. We integrate equivalent functionality as a native Swift window in Codex Switch.

## Goals / Non-Goals
- Goals:
  - Provide a GUI window for viewing provider status, syncing, switching, and managing backups
  - Pure Swift implementation (no Node.js/C# dependency)
  - Follow existing SettingsView/SettingsWindowPresenter architectural patterns
  - Atomic operations with backup/rollback for data safety
- Non-Goals:
  - Windows support (codex-switch is macOS only)
  - Lock file interop with the Node.js codex-provider-sync tool
  - Full TOML parser (regex-based parsing is sufficient for the narrow use case)

## Decisions

### 1. TOML Parsing: Regex-based
- Only need to read/write `model_provider = "..."` at top level and enumerate `[model_providers.<id>]` section headers
- Full TOML parser would be overkill; the original Node.js project uses regex too
- Alternatives: TOMLKit SPM package — rejected to avoid external dependency

### 2. SQLite Access: C API via `import SQLite3`
- macOS ships with libsqlite3; `import SQLite3` gives direct access
- No SPM dependency needed
- Alternatives: GRDB.swift or SQLite.swift — rejected to keep dependencies at zero

### 3. Rollout File Rewriting: Atomic temp-file + rename
- Read first line, parse JSON, update `model_provider`, write to temp file, rename over original
- Preserves all lines after the first byte-for-byte
- Detects and preserves line separator (`\r\n` vs `\n`)

### 4. Backup Strategy: Mirror codex-provider-sync layout
- Backup directory: `~/.codex/backups_state/provider-sync/<timestamp>/`
- Contents: `db/state_5.sqlite`, `config.toml`, `metadata.json`, `session-meta-backup.json`
- Retention: keep most recent 5 (matching original default)
- This allows potential interop if users also have the Node.js tool installed

### 5. Window Presenter: Follow SettingsWindowPresenter pattern
- `ProviderSyncWindowPresenter` with `present()`, lazy `NSWindowController`, `NSHostingController`
- Window size: 520×640, titled + closable + miniaturizable + resizable
- `ProviderSyncViewModel` as `@MainActor ObservableObject`

### 6. Concurrency: File-based lock
- Use `~/.codex/tmp/provider-sync.lock` with `flock()` for mutual exclusion
- Matches the original project's locking approach

## Risks / Trade-offs
- Regex TOML parsing may break on unusual config.toml formatting → Mitigation: handle common edge cases, log warnings for unparseable lines
- Large session directories may cause UI freeze during scan → Mitigation: run scan on background actor, show progress indicator
- SQLite WAL mode files (-shm, -wal) may be present → Mitigation: handle in backup/restore, same as original project

## File Structure

```
CodexSwitch/ProviderSync/
├── ProviderSyncView.swift              # SwiftUI界面
├── ProviderSyncViewModel.swift         # ViewModel
├── ProviderSyncActions.swift           # Action枚举、协议、消息类型
├── ProviderSyncWindowPresenter.swift   # NSWindow管理
├── ProviderSyncService.swift           # 业务逻辑协议 + Live/Mock实现
├── CodexConfigParser.swift             # config.toml读写
├── CodexSessionScanner.swift           # rollout-*.jsonl扫描和改写
├── CodexProviderSQLite.swift           # state_5.sqlite读写
└── ProviderSyncBackupManager.swift     # 备份/恢复管理
```

## Open Questions
- None at this stage; the original project's behavior is well-documented and serves as the reference implementation.
