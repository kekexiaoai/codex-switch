# Change: Add Provider Sync Feature

## Why
When users switch `model_provider` in Codex, historical sessions disappear because provider metadata exists in two separate layers — rollout JSONL files and the SQLite database. The codex-provider-sync project (Node.js/C#) solves this but requires external tooling. Integrating this functionality as a native Swift GUI window in Codex Switch provides a seamless, zero-dependency experience for macOS users.

## What Changes
- Add a new "Provider Sync" window accessible from the menu bar panel
- Implement Swift-native config.toml parsing for `model_provider` and `[model_providers.*]` sections
- Implement Swift-native rollout JSONL file scanning and rewriting (first-line `session_meta` with `payload.model_provider`)
- Implement Swift-native SQLite operations on `state_5.sqlite` (`threads.model_provider` column)
- Provide status view showing current provider, configured providers, and session distribution across both layers
- Provide sync action to unify all sessions under a target provider (with atomic backup/rollback)
- Provide switch action to change `config.toml` provider and sync in one step
- Provide backup listing, restore, and prune functionality
- Follow existing SettingsView/SettingsWindowPresenter patterns

## Impact
- Affected specs: new `provider-sync` capability
- Affected code:
  - `CodexSwitch/ProviderSync/` (new directory, ~10 new files)
  - `CodexSwitch/MenuBar/MenuBarActions.swift` (new action case)
  - `CodexSwitch/MenuBar/MenuBarPanelView.swift` (new action row)
  - `CodexSwitch/MenuBar/MenuBarViewModel.swift` (new method)
  - `CodexSwitch/App/AppEnvironment.swift` (new presenter/factory)
  - `CodexSwitch/CodexAuth/CodexPaths.swift` (new path properties)
