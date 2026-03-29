## 1. Implementation
- [x] 1.1 Add spec coverage for non-blocking account switching and compact updated text.
- [x] 1.2 Refactor switch flow so active-account activation returns before remote/local usage refresh completes.
- [x] 1.3 Trigger a background refresh after switch and update the menu view model when fresh usage arrives.
- [x] 1.4 Replace long header `updatedText` strings with a compact local-time display that fits the menu bar panel and omits timezone text.
- [x] 1.5 Make account switch affordances more obvious at the row level without hiding remove-account controls.
- [x] 1.6 Add or update tests for switch latency behavior, active-account deletion behavior, and header display formatting.
- [x] 1.7 Run `swift test` and `./scripts/package-macos-app.sh`.
