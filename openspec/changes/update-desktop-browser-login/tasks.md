## 1. Specification
- [ ] 1.1 Add a `local-auth-backend` delta replacing terminal-driven browser login with a desktop-owned browser login requirement
- [ ] 1.2 Validate the change with `openspec validate update-desktop-browser-login --strict`

## 2. Login Architecture
- [ ] 2.1 Define a desktop login broker abstraction for app-owned browser authentication
- [ ] 2.2 Remove the product dependency on visible or hidden Terminal flows for the intended login path
- [ ] 2.3 Define completion, timeout, and cancellation behavior for desktop browser login

## 3. Implementation
- [ ] 3.1 Implement browser launch and completion tracking in app-owned code
- [ ] 3.2 Materialize a Codex-compatible `~/.codex/auth.json` without going through Terminal
- [ ] 3.3 Reuse the existing import/archive pipeline after browser login succeeds
- [ ] 3.4 Update login alerts and progress states so they describe desktop-native behavior

## 4. Verification
- [ ] 4.1 Add unit tests for desktop login broker success, cancellation, and timeout
- [ ] 4.2 Add coordinator regression tests for successful post-login import
- [ ] 4.3 Verify packaged macOS app behavior end to end without exposing Terminal
