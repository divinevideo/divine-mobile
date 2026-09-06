#!/usr/bin/env bash
# Fails CI if a test the very_good optimizer MERGES into the shared isolate
# mutates a restorable process-global without restoring it, or if any ordinary
# suite calls an irreversible initializer owned by the root harness. An
# unrestored mutation persists into every later merged test in the shared
# isolate, surfacing as an order-dependent failure cross-attributed to an
# unrelated test. This generalizes the single-global precedent
# check_http_overrides_isolation.sh (PR #5163) to the classes of test seams
# behind the #5159 / #5180 cascades (parent #3137) and the Tier-3/Tier-4 residual
# (#5185).
#
# For classes 1 and 2, a file is in the merge UNLESS it is tagged
# @Tags(['skip_very_good_optimization']). Being under test/manual/ does NOT
# exclude it — only the tag does (the very_good --optimization globber does not
# honor dart_test.yaml's exclude: test/manual/**). Tag matching is
# whitespace-normalized so dart-format-wrapped @Tags([...]) annotations are
# honored. A commented-out @Tags line remains ignored by this stricter gate; do
# not rely on commented annotations as an optimizer escape hatch. Class 3 is
# hard-zero regardless of tag because the root harness already performs the
# initialization for every non-web test.
#
# Three detection classes, each HARD-ZERO (no baseline, no tolerated debt):
#
#   1. CAPTURE-RESTORE (GLOBALS) — `<Singleton>.instance` and static hooks whose
#      documented resting value is the *prior runtime value*. Every untagged
#      *_test.dart that installs one must, within the same file, SNAPSHOT the
#      original (a `<id> = <Global>` read) and RESTORE it by assigning the global
#      back that captured value (`<Global> = <origId>`, e.g. in tearDown /
#      tearDownAll / addTearDown). The restore RHS must be an identifier that
#      holds the captured original — the snapshot id itself, or a local copied
#      from it — NOT an arbitrary bare identifier: the dominant install shape is
#      itself a bare-id write (`Bloc.observer = observer;`) and `<Global> = null`
#      strands null, so tying the restore to the captured value is what makes the
#      check real. Unlike check_http_overrides_isolation.sh — which rejects even a
#      correct restore because a nulled HttpOverrides 400-mock is itself the
#      hazard while the file runs — a within-file restore PASSES here.
#
#   2. RESET-TO-DEFAULT (RESET_TO_DEFAULT_GLOBALS) — top-level debug overrides /
#      test-injection setters whose documented resting value is a compile-time
#      DEFAULT LITERAL (all `null` today), so there is no prior to snapshot. A
#      file that installs a NON-default value must, within the same file, assign
#      the global back to its default literal (`<Global> = <default>`, block or
#      `=> <Global> = <default>)` arrow form). No capture is required; a file
#      whose only assignment IS the default (e.g. a lone `= null`) is harmless
#      and passes.
#
#   3. IRREVERSIBLE INITIALIZERS — calls such as `loadAppFonts()` that mutate
#      process-global state and have no inverse. They belong in the root test
#      harness, before `testMain`, or in the isolated golden tree. Calling one
#      from an ordinary merged suite makes every later test order-dependent.
#
# Detection is textual for all three classes. For the first two, it cannot prove
# the restore is reachable or lives in a tearDown (an inline end-of-body reset
# satisfies the check but not a mid-test throw). The snapshot+restore /
# reset-to-default pair is the canonical fix; the tag is the escape hatch for
# tests that legitimately cannot restore (real plugin / integration tests).
# Class 3 scans code only, with comments and string-literal bodies removed.
#
# Scope: assignment classes inspect only `*_test.dart`; irreversible initializer
# detection inspects every Dart file under mobile/test and mobile/packages/*/test.
# Each package runs its own merged isolate, so mutations cannot cross package
# boundaries but can leak between files within one package. Non-test helpers are
# ignored by assignment detection. Only the app's root flutter_test_config.dart
# and test/goldens/ may call loadAppFonts(); package suites have no root harness.
# HttpOverrides.global keeps its own dedicated STRICT gate (check_http_overrides_isolation.sh)
# and is intentionally not handled here.
#
# GoogleFonts.config.allowRuntimeFetching is intentionally NOT gated: the shared
# test harness sets it `false` suite-wide and `false` is the resting value every
# test wants (benign-monotonic), so an un-restored `= false` is not a hazard.
#
# Usage:
#   bash mobile/scripts/check_process_global_mutations.sh
#   bash mobile/scripts/check_process_global_mutations.sh --selftest
#   (run from the repository root or from mobile/)
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Class 1 — capture-restore globals. Each entry is the ERE core, matched after an
# optional `<prefix>.`. (Tier-2 `<Singleton>.instance` + Tier-4 static hooks.)
GLOBALS=(
  'PathProviderPlatform\.instance'
  'ProVideoEditor\.instance'
  'WebViewPlatform\.instance'
  'UrlLauncherPlatform\.instance'
  'VideoPlayerPlatform\.instance'
  'FirebasePlatform\.instance'
  'DivineCameraPlatform\.instance'
  'DivineQuickActionsPlatform\.instance'
  'BackgroundUploaderPlatform\.instance'
  'CaptionGeneratorPlatform\.instance'
  'FlutterError\.onError'
  'Bloc\.observer'
)

