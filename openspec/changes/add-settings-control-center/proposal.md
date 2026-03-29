# Change: add settings control center

## Why

The current Settings page is only a single toggle for email visibility. That is not enough for a menu bar utility that now owns account imports, browser login diagnostics, status-page visibility, and emerging usage-source configuration.

The macOS client needs a real settings control center where users can manage general app behavior, privacy/data handling, usage refresh policy, and advanced diagnostics actions without leaving the desktop app.

## What Changes

- Expand the Settings window into grouped sections: `General`, `Privacy`, `Usage`, and `Advanced`
- Keep settings instant-apply with no separate `Save` button
- Add `Enable Usage Refresh` and `Usage Source Mode` (`Automatic`, `Local Only`) controls, aligned with the usage-source design
- Add privacy and maintenance actions for clearing logs, clearing usage/cache data, and removing archived account data with explicit confirmation for destructive actions
- Add advanced utility actions for opening `~/.codex`, opening the diagnostics log, and exporting a diagnostics summary
- Add general behavior controls such as launch-at-login and menu bar presentation preferences

## Impact

- Affected specs: `settings-control-center`
- Affected code: `SettingsView`, `SettingsViewModel`, settings persistence helpers, app preferences wiring, diagnostics/actions layer, usage-mode settings persistence, menu bar presentation settings
