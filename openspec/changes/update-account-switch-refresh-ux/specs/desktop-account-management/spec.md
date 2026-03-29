## ADDED Requirements
### Requirement: Account switching does not block on usage refresh
The system SHALL finish account switching as soon as the active auth swap succeeds, without blocking the UI on usage refresh work.

#### Scenario: automatic mode switch remains responsive
- **WHEN** the user switches to another archived account while usage refresh is enabled in `Automatic` mode
- **THEN** the active account selection updates immediately after the auth swap succeeds
- **AND** usage refresh continues asynchronously in the background

### Requirement: Menu bar usage timestamp is compact
The system SHALL display a compact usage status string in the menu bar header so it fits within the menu bar panel width.

#### Scenario: local-only mode uses compact header text
- **WHEN** the menu bar header renders usage status for a locally refreshed account
- **THEN** it shows a short local-time string with the source mode
- **AND** it omits explicit timezone text
- **AND** it does not rely on the full verbose `Updated <full timestamp> (Local Only)` format

### Requirement: Account rows clearly indicate switching affordance
The system SHALL make it obvious that archived account rows are interactive switch targets.

#### Scenario: account row looks actionable
- **WHEN** the menu bar renders archived accounts
- **THEN** the full row provides a visible switch affordance
- **AND** the remove action remains visually distinct from switching

### Requirement: Removing the active account has deterministic fallback behavior
The system SHALL allow removing the active account only when the confirmation explains the outcome and the app can resolve the next active state deterministically.

#### Scenario: delete active account with fallback account available
- **WHEN** the user confirms deletion of the currently active archived account
- **THEN** the app removes that archived account
- **AND** the app switches to another archived account immediately

#### Scenario: delete last active archived account
- **WHEN** the user confirms deletion of the currently active archived account and no other archived account exists
- **THEN** the app removes that archived account
- **AND** the app clears the current auth state
- **AND** the app shows that no active account remains
