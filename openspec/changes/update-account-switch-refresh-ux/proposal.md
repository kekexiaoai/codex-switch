# Change: improve account switch responsiveness and compact usage timestamp display

## Why
Account switching currently blocks on usage refresh work. In `Automatic` mode this can wait on the remote usage API and makes switching feel laggy. The menu bar header also shows a long `Updated ... (Local Only)` string that is truncated in the available width.

## What Changes
- Make account switching complete immediately after auth replacement succeeds, without waiting for usage refresh to finish.
- Move post-switch usage refresh into a background follow-up update so usage values still refresh after switching.
- Compact the menu bar header timestamp into a shorter local-time display that omits the timezone and still communicates source mode.
- Make the account rows read more clearly as interactive switch targets instead of looking like static usage summaries.
- Preserve fuller source diagnostics in the Status page instead of overloading the menu bar header line.

## Impact
- Affected specs: `desktop-account-management`
- Affected code:
  - `apps/mac-client/CodexSwitch/Switching/*`
  - `apps/mac-client/CodexSwitch/MenuBar/*`
  - `apps/mac-client/CodexSwitch/App/*`
