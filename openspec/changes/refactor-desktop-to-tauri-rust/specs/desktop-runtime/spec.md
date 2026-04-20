## ADDED Requirements

### Requirement: Rust-owned desktop runtime

The system SHALL implement the desktop runtime in Rust under a Tauri application boundary rather than in Swift/AppKit as the primary product runtime.

#### Scenario: Desktop command execution

- **WHEN** the UI needs account, usage, provider, settings, diagnostics, or window actions
- **THEN** it invokes Tauri commands exposed by the Rust runtime
- **AND** the UI does not directly read or write `.codex` files

### Requirement: Main window and tray shell

The system SHALL provide a primary main window and a secondary tray panel shell.

#### Scenario: Opening the main workspace

- **WHEN** the user launches the app or opens the full management interface
- **THEN** the main window presents the available desktop tools
- **AND** the tray panel remains a lightweight quick-access surface
