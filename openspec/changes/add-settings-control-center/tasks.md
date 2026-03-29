## 1. Specification
- [x] 1.1 Add a `settings-control-center` delta covering grouped settings sections, instant persistence, usage controls, and maintenance actions
- [x] 1.2 Validate the change with `openspec validate add-settings-control-center --strict`

## 2. Settings Model
- [x] 2.1 Introduce a typed settings store for general, privacy, usage, and advanced preferences
- [x] 2.2 Add persistence for `Enable Usage Refresh` and `Usage Source Mode` using `UserDefaults`
- [x] 2.3 Define confirmation and result messaging for destructive maintenance actions

## 3. Desktop UI
- [x] 3.1 Replace the single-toggle Settings page with grouped sections
- [x] 3.2 Add general controls such as launch-at-login and menu bar presentation preferences
- [x] 3.3 Add privacy and maintenance controls such as email visibility, clear logs, clear cache, and remove archived accounts
- [x] 3.4 Add usage controls for enabling refresh and choosing source mode
- [x] 3.5 Add advanced actions for opening the Codex directory, opening the diagnostics log, and exporting a diagnostics summary

## 4. Verification
- [x] 4.1 Add focused tests for settings persistence and maintenance action routing
- [x] 4.2 Add or update settings UI tests for grouped controls and instant persistence
- [x] 4.3 Run `cd apps/mac-client && swift test`
- [x] 4.4 Run `./scripts/package-macos-app.sh`
