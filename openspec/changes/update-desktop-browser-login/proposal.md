# Change: update desktop browser login flow

## Why

The current browser-login path is still shaped around terminal tooling. Even when it works, it exposes Terminal or a hidden CLI subprocess to the user, which is not appropriate for a desktop menu bar app.

The macOS client should own the browser login experience itself: launch the browser from the app, monitor completion inside the app, and import the resulting Codex auth state without requiring the user to interact with Terminal or a TUI command loop.

## What Changes

- Replace the current terminal-driven browser login orchestration with a desktop-owned browser login flow
- Remove the product requirement that browser authentication must be implemented by invoking `codex login`
- Define an app-managed login broker that opens the browser, waits for completion, and imports the resulting auth profile into the existing archive pipeline
- Allow device-auth or equivalent non-terminal fallback only if it is presented inside the desktop app rather than through Terminal
- Update user-facing login failure handling so the app reports browser-login progress and failure in desktop-native terms

## Impact

- Affected specs: `local-auth-backend`
- Affected code: browser login coordinator, menu bar add-account flow, auth import orchestration, desktop app lifecycle/browser callback handling, login-related alerts and diagnostics
