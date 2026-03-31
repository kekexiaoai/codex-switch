#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

assert_contains() {
  local file_path="$1"
  local expected_text="$2"

  if ! grep -Fq "$expected_text" "$file_path"; then
    echo "缺少预期配置: $file_path => $expected_text" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file_path="$1"
  local unexpected_text="$2"

  if grep -Fq "$unexpected_text" "$file_path"; then
    echo "检测到已不受支持的配置: $file_path => $unexpected_text" >&2
    exit 1
  fi
}

CI_WORKFLOW="$ROOT_DIR/.github/workflows/ci.yml"
PACKAGE_WORKFLOW="$ROOT_DIR/.github/workflows/package.yml"
RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"

for workflow in "$CI_WORKFLOW" "$PACKAGE_WORKFLOW" "$RELEASE_WORKFLOW"; do
  assert_not_contains "$workflow" "macos-13"
done

assert_contains "$CI_WORKFLOW" "runner: macos-15-intel"
assert_contains "$PACKAGE_WORKFLOW" "runner: macos-15-intel"
assert_contains "$RELEASE_WORKFLOW" "runs-on: macos-15-intel"

echo "GitHub workflow runner 配置检查通过"
