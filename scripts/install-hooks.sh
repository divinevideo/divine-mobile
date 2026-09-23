#!/bin/bash
# Install git hooks for divine-mobile development
# Run this once after cloning the repo, or via: cd mobile && mise run setup_hooks

set -e

# An exported CDPATH makes `cd` print where it lands, or land in a same-named
# directory elsewhere, and the command substitutions below capture either.
unset CDPATH

REPO_ROOT="$(git rev-parse --show-toplevel)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
if [[ "$GIT_COMMON_DIR" != /* ]]; then
  GIT_COMMON_DIR="$(cd "$GIT_COMMON_DIR" && pwd)"
fi
HOOKS_DIR="$GIT_COMMON_DIR/hooks"

# Content hash of this installer, stamped into every generated hook. A hook
# whose stamp no longer matches this file re-installs itself and exits instead
# of running its checks, so a change here reaches hooks already installed.
# Hooks generated before the stamp existed carry none and never update
# themselves; they need one manual run of this installer.
GENERATOR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
# Hashed from stdin: given a path containing a backslash, shasum and GNU
# sha256sum prefix the digest with one, and the stamp would never match.
if command -v sha256sum >/dev/null 2>&1; then
  GENERATOR_HASH="$(sha256sum < "$GENERATOR_PATH" | awk '{print $1}')"
else
  GENERATOR_HASH="$(shasum -a 256 < "$GENERATOR_PATH" | awk '{print $1}')"
fi

# Substitute the @GENERATOR_HASH@ stamp and install by rename. A rename leaves
# the inode an already-running hook is reading untouched, so a pre-push still
# running in another worktree finishes the script it started instead of
# resuming at its old byte offset inside the new one.
install_hook() {
  local source_file="$1" target="$2" staged
  staged="$STAGING_DIR/$(basename "$target")"
  awk -v hash="$GENERATOR_HASH" '{ gsub(/@GENERATOR_HASH@/, hash); print }' "$source_file" > "$staged"
  chmod +x "$staged"
  mv "$staged" "$target"
}

if ! command -v mise >/dev/null 2>&1; then
  echo "mise is required but not found on PATH."
  echo "Install mise: https://mise.jdx.dev/getting-started.html"
  exit 1
fi

# Stage inside the hooks directory: the rename then stays on one filesystem,
# so it is atomic, and files created here get the umask's mode rather than
# mktemp's 0600, which would leave other accounts unable to run the hooks.
STAGING_DIR="$(mktemp -d "$HOOKS_DIR/.install-hooks.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Installing git hooks..."

# Create pre-commit hook
PRECOMMIT_TMP="$STAGING_DIR/pre-commit.in"
cat > "$PRECOMMIT_TMP" << 'EOF'
#!/bin/bash
# Pre-commit hook for divine-mobile
# Fast checks only:
#   * dart format on staged files
#   * codegen verification — only when staged files contain codegen inputs
# `flutter analyze` is intentionally NOT run here; pre-push runs it once on
# the full diff, which is the right place to pay that cost.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT/mobile"

# Unset git env vars that break Flutter/Dart in hooks (especially in worktrees)
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

list_codegen_inputs() {
    while IFS= read -r file; do
        [ -z "$file" ] && continue

        local abs_path="$REPO_ROOT/$file"
        [ -f "$abs_path" ] || continue

        local base_path="${abs_path%.dart}"
        if grep -Eq '@Riverpod|@riverpod|@JsonSerializable|@GenerateMocks|@DriftDatabase|@UseRowClass|@DataClassName|@UseMoor|@HiveType' "$abs_path" \
            || grep -Eq "part '.*\\.g\\.dart';" "$abs_path" \
            || [ -f "${base_path}.g.dart" ] \
            || [ -f "${base_path}.mocks.dart" ]; then
            echo "$file"
        fi
    done
}

capture_generated_status() {
    git status --porcelain -- "$REPO_ROOT/mobile" \
        | awk '{print $2}' \
        | grep -E '^mobile/.*(\.g\.dart|\.mocks\.dart|\.types\.temp\.dart)$' \
        | sort -u || true
}

# Content hash of scripts/install-hooks.sh at generation time. When the
# installer changes, this no longer matches and the hook re-installs itself
# below instead of running its checks.
HOOKS_GENERATOR_HASH="@GENERATOR_HASH@"

current_installer_hash() {
    local installer="$REPO_ROOT/scripts/install-hooks.sh"
    [ -f "$installer" ] || return 0
    # From stdin, so a backslash in the path cannot prefix the digest.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum < "$installer" 2>/dev/null | awk '{print $1}' || true
    else
        shasum -a 256 < "$installer" 2>/dev/null | awk '{print $1}' || true
    fi
}

CURRENT_INSTALLER_HASH="$(current_installer_hash)"
if [ -n "$CURRENT_INSTALLER_HASH" ] && [ "$CURRENT_INSTALLER_HASH" != "$HOOKS_GENERATOR_HASH" ]; then
    echo "Git hooks are stale: scripts/install-hooks.sh changed since they were installed."
    echo "Re-installing hooks..."
    if ! reinstall_output="$(bash "$REPO_ROOT/scripts/install-hooks.sh" 2>&1)"; then
        echo "$reinstall_output"
        echo "Re-installing the hooks failed. Fix the error above, then run:"
        echo "  cd mobile && mise run setup_hooks"
        exit 1
    fi
    echo "Hooks updated. Re-run your command."
    exit 1
fi

# Check if any Dart files are staged
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM \
    | grep '^mobile/.*\.dart$' \
    | grep -v '\.g\.dart$' \
    || true)

if [ -z "$STAGED_DART_FILES" ]; then
    exit 0
fi

# Run dart format check on the staged files only (fast).
# Strip the leading "mobile/" prefix because we cd'd into mobile above.
STAGED_FORMAT_PATHS=$(echo "$STAGED_DART_FILES" | sed 's|^mobile/||')
if ! echo "$STAGED_FORMAT_PATHS" | xargs mise exec -- dart format --output=none --set-exit-if-changed; then
    echo ""
    echo "Format check failed!"
    echo "Run: cd mobile && mise exec -- dart format lib test integration_test"
    exit 1
fi

# Verify generated files when codegen inputs were staged.
# Most commits don't touch codegen inputs, so this is a no-op for them.
CODEGEN_INPUTS=$(printf '%s\n' "$STAGED_DART_FILES" | list_codegen_inputs)
if [ -n "$CODEGEN_INPUTS" ]; then
    BEFORE_STATUS_FILE=$(mktemp)
    AFTER_STATUS_FILE=$(mktemp)
    trap 'rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"' EXIT

    capture_generated_status > "$BEFORE_STATUS_FILE"

    echo "Verifying generated files..."
    mise exec -- dart run build_runner build --delete-conflicting-outputs >/dev/null

    capture_generated_status > "$AFTER_STATUS_FILE"
    NEW_GENERATED_CHANGES=$(comm -13 "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE" || true)

    rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"
    trap - EXIT

    if [ -n "$NEW_GENERATED_CHANGES" ]; then
        echo ""
        echo "Generated files changed during verification:"
        echo "$NEW_GENERATED_CHANGES"
        echo ""
        echo "Run: cd mobile && mise exec -- dart run build_runner build --delete-conflicting-outputs"
        echo "Then stage the generated files and commit again."
        exit 1
    fi
fi
EOF

install_hook "$PRECOMMIT_TMP" "$HOOKS_DIR/pre-commit"

# Create pre-push hook
PREPUSH_TMP="$STAGING_DIR/pre-push.in"
cat > "$PREPUSH_TMP" << 'EOF'
#!/bin/bash
# Pre-push hook for divine-mobile
# Verifies generated files and runs tests related to changed files before pushing

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT/mobile"

# Unset git env vars that break Flutter/Dart in hooks (especially in worktrees)
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

list_codegen_inputs() {
    while IFS= read -r file; do
        [ -z "$file" ] && continue

        local abs_path="$REPO_ROOT/$file"
        [ -f "$abs_path" ] || continue

        local base_path="${abs_path%.dart}"
        if grep -Eq '@Riverpod|@riverpod|@JsonSerializable|@GenerateMocks|@DriftDatabase|@UseRowClass|@DataClassName|@UseMoor|@HiveType' "$abs_path" \
            || grep -Eq "part '.*\\.g\\.dart';" "$abs_path" \
            || [ -f "${base_path}.g.dart" ] \
            || [ -f "${base_path}.mocks.dart" ]; then
            echo "$file"
        fi
    done
}

capture_generated_status() {
    git -C "$REPO_ROOT" status --porcelain -- mobile \
        | awk '{print $2}' \
        | grep -E '^mobile/.*(\.g\.dart|\.mocks\.dart|\.types\.temp\.dart)$' \
        | sort -u || true
}

# Content hash of scripts/install-hooks.sh at generation time. When the
# installer changes, this no longer matches and the hook re-installs itself
# below instead of running its checks.
HOOKS_GENERATOR_HASH="@GENERATOR_HASH@"

current_installer_hash() {
    local installer="$REPO_ROOT/scripts/install-hooks.sh"
    [ -f "$installer" ] || return 0
    # From stdin, so a backslash in the path cannot prefix the digest.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum < "$installer" 2>/dev/null | awk '{print $1}' || true
    else
        shasum -a 256 < "$installer" 2>/dev/null | awk '{print $1}' || true
    fi
}

CURRENT_INSTALLER_HASH="$(current_installer_hash)"
if [ -n "$CURRENT_INSTALLER_HASH" ] && [ "$CURRENT_INSTALLER_HASH" != "$HOOKS_GENERATOR_HASH" ]; then
    echo "Git hooks are stale: scripts/install-hooks.sh changed since they were installed."
    echo "Re-installing hooks..."
    if ! reinstall_output="$(bash "$REPO_ROOT/scripts/install-hooks.sh" 2>&1)"; then
        echo "$reinstall_output"
        echo "Re-installing the hooks failed. Fix the error above, then run:"
        echo "  cd mobile && mise run setup_hooks"
        exit 1
    fi
    echo "Hooks updated. Re-run your command."
    exit 1
fi

echo "Running pre-push checks..."

# Get the remote and branch being pushed to
remote="$1"
url="$2"

# Always compare against origin/main to catch all changes that will affect CI
BASE_BRANCH="origin/main"

# Fetch latest main to ensure accurate comparison
git -C "$REPO_ROOT" fetch origin main --quiet 2>/dev/null || true

# Merge-conflict check
CURRENT_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Checking for merge conflicts with main..."
    # Lives in the repo rather than inline so it is testable, and so a fix to
    # it reaches everyone without a re-run of `mise run setup_hooks`. Skipped
    # when absent, e.g. on a branch predating it.
    MERGEABLE_CHECK="$REPO_ROOT/scripts/check_branch_mergeable.sh"
    # Invoked through `bash`, so it needs to be present and readable, not
    # executable. Testing `-x` would skip the whole check on a checkout that
    # lost the +x bit (Windows, a mode-stripped copy) and let a genuine
    # conflict through — the check must fail closed, not open.
    if [ -f "$MERGEABLE_CHECK" ]; then
        bash "$MERGEABLE_CHECK" "$BASE_BRANCH" || exit 1
    else
        echo "Skipped: scripts/check_branch_mergeable.sh not present"
    fi
    echo ""

    # Validate branch name matches semantic PR title convention
    # CI requires PR titles like: feat: ..., fix(scope): ..., chore!: ...
    # Branch names follow: type/issue-description, so extract the prefix
    BRANCH_PREFIX=$(echo "$CURRENT_BRANCH" | sed -n 's|^\([a-z]*\)[/\-].*|\1|p')
    VALID_TYPES="feat fix docs style refactor perf test build ci chore revert"
    if [ -n "$BRANCH_PREFIX" ]; then
        if ! echo " $VALID_TYPES " | grep -q " $BRANCH_PREFIX "; then
            echo "⚠️  Branch prefix '$BRANCH_PREFIX' is not a valid semantic type."
            echo "   Valid types: $VALID_TYPES"
            echo "   PR title must match: <type>(<optional scope>): <description>"
            echo ""
        fi
    fi
fi

# ARB locale consistency (mirrors CI's test/l10n/arb_consistency_test.dart).
# ARB files are non-dart, so the changed-Dart filter below never sees them and
# an ARB-only push would hit the "No Dart files changed" early-exit — hence the
# separate detection here, ahead of that exit. The test asserts every app_*.arb
# locale defines the same keys as app_en.arb (minus _knownUntranslatedDebt).
CHANGED_ARB_FILES=$(git -C "$REPO_ROOT" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^mobile/lib/l10n/app_.*\.arb$' || true)
if [ -n "$CHANGED_ARB_FILES" ]; then
    echo "ARB locale files changed; checking locale consistency..."
    if ! mise exec -- flutter test test/l10n/arb_consistency_test.dart 2>&1; then
        echo ""
        echo "ARB locale consistency check failed!"
        echo "Mirror the app_en.arb key into every other app_*.arb locale (or add"
        echo "it to _knownUntranslatedDebt in test/l10n/arb_consistency_test.dart),"
        echo "then re-run: cd mobile && mise exec -- flutter test test/l10n/arb_consistency_test.dart"
        exit 1
    fi
    echo "ARB locale consistency OK"
    echo ""
fi

# Untested-services floor (mirrors CI's check_untested_services_floor.sh).
# The floor invariant covers ANY service file under lib/services (generated
# excluded), and a NEW offender appears not only when a service is added but
# also when a same-named test is deleted/renamed away. Mirror that here: trigger
# on any added/deleted/renamed mobile/lib/services/*.dart OR any deleted/renamed
# mobile/test/**/*_test.dart, then run the check READ-ONLY (no UPDATE_BASELINE) —
# the check does the full baseline comparison (NEW/STALE/GROWTH) and fails
# closed. Ratcheting the baseline stays a deliberate, manual author step. The
# trigger stays conditional so unrelated pushes are not slowed. The detector is
# a Dart script, so run it under the pinned SDK like every other Dart call here.
CHANGED_SERVICE_FILES=$(git -C "$REPO_ROOT" diff --name-only --diff-filter=ADR "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^mobile/lib/services/.*\.dart$' \
    | grep -vE '\.(g|mocks)\.dart$' || true)
CHANGED_TEST_FILES=$(git -C "$REPO_ROOT" diff --name-only --diff-filter=DR "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^mobile/test/.*_test\.dart$' || true)
if [ -n "$CHANGED_SERVICE_FILES" ] || [ -n "$CHANGED_TEST_FILES" ]; then
    echo "Service/test file(s) changed; checking untested-services floor..."
    if ! mise exec -- bash "$REPO_ROOT/mobile/scripts/check_untested_services_floor.sh"; then
        echo ""
        echo "Untested-services floor check failed!"
        echo "If it reported a NEW untested service: add a same-named *_test.dart"
        echo "for the service, or a <service>_<aspect>_test.dart that imports it"
        echo "(or delete the dead service), then ratchet the baseline:"
        echo "  UPDATE_BASELINE=1 mise exec -- bash mobile/scripts/check_untested_services_floor.sh"
        echo "If it reported 'baseline GREW vs origin/main': your branch is behind an"
        echo "origin/main that shrank the baseline — rebase instead of running"
        echo "UPDATE_BASELINE (which would re-add the offending entries from your"
        echo "stale checkout):"
        echo "  git fetch origin main && git rebase origin/main"
        exit 1
    fi
    echo "Untested-services floor OK"
    echo ""
fi

# Exception-safe error-handler restores in integration_test (mirrors CI's
# check_integration_test_error_restore_safety.sh, #5839). Trigger on any
# added/modified/deleted mobile/integration_test/*.dart so unrelated pushes are
# not slowed.
CHANGED_IT_FILES=$(git -C "$REPO_ROOT" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^mobile/integration_test/.*\.dart$' || true)
if [ -n "$CHANGED_IT_FILES" ]; then
    echo "integration_test file(s) changed; checking error-handler restore safety..."
    if ! bash "$REPO_ROOT/mobile/scripts/check_integration_test_error_restore_safety.sh"; then
        echo ""
        echo "Exception-unsafe ErrorWidget.builder/FlutterError.onError restore in"
        echo "integration_test (#5839). Restore onError via addTearDown; restore"
        echo "ErrorWidget.builder BOTH inline (framework verify) AND via addTearDown"
        echo "(throw path). See test/integration_test_error_restore_contract_test.dart."
        exit 1
    fi
    echo "integration_test error-handler restore safety OK"
    echo ""
fi

# Package CI floor (mirrors CI's check_package_ci_floor.sh). Every package
# under mobile/packages must ship its own analysis_options.yaml and a
# per-package workflow (exceptions live in the shrink-only baseline). Trigger
# on added/deleted/renamed package pubspecs or options files, or any workflow
# file change, so unrelated pushes are not slowed.
CHANGED_PKG_CI_FILES=$(git -C "$REPO_ROOT" diff --name-only --diff-filter=ADR "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^(mobile/packages/[^/]+/(pubspec|analysis_options)\.yaml|\.github/workflows/[^/]+\.(yaml|yml))$' || true)
if [ -n "$CHANGED_PKG_CI_FILES" ]; then
    echo "Package/workflow file(s) changed; checking package CI floor..."
    if ! bash "$REPO_ROOT/mobile/scripts/check_package_ci_floor.sh"; then
        echo ""
        echo "Package CI floor check failed!"
        echo "Every package needs its own analysis_options.yaml and a"
        echo ".github/workflows/<pkg>.yaml. After removing an exception, shrink"
        echo "the baseline:"
        echo "  UPDATE_BASELINE=1 bash mobile/scripts/check_package_ci_floor.sh"
        exit 1
    fi
    echo "Package CI floor OK"
    echo ""
fi

# Package coverage floor (mirrors CI's check_package_coverage_floor.sh). Each
# per-package workflow's min_coverage is locked in a baseline and may only rise.
# Trigger on any workflow file change or a coverage-baseline edit so unrelated
# pushes are not slowed.
CHANGED_COV_FLOOR_FILES=$(git -C "$REPO_ROOT" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^(\.github/workflows/[^/]+\.(yaml|yml)|mobile/scripts/baseline/package_coverage_floors\.txt)$' || true)
if [ -n "$CHANGED_COV_FLOOR_FILES" ]; then
    echo "Workflow/coverage-baseline file(s) changed; checking package coverage floor..."
    if ! bash "$REPO_ROOT/mobile/scripts/check_package_coverage_floor.sh"; then
        echo ""
        echo "Package coverage floor check failed!"
        echo "Per-package min_coverage floors may only rise. If you intentionally"
        echo "raised one, set the workflow's min_coverage to the new measured"
        echo "coverage, then re-lock the baseline:"
        echo "  UPDATE_BASELINE=1 bash mobile/scripts/check_package_coverage_floor.sh"
        echo "If it reported 'LOWERED vs origin/main': your branch is behind an"
        echo "origin/main that raised a floor — rebase instead of re-baselining:"
        echo "  git fetch origin main && git rebase origin/main"
        exit 1
    fi
    echo "Package coverage floor OK"
    echo ""
fi

# Backend-host default guard (mirrors CI's check_backend_host_defaults.sh).
# Backend *defaults* — app_config.dart `*BaseUrl` defaults + workflow
# `--dart-define=<KEY>URL=` injects — must stay on *.divine.video. Trigger on
# app_config.dart or any workflow yaml change so unrelated pushes are not slowed.
CHANGED_HOST_CFG=$(git -C "$REPO_ROOT" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^(mobile/lib/config/app_config\.dart|\.github/workflows/[^/]+\.(yaml|yml))$' || true)
if [ -n "$CHANGED_HOST_CFG" ]; then
    echo "Config/workflow host file(s) changed; checking backend-host defaults..."
    if ! bash "$REPO_ROOT/mobile/scripts/check_backend_host_defaults.sh"; then
        echo ""
        echo "Backend-host default guard failed — a backend default is off"
        echo "*.divine.video. Fix it, or add a tracked exemption to the ALLOWED"
        echo "block in mobile/scripts/check_backend_host_defaults.sh."
        exit 1
    fi
    echo "Backend-host defaults OK"
    echo ""
fi

# Codemagic variable group guard (mirrors CI's check_codemagic_groups.sh).
# Every group named under a workflow's `groups:` key must appear in the setup
# checklist at the top of codemagic.yaml. Codemagic validates the whole file
# before provisioning, so an undeclared group fails every workflow in it and no
# in-script guard can catch it — that took the pipeline down for ~21 hours
# (#7203). Trigger only on codemagic.yaml so unrelated pushes are not slowed.
CHANGED_CODEMAGIC=$(git -C "$REPO_ROOT" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep -E '^codemagic\.yaml$' || true)
if [ -n "$CHANGED_CODEMAGIC" ]; then
    echo "codemagic.yaml changed; checking variable groups..."
    if ! bash "$REPO_ROOT/mobile/scripts/check_codemagic_groups.sh"; then
        echo ""
        echo "Codemagic group guard failed — a referenced variable group is not"
        echo "documented in the setup checklist at the top of codemagic.yaml."
        echo "Create the group in the Codemagic project, then document it there."
        exit 1
    fi
    echo "Codemagic variable groups OK"
    echo ""
fi

# Get list of changed Dart files (excluding generated files)
CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep '^mobile/.*\.dart$' \
    | grep -vE '\.(g|mocks)\.dart$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No Dart files changed, skipping checks"
    exit 0
fi

echo "Changed files:"
echo "$CHANGED_FILES" | head -10
TOTAL_CHANGED=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
if [ "$TOTAL_CHANGED" -gt 10 ]; then
    echo "   ... and $((TOTAL_CHANGED - 10)) more"
fi
echo ""

# Run flutter analyze (mirrors CI)
echo "Running analyzer..."
if ! mise exec -- flutter analyze lib test integration_test; then
    echo ""
    echo "Analysis failed!"
    echo "Fix the issues above before pushing."
    exit 1
fi
echo "Analysis OK"
echo ""

# Mirror CI's generated-file check for codegen inputs
CODEGEN_INPUTS=$(printf '%s\n' "$CHANGED_FILES" | list_codegen_inputs)
if [ -n "$CODEGEN_INPUTS" ]; then
    BEFORE_STATUS_FILE=$(mktemp)
    AFTER_STATUS_FILE=$(mktemp)
    trap 'rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"' EXIT

    capture_generated_status > "$BEFORE_STATUS_FILE"

    echo "Verifying generated files..."
    mise exec -- dart run build_runner build --delete-conflicting-outputs >/dev/null

    capture_generated_status > "$AFTER_STATUS_FILE"
    NEW_GENERATED_CHANGES=$(comm -13 "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE" || true)

    rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"
    trap - EXIT

    if [ -n "$NEW_GENERATED_CHANGES" ]; then
        echo ""
        echo "Generated files are out of date."
        echo "Run: cd mobile && mise exec -- dart run build_runner build --delete-conflicting-outputs"
        echo "Then commit the generated files before pushing."
        echo ""
        echo "$NEW_GENERATED_CHANGES"
        exit 1
    fi

    echo "Generated files OK"
    echo ""
fi

# Find corresponding test files
TEST_FILES=""

for file in $CHANGED_FILES; do
    # test/goldens/ is owned by CI's Goldens job, which runs the whole
    # directory. It is skipped here because the image goldens in it compare
    # against Ubuntu-rendered references, and Skia antialiases differently
    # per OS (2.7-3.7% of pixels, all on glyph edges) — on a Mac they fail
    # every time, and the hook diffs origin/main...HEAD, so every push would
    # re-run them, not just golden-touching ones. The directory also holds a
    # layout-only test that would pass here; it is skipped too rather than
    # teaching the hook which files carry references. Run
    # `mobile/scripts/golden.sh verify` by hand for the structural signal;
    # see mobile/docs/GOLDEN_TESTING_GUIDE.md.
    if [[ "$file" == mobile/test/goldens/* ]]; then
        continue
    fi

    # If it's already a test file, add it directly
    if [[ "$file" == *"_test.dart" ]]; then
        if [ -f "$REPO_ROOT/$file" ]; then
            TEST_FILES="$TEST_FILES $file"
        fi
        continue
    fi

    # Skip non-lib files
    if [[ "$file" != mobile/lib/* ]]; then
        continue
    fi

    # Try standard test path: lib/foo.dart -> test/foo_test.dart
    test_file=$(echo "$file" | sed 's|mobile/lib/|mobile/test/|' | sed 's|\.dart$|_test.dart|')
    if [ -f "$REPO_ROOT/$test_file" ]; then
        TEST_FILES="$TEST_FILES $test_file"
        continue
    fi

    # Try unit test path: lib/foo.dart -> test/unit/foo_test.dart
    test_file=$(echo "$file" | sed 's|mobile/lib/|mobile/test/unit/|' | sed 's|\.dart$|_test.dart|')
    if [ -f "$REPO_ROOT/$test_file" ]; then
        TEST_FILES="$TEST_FILES $test_file"
        continue
    fi
done

# Remove duplicates, strip mobile/ prefix, and exclude integration tests
# (integration tests require an emulator and can't mix with unit tests --
# `flutter test` refuses the mixed invocation outright, so a changed file under
# integration_test_manual/ used to fail the whole hook)
TEST_FILES=$(echo "$TEST_FILES" | tr ' ' '\n' | sort -u | sed 's|^mobile/||' | grep -v '^$' | grep -vE '^integration_test(_manual)?/' || true)

if [ -z "$TEST_FILES" ]; then
    echo "No corresponding test files found for changed files"
    echo "Consider adding tests for your changes!"
    echo ""
    exit 0
fi

echo "Running tests for changed files:"
echo "$TEST_FILES" | head -5
TEST_COUNT=$(echo "$TEST_FILES" | wc -l | tr -d ' ')
if [ "$TEST_COUNT" -gt 5 ]; then
    echo "   ... and $((TEST_COUNT - 5)) more test files"
fi
echo ""

echo "Executing tests..."
if mise exec -- flutter test $TEST_FILES 2>&1; then
    echo ""
    echo "All tests passed!"
else
    echo ""
    echo "Tests failed!"
    echo "Fix the failing tests before pushing."
    echo ""
    echo "To skip this check (not recommended): git push --no-verify"
    exit 1
fi
EOF

install_hook "$PREPUSH_TMP" "$HOOKS_DIR/pre-push"

echo "Git hooks installed!"
echo ""
echo "Pre-commit: format check, flutter analyze, codegen verification"
echo "Pre-push:   merge conflict check, codegen verification, ARB locale consistency,"
echo "            untested-services floor, tests for changed files"
echo ""
echo "To bypass hooks (not recommended): --no-verify"
