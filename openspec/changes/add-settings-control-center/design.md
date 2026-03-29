## Context

The app already has multiple user-facing behaviors that belong in settings, but only one of them is currently configurable. Settings now need to serve as the product-facing configuration surface for privacy, usage policy, app behavior, and diagnostics utilities.

The design also needs to absorb the usage-source plan's immediate configuration requirements:

- `Enable Usage Refresh`
- `Usage Source Mode`

## Goals

- Provide one coherent settings surface for real product behavior
- Keep every preference instant-apply
- Use the existing `UserDefaults` seam where practical
- Route destructive actions through clear confirmation and result messaging
- Reuse existing diagnostics/path concepts rather than inventing parallel storage

## Non-Goals

- No multi-window preferences architecture
- No delayed apply model with `Save` / `Cancel`
- No hidden developer-only terminal flows

## Decisions

- Decision: Group settings into `General`, `Privacy`, `Usage`, and `Advanced`.
  - Why: This keeps operational settings legible while leaving room for future growth.

- Decision: Persist preferences immediately on user interaction.
  - Why: The app is small, local-first, and already uses direct preference writes for email visibility.

- Decision: Gate destructive actions behind explicit confirmation.
  - Why: Clearing logs, cache, or archived accounts is not reversible and should not happen on accidental clicks.

- Decision: Treat usage refresh enablement and source mode as first-class settings.
  - Why: The usage-source design explicitly calls for a visible local-only escape hatch and enable/disable control.

## Risks / Trade-offs

- Adding too many controls without grouping will make the small settings window unreadable, so layout discipline matters.
- Launch-at-login and menu bar presentation preferences may need platform-specific seams; proposal should allow staged implementation if one item turns out to be more expensive than the rest.
- Export diagnostics must stay sanitized and must never include tokens or raw auth secrets.

## Migration Plan

1. Add the new settings-control-center specification and task list.
2. Introduce a typed settings store plus maintenance-action seams.
3. Replace the current settings UI with grouped sections and instant persistence.
4. Validate through tests and packaged app build.
