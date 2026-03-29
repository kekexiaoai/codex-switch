# Codex Switch

Standalone macOS menu bar client for managing multiple Codex-style accounts, usage snapshots, and one-click switching.

## Current Status

This repository is initialized with a planning-first scaffold. The first implementation milestone is a native macOS menu bar client with mock data, local persistence, and a clean path to wire up real account switching later.

## Product Direction

- Native macOS app built with SwiftUI plus an AppKit menu bar host
- Menu bar first experience, no traditional main window required for v1
- Local account storage using Keychain plus Application Support
- Usage refresh and active-account switching implemented by our own client logic
- `codex-auth` is reference material only, not a runtime dependency
- macOS 12 compatibility first via `NSStatusItem + NSPopover`, with an optional `MenuBarExtra` implementation for macOS 13+

## Planned Repository Layout

- `apps/mac-client/`: macOS app project and source files
- `docs/plans/`: implementation plans and design notes
- `tests/`: shared testing notes and future cross-target helpers

## Near-Term Milestones

1. Generate the macOS app project and a working macOS 12-compatible menu bar shell.
2. Add mock account data, progress cards, and account-switch interactions.
3. Introduce persistence, refresh orchestration, and secure credential storage.
4. Replace mock data with real account/session integration.

## Tooling

- Xcode 14+
- Swift 5.7+
- macOS 12+ supported
- macOS 13+ may use `MenuBarExtra` behind a runtime availability check
