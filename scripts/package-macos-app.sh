#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/apps/mac-client/CodexSwitch.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/.build-artifacts/DerivedData"
BUILD_PRODUCTS_PATH="$DERIVED_DATA_PATH/Build/Products/Debug"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Codex Switch.app"
APP_BUNDLE_PATH="$DIST_DIR/$APP_NAME"
CONTENTS_PATH="$APP_BUNDLE_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
FRAMEWORKS_PATH="$CONTENTS_PATH/Frameworks"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

mkdir -p "$DERIVED_DATA_PATH"

xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme CodexSwitchApp \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  >/tmp/codex-switch-package-build.log

rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_PATH" "$FRAMEWORKS_PATH" "$RESOURCES_PATH"

cp "$ROOT_DIR/packaging/Info.plist" "$CONTENTS_PATH/Info.plist"
cp "$BUILD_PRODUCTS_PATH/CodexSwitchApp" "$MACOS_PATH/CodexSwitchApp"
cp -R "$BUILD_PRODUCTS_PATH/CodexSwitchKit.framework" "$FRAMEWORKS_PATH/"

chmod +x "$MACOS_PATH/CodexSwitchApp"

install_name_tool \
  -add_rpath "@executable_path/../Frameworks" \
  "$MACOS_PATH/CodexSwitchApp" 2>/dev/null || true

codesign --force --deep --sign - "$APP_BUNDLE_PATH" >/tmp/codex-switch-package-codesign.log

echo "$APP_BUNDLE_PATH"
