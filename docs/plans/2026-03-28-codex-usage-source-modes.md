# Codex Usage Source Modes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a production-ready usage retrieval layer for the macOS client that can report the current 5-hour and weekly remaining usage by preferring a remote ChatGPT-backed source when available, then falling back to local Codex rollout logs and finally cached snapshots.

**Architecture:** Keep the existing menu bar and status page view models intact, but replace the single-purpose `CodexUsageScanner` flow with a source-aware coordinator. The new usage coordinator should normalize remote API data, local rollout data, and cached snapshots into one shared snapshot model, persist the last successful result with source metadata, and expose both the configured policy and the active runtime mode so the UI can explain whether the app is running in API-backed or local-only semantics.

**Tech Stack:** Swift 5.7, Foundation, URLSession, Swift Concurrency, XCTest, macOS file/network APIs

## Context

The current app only supports one usage source:

- read the active account from `~/.codex/auth.json`
- scan `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` for the machine's current local date
- match entries by email
- cache the last successful snapshot in `~/.codex/accounts/usage-cache.json`

That design is enough for local-only environments, but it does not match the behavior described by the `Loongphy/codex-auth` reference project:

- remote usage mode backed by the ChatGPT web backend
- local fallback mode when remote usage is unavailable
- explicit reporting of the current mode after watcher/bootstrap work

For this product, the gap is not just data freshness. The missing piece is source semantics. Today the UI can only say "Updated ..." or "No usage data". It cannot say:

- whether usage came from a remote source or local logs
- whether the app had to fall back
- why the fallback happened
- whether the currently displayed numbers are fresh or cached

## Problem Statement

The app needs a unified way to answer the user-facing question:

"What is the current remaining 5-hour and weekly usage for the active account, and how trustworthy is that answer?"

The current implementation has four concrete shortcomings:

1. It only supports local rollout parsing.
2. It only stores `percentUsed`, not enough metadata to explain remaining counts or source fidelity.
3. It does not preserve the reason the app ended up in local mode or cache mode.
4. It has no operator-visible setting for "automatic" versus "local-only" behavior.

## Constraints

- `codex-auth` is reference material only, not a runtime dependency.
- The ChatGPT web backend endpoint used by `codex-auth` is not a documented OpenAI public API.
- Remote usage fetching must therefore be treated as experimental and failure-prone.
- Secrets from `auth.json` must never be logged.
- The app must remain useful when the machine is offline, when the remote endpoint changes, or when the account is using API-key mode instead of browser-auth mode.

## Goals

- Support a configurable usage policy:
  - `automatic`: prefer remote usage, then fall back to local logs, then cache
  - `localOnly`: skip remote usage and use local logs plus cache
- Expose the active runtime usage mode:
  - `api`
  - `local`
  - `cache`
  - `unavailable`
- Normalize all sources into a richer usage snapshot model.
- Preserve the current menu bar and status page architecture.
- Surface source and fallback information in diagnostics and status UI.
- Keep local log parsing as a first-class path rather than a debug-only escape hatch.
- Define the threshold and background-worker primitives needed for future auto-switch behavior.

## Non-Goals

- Reproduce the exact `codex-auth` CLI command surface in the first implementation.
- Depend on undocumented remote fields more than necessary.
- Guarantee remote usage mode for every account type.
- Display raw tokens, request headers, or raw remote payloads in diagnostics.

## Recommended Product Behavior

The safest product stance is:

- default configured policy: `automatic`
- default runtime preference: remote first, local fallback second
- visible diagnostics warning whenever remote mode is unavailable
- user-facing local-only escape hatch in Settings

This gives the app the same operator experience as `codex-auth` without making the undocumented remote endpoint mandatory.

## Coverage Against `codex-auth` Auto Mode

The `codex-auth` behavior you quoted contains three separate concerns:

1. usage source semantics
2. threshold-driven auto-switch decisions
3. a long-running managed watcher

This document originally covered only the first concern. The sections below extend the design so the same document can guide all three layers without forcing the app to copy the upstream CLI one-to-one.

## Proposed Data Model

The existing usage model should expand from "percent only" to "source-aware snapshot".

### 1. Configured policy

Create a policy enum:

```swift
public enum CodexUsagePolicy: String, Codable, Equatable {
    case automatic
    case localOnly
}
```

