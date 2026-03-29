## ADDED Requirements
### Requirement: Account diagnostics include a readable label
The system SHALL include a human-readable account label in usage refresh diagnostics for account-scoped events while preserving the stable account identifier.

#### Scenario: usage refresh logs masked account label
- **WHEN** the app logs a usage refresh event for a known account
- **THEN** the diagnostics entry includes the account identifier
- **AND** the diagnostics entry includes a masked email label when one is available

### Requirement: Archived accounts are visually separated in the menu list
The system SHALL render each archived account as a visually distinct item in the menu bar account list.

#### Scenario: account switcher shows clear row boundaries
- **WHEN** the menu bar account list contains multiple archived accounts
- **THEN** each account row appears as its own visually separated item
- **AND** row-level actions remain discoverable without reducing switchability

### Requirement: Users can remove a single archived account
The system SHALL allow the user to remove one archived account at a time from the menu bar interface.

#### Scenario: remove inactive archived account
- **WHEN** the user confirms removal for an archived account that is not currently active
- **THEN** the app deletes that archived account file
- **AND** the app removes the associated metadata entry
- **AND** the account no longer appears in the menu list

#### Scenario: remove currently active archived account with fallback
- **WHEN** the user confirms removal for the archived account that is currently active
- **THEN** the app removes the archived account file and associated metadata entry
- **AND** the app activates another archived account if one exists
- **AND** otherwise the app clears the current auth file so the removed account is no longer active

#### Scenario: cancel remove account
- **WHEN** the user dismisses the removal confirmation
- **THEN** the archived account files and current auth state remain unchanged
