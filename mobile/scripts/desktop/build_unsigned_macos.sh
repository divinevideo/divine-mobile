#!/usr/bin/env bash
# Native compilation only. Store and direct-distribution candidates must use
# their own signing/entitlement validation instead of this unsigned build.
set -euo pipefail

unsigned_config=$(mktemp "${TMPDIR:-/tmp}/divine-unsigned-macos.XXXXXX")
trap 'rm -f "$unsigned_config"' EXIT
cat > "$unsigned_config" <<'XCCONFIG'
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
XCCONFIG

# Plain CODE_SIGNING_ALLOWED environment variables lose to project settings.
# XCODE_XCCONFIG_FILE applies these overrides to the child Xcode invocation.
XCODE_XCCONFIG_FILE="$unsigned_config" flutter build macos --release --no-pub "$@"
