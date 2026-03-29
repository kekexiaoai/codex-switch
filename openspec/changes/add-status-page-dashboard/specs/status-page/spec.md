## ADDED Requirements

### Requirement: Present a hybrid status dashboard
The system SHALL present a desktop status page that combines account operations state with local diagnostics.

#### Scenario: Opening the status page from the menu bar
- **WHEN** the user chooses `Status Page`
- **THEN** the app opens the desktop status window
- **AND** shows the current active-account summary when available
- **AND** shows current usage summaries and archived-account inventory when available

#### Scenario: Status data is partially unavailable
- **WHEN** the user opens the status page before importing any account
- **OR** usage data is unavailable for the current account
- **THEN** the page shows explicit empty-state messaging for the missing operational data
- **AND** continues showing any available diagnostics and runtime information

### Requirement: Show local runtime and Codex diagnostics
The system SHALL show local runtime context and recent browser-login diagnostics on the status page without exposing secrets.

#### Scenario: Displaying runtime and path information
- **WHEN** the status page is shown
- **THEN** it displays the current menu-bar host and runtime mode
- **AND** displays the relevant Codex auth, accounts, and diagnostics-log paths

#### Scenario: Displaying recent login diagnostics
- **WHEN** a diagnostics log exists for browser login activity
- **THEN** the status page shows recent safe diagnostic lines or a summarized login state
- **AND** does not display raw access tokens, refresh tokens, or other auth secrets

### Requirement: Refresh the status snapshot on open
The system SHALL refresh the status-page snapshot each time the window is opened.

#### Scenario: Reopening the status page
- **WHEN** the user opens the status page after account, usage, or diagnostics data has changed
- **THEN** the app refreshes the status snapshot before presenting the content
- **AND** reuses a single status window instance rather than opening duplicate windows
