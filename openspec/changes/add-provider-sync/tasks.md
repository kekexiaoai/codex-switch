## 1. Foundation
- [ ] 1.1 Extend `CodexPaths` with new path properties (configFileURL, sqliteDatabaseURL, archivedSessionsDirectoryURL, providerSyncBackupsDirectoryURL, providerSyncLockFileURL)
- [ ] 1.2 Create `ProviderSyncActions.swift` (action enums, message types, protocol definitions)

## 2. Core Services
- [ ] 2.1 Create `CodexConfigParser.swift` (read/write config.toml: currentProvider, configuredProviders, setProvider)
- [ ] 2.2 Create `CodexSessionScanner.swift` (scan rollout-*.jsonl files, collect changes, apply/rollback first-line rewrites)
- [ ] 2.3 Create `CodexProviderSQLite.swift` (read provider counts, update provider in threads table via SQLite3 C API)
- [ ] 2.4 Create `ProviderSyncBackupManager.swift` (create/list/restore/prune backups under ~/.codex/backups_state/provider-sync/)

## 3. Business Logic
- [ ] 3.1 Create `ProviderSyncService.swift` (protocol + LiveProviderSyncService + MockProviderSyncService: loadStatus, sync, switchProvider, backup management)

## 4. UI Layer
- [ ] 4.1 Create `ProviderSyncViewModel.swift` (@MainActor ObservableObject with published state and action methods)
- [ ] 4.2 Create `ProviderSyncView.swift` (SwiftUI view with Status, Distribution, Sync, Backups sections)
- [ ] 4.3 Create `ProviderSyncWindowPresenter.swift` (NSWindow management following SettingsWindowPresenter pattern)

## 5. Integration
- [ ] 5.1 Add `MenuBarAction.openProviderSync` case and handler
- [ ] 5.2 Add "Provider Sync" action row in `MenuBarPanelView`
- [ ] 5.3 Add `openProviderSync()` to `MenuBarViewModel`
- [ ] 5.4 Register `ProviderSyncWindowPresenter` and factory method in `AppEnvironment`

## 6. Testing
- [ ] 6.1 Unit tests for CodexConfigParser
- [ ] 6.2 Unit tests for CodexSessionScanner
- [ ] 6.3 Unit tests for CodexProviderSQLite
- [ ] 6.4 Unit tests for ProviderSyncBackupManager
- [ ] 6.5 Unit tests for ProviderSyncViewModel
