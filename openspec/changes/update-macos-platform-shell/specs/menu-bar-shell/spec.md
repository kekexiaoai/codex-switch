## ADDED Requirements

### Requirement: macOS 12-compatible menu bar host
The system SHALL provide a menu bar host that runs on macOS 12 using `NSStatusItem` and `NSPopover`.

#### Scenario: Launching on macOS 12
- **WHEN** the app starts on macOS 12
- **THEN** it creates a status item in the menu bar
- **AND** opening the status item shows the account panel inside a popover

### Requirement: Shared panel behavior across host implementations
The system SHALL render the same menu panel content and behavior regardless of whether the host uses AppKit or `MenuBarExtra`.

#### Scenario: Rendering shared content
- **WHEN** the panel is shown on any supported macOS version
- **THEN** the current account, usage summaries, and account switch list are rendered from the same shared SwiftUI view hierarchy

### Requirement: Optional macOS 13+ host path
The system SHALL allow a `MenuBarExtra` host implementation on macOS 13 and later without changing the deployment floor.

#### Scenario: Launching on macOS 13 or later
- **WHEN** the app starts on macOS 13 or later
- **THEN** the runtime may select a `MenuBarExtra` host
- **AND** the rendered panel behavior remains consistent with the macOS 12 host path
