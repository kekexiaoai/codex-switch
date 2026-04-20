## 1. Planning

- [x] 1.1 Write analysis documents for project overview, module inventory, and risk assessment
- [x] 1.2 Write plan documents for task breakdown, dependency graph, and milestones
- [x] 1.3 Write progress tracking documents and master status file
- [x] 1.4 Validate the OpenSpec change with `openspec validate refactor-desktop-to-tauri-rust --strict`

## 2. Application Scaffold

- [x] 2.1 Create the Tauri 2 Rust app structure and React/TypeScript UI app structure
- [x] 2.2 Add shared command/event contracts, DTOs, error types, and application state
- [x] 2.3 Add desktop-first shell layouts for the main window and tray panel

## 3. Core Service Migration

- [x] 3.1 Implement `.codex` path resolution, auth loading, archive import, and account switching in Rust
- [x] 3.2 Implement usage scanning, cache loading, and API fallback in Rust
- [x] 3.3 Implement diagnostics logging/reading and settings persistence with legacy migration
- [x] 3.4 Expose the migrated services through Tauri commands and events

## 4. Advanced Feature Migration

- [x] 4.1 Implement provider sync with config parsing, rollout rewriting, SQLite updates, backup, and rollback
- [x] 4.2 Implement desktop-owned browser login coordination with completion tracking
- [x] 4.3 Integrate provider sync and browser login into the desktop UI flow

## 5. Validation and Packaging

- [x] 5.1 Add Rust unit/integration tests for core compatibility behavior
- [x] 5.2 Add front-end tests for navigation, feature pages, and tray panel behavior
- [ ] 5.3 Update packaging/docs and verify the app through end-to-end flows
