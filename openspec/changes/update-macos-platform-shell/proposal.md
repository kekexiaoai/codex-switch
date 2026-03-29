# Change: update macOS menu bar shell compatibility

## Why
The current implementation plan assumes `MenuBarExtra`, but the active development machine is running macOS 12.7.4. We need a compatibility-first shell strategy so the client can be developed and run on macOS 12 without giving up a cleaner native implementation on macOS 13+.

## What Changes
- Define macOS 12 as the minimum supported version for the menu bar client
- Use `NSStatusItem + NSPopover` as the required shell implementation
- Allow `MenuBarExtra` on macOS 13+ behind runtime availability checks
- Keep shared SwiftUI panel content and state management independent from the shell host

## Impact
- Affected specs: `menu-bar-shell`
- Affected code: future app host setup, menu bar shell wiring, implementation plan, README
