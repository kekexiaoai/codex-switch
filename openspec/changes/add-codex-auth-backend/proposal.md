# Change: add local Codex auth backend

## Why

The current application flow still uses demo-style local account creation. The product now needs a real backend model aligned with Codex itself: active auth in `~/.codex/auth.json`, archived accounts in `~/.codex/accounts/`, and usage derived from `~/.codex/sessions/`.

## What Changes

- Add a local Codex auth backend model based on real auth file import, archival, switching, and usage scanning
- Define browser login import by reusing `codex login` rather than reimplementing OAuth
- Replace the current conceptual Add Account model with real auth import sources
- Replace the current metadata-plus-secret persistence split with auth-file-backed account archival and derived metadata snapshots

## Impact

- Affected specs: `local-auth-backend`
- Affected code: account import flow, switching layer, usage scanning layer, menu bar integration, app environment wiring, existing account repository/storage abstractions
