## ADDED Requirements

### Requirement: Desktop-native visual direction

The system SHALL present a desktop-oriented interface rather than a web dashboard aesthetic.

#### Scenario: Rendering the main shell

- **WHEN** the main window renders
- **THEN** it uses a compact desktop layout with a narrow sidebar and a focused work area
- **AND** it does not render a website-style top navigation bar, hero section, or marketing-style landing page

### Requirement: Tray panel scope

The system SHALL keep the tray panel focused on quick actions and summaries.

#### Scenario: Using the tray

- **WHEN** the user opens the tray panel
- **THEN** the panel shows current account state, usage summary, quick switching, and core shortcuts
- **AND** it does not contain the full management workflows that belong in the main window