This is user intent, not the resolved runtime mode.

### 2. Resolved runtime mode

Create a runtime mode enum:

```swift
public enum CodexUsageMode: String, Codable, Equatable {
    case api
    case local
    case cache
    case unavailable
}
```

This is what the app actually used on the last refresh.

### 3. Richer usage window

Expand `CodexUsageWindow` so the app can express either percentages only or real count-based remaining values when available:

```swift
public struct CodexUsageWindow: Codable, Equatable {
    public let percentUsed: Int
    public let resetsAt: Date
    public let usedUnits: Int?
    public let limitUnits: Int?
    public let remainingUnits: Int?
}
```

Rules:

- API source should populate count fields when the payload contains them.
- Local source may leave count fields `nil` if rollout logs only expose percentages.
- UI should continue to render percentage bars even when counts are missing.

### 4. Source-aware snapshot

Expand `CodexUsageSnapshot`:

```swift
public struct CodexUsageSnapshot: Codable, Equatable {
    public let accountID: String
    public let updatedAt: Date
    public let resolvedAt: Date
    public let sourceMode: CodexUsageMode
    public let sourceDescription: String
    public let fiveHour: CodexUsageWindow
    public let weekly: CodexUsageWindow
}
```

Meaning:

- `updatedAt`: timestamp reported by the source payload
- `resolvedAt`: time our app produced the normalized snapshot
- `sourceMode`: `api`, `local`, or `cache`
- `sourceDescription`: short human-readable reason such as `"ChatGPT backend"`, `"rollout logs"`, or `"cached after remote 401"`

### 5. Usage status cache

Replace the bare dictionary cache with a state-bearing cache:

```swift
public struct CodexUsageState: Codable, Equatable {
    public let configuredPolicy: CodexUsagePolicy
    public let activeMode: CodexUsageMode
    public let activeAccountID: String?
    public let lastErrorCategory: String?
    public let lastErrorSummary: String?
    public let updatedAt: Date
}

public struct CodexUsageCache: Codable, Equatable {
    public var entries: [String: CodexUsageSnapshot]
    public var state: CodexUsageState?
}
```

This lets the menu bar and status page explain what happened even when no fresh snapshot exists.

## Proposed Source Architecture

### 1. `CodexUsageAPIClient`

Create a small remote adapter responsible for one thing: converting the active `auth.json` into a sanitized HTTP request and decoding the remote usage response.

Responsibilities:

- read `tokens.access_token`
- read optional `tokens.account_id`
- call `https://chatgpt.com/backend-api/wham/usage`
- send `Authorization: Bearer <access_token>`
- send `ChatGPT-Account-Id: <account_id>` when present
- apply short timeout and conservative retry behavior
- map remote payload into `CodexUsageSnapshot`

Error categories should be explicit:

- `remoteAuthUnavailable`
- `remoteUnauthorized`
- `remoteForbidden`
- `remoteUnsupported`
- `remoteRateLimited`
- `remoteServerError`
- `remoteNetworkError`
- `remotePayloadInvalid`

These categories are important because only some of them should automatically trigger local fallback. Recommended fallback behavior:

- fallback to local on: missing token, timeout, offline, 401, 403, 404, 429, invalid payload, 5xx
- do not retry aggressively inside the same refresh cycle

### 2. `CodexUsageScanner`

Keep the current scanner but make it more realistic and more tolerant.

Changes:

- continue reading newest `rollout-*.jsonl` first inside `~/.codex/sessions/YYYY/MM/DD/`
- support the current simplified test fixture shape
- add support for the nested `event_msg -> token_count -> rate_limits` style shape emitted by newer rollout logs
- match by normalized email first
- optionally match by account identifier if local logs expose one later
- return both the snapshot and a `sourceDescription` of `"rollout logs"`

### 3. `CodexUsageResolver`

Create a coordinator that owns source selection.

Suggested interface:

```swift
public struct CodexUsageRefreshResult: Equatable {
    public let snapshot: CodexUsageSnapshot?
    public let state: CodexUsageState
}

public protocol CodexUsageResolving {
    func refreshUsage(for account: Account, policy: CodexUsagePolicy) async throws -> CodexUsageRefreshResult
}
```

Resolution algorithm:

