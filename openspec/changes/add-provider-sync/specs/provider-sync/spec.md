## ADDED Requirements

### Requirement: Provider Status Display
The system SHALL display the current `model_provider` from `~/.codex/config.toml`, the list of configured providers from `[model_providers.*]` section headers, the provider distribution across rollout JSONL files (sessions vs archived_sessions), the provider distribution in the `threads` table of `state_5.sqlite`, and backup summary information.

#### Scenario: Status loaded successfully
- **WHEN** the user opens the Provider Sync window
- **THEN** the current provider, configured providers list, rollout file distribution, SQLite distribution, and backup info are displayed

#### Scenario: Config file missing
- **WHEN** `~/.codex/config.toml` does not exist
- **THEN** the current provider is shown as "openai" (default) and the configured providers list shows only "openai"

#### Scenario: SQLite database missing
- **WHEN** `~/.codex/state_5.sqlite` does not exist
- **THEN** the database distribution section shows "No database found" and sync/switch actions that require the database are disabled

### Requirement: Provider Sync Action
The system SHALL synchronize all session metadata to a target provider by rewriting the `model_provider` field in the first line of all `rollout-*.jsonl` files under `sessions/` and `archived_sessions/`, and updating the `threads.model_provider` column in `state_5.sqlite`, within a transaction with automatic backup and rollback on failure.

#### Scenario: Sync all sessions to current provider
- **WHEN** the user clicks "Sync Now" with a target provider selected
- **THEN** a backup is created, all mismatched rollout files have their first-line `payload.model_provider` rewritten atomically, the SQLite `threads` table is updated in a transaction, and a success message is displayed with the count of changed files and rows

#### Scenario: Sync failure with rollback
- **WHEN** an error occurs during sync (e.g., SQLite write fails)
- **THEN** all already-rewritten rollout files are rolled back to their original first lines, the SQLite transaction is rolled back, and an error message is displayed

### Requirement: Provider Switch Action
The system SHALL allow switching the active provider by updating `model_provider` in `config.toml` and then performing a full sync. If sync fails, the config change is also rolled back.

#### Scenario: Switch and sync succeed
- **WHEN** the user selects a new provider and clicks "Switch & Sync"
- **THEN** `config.toml` is updated with the new `model_provider`, sync is performed, and a success message is shown

#### Scenario: Switch fails due to unknown provider
- **WHEN** the user attempts to switch to a provider not configured in `config.toml`
- **THEN** an error message is shown listing the available providers

### Requirement: Backup Management
The system SHALL create timestamped backups before each sync operation (containing `state_5.sqlite`, `config.toml`, and session metadata), list existing backups, restore from a selected backup, and auto-prune keeping the most recent 5 backups.

#### Scenario: Backup created before sync
- **WHEN** a sync or switch operation begins
- **THEN** a backup is created under `~/.codex/backups_state/provider-sync/<timestamp>/` containing the database, config, and session metadata before modification

#### Scenario: Restore from backup
- **WHEN** the user selects a backup and clicks "Restore"
- **THEN** `config.toml`, `state_5.sqlite`, and all affected rollout file first-lines are restored to their backed-up state

#### Scenario: Prune old backups
- **WHEN** the user clicks "Prune Old" or auto-prune triggers after sync
- **THEN** only the most recent 5 backups are retained and older ones are deleted

### Requirement: Menu Bar Integration
The system SHALL provide a "Provider Sync" action row in the menu bar panel that opens the Provider Sync window.

#### Scenario: Open Provider Sync from menu bar
- **WHEN** the user clicks "Provider Sync" in the menu bar panel
- **THEN** the Provider Sync window opens (or comes to front if already open)

### Requirement: Window Presentation
The system SHALL present the Provider Sync UI in a standalone macOS window (520×640, titled, closable, miniaturizable, resizable) following the same `NSWindowController` + `NSHostingController` pattern as the Settings window.

#### Scenario: Window reuse
- **WHEN** the user opens Provider Sync while the window is already open
- **THEN** the existing window is brought to front with refreshed data instead of creating a new window