# Class 2 — reset-to-default globals, `core:defaultLiteral` (colon-delimited so
# bash 3.2 — macOS's default /bin/bash for local runs — needs no associative
# arrays; CI runs this via mobile_ci.yaml, not a git hook). The default literal
# must be a regex-safe token; all defaults are `null` today.
#
# Note: debugDefaultTargetPlatformOverride is also a Flutter *foundation debug
# var* — in a `testWidgets` test, `debugAssertAllFoundationVarsUnset` (foundation
# debug.dart) already fails the test at end-of-body if it is left set, so a leak
# there is loud, not silent, and only an INLINE reset works (that assertion runs
# before tearDown/addTearDown). This gate still earns its keep for it by covering
# plain `test()` usage, which has no such framework guard; the other entries
# below have no framework guard at all.
RESET_TO_DEFAULT_GLOBALS=(
  'debugDefaultTargetPlatformOverride:null'
  'debugImageCacheOverride:null'
  'debugUsesAppleAppStoreTipPolicyOverride:null'
  'VideoEditorRenderService\.renderVideoOverride:null'
  'VideoEditorRenderService\.renderVideoToClipOverride:null'
  'VideoEditorRenderService\.crashReporterOverride:null'
  'NativeProofModeService\.proofFileOverride:null'
  'NativeProofModeService\.c2paSigningServiceFactoryOverride:null'
  'InfiniteVideoFeed\.debugIsSupportedOverride:null'
)

# SCAN_DIR remains a single-root override for the synthetic self-tests.
# Production scans cover the app bundle and every package bundle.
if [[ -n "${SCAN_DIR:-}" ]]; then
  SCAN_ROOTS=("$SCAN_DIR")
  APP_TEST_ROOT="$SCAN_DIR"
else
  SCAN_ROOTS=("$MOBILE_DIR/test")
  for package_test_root in "$MOBILE_DIR"/packages/*/test; do
    [[ -d "$package_test_root" ]] && SCAN_ROOTS+=("$package_test_root")
  done
  APP_TEST_ROOT="$MOBILE_DIR/test"
fi

is_skip_vgv_tagged() {
  local f="$1" tag_body tag_flat
  tag_body=$(grep -vE '^[[:space:]]*//' "$f" || true)
  tag_flat=$(tr -d '[:space:]' <<<"$tag_body")
  grep -qE "@Tags\(\[[^]]*['\"]skip_very_good_optimization['\"]" <<<"$tag_flat"
}

