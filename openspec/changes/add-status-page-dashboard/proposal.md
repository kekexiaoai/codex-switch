# Change: add hybrid status page dashboard

## Why

The current `Status Page` entry only opens a thin placeholder window. It does not help users or testers understand the app's real operating state during account import, browser login, switching, or release validation.

The macOS client needs a desktop-native status page that combines account state, usage state, and local diagnostics in one place so support and release testing can quickly verify what the app is doing.

## What Changes

- Add a hybrid status page window that combines operational account data with local diagnostics
- Show active-account identity, tier, archived-account count, usage summaries, and last refresh information
- Show runtime host, runtime mode, important Codex file paths, and recent browser-login diagnostics without exposing secrets
- Define empty-state and unavailable-data behavior so the page stays useful before any account is imported
- Refresh the status snapshot when the page is opened and reuse a single desktop status window instead of spawning duplicates

## Impact

- Affected specs: `status-page`
- Affected code: `StatusWindowView`, `StatusView`, app environment wiring, status-window presentation, account/usage aggregation, diagnostics log reading
