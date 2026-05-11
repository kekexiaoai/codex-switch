# Release Checklist

## Build And Test

- Run `swift test` in `apps/mac-client`
- Run `xcodebuild test -project apps/mac-client/CodexSwitch.xcodeproj -scheme CodexSwitch -destination 'platform=macOS'`
- Confirm the app launches on a macOS 12 machine

## Product Checks

- Verify the menu bar status item appears on launch
- Verify the popover renders current account, usage summaries, and account list
- Verify the Settings window toggles the email visibility preference

## Packaging

- Confirm bundle identifier and signing settings are correct
- Run `./scripts/package-macos-app.sh` and confirm `dist/Codex Switch.app` exists
- Push a `v*-swift` tag and confirm the Swift legacy Release workflow publishes arm64 and x86_64 DMG assets
