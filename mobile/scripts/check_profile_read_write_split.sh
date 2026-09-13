#!/usr/bin/env bash
# Profile read/write split invariant (#6423).
#
# profileReadRepositoryProvider hands over a ProfileReader at the
# identity-known phase — before the signer-backed NostrClient exists. That is
# safe for Drift reads and unsafe for signing, so no file may reach a profile
# publish through the loose provider.
#
# The ProfileReader type already makes the DIRECT route impossible: it cannot
# express saveProfileEvent / claimUsername / drivePendingSave.
# This guard covers the INDIRECT route a type cannot see — a file that reads
# the loose provider and separately calls a publish method on something else
# (a repository it also holds, a service, a bloc field).
#
# Detector (code only — comments and string literals are stripped first by
# lib/dart_code_only.awk, so a doc comment naming saveProfileEvent never trips
# it): files under mobile/lib mentioning profileReadRepositoryProvider are
# intersected with files calling a publish method.
#
# There is no baseline: the correct count is zero, always. If this fires, move
# the publish to profileRepositoryProvider (which stays gated on
# isReadyForActiveClient) rather than widening ProfileReader.
#
# Usage (from the repo root or mobile/):
#   bash mobile/scripts/check_profile_read_write_split.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LOOSE_PROVIDER='profileReadRepositoryProvider'
# Publish methods on ProfileRepository — each signs a Nostr event.
PUBLISH_METHODS='saveProfileEvent|claimUsername|drivePendingSave'

violations=()

while IFS= read -r f; do
  code="$(awk -f "$SCRIPT_DIR/lib/dart_code_only.awk" "$f" 2>/dev/null || true)"
  [ -n "$code" ] || continue

  printf '%s' "$code" | grep -q "$LOOSE_PROVIDER" || continue

  hits="$(printf '%s' "$code" \
    | grep -oE "\.($PUBLISH_METHODS)\(" \
    | sed 's/^\.//; s/($//; s/(//' \
    | LC_ALL=C sort -u \
    | tr '\n' ' ' || true)"

  if [ -n "${hits// /}" ]; then
    rel="${f#"$MOBILE_DIR/"}"
    violations+=("mobile/$rel — calls: ${hits% }")
  fi
done < <(find "$MOBILE_DIR/lib" -name '*.dart' ! -name '*.g.dart' \
           ! -name '*.freezed.dart' | LC_ALL=C sort)

if [ ${#violations[@]} -gt 0 ]; then
  echo "profile read/write split VIOLATION (${#violations[@]} file(s)):"
  printf '  %s\n' "${violations[@]}"
  cat <<'EOF'

A file that reads profileReadRepositoryProvider also publishes a profile.

That provider resolves at the identity-known phase, which carries a pubkey but
no signer-backed client, so a publish reached from there can be signed by the
wrong key or not at all (#1048, #6423).

Fix: take the publish dependency from profileRepositoryProvider instead — it
stays gated on isReadyForActiveClient. Do NOT widen ProfileReader to make the
call compile.
EOF
  exit 1
fi

echo "profile read/write split OK (no file both reads $LOOSE_PROVIDER and publishes)"
