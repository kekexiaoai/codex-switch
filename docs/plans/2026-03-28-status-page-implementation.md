# Status Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the placeholder macOS status window with a hybrid dashboard that shows account, usage, runtime, and browser-login diagnostics in one read-only page.

**Architecture:** Add a dedicated status snapshot loader that reads from existing account, usage, and path services plus a small diagnostics-log reader. Keep the status page read-only, render it through SwiftUI, and make the AppKit status-window presenter reuse one window while refreshing the snapshot on open.

**Tech Stack:** Swift 5.7, SwiftUI, AppKit, Foundation, Swift Concurrency, XCTest, Swift Package Manager

### Task 1: Status snapshot read model

**Files:**
- Create: `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshot.swift`
- Create: `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshotLoader.swift`
- Test: `apps/mac-client/CodexSwitchTests/Diagnostics/StatusSnapshotLoaderTests.swift`

**Steps:**
1. Write a failing test for loading active account data, archived-account count, usage summaries, and fallback empty states into one status snapshot.
2. Run `cd apps/mac-client && swift test --filter StatusSnapshotLoaderTests` and verify the test fails for missing implementation.
3. Implement the minimal read model and loader needed to satisfy the test.
4. Re-run `cd apps/mac-client && swift test --filter StatusSnapshotLoaderTests` and confirm it passes.
5. Commit.

### Task 2: Diagnostics log summarizer

**Files:**
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexDiagnosticsLogger.swift`
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshotLoader.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexDiagnosticsLoggerTests.swift`
- Test: `apps/mac-client/CodexSwitchTests/Diagnostics/StatusSnapshotLoaderTests.swift`

**Steps:**
1. Write a failing test for reading recent browser-login diagnostics safely from the log file.
2. Run the focused `swift test` filters and verify red.
3. Implement a minimal reader/summarizer that surfaces recent safe lines without secrets.
4. Re-run the focused tests and confirm green.
5. Commit.

### Task 3: Hybrid status page UI

**Files:**
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusView.swift`
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusWindowView.swift`
- Test: `apps/mac-client/CodexSwitchTests/Diagnostics/StatusWindowViewTests.swift`

**Steps:**
1. Write a failing UI test for rendering the operational and diagnostics sections from a status snapshot.
2. Run `cd apps/mac-client && swift test --filter StatusWindowViewTests` and verify red.
3. Implement the smallest SwiftUI layout that satisfies the snapshot-driven tests.
4. Re-run `cd apps/mac-client && swift test --filter StatusWindowViewTests` and confirm green.
5. Commit.

### Task 4: App wiring and window reuse

**Files:**
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Modify: `apps/mac-client/CodexSwitchApp/App/AppDelegate.swift`
- Modify: `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarActionTests.swift`
- Modify: `apps/mac-client/CodexSwitchTests/MenuBar/StatusItemControllerTests.swift`
- Modify: `openspec/changes/add-status-page-dashboard/tasks.md`

**Steps:**
1. Write a failing test for refreshing the status snapshot when the status window is opened and for reusing the same window controller.
2. Run the focused `swift test` filters and verify red.
3. Wire the loader into the live environment and update the AppKit presenter to refresh and reuse the window.
4. Re-run the focused tests and confirm green.
5. Run `cd apps/mac-client && swift test` and confirm the full suite passes.
6. Run `./scripts/package-macos-app.sh` and confirm the app still packages successfully.
7. Update the OpenSpec task checklist to reflect completed work.
8. Commit.
