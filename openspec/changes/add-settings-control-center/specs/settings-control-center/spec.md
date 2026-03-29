## ADDED Requirements

### Requirement: Present grouped settings sections
The system SHALL present the Settings window as a grouped control center for general app behavior, privacy, usage, and advanced tooling.

#### Scenario: Opening the Settings window
- **WHEN** the user opens Settings from the menu bar
- **THEN** the app shows grouped sections for `General`, `Privacy`, `Usage`, and `Advanced`
- **AND** each section shows the current persisted values when available

### Requirement: Apply settings immediately
The system SHALL persist supported settings as soon as the user changes them, without requiring a separate save action.

#### Scenario: Toggling a preference
- **WHEN** the user changes a supported toggle or picker in Settings
- **THEN** the preference is persisted immediately
- **AND** the UI reflects the new value without waiting for `Save` or reopening the window

### Requirement: Configure usage refresh behavior
The system SHALL let the user enable or disable usage refresh and select the usage source mode.

#### Scenario: Enabling usage refresh
- **WHEN** the user enables usage refresh
- **THEN** the app persists that preference immediately
- **AND** the selected usage source mode remains available for configuration

#### Scenario: Selecting usage source mode
- **WHEN** the user selects `Automatic` or `Local Only`
- **THEN** the app persists the chosen usage source mode immediately
- **AND** future refresh behavior uses that persisted configuration

### Requirement: Protect destructive maintenance actions
The system SHALL require explicit confirmation before destructive settings actions mutate local account or diagnostics data.

#### Scenario: Clearing local data from Settings
- **WHEN** the user chooses to clear logs, clear cache, or remove archived accounts
- **THEN** the app asks for explicit confirmation before performing the action
- **AND** shows a user-facing result message after the action completes or fails

### Requirement: Provide advanced diagnostics utilities
The system SHALL offer advanced utility actions from Settings for local diagnostics workflows.

#### Scenario: Opening diagnostics resources
- **WHEN** the user chooses to open the Codex directory or diagnostics log from Settings
- **THEN** the app opens the corresponding local resource using desktop-native behavior

#### Scenario: Exporting diagnostics summary
- **WHEN** the user chooses to export diagnostics from Settings
- **THEN** the app produces a sanitized diagnostics summary
- **AND** the export does not include raw auth tokens or other secrets
