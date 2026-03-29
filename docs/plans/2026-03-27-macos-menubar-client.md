# macOS Menu Bar Client Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a standalone macOS menu bar client that manages multiple accounts, displays usage snapshots, and supports fast account switching without depending on the `codex-auth` project.

**Architecture:** The app will be a native SwiftUI `MenuBarExtra` application with a small domain layer for accounts and usage, a local persistence layer backed by Keychain plus Application Support, and a refresh/switch engine that isolates side effects from the UI. We will implement the first usable version with mock-backed flows first, then swap in the real integration layer behind protocols so the UI and tests stay stable.

**Tech Stack:** SwiftUI, AppKit interop where needed, Swift Concurrency, XCTest, Keychain Services, UserDefaults/Application Support, Xcode project

### Task 1: Repository and App Project Bootstrap

**Files:**
- Create: `apps/mac-client/CodexSwitch.xcodeproj`
- Create: `apps/mac-client/CodexSwitch/App/CodexSwitchApp.swift`
- Create: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Create: `apps/mac-client/CodexSwitchTests/CodexSwitchTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import CodexSwitch

final class CodexSwitchTests: XCTestCase {
    func testAppEnvironmentStartsWithMockServices() {
        let environment = AppEnvironment.preview
        XCTAssertNotNil(environment.accountStore)
        XCTAssertNotNil(environment.usageService)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS'`
Expected: FAIL because the project and app environment do not exist yet.

**Step 3: Write minimal implementation**

```swift
struct AppEnvironment {
    let accountStore: MockAccountStore
    let usageService: MockUsageService

    static let preview = AppEnvironment(
        accountStore: MockAccountStore(),
        usageService: MockUsageService()
    )
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS'`
Expected: PASS for the bootstrap test.

**Step 5: Commit**

```bash
git add apps/mac-client
git commit -m "chore: bootstrap macOS menu bar app project"
```

### Task 2: Menu Bar Shell and Mock UI

**Files:**
- Create: `apps/mac-client/CodexSwitch/MenuBar/MenuBarScene.swift`
- Create: `apps/mac-client/CodexSwitch/MenuBar/MenuBarPanelView.swift`
- Create: `apps/mac-client/CodexSwitch/MenuBar/UsageSummaryCard.swift`
- Create: `apps/mac-client/CodexSwitch/MenuBar/AccountRowView.swift`
- Test: `apps/mac-client/CodexSwitchTests/MenuBar/MenuBarViewModelTests.swift`

**Step 1: Write the failing test**

```swift
func testMenuBarViewModelFormatsCurrentAccountSummary() async {
    let viewModel = MenuBarViewModel.preview
    await viewModel.refresh()
    XCTAssertEqual(viewModel.headerEmail, "a••••@gmail.com")
    XCTAssertEqual(viewModel.accountRows.count, 5)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MenuBarViewModelTests`
Expected: FAIL because the view model and menu bar scene are not implemented.

**Step 3: Write minimal implementation**

```swift
@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var headerEmail = ""
    @Published private(set) var accountRows: [AccountRowModel] = []

    static let preview = MenuBarViewModel(service: MockMenuBarService())

    func refresh() async {
        let snapshot = await service.loadSnapshot()
        headerEmail = snapshot.currentAccount.emailMask
        accountRows = snapshot.accounts
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/MenuBarViewModelTests`
Expected: PASS with mock-backed menu bar state.

**Step 5: Commit**

```bash
git add apps/mac-client
git commit -m "feat: add menu bar shell with mock account state"
```

### Task 3: Local Persistence and Secure Credentials

**Files:**
- Create: `apps/mac-client/CodexSwitch/Accounts/Account.swift`
- Create: `apps/mac-client/CodexSwitch/Accounts/AccountRepository.swift`
- Create: `apps/mac-client/CodexSwitch/Accounts/KeychainCredentialStore.swift`
- Create: `apps/mac-client/CodexSwitch/Accounts/ApplicationSupportAccountStore.swift`
- Test: `apps/mac-client/CodexSwitchTests/Accounts/AccountRepositoryTests.swift`

**Step 1: Write the failing test**

```swift
func testRepositoryPersistsAccountMetadataSeparatelyFromSecrets() async throws {
    let repository = AccountRepository(
        metadataStore: InMemoryAccountMetadataStore(),
        credentialStore: InMemoryCredentialStore()
    )

    let account = Account(id: "acct-1", emailMask: "a••••@gmail.com", tier: .team)
    try await repository.save(account: account, secret: "token-123")

    let loaded = try await repository.loadAccounts()
    XCTAssertEqual(loaded.first?.emailMask, account.emailMask)
    XCTAssertNil(loaded.first?.embeddedSecret)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/AccountRepositoryTests`
Expected: FAIL because the repository and stores do not exist.

**Step 3: Write minimal implementation**

```swift
struct Account: Codable, Equatable {
    let id: String
    let emailMask: String
    let tier: AccountTier
    var embeddedSecret: String? = nil
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/AccountRepositoryTests`
Expected: PASS with metadata and secrets stored separately.

