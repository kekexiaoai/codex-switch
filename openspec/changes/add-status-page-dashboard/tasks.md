## 1. Specification
- [ ] 1.1 Add a `status-page` delta describing the hybrid operational and diagnostics dashboard
- [ ] 1.2 Validate the change with `openspec validate add-status-page-dashboard --strict`

## 2. Status Data Model
- [ ] 2.1 Define a status snapshot model that aggregates active account, archived account count, usage summaries, runtime information, and Codex paths
- [ ] 2.2 Add a diagnostics reader that summarizes recent browser-login log lines without exposing raw secrets
- [ ] 2.3 Provide stable empty-state behavior when no active account, no archived accounts, or no diagnostics log exists

## 3. Desktop UI
- [ ] 3.1 Replace the placeholder status window content with a hybrid dashboard layout
- [ ] 3.2 Show operational sections for active account, tier, usage, and account inventory
- [ ] 3.3 Show diagnostics sections for runtime host, runtime mode, auth/log file locations, and latest login activity
- [ ] 3.4 Reuse a single status window instance and refresh the snapshot every time the user opens the page

## 4. Verification
- [ ] 4.1 Add focused tests for status snapshot loading and diagnostics parsing
- [ ] 4.2 Add or update action/window tests for opening and refreshing the status page
- [ ] 4.3 Run `cd apps/mac-client && swift test`
- [ ] 4.4 Run `./scripts/package-macos-app.sh`
