## 1. Design
- [x] 1.1 Document the real Codex auth backend design in `docs/plans/2026-03-28-codex-auth-backend-design.md`
- [x] 1.2 Review the design against the current menu bar architecture

## 2. Specification
- [x] 2.1 Add requirements for importing active auth, importing backup auth, switching accounts, and scanning usage logs
- [x] 2.2 Add requirements for browser login orchestration via `codex login`
- [x] 2.3 Validate the change with `openspec validate add-codex-auth-backend --strict`

## 3. Implementation
- [ ] 3.1 Add Codex path/runtime abstractions for `~/.codex/auth.json`, `~/.codex/accounts/`, and `~/.codex/sessions/`
- [ ] 3.2 Add auth-file parsing, JWT decoding, email masking, and archive filename helpers with unit tests
- [ ] 3.3 Implement the unified import pipeline for current active auth and backup `auth.json` imports
- [ ] 3.4 Replace app-owned metadata/secret persistence with archive-backed account repository behavior
- [ ] 3.5 Implement archived account switching by atomically replacing `~/.codex/auth.json`
- [ ] 3.6 Implement usage scanning from `~/.codex/sessions/rollout-*.jsonl` plus cached last-known snapshots
- [ ] 3.7 Implement browser login import by coordinating `codex login`
- [ ] 3.8 Replace demo/manual add-account actions with import-driven menu bar flows and refresh wiring
- [ ] 3.9 Add integration tests for import, switch, usage scan, and login coordination fixtures