run_scan() {
  local violations="" core files f body def

  # --- Class 1: capture-restore ---
  for core in "${GLOBALS[@]}"; do
    files=$(grep -rlE --include='*_test.dart' "$core" "${SCAN_ROOTS[@]}" || true)
    for f in $files; do
      body=$(grep -vE '^[[:space:]]*//' "$f" || true)

      # A real ASSIGNMENT (install or restore): (<prefix>.)?CORE = , not == / =>.
      if ! grep -qE "(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=([^=>]|$)" <<<"$body"; then
        continue
      fi
      # Tagged out of the merge? Whole-file and whitespace-normalized, matching
      # the very_good text-scan shape for dart-format-wrapped @Tags([...]).
      if is_skip_vgv_tagged "$f"; then
        continue
      fi
      # SNAPSHOT: identifiers that hold a value READ FROM the global. Seed with
      # the LHS of every `<id> = <Global>` capture, then grow transitively across
      # `<id2> = <id1>` copies (a tearDown that promotes the snapshot into a local
      # before restoring — e.g. WebViewPlatform's non-null-setter guard). Word
      # boundary `.` is excluded so a `<Global>.instance = <id>` restore line is
      # never itself mistaken for a copy that adds `instance` to the set.
      # `|| true` on every grep|sed: under `set -o pipefail` a no-match grep
      # (exit 1) would otherwise abort the whole scan.
      local orig_ids
      orig_ids=$(grep -oE \
        "[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*([A-Za-z_][A-Za-z0-9_]*\.)?${core}([^A-Za-z0-9_]|$)" \
        <<<"$body" | sed -E 's/[[:space:]]*=.*//' | sort -u || true)
      local has_capture=0
      if [[ -n "$orig_ids" ]]; then has_capture=1; fi

      local id1 copies grown
      for _ in 1 2 3 4 5; do
        grown="$orig_ids"
        for id1 in $orig_ids; do
          copies=$(grep -oE \
            "(^|[^A-Za-z0-9_.])[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*${id1}([^A-Za-z0-9_]|$)" \
            <<<"$body" | sed -E 's/^[^A-Za-z_]*//; s/[[:space:]]*=.*//' || true)
          if [[ -n "$copies" ]]; then
            grown=$(printf '%s\n%s\n' "$grown" "$copies" | sort -u)
          fi
        done
        if [[ "$grown" == "$orig_ids" ]]; then break; fi
        orig_ids="$grown"
      done

      # RESTORE: `<Global> = <origId>` (block `= origId;`, arrow `=> ... = origId)`,
      # nullable promotion `= origId!`, or dart-format-wrapped trailing-comma
      # `= origId,`) where <origId> is one of the captured-original identifiers
      # above. Tying the RHS to a captured value — not any bare identifier —
      # rejects the bare-id install `<Global> = observer;` and the null-strand
      # `<Global> = null;`, and excludes null/true/false for free (they can never
      # be a capture LHS).
      local has_restore=0
      if [[ "$has_capture" -eq 1 ]]; then
        local id_alt
        id_alt="${orig_ids//$'\n'/|}"
        if grep -qE \
          "([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=[[:space:]]*(${id_alt})!?[[:space:]]*[;,)]" \
          <<<"$body"; then
          has_restore=1
        fi
      fi
      if [[ "$has_capture" -eq 0 || "$has_restore" -eq 0 ]]; then
        rel="${f#"$MOBILE_DIR"/}"
        disp="${core//\\/}"
        violations="$violations  $rel  ($disp) [capture-restore]"$'\n'
      fi
    done
  done

  # --- Class 2: reset-to-default ---
  local entry
  for entry in "${RESET_TO_DEFAULT_GLOBALS[@]}"; do
    core="${entry%%:*}"
    def="${entry##*:}"
    files=$(grep -rlE --include='*_test.dart' "$core" "${SCAN_ROOTS[@]}" || true)
    for f in $files; do
      body=$(grep -vE '^[[:space:]]*//' "$f" || true)

      if ! grep -qE "(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=([^=>]|$)" <<<"$body"; then
        continue
      fi
      if is_skip_vgv_tagged "$f"; then
        continue
      fi
      # RESET-TO-DEFAULT present: `<Global> = <default>` (block, arrow, or
      # dart-format-wrapped trailing-comma `= <default>,` form — hence `[;,)]`).
      local has_default_reset=0
      if grep -qE "([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=[[:space:]]*${def}[[:space:]]*[;,)]" <<<"$body"; then
        has_default_reset=1
      fi
      # NON-default install present: an assignment line that is NOT a reset to the
      # default literal (so a file whose only assignment is the default passes).
      local has_nondefault_install=0
      if grep -E "(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=([^=>]|$)" <<<"$body" \
         | grep -qvE "([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=[[:space:]]*${def}[[:space:]]*[;,)]"; then
        has_nondefault_install=1
      fi
      if [[ "$has_nondefault_install" -eq 1 && "$has_default_reset" -eq 0 ]]; then
        rel="${f#"$MOBILE_DIR"/}"
        disp="${core//\\/}"
        violations="$violations  $rel  ($disp) [reset-to-default → $def]"$'\n'
      fi
    done
  done

  # --- Class 3: irreversible process-global initializers ---
  # Match the bare identifier, not `loadAppFonts(`. `setUpAll(loadAppFonts);` is
  # the same irreversible load, and very_good_analysis enables
  # unnecessary_lambdas, which reports "Closure should be a tearoff" on
  # `setUpAll(() => loadAppFonts())` — so requiring the paren would gate the
  # spelling the linter discourages and wave through the one it recommends.
  # Widening is safe here because dart_code_only.awk has already removed comments
  # and string-literal bodies, which is what made the paren load-bearing before.
  irreversible='(^|[^[:alnum:]_])loadAppFonts([^[:alnum:]_]|$)'
  files=$(grep -rlE --include='*.dart' "$irreversible" "${SCAN_ROOTS[@]}" || true)
  for f in $files; do
    body=$(awk -f "$SCRIPT_DIR/lib/dart_code_only.awk" "$f" 2>/dev/null || true)
    if ! grep -qE "$irreversible" <<<"$body"; then
      continue
    fi
    rel="${f#"$MOBILE_DIR"/}"
    case "$f" in
      "$APP_TEST_ROOT/flutter_test_config.dart"|"$APP_TEST_ROOT/goldens/"*) continue ;;
    esac
    violations="$violations  $rel  (loadAppFonts) [irreversible initializer]"$'\n'
  done

  if [[ -n "$violations" ]]; then
    echo "FAIL [process_global_mutations]: test mutates a process-global"
    echo "outside its required restoration or isolation boundary:"
    printf '%s' "$violations" | sed '/^$/d'
    echo ""
    echo "An unrestored class 1/2 mutation in a MERGED (untagged) test leaks"
    echo "into every later test in the shared very_good --optimization isolate."
    echo "An irreversible initializer is banned outside the root harness and"
    echo "isolated golden tree, where its process-wide lifetime is intentional."
    echo "(generalizes PR #5163; cascades #5159 / #5180; parent #3137; residual #5185)."
    echo ""
    echo "Remediation — pick one:"
    echo "  (a) [capture-restore] Snapshot the original and restore it in the file:"
    echo "        late <Type> original;"
    echo "        setUp(() { original = <Global>; <Global> = <fake>; });"
    echo "        tearDown(() { <Global> = original; });"
    echo "  (b) [reset-to-default] Assign the global back to its default in a"
    echo "      guaranteed-reachable tearDown/addTearDown (NOT an inline end-of-body"
    echo "      line, which a mid-test throw would skip). NB: a foundation debug var"
    echo "      like debugDefaultTargetPlatformOverride needs an INLINE reset instead"
    echo "      under testWidgets (see the header note), so use a plain override here:"
    echo "        addTearDown(() => InfiniteVideoFeed.debugIsSupportedOverride = null);"
    echo "  (c) [capture-restore / reset-to-default] Real-plugin / integration"
    echo "      test that cannot restore: tag it so it stays out of the merge"
    echo "      (annotation BEFORE the first import):"
    echo "        @Tags(['skip_very_good_optimization', 'integration'])"
    echo "      then bump mobile/test/vgv_tag_baseline.txt if the tag count rises."
    echo "  (d) [irreversible initializer] Move it to flutter_test_config.dart"
    echo "      before testMain, or keep it under the isolated test/goldens tree."
    return 1
  fi

  echo "OK: no test leaks a process-global (capture-restore + reset-to-default + irreversible initializer)."
  return 0
}

