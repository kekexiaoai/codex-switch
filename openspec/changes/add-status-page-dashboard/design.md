## Context

The app already has three useful sources of truth, but the current status window does not compose them:

- account metadata from archived auth files
- usage summaries from the existing menu-bar snapshot path
- browser-login diagnostics from `~/.codex/codex-switch-login.log`

The new page should stay read-only and avoid becoming a second control surface. Its job is visibility, not mutation.

## Goals

- Present one hybrid dashboard for both release testing and daily troubleshooting
- Reuse existing account and usage services where possible
- Keep diagnostics safe by summarizing local state without surfacing tokens or other secrets
- Support empty states cleanly before the user has added any account

## Non-Goals

- No account mutation actions from the status page in v1
- No live streaming log tail
- No separate navigation shell or multi-tab window

## Decisions

- Decision: Introduce a dedicated status snapshot loader instead of binding the view directly to unrelated services.
  - Why: The page needs a normalized read model spanning accounts, usage, runtime metadata, and diagnostics text.

- Decision: Reuse existing usage/account primitives, but add a small diagnostics reader for recent login events.
  - Why: Existing menu-bar code already knows how to express usage and account state, while diagnostics currently exist only as raw log lines.

- Decision: Reuse one window controller instance and refresh the snapshot on open.
  - Why: This matches desktop expectations and avoids multiple stale status windows.

## Risks / Trade-offs

- Diagnostics logs are free-form text, so v1 should summarize recent safe lines rather than over-parse them.
- The live environment currently exposes some data only indirectly, so the status snapshot loader may need a few new read-only seams.

## Migration Plan

1. Add the new status-page specification and plan.
2. Implement a read-only snapshot loader plus diagnostics summarizer behind tests.
3. Replace the placeholder status window with the new dashboard.
4. Validate via `swift test` and packaged app build.
