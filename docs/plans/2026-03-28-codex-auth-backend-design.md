# Codex Auth Backend Design

## Goal

Replace the current demo-style local account creation flow with a real Codex-backed local auth management layer that:

- imports real Codex auth profiles from `~/.codex/auth.json`
- archives accounts in `~/.codex/accounts/`
- switches the active account by replacing `~/.codex/auth.json`
- reads usage information from `~/.codex/sessions/rollout-*.jsonl`
- reuses `codex login` for browser-based login instead of reimplementing OAuth

## Recommendation

Use Codex itself as the authentication authority and treat this app as a local account orchestrator.

This is the recommended approach because:

- it avoids reimplementing OAuth 2.0 / localhost callback handling
- it stays aligned with how Codex already stores active auth state
- it keeps failure modes local and debuggable
- it minimizes compatibility drift with future Codex CLI updates

Alternative approaches considered:

1. Reimplement browser OAuth directly in the app
- Rejected because it duplicates security-sensitive logic and will drift from Codex behavior

2. Store only metadata in the app and never archive full auth files
- Rejected because switching accounts fundamentally requires restoring a full `auth.json`

3. Keep the current manual form as the main add-account path
- Rejected because user input is not a trustworthy source of account identity or plan state

## Architecture

The backend should be a local file-and-process integration layer with five concrete subsystems.

### 1. Active Auth Store

Owns the current Codex session file:

- path: `~/.codex/auth.json`
- responsibilities:
  - load current active auth
  - validate file structure
  - atomically replace the active auth file during account switching

Key rule:

- never partially overwrite `auth.json`
- always write to a temp file and `rename` into place

### 2. Archived Account Store

Owns the managed account archive:

- path: `~/.codex/accounts/`
- file naming rule: `base64url(email).json`
- stored content: full archived auth file, not only metadata

Metadata shown in the UI should be derived from archived auth content, not treated as the source of truth.

### 3. JWT Decoder

Reads `tokens.id_token` from the auth file and extracts identity information from the JWT payload:

- `email`
- `plan` / `tier`
- optional stable claims such as `sub`

The app should not trust form input for these values when a real auth file exists.

### 4. Login Coordinator

Responsible for browser-based login by reusing `codex login`.

Flow:

1. launch `codex login`
2. let Codex open the browser and complete OAuth
3. wait for `~/.codex/auth.json` to be updated or for the subprocess to exit successfully
4. import the resulting auth file into the managed archive

This coordinator should not implement OAuth itself.

### 5. Usage Scanner

Reads usage/rate-limit information from:

- path: `~/.codex/sessions/`
- files: latest `rollout-*.jsonl`

Responsibilities:

- find the newest relevant session logs
- parse entries that contain rate-limit data
- derive:
  - 5-hour usage and reset time
  - weekly usage and reset time
  - last update timestamp

This scanner is the usage backend for the menu bar summaries.

## Unified Account Import Pipeline

All account-add paths must converge on the same import pipeline.

### Input Sources

1. Import current active account from `~/.codex/auth.json`
2. Login in browser via `codex login`, then import the resulting active auth
3. Import a backup `auth.json` file selected by the user

### Pipeline

1. Read auth file contents
2. Validate JSON structure
3. Extract `tokens.id_token`
4. Decode JWT payload
5. Derive:
- full email
- masked email
- tier
- optional stable subject id
6. Compute archive filename with `base64url(email)`
7. Save full auth file into `~/.codex/accounts/<encoded>.json`
8. Update local metadata cache/UI snapshot
9. Optionally activate the imported account

## Switching Logic

Switching an account should do exactly this:

1. resolve target archive file in `~/.codex/accounts/`
2. load full archived auth JSON
3. atomically replace `~/.codex/auth.json`
4. mark the selected account as active in app state
5. trigger a usage refresh pass

The archive file itself remains immutable unless the user explicitly reimports or refreshes auth state.

## Data Model

The current `Account` model should evolve to reflect real auth-backed identity.

Required fields:

- `id`
- `email`
- `emailMask`
- `tier`
- `archiveFilename`
- `source`
- `lastImportedAt`

Where:

- `id` should prefer a stable identity claim if available
- `archiveFilename` is the actual account file key in `~/.codex/accounts/`
- `source` distinguishes current import, browser login import, and backup import

## Error Handling

Errors should be expressed in user-facing categories rather than raw file/process failures.

Recommended categories:

- current auth file missing
- auth file unreadable
- auth JSON invalid
- `id_token` missing
- JWT payload invalid
- archive write failed
- active auth replacement failed
- `codex login` cancelled
- `codex login` failed
- usage scan found no relevant session data

The UI can then map these to concise status messages.

## Security Constraints

- store archived auth files only in the user’s Codex directory tree
- never log raw token contents
- never expose full email unless the user enables it
- use atomic file replacement for auth switching
- avoid copying auth material into ad hoc temp locations beyond a short-lived atomic-write temp file

## Testing Strategy

Backend implementation should be validated at four levels.

### Unit

- JWT payload decoding
- email masking
- archive filename generation
- auth file validation
- session log parsing

### Integration

- import current `auth.json`
- import backup `auth.json`
- switch archived account into active `auth.json`
- usage scan against fixture `rollout-*.jsonl`

### Process Coordination

- `codex login` launch handling
- process completion / cancellation handling
- auth file change detection after login

### UI Integration

- menu bar list refresh after import
- header refresh after switch
- usage card refresh after scan

## Recommended Delivery Order

1. Implement `Import Current Account`
2. Implement `Import Backup auth.json`
3. Implement account switching via active auth replacement
4. Implement usage scanning from `~/.codex/sessions/`
5. Implement browser login import by orchestrating `codex login`

This order minimizes risk because each step builds on local, testable behavior before adding subprocess coordination.