1. Build the active account from `auth.json`.
2. If policy is `automatic`, try remote API first.
3. If remote succeeds:
   - save snapshot to cache
   - save state with `activeMode = .api`
   - return
4. If remote fails:
   - record sanitized failure category
   - attempt local scan
5. If local succeeds:
   - save snapshot to cache
   - save state with `activeMode = .local`
   - include fallback reason in `sourceDescription`
   - return
6. If local fails but cache exists:
   - return cached snapshot
   - save state with `activeMode = .cache`
7. If all sources fail:
   - save state with `activeMode = .unavailable`
   - throw `CodexAuthError.noUsageData`

This is the core behavior the rest of the app should depend on.

## Auto-Switch Threshold Design

The app should treat threshold configuration as a separate concern from usage retrieval.

### Threshold model

Create a persisted threshold model:

```swift
public struct CodexAutoSwitchThresholds: Codable, Equatable {
    public let fiveHourRemainingPercent: Int
    public let weeklyRemainingPercent: Int

    public static let `default` = CodexAutoSwitchThresholds(
        fiveHourRemainingPercent: 10,
        weeklyRemainingPercent: 5
    )
}
```

This matches the `codex-auth` semantics you quoted:

- default 5h threshold: `10%` remaining
- default weekly threshold: `5%` remaining

The command examples:

- `codex-auth config auto --5h 12`
- `codex-auth config auto --5h 12 --weekly 8`
- `codex-auth config auto --weekly 8`

translate in this app to persisted settings changes, not necessarily a CLI. The app should still support the same meaning:

- override only 5h threshold
- override only weekly threshold
- override both independently

### Threshold evaluation rules

Threshold checks should evaluate on remaining percent, not used percent.

Normalized formulas:

```swift
let fiveHourRemaining = max(0, 100 - snapshot.fiveHour.percentUsed)
let weeklyRemaining = max(0, 100 - snapshot.weekly.percentUsed)
```

Trigger conditions:

- switch when `fiveHourRemaining < fiveHourRemainingPercent`
- switch when `weeklyRemaining < weeklyRemainingPercent`

Important detail:

- use strict `<`, not `<=`, to match the wording "drops below"

### Threshold decision output

Create a decision model:

```swift
public enum CodexAutoSwitchTrigger: Equatable {
    case none
    case fiveHourThreshold(currentRemaining: Int, threshold: Int)
    case weeklyThreshold(currentRemaining: Int, threshold: Int)
}
```

If both thresholds are crossed, prioritize the more urgent window:

1. 5-hour threshold
2. weekly threshold

This keeps behavior deterministic and easy to explain in logs.

## Auto-Switch Worker Design

The app needs an explicit background worker abstraction rather than scattering timers across view models.

### Worker responsibilities

- refresh usage for the active account on an interval
- evaluate thresholds against the resolved usage snapshot
- select the next eligible account when the active one is below threshold
- perform the account switch silently
- persist the latest worker status for UI/diagnostics
- publish the current usage mode immediately after auto mode is enabled

### Worker lifecycle

Recommended states:

```swift
public enum CodexAutoSwitchState: String, Codable, Equatable {
    case disabled
    case starting
    case running
    case degraded
    case stopped
}
```

Recommended status payload:

```swift
public struct CodexAutoSwitchStatus: Codable, Equatable {
    public let state: CodexAutoSwitchState
    public let configuredPolicy: CodexUsagePolicy
    public let activeUsageMode: CodexUsageMode
    public let thresholds: CodexAutoSwitchThresholds
    public let lastCheckedAt: Date?
    public let lastSwitchAt: Date?
    public let lastDecisionSummary: String?
}
```

This is the app equivalent of:

"config auto enable prints the current usage mode after installing the watcher"

because after enabling auto mode, the UI and diagnostics can immediately show:

- watcher state: `running`
- usage mode: `api` or `local`
- thresholds: `5h < 10%`, `weekly < 5%`

### Worker scheduling

Recommended default polling interval:

- every 60 seconds while running

Rationale:

- frequent enough to react before quota exhaustion
- infrequent enough to avoid unnecessary remote traffic

The interval should be configurable later, but not user-exposed in v1.

### Worker implementation shape

Introduce:

```swift
public protocol CodexAutoSwitchWorking: Sendable {
    func start() async
    func stop() async
    func status() async -> CodexAutoSwitchStatus
}
```

