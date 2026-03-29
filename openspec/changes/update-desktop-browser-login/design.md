## Context

The existing local-auth backend proposal explicitly chose to reuse `codex login` instead of implementing desktop-owned authentication. That choice optimized for reuse of Codex CLI behavior, but it leaks terminal constraints into the product surface.

Recent validation made the trade-off clear:

- hidden subprocess login cannot support interactive `/login` flows
- visible Terminal fallback is workable but not acceptable as a desktop UX
- terminal-driven orchestration keeps the app dependent on CLI interaction models instead of desktop-native state transitions

The new design should preserve the existing auth archive model:

- active auth stays in `~/.codex/auth.json`
- archived auth stays in `~/.codex/accounts/*.json`
- all successful login outputs still converge on the existing import/archive pipeline

What changes is only the login entry point and orchestration layer.

## Goals / Non-Goals

- Goals:
  - Start browser login from the macOS app without exposing Terminal
  - Detect login completion in app-owned code
  - Continue importing successful auth output through the existing archive pipeline
  - Preserve current account switching and usage behavior
- Non-Goals:
  - Rebuild the whole local-auth backend
  - Keep Terminal as a visible or hidden dependency of the intended user flow
  - Require the user to type `/login` in a CLI to authenticate

## Options Considered

### Option 1: Keep `codex login`, but hide Terminal better

This includes hidden pseudo-terminals, auto-closing Terminal windows, or embedding a terminal-like surface.

Rejected because it still makes desktop login dependent on CLI interaction semantics. It hides the problem instead of removing it.

### Option 2: Launch Terminal only as an exceptional fallback

This keeps a desktop-first path but still falls back to Terminal for some Codex versions or auth modes.

Rejected for the first-class flow because it creates inconsistent UX and keeps login reliability tied to external terminal state.

### Option 3: Desktop-owned browser login broker

The app initiates browser authentication itself, owns completion detection, and imports the resulting auth file without exposing terminal tooling.

Chosen because it matches the product surface: a desktop app should own the desktop login experience.

## Proposed Architecture

Introduce a desktop login broker layer with these responsibilities:

1. Begin browser authentication from the app
   - open the browser directly from macOS app code
   - start any required local listener, callback observer, or auth session tracker

2. Track login completion in app-owned state
   - detect successful callback, token handoff, device authorization completion, or auth-file update
   - enforce timeout and cancellation rules without relying on terminal process state

3. Materialize Codex-compatible auth artifacts
   - write or update `~/.codex/auth.json` in the same shape expected by the rest of the backend
   - validate the resulting auth content through the existing importer

4. Reuse the import pipeline
   - once the auth file is available, continue using the existing JWT decoding, archival, deduplication, and activation behavior

## Data Flow

1. User clicks `Login in Browser`
2. Menu bar view model asks the login coordinator to start desktop login
3. Login coordinator delegates to the desktop login broker
4. Desktop login broker opens browser and waits for completion
5. On success, broker updates `~/.codex/auth.json`
6. Coordinator imports current auth via the existing importer
7. App archives the auth profile and activates the resulting account

## Error Handling

The app should distinguish:

- browser flow cancelled by the user
- browser flow timed out
- callback completed but auth payload was invalid
- browser flow completed but `auth.json` could not be materialized
- browser or callback infrastructure unavailable on the local machine

These failures should map to desktop-native alert copy. They should not mention Terminal, shell commands, or manual TUI fallback in the primary flow.

## Testing Strategy

- unit tests for desktop login broker state transitions
- unit tests for callback success, timeout, and cancellation handling
- integration-style tests for coordinator behavior once a browser login result updates `auth.json`
- regression tests confirming menu bar alerts no longer mention Terminal for the primary login path

## Migration Plan

1. Add spec delta for desktop-owned browser login
2. Introduce desktop login broker interfaces and tests
3. Replace current process-based login runner in the app runtime
4. Update menu bar login messaging and progress states
5. Remove terminal-driven login code paths from the intended UX

## Open Questions

- Which browser-auth protocol details from Codex or `codex-auth` can be reused directly in Swift without shelling out
- Whether the first implementation should prefer localhost callback handling, device auth presented in-app, or another desktop-native mechanism
- Whether login completion should be driven by callback receipt, auth-file creation, or both for defense in depth
