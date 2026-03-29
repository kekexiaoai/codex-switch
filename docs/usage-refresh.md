# Usage Refresh Logic

This document explains how Codex Switch refreshes usage data today, which source is used in each mode, and which diagnostics log entries are expected during troubleshooting.

## User-Facing Settings

Codex Switch currently exposes two usage source modes in Settings:

- `Automatic`
- `Local Only`

There is also a global switch:

- `Enable Usage Refresh`

### `Enable Usage Refresh`

- When disabled, the app does not execute usage refresh work.
- The UI reports `Usage refresh disabled`.
- Cached numbers may still be shown if a view reads previously persisted data, but no fresh API or local session scan is attempted.

### `Automatic`

- First tries the ChatGPT web backend endpoint: `https://chatgpt.com/backend-api/wham/usage`
- Uses `tokens.access_token` from `~/.codex/auth.json`
- Sends `ChatGPT-Account-Id` when `tokens.account_id` is present
- If the remote request fails or cannot run, falls back to local usage discovery
- Local fallback scans the machine's current local-date directory:
  - `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`
- If no valid local snapshot is found, falls back to `~/.codex/accounts/usage-cache.json`

### `Local Only`

- Skips the remote API completely
- Reads only:
  - local current-date rollout logs under `~/.codex/sessions/YYYY/MM/DD/`
  - cached snapshots in `~/.codex/accounts/usage-cache.json`

## When Refresh Actually Happens

There is no background polling worker or fixed refresh interval in the current product.

Usage refresh is currently trigger-based, not timer-based.

The main trigger points are:

- opening the menu bar panel
- opening the Status page
- switching the active account
- finishing account import or browser login flows when the UI refreshes afterwards
- explicit internal calls to `usageService.refreshUsage()` or `usageService.usageSnapshot(for:)`

So if someone asks "does refresh usage refresh?", the answer is:

- yes, when that code path is invoked
- no, it is not currently running on a periodic timer such as every 30s or every 60s

## Current Refresh Flow

### Menu/status refresh path

1. UI calls `MenuBarViewModel.refresh()`
2. `EnvironmentMenuBarService.loadSnapshot()` runs
3. `LiveUsageService.refreshUsage()` triggers a fresh usage resolution attempt
4. The active account summary reads `usageSnapshot(for:)`
5. The latest normalized snapshot is rendered into the menu bar or status view

### Resolver path

The source decision is owned by `CodexUsageResolver`.

For `Automatic`:

1. log usage refresh start
2. try remote API
3. on success:
   - save snapshot into cache
   - return API result
4. on failure:
   - log the failure category
   - fall back to local scanner
5. local scanner tries rollout logs first, then cache

For `Local Only`:

1. log usage refresh start
2. skip remote API
3. try rollout logs first
4. if unavailable, use cache

## Diagnostics Logging

Usage refresh diagnostics are written into the diagnostics folder:

- `~/.codex/codex-switch/browser-login.log`
- `~/.codex/codex-switch/usage-refresh.log`

Browser login and usage refresh now use separate log files under the same diagnostics folder.

### Expected usage refresh log events

- `usage_refresh_started mode=<automatic|localOnly> account=<account-id>`
- `usage_refresh_api_started account=<account-id>`
- `usage_refresh_api_succeeded account=<account-id>`
- `usage_refresh_api_failed account=<account-id> reason=<reason>`
- `usage_refresh_api_skipped account=<account-id> reason=missing_access_token`
- `usage_refresh_local_succeeded mode=<automatic|localOnly> account=<account-id> source=<rollout_logs|cache>`

### Notes

- The logger must never write secrets such as `access_token`, `refresh_token`, `id_token`, or raw bearer headers.
- `account=<account-id>` is allowed because the project already logs normalized account identifiers elsewhere and they are useful for troubleshooting account selection and fallback behavior.
- The Status page diagnostics section now represents general diagnostics activity, not only browser login events.

## Source Code Pointers

- `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- `apps/mac-client/CodexSwitch/MenuBar/MenuBarService.swift`
- `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageResolver.swift`
- `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageScanner.swift`
- `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageAPIClient.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshotLoader.swift`