Back the live implementation with:

- a dedicated actor for worker state
- one long-lived `Task`
- cooperative cancellation

Avoid:

- multiple concurrent polling loops
- view-owned timers
- switch attempts from more than one subsystem

### Account selection for silent switch

When the active account falls below threshold:

1. load archived accounts
2. exclude the current active account
3. prefer accounts with a cached or fresh snapshot above both thresholds
4. if multiple candidates qualify, pick the one with the highest 5h remaining
5. if tied, pick the one with the highest weekly remaining
6. if still tied, pick the earliest imported account for deterministic behavior

If no eligible candidate exists:

- remain on the current account
- keep watcher running
- mark status as `degraded`
- surface `"No eligible replacement account"` in diagnostics

### Safety rules

- never switch accounts if the latest snapshot came from stale cache older than a configured freshness horizon
- never switch accounts repeatedly within a short cooldown window
- do not start a second switch while one is already in flight

Recommended initial defaults:

- cache freshness horizon for auto-switch decisions: 10 minutes
- post-switch cooldown: 2 minutes

These are stricter than display-only usage because silent switching should prefer freshness over convenience.

## Settings and UX Mapping for Auto Mode

The current app does not need to mimic `codex-auth config auto` as a terminal command, but it should expose the same controls in Settings.

Recommended Settings fields:

- `Enable automatic switching`
- `Usage source mode`
  - `Automatic (API + local fallback)`
  - `Local logs only`
- `5-hour minimum remaining %`
- `Weekly minimum remaining %`

Recommended immediate feedback after enabling:

- `"Auto-switch enabled"`
- `"Usage mode: API"` or `"Usage mode: Local fallback"`
- `"Thresholds: 5h < 10%, weekly < 5%"`

This is the UX equivalent of the CLI printing the current usage mode after `config auto enable`.

## Diagnostics Requirements for Auto Mode

Extend diagnostics so operators can answer:

- is the watcher running right now
- what usage mode is it using
- what thresholds are configured
- why did it switch
- why did it refuse to switch

Add these fields to the status snapshot model:

- auto-switch enabled flag
- watcher state
- active usage mode
- configured thresholds
- last auto decision summary
- last switch timestamp
- last degraded reason

These details should appear on the status page even when the menu bar stays compact.

## Auth Requirements for Remote Mode

Remote mode must not assume every `auth.json` is browser-auth capable.

The resolver should detect three cases:

1. Full browser-auth session
   - has `access_token`
   - may have `account_id`
   - remote mode allowed

2. Partial auth state
   - has `id_token` but no `access_token`
   - local mode only

3. API-key-driven environment
   - current auth file missing or unrelated to browser login
   - local mode only, or unavailable if no rollout data

This distinction matters because current app flows already support importing archived `auth.json` files that may not all contain the same token set.

## UI and Diagnostics Changes

The UI does not need a large redesign. It needs better explanation.

### Menu bar

Keep the two summary cards, but improve the status string:

- current: `"Updated 2026-03-28T09:00:00Z"`
- proposed: `"Updated 2026-03-28T09:00:00Z via API"`
- fallback example: `"Updated 2026-03-28T09:00:00Z via Local fallback"`

When `remainingUnits` is available, the subtitle can prefer:

- `"12 left, resets 2026-03-29T03:00:00Z"`

Otherwise continue showing reset time only.

### Status page

Extend diagnostics and snapshot fields to show:

- configured usage policy
- active usage mode
- last fallback/error summary
- source description for the active snapshot
- auto-switch enabled state
- configured thresholds
- watcher health and last decision summary

This should be visible in:

- `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshot.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshotLoader.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusView.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusWindowView.swift`

### Settings

Add a user toggle or picker for:

- `Automatic (API + local fallback)`
- `Local logs only`

Add auto-switch controls for:

- `Enable automatic switching`
- `5-hour minimum remaining %`
- `Weekly minimum remaining %`

Recommended persistence approach:

- use `UserDefaults`
- key: `usagePolicy`
- key: `autoSwitchEnabled`
- key: `autoSwitchThresholds`

The existing settings seam already stores email visibility there, so this stays consistent.

## Security and Compliance Notes

This design intentionally treats remote mode as experimental.

Rules:

