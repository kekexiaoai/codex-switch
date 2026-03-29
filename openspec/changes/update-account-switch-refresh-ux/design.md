## Context
The current switch flow updates `activeAccountID`, then synchronously calls `usageService.refresh(reason: .switchTriggered)`. In `Automatic` mode this can wait on the ChatGPT usage API before the menu updates. Separately, the menu header displays the full `Updated <timestamp> (Local Only)` text, which frequently truncates.

## Goals / Non-Goals
- Goals:
  - Make switching feel immediate regardless of usage source mode.
  - Keep post-switch usage data refreshing automatically.
  - Shorten the menu header status line so it fits without truncation.
- Non-Goals:
  - Removing usage refresh entirely.
  - Redesigning the Status page.
  - Adding periodic polling.

## Decisions
- Decision: switching will become optimistic from the user’s perspective.
  - The app will replace the active auth, update the selected account state, and return control immediately.
  - Usage refresh will start in the background after the switch succeeds.
- Decision: the menu header will show a compact local-time status string.
  - Recommended format: `<HH:mm> Auto`, `<HH:mm> Local`, `No usage`, or `Refresh off`.
  - The more detailed source and full updated timestamp remain available on the Status page.
- Decision: the full account row remains the switch target, and the visual treatment should make that obvious.
  - Preferred cues: hover/pressed feedback on the whole row, a trailing chevron or “Switch” affordance, and keeping the remove action visually separate.
- Decision: removing the active account remains allowed.
  - If another archived account exists, the app switches to that account immediately after removal.
  - If no archived account remains, the app clears the current auth and leaves the app with no active account.
  - The confirmation message must explicitly state this outcome before deletion.

## Risks / Trade-offs
- Background refresh means usage values may lag briefly behind the newly switched account.
  - Mitigation: refresh immediately in a detached follow-up task and update the UI when the refresh completes.
- Compact strings expose less detail in the menu itself.
  - Mitigation: keep the Status page as the detailed operational view.
- Making the entire row clickable can conflict visually with the remove action.
  - Mitigation: keep the destructive action in a clearly separated trailing control area.

## Open Questions
- None.
