## 1. Planning

- [ ] 1.1 Write analysis documents for project overview, module inventory, and risk assessment
- [ ] 1.2 Write plan documents for task breakdown, dependency graph, and milestones
- [ ] 1.3 Write progress tracking documents and master status file
- [ ] 1.4 Validate the OpenSpec change with `openspec validate refactor-desktop-to-tauri-rust --strict`

## 2. Application Scaffold

- [ ] 2.1 Create the Tauri 2 Rust app structure and React/TypeScript UI app structure
- [ ] 2.2 Add shared command/event contracts, DTOs, error types, and application state
- [ ] 2.3 Add desktop-first shell layouts for the main window and tray panel

## 3. Core Service Migration

- [ ] 3.1 Implement `.codex` path resolution, auth loading, archive import, and account switching in Rust
- [ ] 3.2 Implement usage scanning, cache loading, and API fallback in Rust
- [ ] 3.3 Implement diagnostics logging/reading and settings persistence with legacy migration
- [ ] 3.4 Expose the migrated services through Tauri commands and events

## 4. Advanced Feature Migration

- [ ] 4.1 Implement provider sync with config parsing, rollout rewriting, SQLite updates, backup, and rollback
- [ ] 4.2 Implement desktop-owned browser login coordination with completion tracking
- [ ] 4.3 Integrate provider sync and browser login into the desktop UI flow

## 5. Validation and Packaging

- [ ] 5.1 Add Rust unit/integration tests for core compatibility behavior
- [ ] 5.2 Add front-end tests for navigation, feature pages, and tray panel behavior
- [ ] 5.3 Update packaging/docs and verify the app through end-to-end flows
