## ADDED Requirements

### Requirement: Import current active Codex auth
The system SHALL import the currently active Codex auth profile from `~/.codex/auth.json`.

#### Scenario: Importing the active auth file
- **WHEN** the user chooses to import the current account
- **THEN** the system reads `~/.codex/auth.json`
- **AND** validates the auth file structure
- **AND** extracts identity information from `tokens.id_token`
- **AND** archives the full auth file under `~/.codex/accounts/`

#### Scenario: Current auth file is unavailable
- **WHEN** the user chooses to import the current account
- **AND** `~/.codex/auth.json` does not exist or cannot be read
- **THEN** the system reports a user-facing current-auth-file error category
- **AND** does not create or mutate any archived account file

### Requirement: Import backup auth files
The system SHALL support importing a backup `auth.json` file selected by the user.

#### Scenario: Importing a backup auth file
- **WHEN** the user selects a valid backup `auth.json`
- **THEN** the system validates the file
- **AND** extracts identity information from `tokens.id_token`
- **AND** archives the full auth file under `~/.codex/accounts/`

#### Scenario: Backup auth file is invalid
- **WHEN** the user selects a backup file with invalid JSON structure or without `tokens.id_token`
- **THEN** the system reports a user-facing validation error category
- **AND** does not archive the file

### Requirement: Archive accounts as full auth files
The system SHALL store archived accounts as complete auth JSON files in `~/.codex/accounts/`.

#### Scenario: Storing an archived account
- **WHEN** an auth profile is successfully imported
- **THEN** the archived file name is derived from `base64url(email)`
- **AND** the archived file contains the full auth JSON content needed for later switching

#### Scenario: Deriving account metadata from archived auth
- **WHEN** an auth profile is successfully imported
- **THEN** the system derives the account identifier from JWT `sub` when present and otherwise falls back to normalized email
- **AND** derives displayed email masking from the decoded email claim
- **AND** records the archive filename, import source, and last imported timestamp for UI use

### Requirement: Switch active account by replacing auth.json
The system SHALL switch accounts by replacing the active `~/.codex/auth.json` with the archived auth file of the selected account.

#### Scenario: Switching accounts
- **WHEN** the user activates an archived account
- **THEN** the system atomically replaces `~/.codex/auth.json`
- **AND** refreshes active account state in the app

#### Scenario: Archived account cannot be activated
- **WHEN** the user activates an archived account whose archived auth file is missing, invalid, or cannot replace the active auth file
- **THEN** the system reports a user-facing active-auth-replacement error category
- **AND** leaves the existing active auth file unchanged

### Requirement: Read usage from Codex session logs
The system SHALL derive usage snapshots from Codex-generated session log files in `~/.codex/sessions/`.

#### Scenario: Scanning session logs
- **WHEN** the app refreshes usage for the active account
- **THEN** it scans the latest relevant `rollout-*.jsonl` files
- **AND** extracts 5-hour and weekly rate-limit information when available

#### Scenario: No fresh usage data is found
- **WHEN** the app refreshes usage for the active account
- **AND** no relevant session log entry can be parsed for the active account
- **THEN** the system reports a user-facing no-usage-data category
- **AND** may continue showing the last successful cached usage snapshot for that account if one exists

### Requirement: Reuse codex login for browser authentication
The system SHALL orchestrate browser login by invoking `codex login` instead of reimplementing OAuth internally.

#### Scenario: Starting browser login
- **WHEN** the user chooses browser login
- **THEN** the app launches `codex login`
- **AND** waits for Codex to update the active auth file
- **AND** imports the resulting auth profile after login completes successfully

#### Scenario: Browser login is cancelled or fails
- **WHEN** the user chooses browser login
- **AND** the `codex login` process exits unsuccessfully or is cancelled before producing a valid auth file
- **THEN** the system reports a user-facing login failure category
- **AND** does not archive partial or invalid auth state

### Requirement: Use one import pipeline for every account-add path
The system SHALL route current-auth import, backup-file import, and browser-login import through the same validation, JWT decoding, and archival pipeline.

#### Scenario: Import sources converge on the same pipeline
- **WHEN** the user imports an account from any supported source
- **THEN** the system applies the same auth validation rules
- **AND** derives metadata using the same JWT decoding rules
- **AND** writes the same archive format into `~/.codex/accounts/`

### Requirement: Protect local auth material during import and switching
The system SHALL keep archived and active auth material inside the user’s Codex directory tree and avoid exposing raw tokens through logs or UI.

#### Scenario: Writing archived or active auth files
- **WHEN** the system imports or switches an account
- **THEN** it writes auth material only to `~/.codex/auth.json`, `~/.codex/accounts/`, or a short-lived temp file required for atomic replacement
- **AND** it never logs raw token values
- **AND** it does not show full email addresses unless the user has enabled that preference
