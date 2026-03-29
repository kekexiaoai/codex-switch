## ADDED Requirements

### Requirement: Import current active Codex auth
The system SHALL import the currently active Codex auth profile from `~/.codex/auth.json`.

#### Scenario: Importing the active auth file
- **WHEN** the user chooses to import the current account
- **THEN** the system reads `~/.codex/auth.json`
- **AND** validates the auth file structure
- **AND** extracts identity information from `tokens.id_token`
- **AND** archives the full auth file under `~/.codex/accounts/`

### Requirement: Import backup auth files
The system SHALL support importing a backup `auth.json` file selected by the user.

#### Scenario: Importing a backup auth file
- **WHEN** the user selects a valid backup `auth.json`
- **THEN** the system validates the file
- **AND** extracts identity information from `tokens.id_token`
- **AND** archives the full auth file under `~/.codex/accounts/`

### Requirement: Archive accounts as full auth files
The system SHALL store archived accounts as complete auth JSON files in `~/.codex/accounts/`.

#### Scenario: Storing an archived account
- **WHEN** an auth profile is successfully imported
- **THEN** the archived file name is derived from `base64url(email)`
- **AND** the archived file contains the full auth JSON content needed for later switching

### Requirement: Switch active account by replacing auth.json
The system SHALL switch accounts by replacing the active `~/.codex/auth.json` with the archived auth file of the selected account.

#### Scenario: Switching accounts
- **WHEN** the user activates an archived account
- **THEN** the system atomically replaces `~/.codex/auth.json`
- **AND** refreshes active account state in the app

### Requirement: Read usage from Codex session logs
The system SHALL derive usage snapshots from Codex-generated session log files in `~/.codex/sessions/`.

#### Scenario: Scanning session logs
- **WHEN** the app refreshes usage for the active account
- **THEN** it scans the latest relevant `rollout-*.jsonl` files
- **AND** extracts 5-hour and weekly rate-limit information when available

### Requirement: Reuse codex login for browser authentication
The system SHALL orchestrate browser login by invoking `codex login` instead of reimplementing OAuth internally.

#### Scenario: Starting browser login
- **WHEN** the user chooses browser login
- **THEN** the app launches `codex login`
- **AND** waits for Codex to update the active auth file
- **AND** imports the resulting auth profile after login completes successfully
