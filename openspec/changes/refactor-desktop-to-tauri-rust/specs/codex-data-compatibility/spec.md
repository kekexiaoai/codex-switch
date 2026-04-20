## ADDED Requirements

### Requirement: Codex data compatibility

The system SHALL preserve compatibility with the existing Codex data layout.

#### Scenario: Reading and writing Codex files

- **WHEN** the desktop runtime loads or updates account, usage, provider, or diagnostics data
- **THEN** it uses the existing files and directories under `~/.codex`
- **AND** it does not require a one-time migration of the Codex-owned data layout

### Requirement: Desktop preference isolation

The system SHALL store UI preferences separately from Codex-owned data.

#### Scenario: Persisting desktop settings

- **WHEN** the app stores window/UI preferences or app-local settings
- **THEN** those values are written into the application config directory
- **AND** the app keeps Codex runtime data under `~/.codex`