**Step 5: Commit**

```bash
git add apps/mac-client
git commit -m "feat: add secure local account persistence"
```

### Task 4: Refresh and Active Account Switching Engine

**Files:**
- Create: `apps/mac-client/CodexSwitch/Switching/ActiveAccountController.swift`
- Create: `apps/mac-client/CodexSwitch/Switching/UsageRefreshService.swift`
- Create: `apps/mac-client/CodexSwitch/Switching/SwitchCommandRunner.swift`
- Test: `apps/mac-client/CodexSwitchTests/Switching/ActiveAccountControllerTests.swift`

**Step 1: Write the failing test**

```swift
func testSwitchingAccountMarksSelectionAndRefreshesUsage() async throws {
    let controller = ActiveAccountController(
        switcher: StubSwitchCommandRunner(),
        usageService: StubUsageRefreshService()
    )

    try await controller.activateAccount(id: "acct-2")

    XCTAssertEqual(controller.activeAccountID, "acct-2")
    XCTAssertEqual(controller.lastRefreshSource, "switch")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/ActiveAccountControllerTests`
Expected: FAIL because switching orchestration does not exist.

**Step 3: Write minimal implementation**

```swift
@MainActor
final class ActiveAccountController: ObservableObject {
    @Published private(set) var activeAccountID: String?
    @Published private(set) var lastRefreshSource: String?

    func activateAccount(id: String) async throws {
        try await switcher.activateAccount(id: id)
        activeAccountID = id
        _ = try await usageService.refresh(reason: .switchTriggered)
        lastRefreshSource = "switch"
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/ActiveAccountControllerTests`
Expected: PASS with a deterministic mock switching flow.

**Step 5: Commit**

```bash
git add apps/mac-client
git commit -m "feat: add account switching orchestration"
```

### Task 5: Settings, Diagnostics, and Packaging

**Files:**
- Create: `apps/mac-client/CodexSwitch/Settings/SettingsView.swift`
- Create: `apps/mac-client/CodexSwitch/Diagnostics/StatusView.swift`
- Create: `docs/release-checklist.md`
- Test: `apps/mac-client/CodexSwitchTests/Settings/SettingsViewModelTests.swift`

**Step 1: Write the failing test**

```swift
func testSettingsViewModelTogglesEmailVisibilityPreference() {
    let defaults = UserDefaults(suiteName: "CodexSwitchTests")!
    let viewModel = SettingsViewModel(defaults: defaults)

    viewModel.setShowEmails(true)

    XCTAssertTrue(defaults.bool(forKey: "showEmails"))
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/SettingsViewModelTests`
Expected: FAIL because settings and diagnostics are not present.

**Step 3: Write minimal implementation**

```swift
@MainActor
final class SettingsViewModel: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func setShowEmails(_ enabled: Bool) {
        defaults.set(enabled, forKey: "showEmails")
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/SettingsViewModelTests`
Expected: PASS with settings persisted to defaults.

**Step 5: Commit**

```bash
git add apps/mac-client docs/release-checklist.md
git commit -m "feat: add settings and packaging checklist"
```

### Task 6: Replace Mock Services With Real Account Integration

**Files:**
- Modify: `apps/mac-client/CodexSwitch/App/AppEnvironment.swift`
- Modify: `apps/mac-client/CodexSwitch/Switching/SwitchCommandRunner.swift`
- Modify: `apps/mac-client/CodexSwitch/Switching/UsageRefreshService.swift`
- Test: `apps/mac-client/CodexSwitchTests/Integration/RealIntegrationSmokeTests.swift`

**Step 1: Write the failing test**

```swift
func testRealEnvironmentCanResolveConfiguredAccountBackend() throws {
    let environment = try AppEnvironment.live(configuration: .fixture)
    XCTAssertEqual(environment.runtimeMode, .live)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/RealIntegrationSmokeTests`
Expected: FAIL because the live integration path is not yet implemented.

**Step 3: Write minimal implementation**

```swift
extension AppEnvironment {
    static func live(configuration: RuntimeConfiguration) throws -> AppEnvironment {
        AppEnvironment(
            accountStore: LiveAccountStore(configuration: configuration),
            usageService: LiveUsageService(configuration: configuration),
            runtimeMode: .live
        )
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS' -only-testing:CodexSwitchTests/RealIntegrationSmokeTests`
Expected: PASS with a smoke-tested live integration path.

**Step 5: Commit**

```bash
git add apps/mac-client
git commit -m "feat: wire mac client to real account integration"
```

## Notes

- Keep v1 menu content focused: current account, usage cards, switch list, add account, status, show emails, settings, quit.
- Treat account switching and usage refresh as separate protocols from day one so mock-first and live modes remain swappable.
- Do not couple UI state directly to Keychain or shell execution APIs.
- When we generate the Xcode project, target a deployment version that supports `MenuBarExtra`.

