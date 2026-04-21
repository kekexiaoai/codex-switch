#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UI_DIR="$ROOT_DIR/apps/rust-client/ui"
APP_BUNDLE_PATH="$ROOT_DIR/apps/rust-client/src-tauri/target/release/bundle/macos/Codex Switch.app"

cd "$UI_DIR"
npm install
npm run tauri build -- --bundles app

echo "$APP_BUNDLE_PATH"
