#!/usr/bin/env bash
# ABOUTME: Fails when focused service suites outgrow their declared CI scopes.
# ABOUTME: Keeps changed-file suite selection synchronized with Dart dependencies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$MOBILE_DIR/.." && pwd)"

cd "$MOBILE_DIR"
dart run scripts/lib/service_suite_scope_detector.dart \
  --repo-root "$REPO_DIR" "$@"
