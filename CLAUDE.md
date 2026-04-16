<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.
<!-- OPENSPEC:END -->

# Project Overview

Codex Switch is a native macOS menu bar client for managing multiple Codex-style accounts, usage snapshots, and one-click switching.

## Build & Test Commands

```bash
# Run all tests
xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS'

# Build the app
xcodebuild build -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitchApp -configuration Debug

# Package as double-clickable app bundle (outputs to dist/Codex Switch.app)
./scripts/package-macos-app.sh

# Run a single test file (example)
xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/CodexUsageScannerTests
```

## Tech Stack

- Swift 5.7+, SwiftUI + AppKit
- macOS 12+ compatibility (uses NSStatusItem + NSPopover; MenuBarExtra available for macOS 13+)
- Xcode 14+
- Keychain + Application Support for local persistence

## Architecture

```
apps/mac-client/
├── CodexSwitch/               # Main library target (CodexSwitchKit)
│   ├── App/                   # App entry, environment, menu bar hosting
│   ├── Accounts/              # Account models and persistence
│   ├── CodexAuth/             # Auth backend: file store, usage scanner, login broker
│   ├── Diagnostics/           # Logging and diagnostics
│   ├── MenuBar/               # Menu bar UI: panel, rows, status display
│   ├── Settings/              # Preferences and settings UI
│   ├── Switching/             # Account switch orchestration
│   └── Resources/             # Assets and resources
├── CodexSwitchApp/            # Executable target
└── CodexSwitchTests/          # Unit and integration tests
```

Key modules:
- **CodexAuth**: Handles authentication, usage scanning, and login coordination. Reads Codex session files and resolves usage data.
- **DesktopCodexLoginBroker**: Orchestrates browser-based login flow for desktop clients.
- **CodexUsageScanner**: Scans and parses usage data from Codex sources.
- **AppEnvironment**: Central dependency container for the app.

## OpenSpec Workflow

This project uses OpenSpec for spec-driven development. See `openspec/AGENTS.md` for full details.

Quick reference:
- `openspec list` — List active changes
- `openspec list --specs` — List existing capabilities
- `openspec show <item>` — View change or spec details
- `openspec validate <change> --strict` — Validate a proposal
- `openspec archive <change-id> --yes` — Archive after deployment

**Create proposals** for: new features, breaking changes, architecture changes, performance/security work.
**Skip proposals** for: bug fixes, typos, comments, non-breaking dependency updates.

## Key Conventions

- **Local-first**: Keychain for credentials, Application Support for data files
- **macOS 12 compatibility**: Use `NSStatusItem + NSPopover` as primary; `MenuBarExtra` behind `@available` check for macOS 13+
- **Proposal before code**: For non-trivial changes, create an OpenSpec proposal first