# --- self-test: run the REAL scan over synthetic fixtures, assert exit codes ---
run_selftest() {
  local rc=0 tmp got desc want
  _case() {
    desc="$1"; want="$2"; local content="$3"
    tmp="$(mktemp -d)"
    printf '%s' "$content" > "$tmp/fixture_test.dart"
    if SCAN_DIR="$tmp" bash "$0" >/dev/null 2>&1; then got=0; else got=$?; fi
    rm -rf "$tmp"
    if [[ "$got" -eq "$want" ]]; then
      echo "  ok   ($got) $desc"
    else
      echo "  FAIL (got $got, want $want) $desc"; rc=1
    fi
  }

  echo "self-test:"
  _case "capture-restore leaker (Bloc.observer install, no restore) → FAIL" 1 \
'import "x";
void main() { Bloc.observer = MyObserver(); }
'
  _case "capture-restore correct (snapshot + restore) → PASS" 0 \
'import "x";
void main() {
  final prior = Bloc.observer;
  Bloc.observer = MyObserver();
  addTearDown(() => Bloc.observer = prior);
}
'
  _case "package-owned singleton install without restore → FAIL" 1 \
'import "x";
void main() { DivineCameraPlatform.instance = FakeCameraPlatform(); }
'
  _case "bare-id install masquerading as restore (snapshot + install, no real restore) → FAIL" 1 \
'import "x";
void main() {
  final previousObserver = Bloc.observer;
  Bloc.observer = observer;
}
'
  _case "bare-id install PLUS real restore (models divine_bloc_observer_test) → PASS" 0 \
'import "x";
void main() {
  final previousObserver = Bloc.observer;
  Bloc.observer = observer;
  addTearDown(() => Bloc.observer = previousObserver);
}
'
  _case "null strand masquerading as restore (FlutterError.onError = null) → FAIL" 1 \
'import "x";
void main() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {};
  tearDown(() { FlutterError.onError = null; });
}
'
  _case "restore via copied local inside guard (models nostr WebView tearDown) → PASS" 0 \
