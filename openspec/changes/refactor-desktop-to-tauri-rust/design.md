## Context

Codex Switch already implements the required product behavior in Swift, but the runtime is macOS-specific and the UI hosting model is not reusable across platforms. The replacement runtime must preserve the current `.codex` contract while consolidating product behavior behind a Rust core and a Tauri boundary. The visual design must avoid obvious web/SaaS patterns and instead feel like a compact desktop productivity tool.

## Goals / Non-Goals

- Goals:
  - Preserve feature parity with the current Swift desktop client
  - Preserve compatibility with existing `.codex` data files and directories
  - Establish a Rust + Tauri + React/shadcn architecture that can evolve cross-platform
  - Deliver a de-webbed desktop UI centered around a main window and a lightweight tray panel
- Non-Goals:
  - Shipping a standalone browser/web product
  - Deleting the Swift baseline in the first migration pass
  - Requiring terminal-driven login as the intended authentication path

## Decisions

### 1. Runtime split: Rust owns behavior, React owns presentation

- All `.codex` reads/writes, provider sync operations, login orchestration, diagnostics, and settings persistence live in Rust
- The UI layer only calls Tauri commands and subscribes to events

### 2. Compatibility first

- `~/.codex/auth.json`, `~/.codex/accounts/*.json`, usage caches, rollout logs, `config.toml`, SQLite provider metadata, and diagnostics logs remain source-of-truth formats
- App-specific UI preferences move to the Tauri app config directory

### 3. Main window first, tray second

- The main window is the primary place for account management, usage, provider sync, diagnostics, and settings
- The tray panel exposes current account status, quick switching, refresh, open-main-window, settings, and quit

### 4. UI is desktop software, not a web dashboard

- Use shadcn/ui as the component base, but restyle it into a lower-saturation, tighter-density, tool-like desktop UI
- Avoid top website navigation, hero sections, metric vanity cards, and long scrolling landing-page layouts

## Risks / Trade-offs

- Rebuilding login and provider sync in Rust introduces compatibility risk
  - Mitigation: port behavior through fixture-driven tests before wiring UI
- Tauri tray/platform behavior differs across OSes
  - Mitigation: keep the main window as the stable primary surface
- React/shadcn defaults can drift toward web aesthetics
  - Mitigation: establish desktop design tokens and shell primitives before feature pages

## Migration Plan

1. Land planning docs and OpenSpec
2. Build the Tauri/React/shadcn skeleton
3. Port Rust core services with tests first
4. Port advanced features: provider sync and desktop browser login
5. Build the desktop UI shell and pages
6. Validate behavior against Swift and update packaging/docs
