## 1. Planning
- [x] 1.1 Update the repository README to reflect macOS 12 compatibility and the dual-host strategy
- [x] 1.2 Update the implementation plan to replace the `MenuBarExtra`-first assumption

## 2. Specification
- [x] 2.1 Add the `menu-bar-shell` capability delta covering macOS 12 compatibility
- [x] 2.2 Validate the change with `openspec validate update-macos-platform-shell --strict`

## 3. Implementation Follow-Through
- [ ] 3.1 Generate the app host so macOS 12 uses `NSStatusItem + NSPopover`
- [ ] 3.2 Add a macOS 13+ availability path for `MenuBarExtra`
- [ ] 3.3 Keep both host paths rendering the same panel content and behavior
