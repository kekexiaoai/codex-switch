# Codex Auth Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the demo account backend in the macOS client with a real local Codex auth backend based on `~/.codex/auth.json`, archived account files, and session log scanning.

**Architecture:** Keep the existing SwiftUI/menu bar presentation layers in place, but replace the fixture/demo persistence and switching internals with Codex-backed adapters. The implementation should introduce a small set of filesystem, auth parsing, import, switching, usage, and login-coordination services that can be tested independently and then wired into `AppEnvironment`, `MenuBarViewModel`, and `EnvironmentMenuBarService`.

**Tech Stack:** Swift 5.7, Foundation, Swift Concurrency, XCTest, Swift Package Manager, macOS file/process APIs

### Task 1: Codex runtime paths and account model

**Files:**
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexPaths.swift`
- Modify: `apps/mac-client/CodexSwitch/Accounts/Account.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexPathsTests.swift`

**Steps:**
1. Write a failing test for default Codex paths and the expanded account model fields.
2. Run `swift test --filter CodexPathsTests` and verify the failure is for missing code.
3. Implement `CodexPaths` plus the new account fields required by the change.
4. Re-run `swift test --filter CodexPathsTests` and confirm it passes.

### Task 2: Auth parsing helpers

**Files:**
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthModels.swift`
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexJWTDecoder.swift`
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexArchiveNaming.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexAuthParsingTests.swift`

**Steps:**
1. Write failing tests for decoding `tokens.id_token`, masking email, selecting stable account id, and generating archive filenames.
2. Run `swift test --filter CodexAuthParsingTests` and verify red.
3. Implement the smallest parsing helpers needed to satisfy those tests.
4. Re-run `swift test --filter CodexAuthParsingTests` and confirm green.

### Task 3: Unified auth import pipeline

**Files:**
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthImporter.swift`
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthFileStore.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexAuthImporterTests.swift`

**Steps:**
1. Write failing tests for importing current auth, importing backup auth, and rejecting invalid auth.
2. Run `swift test --filter CodexAuthImporterTests` and verify red.
3. Implement archive write behavior, metadata derivation, and error categorization.
4. Re-run `swift test --filter CodexAuthImporterTests` and confirm green.

### Task 4: Archive-backed repository and switching

**Files:**
- Modify: `apps/mac-client/CodexSwitch/Accounts/AccountRepository.swift`
- Create: `apps/mac-client/CodexSwitch/Switching/CodexAccountSwitcher.swift`
- Modify: `apps/mac-client/CodexSwitch/Switching/SwitchCommandRunner.swift`
- Test: `apps/mac-client/CodexSwitchTests/Accounts/AccountRepositoryTests.swift`
- Test: `apps/mac-client/CodexSwitchTests/Switching/ActiveAccountControllerTests.swift`

**Steps:**
1. Write failing tests for loading archive-derived accounts and atomically switching active auth.
2. Run focused `swift test` filters and verify red.
3. Implement the repository and switcher changes with minimal API churn for the UI layer.
4. Re-run the same focused tests and confirm green.

### Task 5: Usage scanning and login coordination

**Files:**
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageScanner.swift`
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexLoginCoordinator.swift`
- Modify: `apps/mac-client/CodexSwitch/Switching/UsageRefreshService.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageScannerTests.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexLoginCoordinatorTests.swift`

**Steps:**
1. Write failing tests for parsing rollout logs, caching last-known usage, and handling successful or cancelled `codex login`.
2. Run the focused `swift test` filters and verify red.
3. Implement the scanner and coordinator with filesystem/process injection seams.
4. Re-run the tests and confirm green.

### Task 6: Wire the live app and remove demo add-account flows

**Files:**
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarService.swift`
- Modify: `apps/mac-client/CodexSwitchTests/Integration/RealIntegrationSmokeTests.swift`
- Modify: `openspec/changes/add-codex-auth-backend/tasks.md`

**Steps:**
1. Write failing integration tests for the live environment using Codex-backed services instead of fixture/demo account creation.
2. Run `swift test --filter RealIntegrationSmokeTests` and verify red.
3. Wire the new services into the live environment and swap manual add-account behavior to import-driven actions.
4. Re-run focused integration tests, then run the full `swift test` suite and confirm green.
5. Update the OpenSpec task checklist to reflect the implementation that actually landed.
