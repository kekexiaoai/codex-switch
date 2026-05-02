## ADDED Requirements

### Requirement: Sessions Page
The desktop client SHALL provide a dedicated Sessions page for browsing Codex CLI conversation history.

#### Scenario: User opens Sessions page
- **WHEN** the user selects `Sessions` from the desktop navigation
- **THEN** the app displays a session list and a session detail area
- **AND** the app does not require launching an external Web server

### Requirement: Session Indexing
The desktop client SHALL build a read-only session index from `~/.codex/history.jsonl` and `~/.codex/sessions/**/*.jsonl`.

#### Scenario: Session files exist
- **WHEN** Codex session JSONL files are present
- **THEN** the app lists sessions sorted by recency
- **AND** each session includes id, display text, project, project name, timestamp, file path, and message count when available

### Requirement: Session Detail
The desktop client SHALL display parsed messages for a selected session.

#### Scenario: User selects a session
- **WHEN** the user selects a session from the Sessions page
- **THEN** the app reads the matching JSONL file
- **AND** shows a compact conversation timeline

### Requirement: Sessions Filtering
The desktop client SHALL support project and text filtering in the Sessions page.

#### Scenario: User filters sessions
- **WHEN** the user enters a search term or selects a project
- **THEN** the visible session list updates locally without changing session files
