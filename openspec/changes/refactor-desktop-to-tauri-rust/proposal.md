# Change: Refactor Codex Switch Desktop to Rust + Tauri

## Why

The current desktop application is implemented as a Swift/AppKit/SwiftUI macOS client. That implementation has grown to cover account management, browser login, usage refresh, provider sync, diagnostics, and settings, but it is tightly bound to Apple-specific UI hosting and makes future cross-platform delivery expensive. The repository already has an early `rust-client` placeholder, and the product direction now requires a Rust + Tauri desktop runtime with a React/shadcn front-end that preserves `.codex` compatibility while presenting a desktop-native, de-webbed interface.

## What Changes

- Replace the Swift desktop runtime with a Rust + Tauri runtime under `apps/rust-client`
- Add a React + TypeScript + shadcn/ui front-end tuned for desktop software aesthetics rather than web SaaS patterns
- Keep `.codex` auth, archive, usage, provider, and diagnostics compatibility intact
- Introduce Tauri commands/events as the single app boundary between UI and business logic
- Move desktop UI preferences to an app config directory while preserving Codex-owned data in `~/.codex`
- Keep the existing Swift implementation as a migration baseline until the Tauri app reaches feature parity

## Impact

- Affected specs:
  - new `desktop-runtime`
  - new `desktop-ui`
  - new `codex-data-compatibility`
- Affected code:
  - `apps/rust-client/**`
  - `docs/analysis/**`
  - `docs/plan/**`
  - `docs/progress/**`
