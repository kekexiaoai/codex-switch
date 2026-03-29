# Settings Control Center Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand the macOS client settings window from a single email toggle into a grouped control center for general preferences, privacy/maintenance actions, usage configuration, and advanced diagnostics utilities.

**Architecture:** Introduce a typed settings store backed by `UserDefaults`, add explicit action handlers for destructive maintenance and advanced utilities, and keep the settings UI instant-apply. Reuse existing Codex paths, diagnostics logging, and usage-policy seams rather than creating separate preference systems.

**Tech Stack:** Swift 5.7, SwiftUI, AppKit, Foundation, UserDefaults, XCTest, Swift Package Manager

### Task 1: Typed settings store and usage preferences

**Files:**
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsViewModel.swift`
- Test: `apps/mac-client/CodexSwitchTests/Settings/SettingsViewModelTests.swift`

**Steps:**
1. Write failing tests for `Enable Usage Refresh`, `Usage Source Mode`, and any new persisted general/privacy preferences.
2. Run `cd apps/mac-client && swift test --filter SettingsViewModelTests` and verify red.
3. Implement the minimal typed settings persistence needed to satisfy those tests.
4. Re-run `cd apps/mac-client && swift test --filter SettingsViewModelTests` and confirm green.
5. Commit.

### Task 2: Maintenance and advanced action routing

**Files:**
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsViewModel.swift`
- Create: `apps/mac-client/CodexSwitch/Settings/SettingsActions.swift`
- Test: `apps/mac-client/CodexSwitchTests/Settings/SettingsViewModelTests.swift`

**Steps:**
1. Write failing tests for confirmation-backed destructive actions and advanced utility action dispatch.
2. Run the focused `swift test` filter and verify red.
3. Implement the smallest action-routing layer that satisfies those tests.
4. Re-run the focused tests and confirm green.
5. Commit.

### Task 3: Grouped settings UI

**Files:**
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`
- Create: `apps/mac-client/CodexSwitchTests/Settings/SettingsViewTests.swift`

**Steps:**
1. Write a failing UI test for grouped sections and visible controls.
2. Run `cd apps/mac-client && swift test --filter SettingsViewTests` and verify red.
3. Implement the grouped settings layout with instant-apply bindings and action affordances.
4. Re-run `cd apps/mac-client && swift test --filter SettingsViewTests` and confirm green.
5. Commit.

### Task 4: App wiring and verification

**Files:**
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Modify: `apps/mac-client/CodexSwitchApp/App/CodexSwitchApp.swift`
- Modify: `openspec/changes/add-settings-control-center/tasks.md`

**Steps:**
1. Write a failing test for live settings wiring if a new environment seam is required.
2. Run the focused test filter and verify red.
3. Wire the new settings store and action handlers into the app.
4. Re-run focused tests, then run `cd apps/mac-client && swift test`.
5. Run `./scripts/package-macos-app.sh`.
6. Update the OpenSpec task checklist to reflect completed work.
7. Commit.
