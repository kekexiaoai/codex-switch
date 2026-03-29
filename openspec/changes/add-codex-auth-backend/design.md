## Context

Codex itself is the source of truth for authentication. The app should not behave like a separate identity provider or OAuth client. It should manage local Codex auth artifacts and coordinate Codex’s own login flow.

Relevant local artifacts:

- active auth: `~/.codex/auth.json`
- archived auths: `~/.codex/accounts/*.json`
- usage logs: `~/.codex/sessions/rollout-*.jsonl`

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

## Risks / Trade-offs

- Codex file formats may change over time
  - Mitigation: centralize parsing in dedicated adapters and validate shape defensively

- Session logs may not always contain fresh data for every archived account
  - Mitigation: cache the last successful usage snapshot per account and refresh after switch

- `codex login` subprocess behavior may differ across environments
  - Mitigation: isolate process orchestration and surface explicit failure categories

## Migration Plan

1. Land the design and spec
2. Replace the current Add Account demo path with active-auth import
3. Add backup import and account switching
4. Add usage scanning
5. Add browser login import via `codex login`

## Open Questions

- Which JWT claim is the most stable account identifier across Codex plans and identity states
- How aggressively the app should poll/watch `~/.codex/auth.json` during `codex login`
- Whether archived account files should also include a lightweight sidecar metadata cache for faster menu loading