'import "x";
void main() {
  WebViewPlatform? originalWebViewPlatform;
  setUp(() { originalWebViewPlatform = WebViewPlatform.instance; });
  tearDown(() {
    final original = originalWebViewPlatform;
    if (original != null) { WebViewPlatform.instance = original; }
  });
  WebViewPlatform.instance = _FakeWebViewPlatform();
}
'
  _case "restore via nullable promotion (= original!) → PASS" 0 \
'import "x";
void main() {
  final original = WebViewPlatform.instance;
  WebViewPlatform.instance = _FakeWebViewPlatform();
  addTearDown(() => WebViewPlatform.instance = original!);
}
'
  _case "reset-to-default leaker (debugDefaultTargetPlatformOverride, no = null) → FAIL" 1 \
'import "x";
void main() { debugDefaultTargetPlatformOverride = TargetPlatform.iOS; }
'
  _case "reset-to-default correct (= null in tearDown) → PASS" 0 \
'import "x";
void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tearDown(() { debugDefaultTargetPlatformOverride = null; });
}
'
  _case "reset-to-default arrow form (=> = null)) → PASS" 0 \
'import "x";
void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}
'
  _case "reset-to-default dart-format-wrapped trailing comma (= null,) → PASS" 0 \
'import "x";
void main() {
  VideoEditorRenderService.renderVideoToClipOverride = _fake;
  addTearDown(
    () => VideoEditorRenderService.renderVideoToClipOverride = null,
  );
}
'
  _case "capture-restore dart-format-wrapped trailing comma (= prior,) → PASS" 0 \
