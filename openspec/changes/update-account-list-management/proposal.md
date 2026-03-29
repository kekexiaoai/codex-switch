# Change: improve account list readability and add per-account removal

## Why
The menu bar account list is currently visually dense, diagnostics logs only expose raw account IDs, and there is no way to remove a single invalid or unwanted archived account. These gaps make account operations harder to read, audit, and maintain.

## What Changes
- Add a human-readable account label to usage refresh diagnostics while keeping the stable account identifier.
- Update the account switcher list presentation so each account row reads as an individual item instead of a single merged block.
- Add a per-account remove action with confirmation for archived accounts in the menu bar UI.
- Define how removal behaves when the removed account is currently active so the app state stays coherent.

## Impact
- Affected specs: `desktop-account-management`
- Affected code:
  - `apps/mac-client/CodexSwitch/MenuBar/*`
  - `apps/mac-client/CodexSwitch/Accounts/*`
  - `apps/mac-client/CodexSwitch/CodexAuth/*`
  - `apps/mac-client/CodexSwitch/Switching/*`