- never log `Authorization` headers
- never log `access_token`, `refresh_token`, or `id_token`
- never persist raw remote responses
- only persist normalized usage state
- sanitize every remote error before writing diagnostics

The design should also include a visible product note in diagnostics or settings that remote mode depends on a non-public web backend and may stop working without notice.

## File-Level Implementation Shape

### New files

- `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageMode.swift`
- `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageAPIClient.swift`
- `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageResolver.swift`
- `apps/mac-client/CodexSwitch/Switching/CodexAutoSwitchWorker.swift`
- `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageAPIClientTests.swift`
- `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageResolverTests.swift`
- `apps/mac-client/CodexSwitchTests/Switching/CodexAutoSwitchWorkerTests.swift`

### Existing files to modify

- `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthModels.swift`
- `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthFileStore.swift`
- `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageScanner.swift`
- `apps/mac-client/CodexSwitch/Switching/UsageRefreshService.swift`
- `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- `apps/mac-client/CodexSwitch/MenuBar/MenuBarModels.swift`
- `apps/mac-client/CodexSwitch/MenuBar/MenuBarService.swift`
- `apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift`
- `apps/mac-client/CodexSwitch/Settings/SettingsViewModel.swift`
- `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshot.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshotLoader.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusView.swift`
- `apps/mac-client/CodexSwitch/Diagnostics/StatusWindowView.swift`
- `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageScannerTests.swift`
- `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarViewModelTests.swift`
- `apps/mac-client/CodexSwitchTests/Diagnostics/StatusSnapshotLoaderTests.swift`
- `apps/mac-client/CodexSwitchTests/Integration/RealIntegrationSmokeTests.swift`

## Testing Strategy

### Unit

- remote request building from `auth.json`
- remote payload decoding into normalized windows
- remote error category mapping
- rollout parsing for both simplified and nested event shapes
- cache/state read-write behavior

### Integration

- automatic mode prefers API when remote payload is valid
- automatic mode falls back to local when remote returns 401
- local-only mode never hits `URLSession`
- cache mode is used when remote and local both fail
- settings changes alter resolver policy on the next refresh
- auto-switch triggers when 5h remaining drops below threshold
- auto-switch triggers when weekly remaining drops below threshold
- auto-switch does not trigger when only stale cache is available
- enabling auto mode immediately publishes the current usage mode and thresholds

### UI integration

- menu bar `updatedText` includes `via API`, `via Local`, or `via Cache`
- status page exposes policy, mode, and fallback reason
- settings reflect persisted usage policy
- settings reflect persisted auto-switch thresholds and enabled state
- diagnostics expose watcher state and last switch decision

## Risks and Mitigations

### Risk: Remote payload drift

Mitigation:

- keep remote decoding in one adapter
- ignore unknown fields
- fail soft into local fallback

### Risk: Local logs vary across Codex versions

Mitigation:

- support multiple known shapes
- keep existing simplified fixture support so tests stay stable

### Risk: Users assume API mode is official or guaranteed

Mitigation:

- label it experimental in diagnostics/settings
- keep local-only escape hatch

### Risk: UI starts depending on count fields that local mode cannot provide

Mitigation:

- make count fields optional
- continue rendering percentage-based bars as the baseline

## Delivery Order

### Task 1: Usage mode models and persistence

**Files:**
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageMode.swift`
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthModels.swift`
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthFileStore.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageResolverTests.swift`

**Steps:**
1. Write failing tests for `CodexUsagePolicy`, `CodexUsageMode`, `CodexUsageState`, and cache persistence.
2. Run `swift test --filter CodexUsageResolverTests` and verify failure is due to missing usage mode types.
3. Implement the new usage mode and cache state models with minimal persistence helpers.
4. Re-run `swift test --filter CodexUsageResolverTests` and confirm the model/persistence assertions pass.

### Task 2: Remote usage client

**Files:**
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageAPIClient.swift`
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexAuthFileStore.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageAPIClientTests.swift`

**Steps:**
1. Write failing tests for request construction, header selection, timeout behavior, and remote error mapping.
2. Run `swift test --filter CodexUsageAPIClientTests` and verify red.
3. Implement a tiny URLSession-backed client that converts remote payloads into normalized `CodexUsageSnapshot` values.
4. Re-run `swift test --filter CodexUsageAPIClientTests` and confirm green.

