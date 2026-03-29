## MODIFIED Requirements

### Requirement: Desktop-owned browser authentication
The system SHALL orchestrate browser login from the desktop app itself rather than requiring the user to interact with Terminal or `codex login`.

#### Scenario: Starting browser login from the menu bar app
- **WHEN** the user chooses browser login
- **THEN** the app launches the browser-login flow from app-owned code
- **AND** does not require the user to interact with Terminal or a CLI prompt
- **AND** waits for the login flow to produce a valid active auth profile

#### Scenario: Browser login completes successfully
- **WHEN** the user completes desktop browser login
- **THEN** the app materializes or updates `~/.codex/auth.json`
- **AND** validates the resulting auth file through the existing import pipeline
- **AND** archives the resulting auth profile after login completes successfully

#### Scenario: Browser login is cancelled or fails
- **WHEN** the user cancels browser login
- **OR** the desktop login flow times out or fails before producing a valid auth file
- **THEN** the system reports a user-facing login failure category
- **AND** does not require the user to switch to Terminal to continue the intended desktop login flow
- **AND** does not archive partial or invalid auth state
