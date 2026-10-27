#!/usr/bin/env bash
# Per-package merged-isolate channel-handler ratchet (#5838). Each package under
# mobile/packages runs its OWN fully-merged `very_good test --optimization`
# bundle (the reusable flutter_package.yml defaults test_optimization: true),
# and — unlike mobile/test — NO package has a flutter_test_config.dart
# heal-and-blame harness. So a package test that installs a MethodChannel /
# EventChannel mock handler WITHOUT tearing it back down leaks that handler into
# every later file in the same package's bundle, an order-dependent flake
# confined to that package's suite.
#
# This freezes the set of package *_test.dart ENTRIES that install a channel
# handler (setMockMethodCallHandler / setMockStreamHandler) but never null one
# back down. The set may only ever SHRINK: a NEW such entry fails CI. This is the
# packages analogue of check_shared_channel_overrides.sh (#5738), which guards
# the mobile/test tree only. See lib/list_ratchet.sh for NEW/STALE/GROWTH
# semantics and .claude/rules/testing.md (VGV merged isolate).
#
# Detector (grep proxy): a *_test.dart under mobile/packages/*/test that calls
# setMockMethodCallHandler( / setMockStreamHandler( AND does NOT pair any install
# with a `(..., null)` teardown, and is NOT tagged @Tags(['skip_very_good_optimization'])
# (tagged files run in their own isolate). Non-*_test.dart helpers
# (test_setup.dart, **/helpers/*.dart) are not bundle entries and are excluded by
# the --include filter — they install suite-wide mocks by design, exactly like
# mobile/test/test_setup.dart. Being a grep proxy it cannot prove the teardown is
# reachable or nulls the SAME channel; the canonical fix is to null the handler
# in tearDown, and the tag is the escape hatch for a test that legitimately
# cannot restore.
#
# Regenerate ONLY after REMOVING an install (never to add one):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_package_channel_isolation.sh
# Usage (from the repo root or mobile/):
#   bash mobile/scripts/check_package_channel_isolation.sh

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RATCHET_LABEL="package_channel_isolation"
BASELINE_FILE="$SCRIPT_DIR/baseline/package_channel_raw_installs.txt"
BASELINE_REPO_PATH="mobile/scripts/baseline/package_channel_raw_installs.txt"
BASE_REF="${PACKAGE_CHANNEL_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${PACKAGE_CHANNEL_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="PACKAGE_CHANNEL_ALLOW_NO_BASE"
NEW_HINT="A package test installs a MethodChannel/EventChannel mock handler (setMockMethodCallHandler / setMockStreamHandler) without ever nulling one back down, so it leaks into every later file in that package's very_good --optimization merged isolate. Null the handler in tearDown, e.g. TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null); (or setMockStreamHandler(channel, null)). If the test genuinely cannot restore, tag the file @Tags(['skip_very_good_optimization']). See .claude/rules/testing.md (VGV merged isolate) and #5838."
STALE_HINT="A package test stopped leaking a channel handler (added a null teardown or a skip tag)."
FOOTER="Package channel installs without a teardown are frozen and may only decrease.
Null every installed handler in tearDown so it does not leak across the package's
merged isolate. Singletons are guarded separately (#6060 / follow-up); the runtime
per-package heal-and-blame harness remains a stronger future option (#5838 notes).
See mobile/scripts/check_shared_channel_overrides.sh (mobile/test analogue) and #5838."

emit_current() {
  local f rel
  # *_test.dart entries under any package's test/ tree that install a channel
  # handler. --include naturally excludes non-*_test.dart helpers (test_setup.dart,
  # helpers/*.dart); the /test/ filter excludes integration_test/ and example/.
  for f in $(grep -rlE 'setMockMethodCallHandler\(|setMockStreamHandler\(' \
      "$MOBILE_DIR/packages" --include='*_test.dart' 2>/dev/null \
      | grep -E '/test/' | LC_ALL=C sort); do
    rel="${f#"$MOBILE_DIR"/}"
    # Tagged out of the merge (own isolate) → cannot contaminate the bundle.
    if grep -qE '^[[:space:]]*@Tags\([^)]*skip_very_good_optimization' "$f"; then
      continue
    fi
    # Disciplined: nulls at least one handler back down (paired teardown).
    # Flatten newlines first, because `dart format` wraps a long teardown across
    # lines — setMockMethodCallHandler(\n  const MethodChannel('…'),\n  null,\n) —
    # which a per-line grep would miss, wrongly flagging a disciplined file as a
    # leaker (that file can never then be shrunk out via the documented remedy,
    # since it already has the teardown). The `[^,]*` stays comma-bounded to the
    # channel arg, so an installed handler that *returns* null —
    # setMockMethodCallHandler(channel, (call) async => null) — is not mistaken
    # for a teardown (after the comma comes `(call)`, not `null`).
    if tr '\n' ' ' <"$f" | grep -qE 'setMockMethodCallHandler\([^,]*,[[:space:]]*null|setMockStreamHandler\([^,]*,[[:space:]]*null'; then
      continue
    fi
    printf '%s\n' "$rel"
  done
}

print_baseline_header() {
  cat <<'EOF'
# Frozen baseline (#5838): package *_test.dart entries that install a MethodChannel/
# EventChannel mock handler (setMockMethodCallHandler / setMockStreamHandler) without
# nulling any back down, so the handler leaks across that package's very_good
# --optimization merged isolate (no per-package heal-and-blame harness exists).
# Generated by scripts/check_package_channel_isolation.sh. The set may only SHRINK
# (growth fails CI vs origin/main). Fix an entry by nulling the handler in tearDown
# (or tagging the file @Tags(['skip_very_good_optimization'])), then shrink this
# baseline. Packages analogue of check_shared_channel_overrides.sh (#5738).
EOF
}

# shellcheck source=lib/list_ratchet.sh
source "$SCRIPT_DIR/lib/list_ratchet.sh"
run_list_ratchet