### Task 3: Local scanner hardening and resolver coordination

**Files:**
- Create: `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageResolver.swift`
- Modify: `apps/mac-client/CodexSwitch/CodexAuth/CodexUsageScanner.swift`
- Modify: `apps/mac-client/CodexSwitch/Switching/UsageRefreshService.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageScannerTests.swift`
- Test: `apps/mac-client/CodexSwitchTests/CodexAuth/CodexUsageResolverTests.swift`

**Steps:**
1. Write failing tests for nested rollout parsing, automatic remote-to-local fallback, and cache fallback.
2. Run focused `swift test` filters and verify red.
3. Implement the resolver and update the scanner to parse both known rollout shapes.
4. Re-run the same focused tests and confirm green.

### Task 4: App wiring, settings, and menu bar status text

**Files:**
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarModels.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarService.swift`
- Modify: `apps/mac-client/CodexSwitch/MenuBar/MenuBarViewModel.swift`
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsViewModel.swift`
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`
- Test: `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarViewModelTests.swift`
- Test: `apps/mac-client/CodexSwitchTests/Integration/RealIntegrationSmokeTests.swift`

**Steps:**
1. Write failing tests for persisted usage policy, updated menu bar status text, active account summary refresh, and immediate mode reporting after enabling auto-switch.
2. Run the focused tests and verify red.
3. Wire the live environment to use the resolver-backed refresh path and settings-backed policy selection.
4. Re-run the focused tests and confirm green.

### Task 5: Auto-switch worker and threshold decisions

**Files:**
- Create: `apps/mac-client/CodexSwitch/Switching/CodexAutoSwitchWorker.swift`
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsViewModel.swift`
- Modify: `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`
- Test: `apps/mac-client/CodexSwitchTests/Switching/CodexAutoSwitchWorkerTests.swift`

**Steps:**
1. Write failing tests for threshold evaluation, candidate selection, cooldown handling, and immediate status reporting after enable.
2. Run `swift test --filter CodexAutoSwitchWorkerTests` and verify red.
3. Implement a single-task background worker with threshold-driven switch decisions.
4. Re-run `swift test --filter CodexAutoSwitchWorkerTests` and confirm green.

### Task 6: Diagnostics and status surfaces

**Files:**
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshot.swift`
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusSnapshotLoader.swift`
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusView.swift`
- Modify: `apps/mac-client/CodexSwitch/Diagnostics/StatusWindowView.swift`
- Test: `apps/mac-client/CodexSwitchTests/Diagnostics/StatusSnapshotLoaderTests.swift`

**Steps:**
1. Write failing tests for policy/mode/fallback summaries in diagnostics.
2. Run `swift test --filter StatusSnapshotLoaderTests` and verify red.
3. Implement the new snapshot fields and render the usage mode information in the diagnostics views.
4. Re-run `swift test --filter StatusSnapshotLoaderTests` and confirm green.

### Task 7: End-to-end verification

**Files:**
- Modify: `openspec/changes/add-codex-auth-backend/design.md`
- Modify: `openspec/changes/add-codex-auth-backend/tasks.md`

**Steps:**
1. Update the existing backend change documents so they reflect the new multi-source usage architecture instead of local-only scanning.
2. Run `swift test`.
3. Run any focused smoke scenario that exercises API success, local fallback, and cached fallback.
4. Update the OpenSpec checklist only after the implementation and tests actually land.

## Recommended Acceptance Criteria

- With a browser-auth `auth.json` and a valid remote response, the app shows `via API`.
- With a browser-auth `auth.json` and a failing remote response but valid rollout logs, the app shows `via Local fallback`.
- With no fresh local data but a cached snapshot, the app shows `via Cache`.
- With no usable source, the app shows `No usage data` and diagnostics explain why.
- Switching the Settings policy to local-only prevents any remote request on the next refresh.
- Enabling auto-switch immediately shows the current usage mode and configured thresholds.
- The worker silently switches accounts when 5h remaining is below threshold.
- The worker silently switches accounts when weekly remaining is below threshold.
- If no eligible replacement exists, the worker stays running and reports a degraded reason instead of thrashing accounts.

Plan complete and saved to `docs/plans/2026-03-28-codex-usage-source-modes.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
