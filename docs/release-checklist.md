# Release Checklist

## Build And Test

- Run `npm ci && npm test && npm run build` in `apps/rust-client/ui`
- Run `cargo test && cargo build` in `apps/rust-client/src-tauri`
- Run `npm run tauri build -- --bundles dmg` in `apps/rust-client/ui`
- Confirm the generated app launches correctly on macOS

## Product Checks

- Verify the tray icon appears on launch
- Verify the tray panel renders current account, usage summaries, and quick switch rows
- Verify the main window opens and all feature sections render
- Verify browser login, backup import, provider sync, and settings flows behave correctly
- Verify “显示完整邮箱” and “开机启动” settings take effect

## Packaging

- Confirm Tauri bundle metadata and icons are correct
- Confirm macOS DMG files exist under `apps/rust-client/src-tauri/target/release/bundle/dmg/`
- Push a `v*` tag and confirm the Release workflow publishes macOS arm64/x86_64, Windows x64, and Linux x64 assets
