## 1. Design
- [x] 1.1 Document the real Codex auth backend design in `docs/plans/2026-03-28-codex-auth-backend-design.md`
- [ ] 1.2 Review the design against the current menu bar architecture

## 2. Specification
- [ ] 2.1 Add requirements for importing active auth, importing backup auth, switching accounts, and scanning usage logs
- [ ] 2.2 Add requirements for browser login orchestration via `codex login`
- [ ] 2.3 Validate the change with `openspec validate add-codex-auth-backend --strict`

## 3. Implementation
- [ ] 3.1 Implement current active auth import from `~/.codex/auth.json`
- [ ] 3.2 Implement backup `auth.json` import
- [ ] 3.3 Implement archived account switching by replacing `~/.codex/auth.json`
- [ ] 3.4 Implement usage scanning from `~/.codex/sessions/rollout-*.jsonl`
- [ ] 3.5 Implement browser login import by coordinating `codex login`
