## Context

Codex itself is the source of truth for authentication. The app should not behave like a separate identity provider or OAuth client. It should manage local Codex auth artifacts and coordinate Codex’s own login flow.

Relevant local artifacts:

- active auth: `~/.codex/auth.json`
- archived auths: `~/.codex/accounts/*.json`
- usage logs: `~/.codex/sessions/rollout-*.jsonl`

## Current Architecture Review

The current macOS client is still organized around a demo-oriented account model:

- `AccountRepository` persists lightweight account metadata separately from secrets
- `ApplicationSupportAccountStore` writes metadata into an app-owned `accounts.json`
- `KeychainCredentialStore` stores a per-account secret unrelated to Codex auth files
- `MenuBarViewModel` still supports manual/demo account creation
- `StubSwitchCommandRunner` and `StubUsageRefreshService` are placeholders with no Codex integration

This means the local auth backend change is not a thin adapter. It must replace the source of truth beneath the existing menu bar flows while preserving the current UI-facing seams:

- `MenuBarViewModel` should continue to depend on a repository/service layer, not raw filesystem code
- `ActiveAccountController` remains the entry point for switch-triggered refreshes
- `EnvironmentMenuBarService` remains responsible for mapping backend state into menu bar snapshot models

## Architecture Alignment

The backend should land as a set of Codex-specific adapters behind the current app-facing seams:

- replace app-owned metadata persistence with a repository that derives account rows from archived auth files
- replace secret storage with full archived `auth.json` files in `~/.codex/accounts/`
- replace stub switching with an active-auth writer that atomically swaps `~/.codex/auth.json`
- replace stub usage refresh with a scanner over `~/.codex/sessions/rollout-*.jsonl`
- replace manual add-account flows with import actions backed by the unified import pipeline

## Goals / Non-Goals

- Goals:
  - Import and archive real Codex auth files
  - Switch accounts by replacing the active auth file
  - Read usage from Codex-generated session logs
  - Reuse `codex login` for browser auth
- Non-Goals:
  - Reimplement OAuth in the app
  - Invent a second independent account model disconnected from Codex files
  - Treat manual user-entered email/tier as account truth

## Decisions

- Decision: archived account files SHALL store full auth JSON
  - Why: switching requires restoring a complete auth state

- Decision: browser login SHALL be orchestrated by invoking `codex login`
  - Why: Codex already owns the browser/OAuth/localhost callback flow

- Decision: usage SHALL be derived from `rollout-*.jsonl` files in `~/.codex/sessions/`
  - Why: Codex already emits the relevant rate-limit state locally

- Decision: all add-account entry points SHALL converge on a single import pipeline
  - Why: this keeps validation, JWT decoding, archival, and deduplication logic consistent

- Decision: account metadata shown in the UI SHALL be derived from archived auth files and cached snapshots, not handwritten form fields
  - Why: the current demo/manual add-account path would otherwise reintroduce a second source of truth

- Decision: existing menu bar and switching view models SHALL keep protocol-friendly seams while the concrete live implementations swap from fixture/demo logic to Codex-backed adapters
  - Why: this minimizes UI churn and keeps the change focused on backend replacement

## Risks / Trade-offs

- Codex file formats may change over time
  - Mitigation: centralize parsing in dedicated adapters and validate shape defensively

- Session logs may not always contain fresh data for every archived account
  - Mitigation: cache the last successful usage snapshot per account and refresh after switch

- `codex login` subprocess behavior may differ across environments
  - Mitigation: isolate process orchestration and surface explicit failure categories

## Migration Plan

1. Land the design and spec
2. Introduce Codex-aware account/archive/auth adapters behind the current repository and switching seams
3. Replace the current Add Account demo path with active-auth import and backup import
4. Add account switching and usage scanning
5. Add browser login import via `codex login`

## Open Questions

- Which JWT claim is the most stable account identifier across Codex plans and identity states
- How aggressively the app should poll/watch `~/.codex/auth.json` during `codex login`
- Whether archived account files should also include a lightweight sidecar metadata cache for faster menu loading

## Resolutions Required Before Implementation Completion

- Stable account identity SHALL prefer JWT `sub` when present and fall back to normalized email only when `sub` is unavailable
- Usage snapshots SHALL be associated to the currently active account after a switch-triggered refresh; archived inactive accounts may show the last successful cached snapshot until they become active again
- Browser login orchestration may use file polling initially; a filesystem event watcher is optional and not required for the first implementation