'import "x";
void main() {
  final prior = Bloc.observer;
  Bloc.observer = _Fake();
  addTearDown(
    () => Bloc.observer = prior,
  );
}
'
  _case "newly-gated sibling c2paSigningServiceFactoryOverride leaker → FAIL" 1 \
'import "x";
void main() {
  NativeProofModeService.c2paSigningServiceFactoryOverride = () => _fake;
}
'
  _case "tagged leaker (skip_very_good_optimization, tag below class defs) → PASS" 0 \
'class _Foo {}
@Tags(["skip_very_good_optimization"])
import "x";
void main() { debugDefaultTargetPlatformOverride = TargetPlatform.iOS; }
'
  _case "multi-line tagged leaker (dart-format-wrapped @Tags) → PASS" 0 \
'@Tags([
  "skip_very_good_optimization",
])
import "x";
void main() { Bloc.observer = MyObserver(); }
'
  _case "commented-out tag does not exclude a leaker → FAIL" 1 \
'// @Tags(["skip_very_good_optimization"])
import "x";
void main() { Bloc.observer = MyObserver(); }
'
  _case "commented-out install → PASS" 0 \
'import "x";
void main() {
  // debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  // Bloc.observer = MyObserver();
}
'
  _case "lone default assignment (= null only, no install) → PASS" 0 \
'import "x";
void main() { setUp(() { debugDefaultTargetPlatformOverride = null; }); }
'
  _case "suite-local irreversible font load → FAIL" 1 \
'import "x";
void main() { setUpAll(() async { await loadAppFonts(); }); }
'
  _case "suite-local irreversible font load, tear-off → FAIL" 1 \
'import "x";
void main() { setUpAll(loadAppFonts); }
'
  _case "identifier that merely contains the name → PASS" 0 \
'import "x";
void main() { final loadAppFontsHelper = 1; print(loadAppFontsHelper); }
'
  _case "irreversible initializer named in a string → PASS" 0 \
'import "x";
void main() {
  test("no suite calls loadAppFonts() from setUpAll", () {});
}
'
  _case "irreversible initializer inside a block comment → PASS" 0 \
'import "x";
void main() {
  /* await loadAppFonts(); */
}
'
  tmp="$(mktemp -d)"
  printf '%s' 'void main() { loadAppFonts(); }' > "$tmp/flutter_test_config.dart"
  if SCAN_DIR="$tmp" bash "$0" >/dev/null 2>&1; then got=0; else got=$?; fi
  rm -rf "$tmp"
  if [[ "$got" -eq 0 ]]; then
    echo "  ok   (0) root-harness irreversible font load → PASS"
  else
    echo "  FAIL (got $got, want 0) root-harness irreversible font load → PASS"
    rc=1
  fi
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/goldens"
  printf '%s' 'void main() { loadAppFonts(); }' > "$tmp/goldens/fixture_test.dart"
  if SCAN_DIR="$tmp" bash "$0" >/dev/null 2>&1; then got=0; else got=$?; fi
  rm -rf "$tmp"
  if [[ "$got" -eq 0 ]]; then
    echo "  ok   (0) golden-local irreversible font load → PASS"
  else
    echo "  FAIL (got $got, want 0) golden-local irreversible font load → PASS"
    rc=1
  fi
  return $rc
}

if [[ "${1:-}" == "--selftest" ]]; then
  run_selftest
  exit $?
fi

run_scan
exit $?
