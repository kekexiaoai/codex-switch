## Context
Codex Switch stores archived accounts as JSON files under `~/.codex/accounts/` and derives the active account from the current `~/.codex/auth.json`. The menu bar UI renders archived accounts as a flat list, while diagnostics events currently log only raw account IDs for usage refresh activity.

## Goals / Non-Goals
- Goals:
  - Make diagnostics easier to inspect by including a readable account label.
  - Improve visual separation between account rows.
  - Let the user remove one archived account at a time from the menu UI.
  - Keep the app in a valid state after removing the currently active account.
- Non-Goals:
  - Bulk account deletion from the menu bar.
  - Editing account labels manually.
  - Changing the existing settings-based "remove all archived accounts" behavior.

## Decisions
- Decision: usage refresh diagnostics will log both the stable account ID and a masked email label when available.
  - Alternatives considered:
    - Log only raw ID: rejected because it is hard to map during troubleshooting.
    - Log full email: rejected because masked labels are safer for local diagnostics.
- Decision: the menu bar account switcher will present each account as a visually distinct row with its own remove affordance.
  - Alternatives considered:
    - Add only divider lines: acceptable but weaker visual grouping.
    - Move removal into Settings: rejected because the user needs row-level maintenance where switching already happens.
- Decision: removing an account deletes its archived auth file and metadata entry. If that account is currently active, the app will immediately activate another archived account when available; otherwise it will clear the current auth file so the removed account does not remain active invisibly.
  - Alternatives considered:
    - Remove archive only and keep current auth: rejected because it leaves the app and CLI state inconsistent.
    - Block deletion of the active account: rejected because it forces extra user steps for a common cleanup case.

## Risks / Trade-offs
- Removing the active account is destructive because it can also affect `~/.codex/auth.json`.
  - Mitigation: require explicit confirmation and make the post-delete behavior deterministic.
- Diagnostics labels may become stale if an account email changes.
  - Mitigation: derive the label from the current account object at log time instead of storing a separate cache.

## Migration Plan
1. Add row-level remove handling in the menu view model and UI.
2. Extend archived account storage with single-account deletion primitives.
3. Apply active-account fallback when deleting the selected account.
4. Update diagnostics formatting and tests.

## Open Questions
- None.
