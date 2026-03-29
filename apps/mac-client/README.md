# mac-client

This directory will contain the native SwiftUI macOS menu bar application.

## Intended Source Layout

- `CodexSwitch.xcodeproj`: Xcode project
- `CodexSwitch/App/`: app entry and shared environment
- `CodexSwitch/MenuBar/`: menu bar scene, panel, and row components
- `CodexSwitch/Accounts/`: account models and persistence
- `CodexSwitch/Switching/`: refresh and switching orchestration
- `CodexSwitch/Settings/`: settings and preferences
- `CodexSwitchTests/`: unit and integration tests

## First Build Target

The first coded milestone is a mock-backed `MenuBarExtra` shell that matches the intended menu bar panel layout before we wire any real account backend.

