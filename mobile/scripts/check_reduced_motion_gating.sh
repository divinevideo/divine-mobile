#!/usr/bin/env bash
# Skeleton shimmer and repeating AnimationControllers animate forever unless a
# call site gates them, and the indicator guard cannot see either shape. Keep
# both on a reduced-motion gate so the preference is honoured and the app can
# reach quiescence for UI automation (#9317, follow-up to #8651 / #8691).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_DIR"
# A zero-tolerance guard has to distinguish "found nothing" from "could not
# look". The detector exits 1 for findings and 2 for a bad invocation or an
# unreadable file; `dart run` itself exits non-zero on an unresolved package
# or a compile error.
rc=0
dart run scripts/lib/reduced_motion_gating_detector.dart \
  lib packages --path-prefix "$MOBILE_DIR" --detail || rc=$?

if [ "$rc" -eq 0 ]; then
  echo "Reduced-motion gating guard passed (zero ungated animations)."
elif [ "$rc" -eq 1 ]; then
  echo >&2
  echo "Perpetual animations must consult the reduced-motion preference." >&2
  echo "  skeletonizer: pass effect: vineSkeletonEffectOf(context)" >&2
  echo "  repeat:       gate on MediaQuery.disableAnimationsOf(context)," >&2
  echo "                MediaQuery.of(context).disableAnimations, or" >&2
  echo "                context.reduceMotion, and park a static frame" >&2
  exit 1
else
  echo >&2
  echo "Reduced-motion gating guard could NOT run (exit $rc)." >&2
  echo "This is a tooling failure, not a finding: nothing was verified." >&2
  echo "Check the detector invocation and that 'dart' resolves to the" >&2
  echo "pinned SDK (try: mise exec -- bash scripts/$(basename "$0"))." >&2
  exit "$rc"
fi
