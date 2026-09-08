#!/bin/bash
# Regression checks for repository Codex hooks and generated skills.

set -e
trap 'echo "test-config.sh failed at line $LINENO: $BASH_COMMAND" >&2' ERR

REPO_ROOT=$(git rev-parse --show-toplevel)
POST_EDIT_HOOK="$REPO_ROOT/.codex/hooks/post-edit-dart.sh"
BUILD_HOOK="$REPO_ROOT/.codex/hooks/pre-commit-build-runner.sh"
CODEX_GIT_HOOK="$REPO_ROOT/.codex/hooks/check-git-hooks.sh"
CLAUDE_GIT_HOOK="$REPO_ROOT/.claude/hooks/check-git-hooks.sh"
WORKTREE_GUARD_HOOK="$REPO_ROOT/.claude/hooks/session-start-worktree-guard.sh"
CLAUDE_PURGE_HOOK="$REPO_ROOT/.claude/hooks/session-end-purge-build-artifacts.sh"
CLAUDE_ANALYZE_HOOK="$REPO_ROOT/.claude/hooks/post-edit-analyze.sh"
CLAUDE_SETTINGS="$REPO_ROOT/.claude/settings.json"
CODEX_HOOKS="$REPO_ROOT/.codex/hooks.json"

SCRATCH_DIR=$(mktemp -d "${TMPDIR:-/tmp}/divine-codex-hooks.XXXXXX")
trap 'rm -rf "$SCRATCH_DIR"' EXIT

"$REPO_ROOT/.codex/scripts/sync-agent-skills.sh" --check

hook_timeout() {
  local config=$1
  local hook_name=$2

  jq -er --arg hook_name "$hook_name" '
    [.hooks | .[] | .[] | .hooks[]
      | select(.command | test("/" + $hook_name + "\\\"?$"))
      | .timeout]
    | if length == 1 then .[0]
      else error("expected exactly one registration for " + $hook_name)
      end
  ' "$config"
}

validate_hook_configs() {
  local claude_settings=$1
  local codex_hooks=$2
  local repo_root=$3
  local config_name config_path hook_cmd hook_path missing_timeouts bad_timeouts
  local claude_timeout codex_timeout claude_format_timeout claude_analyze_timeout
  local hook_name registered_hooks expected_hooks
  local parity_hooks=(
    pre-edit-nostr-id-guard.sh
    pre-edit-vinetheme-guard.sh
    check-git-hooks.sh
    pre-commit-build-runner.sh
  )
  local client_hooks

  # A registration pointing at a missing file must fail loudly here rather
  # than being silently skipped when a hook event fires.
  for config_name in Claude Codex; do
    if [ "$config_name" = Claude ]; then
      config_path=$claude_settings
    else
      config_path=$codex_hooks
    fi

    while IFS= read -r hook_cmd; do
      # Match the literal config command prefixes, not the current shell env.
      # shellcheck disable=SC2016
      case "$config_name:$hook_cmd" in
        'Claude:"$CLAUDE_PROJECT_DIR"'/*)
          hook_path=${hook_cmd#'"$CLAUDE_PROJECT_DIR"'}
          ;;
        'Codex:"$(git rev-parse --show-toplevel)'/*'"')
          hook_path=${hook_cmd#'"$(git rev-parse --show-toplevel)'}
          hook_path=${hook_path%'"'}
          ;;
        *)
          echo "Unrecognized $config_name hook command shape: $hook_cmd" >&2
          return 1
          ;;
      esac
      if [ ! -x "$repo_root$hook_path" ]; then
        echo "Registered $config_name hook is missing or not executable: $hook_cmd" >&2
        return 1
      fi
    done < <(jq -er '.hooks | .[] | .[] | .hooks[].command' "$config_path")

    missing_timeouts=$(jq -r '.hooks | .[] | .[] | .hooks[]
      | select(.timeout == null)
      | .command' "$config_path")
    if [ -n "$missing_timeouts" ]; then
      echo "Every $config_name hook must declare an explicit timeout; missing on: $missing_timeouts" >&2
      return 1
    fi

    bad_timeouts=$(jq -r '.hooks | .[] | .[] | .hooks[].timeout' "$config_path" \
      | awk '$1 !~ /^[0-9]+$/ || $1 < 1 || $1 > 600 { print }')
    if [ -n "$bad_timeouts" ]; then
      echo "$config_name hook timeouts must be whole seconds from 1 through 600: got $bad_timeouts" >&2
      return 1
    fi
  done

  # The clients register hooks differently, so parity is an explicit policy,
  # not blanket config equality. Codex combines Claude's independently budgeted
  # format and analyze hooks, hence the sum for post-edit-dart.
  for hook_name in "${parity_hooks[@]}"; do
    claude_timeout=$(hook_timeout "$claude_settings" "$hook_name") || return 1
    codex_timeout=$(hook_timeout "$codex_hooks" "$hook_name") || return 1
    if [ "$codex_timeout" -ne "$claude_timeout" ]; then
      echo "Hook timeout diverged for $hook_name: Claude=$claude_timeout Codex=$codex_timeout" >&2
      return 1
    fi
  done

  claude_format_timeout=$(hook_timeout "$claude_settings" post-edit-format.sh) || return 1
  claude_analyze_timeout=$(hook_timeout "$claude_settings" post-edit-analyze.sh) || return 1
  codex_timeout=$(hook_timeout "$codex_hooks" post-edit-dart.sh) || return 1
  claude_timeout=$((claude_format_timeout + claude_analyze_timeout))
  if [ "$codex_timeout" -ne "$claude_timeout" ]; then
    echo "Combined post-edit timeout diverged: Claude=$claude_timeout Codex=$codex_timeout" >&2
    return 1
  fi

  # Every new registration needs an explicit parity or client-only decision.
  # Claude's cleanup hook deliberately has no Codex counterpart.
  for config_name in Claude Codex; do
    if [ "$config_name" = Claude ]; then
      config_path=$claude_settings
      client_hooks=(post-edit-format.sh post-edit-analyze.sh session-end-purge-build-artifacts.sh)
    else
      config_path=$codex_hooks
      client_hooks=(post-edit-dart.sh)
    fi
    registered_hooks=$(jq -r '.hooks | .[] | .[] | .hooks[]
      | .command | split("/")[-1] | rtrimstr("\"")' "$config_path" | LC_ALL=C sort)
    expected_hooks=$(printf '%s\n' "${parity_hooks[@]}" "${client_hooks[@]}" | LC_ALL=C sort)
    if [ "$registered_hooks" != "$expected_hooks" ]; then
      echo "$config_name hook registrations changed; update the timeout parity policy." >&2
      return 1
    fi
  done
}

validate_hook_configs "$CLAUDE_SETTINGS" "$CODEX_HOOKS" "$REPO_ROOT"

jq -e '.hooks.SessionEnd[]
  | select(.matcher == "logout|prompt_input_exit|bypass_permissions_disabled")
  | .hooks[]
  | select(.command | endswith("session-end-purge-build-artifacts.sh"))' \
  "$CLAUDE_SETTINGS" >/dev/null || {
  echo "SessionEnd purge hook registration is missing or its matcher changed." >&2
  exit 1
}

# Prove the validation detects both historical timeout values and a broken
# registration instead of merely passing the checked-in configuration.
CONFIG_TEST_DIR="$SCRATCH_DIR/config"
mkdir -p "$CONFIG_TEST_DIR"

expect_invalid_hook_config() {
  local description=$1
  local claude_fixture=$2
  local codex_fixture=$3

  if validate_hook_configs \
    "$claude_fixture" "$codex_fixture" "$REPO_ROOT" \
    >/dev/null 2>&1; then
    echo "Hook validation accepted $description." >&2
    exit 1
  fi
}

jq '(.hooks.PreToolUse[].hooks[]
  | select(.command | endswith("/pre-commit-build-runner.sh\""))
  | .timeout) = 120' "$CODEX_HOOKS" > "$CONFIG_TEST_DIR/build-timeout.json"
expect_invalid_hook_config \
  "the historical 120s build-runner timeout" \
  "$CLAUDE_SETTINGS" \
  "$CONFIG_TEST_DIR/build-timeout.json"

jq '(.hooks.PostToolUse[].hooks[]
  | select(.command | endswith("/post-edit-dart.sh\""))
  | .timeout) = 60' "$CODEX_HOOKS" > "$CONFIG_TEST_DIR/post-edit-timeout.json"
expect_invalid_hook_config \
  "the historical 60s post-edit timeout" \
  "$CLAUDE_SETTINGS" \
  "$CONFIG_TEST_DIR/post-edit-timeout.json"

jq '(.hooks.PostToolUse[].hooks[]
  | select(.command | endswith("/post-edit-dart.sh\""))
  | .command) |= sub("post-edit-dart\\.sh"; "missing-post-edit-dart.sh")' \
  "$CODEX_HOOKS" > "$CONFIG_TEST_DIR/missing-hook.json"
expect_invalid_hook_config \
  "a registration whose script is missing" \
  "$CLAUDE_SETTINGS" \
  "$CONFIG_TEST_DIR/missing-hook.json"

for config_name in Claude Codex; do
  if [ "$config_name" = Claude ]; then
    config_path=$CLAUDE_SETTINGS
  else
    config_path=$CODEX_HOOKS
  fi
  for mutation in \
    '.hooks.PreToolUse[0].hooks[0].timeout = 0' \
    '.hooks.PreToolUse[0].hooks[0].timeout = 601' \
    'del(.hooks.PostToolUse)' \
    '.hooks.PreToolUse[0].hooks[0].command |= sub("pre-edit-nostr-id-guard"; "missing-hook")'; do
    jq "$mutation" "$config_path" > "$CONFIG_TEST_DIR/invalid.json"
    if [ "$config_name" = Claude ]; then
      expect_invalid_hook_config "$config_name $mutation" \
        "$CONFIG_TEST_DIR/invalid.json" "$CODEX_HOOKS"
    else
      expect_invalid_hook_config "$config_name $mutation" \
        "$CLAUDE_SETTINGS" "$CONFIG_TEST_DIR/invalid.json"
    fi
  done
done

# Keep parity satisfied so only the positive-timeout rule rejects zero.
jq '(.hooks | .[] | .[] | .hooks[].timeout) = 0' \
  "$CLAUDE_SETTINGS" > "$CONFIG_TEST_DIR/zero-claude.json"
jq '(.hooks | .[] | .[] | .hooks[].timeout) = 0' \
  "$CODEX_HOOKS" > "$CONFIG_TEST_DIR/zero-codex.json"
expect_invalid_hook_config "zero timeouts despite matching budgets" \
  "$CONFIG_TEST_DIR/zero-claude.json" "$CONFIG_TEST_DIR/zero-codex.json"

# Use an existing executable that is not a registered hook. A new pair must
# require an explicit parity decision even when both paths are executable.
for config_path in "$CLAUDE_SETTINGS" "$CODEX_HOOKS"; do
  jq '.hooks.PreToolUse[0].hooks += [
    (.hooks.PreToolUse[0].hooks[0]
      | .command |= sub("hooks/pre-edit-nostr-id-guard.sh"; "scripts/sync-agent-skills.sh")
      | .command |= sub(".claude/"; ".codex/")
      | .timeout = 10)
    ]' "$config_path" > "$CONFIG_TEST_DIR/$(basename "$config_path")"
done
jq '.hooks.PreToolUse[0].hooks[-1].timeout = 599' \
  "$CONFIG_TEST_DIR/hooks.json" > "$CONFIG_TEST_DIR/new-codex-hook.json"
expect_invalid_hook_config "a new hook pair without a parity policy" \
  "$CONFIG_TEST_DIR/settings.json" "$CONFIG_TEST_DIR/new-codex-hook.json"
expect_invalid_hook_config "a new Codex-only hook without a parity policy" \
  "$CLAUDE_SETTINGS" "$CONFIG_TEST_DIR/new-codex-hook.json"

# shellcheck disable=SC2016
grep -Fq 'Read and apply ALL rules from `AGENTS.md`' \
  "$REPO_ROOT/.agents/skills/review-before-commit/SKILL.md"
if grep -Fq '/review-before-commit' \
  "$REPO_ROOT/.agents/skills/review-before-commit/SKILL.md"; then
  echo "Generated review skill still uses the Claude slash invocation." >&2
  exit 1
fi
if grep -Fq '.claude/AGENTS.md' \
  "$REPO_ROOT/.agents/skills/review-before-commit/SKILL.md"; then
  echo "Generated review skill points to a nonexistent .claude/AGENTS.md." >&2
  exit 1
fi
grep -Fq '**Published**: May 2023<br>' \
  "$REPO_ROOT/.agents/skills/claudeception/resources/research-references.md"
# shellcheck disable=SC2088
grep -Fq '~/.agents/skills/art-direct/styles/' \
  "$REPO_ROOT/.agents/skills/art-direct/docs/2026-01-28-art-direct-design.md"

TEST_REPO="$SCRATCH_DIR/repo"
BIN_DIR="$SCRATCH_DIR/bin"
CALL_LOG="$SCRATCH_DIR/dart-calls.log"
mkdir -p "$TEST_REPO/mobile/lib" "$BIN_DIR"

git -C "$TEST_REPO" init -q

touch "$TEST_REPO/mobile/mise.toml"
mkdir -p "$TEST_REPO/mobile/.dart_tool"
touch "$TEST_REPO/mobile/.dart_tool/package_config.json"
cat > "$TEST_REPO/mobile/pubspec.yaml" <<'EOF'
name: codex_hook_test
environment:
  sdk: ^3.0.0
EOF
cat > "$TEST_REPO/mobile/lib/warning file.dart" <<'EOF'
// ANALYZER_WARNING
void main() {}
EOF
cat > "$TEST_REPO/mobile/lib/clean.dart" <<'EOF'
void main() {}
EOF
cat > "$TEST_REPO/mobile/lib/info only.dart" <<'EOF'
// ANALYZER_INFO
void main() {}
EOF
cat > "$TEST_REPO/mobile/lib/with space.dart" <<'EOF'
@freezed
class GeneratedInput {}
EOF

cat > "$BIN_DIR/mise" <<'EOF'
#!/bin/bash
if [ "$1" != "exec" ] || [ "$2" != "--" ] || [ "$3" != "dart" ]; then
  exit 99
fi
shift 3
exec "$TEST_DART" "$@"
EOF
cat > "$BIN_DIR/test-dart" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$DART_CALL_LOG"
case "$1" in
  --version)
    exit 0
    ;;
  format)
    exit 0
    ;;
  analyze)
    if grep -q 'ANALYZER_WARNING' "$2"; then
      # Mirror real `dart analyze`: a header and footer around the diagnostic,
      # severity right-padded to 7 characters so `warning` sits at column 1.
      echo "Analyzing $2..."
      echo
      echo "warning - $2:1:1 - Test warning. - test_warning"
      echo
      echo "1 issue found."
      exit 2
    fi
    # Info-level diagnostics are reported with exit 0, so the severity match is
    # the only thing that can surface them.
    if grep -q 'ANALYZER_INFO' "$2"; then
      echo "Analyzing $2..."
      echo
      echo "   info - $2:1:1 - Test info. - test_info"
      echo
      echo "1 issue found."
      exit 0
    fi
    echo "No issues found!"
    exit 0
    ;;
  run)
    if [ "${BUILD_FAIL:-0}" = "1" ]; then
      echo "BUILD FAILED: simulated builder error"
      exit 1
    fi
    exit 0
    ;;
  *)
    exit 98
    ;;
esac
EOF
chmod +x "$BIN_DIR/mise" "$BIN_DIR/test-dart"
ln -sf "$BIN_DIR/test-dart" "$BIN_DIR/dart"

POST_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: mobile/lib/warning file.dart\n*** End Patch' \
  '{tool_input: {command: $command}}')
POST_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$POST_PAYLOAD")

if ! printf '%s\n' "$POST_OUTPUT" | jq -e \
  '.decision == "block"
   and (.reason | startswith("Analyzer diagnostics in"))
   and (.reason | contains("Test warning"))' >/dev/null; then
  echo "Post-edit hook did not surface a column-1 warning via the severity match." >&2
  echo "It fell back to the analyzer exit code, whose message also contains the" >&2
  echo "diagnostic text, so this assertion pins the severity-match path." >&2
  echo "Reason was: $(printf '%s' "$POST_OUTPUT" | jq -r '.reason // "<none>"')" >&2
  exit 1
fi
FORMAT_LINE=$(grep -n '^format ' "$CALL_LOG" | cut -d: -f1)
ANALYZE_LINE=$(grep -n '^analyze ' "$CALL_LOG" | cut -d: -f1)
if [ -z "$FORMAT_LINE" ] || [ -z "$ANALYZE_LINE" ] || [ "$FORMAT_LINE" -ge "$ANALYZE_LINE" ]; then
  echo "Post-edit hook did not format before analyzing." >&2
  exit 1
fi

INFO_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: mobile/lib/info only.dart\n*** End Patch' \
  '{tool_input: {command: $command}}')
INFO_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$INFO_PAYLOAD")

if ! printf '%s\n' "$INFO_OUTPUT" | jq -e \
  '.decision == "block" and (.reason | contains("info -"))' >/dev/null; then
  echo "Post-edit hook did not block info-level diagnostics reported with exit 0." >&2
  exit 1
fi

# A file with no diagnostics must not block, or every edit stalls.
CLEAN_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: mobile/lib/clean.dart\n*** End Patch' \
  '{tool_input: {command: $command}}')
CLEAN_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$CLEAN_PAYLOAD")

if [ -n "$CLEAN_OUTPUT" ]; then
  echo "Post-edit hook blocked a file with no diagnostics: $CLEAN_OUTPUT" >&2
  exit 1
fi

NON_DART_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: README.md\n*** End Patch' \
  '{tool_input: {command: $command}}')
NON_DART_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="/usr/bin:/bin" "$POST_EDIT_HOOK" <<< "$NON_DART_PAYLOAD")
if [ -n "$NON_DART_OUTPUT" ]; then
  echo "Non-Dart edit unexpectedly required a Dart toolchain." >&2
  exit 1
fi

# The no-toolchain path must be exercised with mise and dart both hidden:
# dev machines commonly install mise system-wide (e.g. /usr/bin/mise), and
# then it resolves a real dart, analyzes the fixture, and emits no block —
# failing this test before the purge-hook tests below ever run. Pin the PATH
# to a scratch bin holding only the tools the hook needs when no SDK resolves.
NO_TOOLCHAIN_BIN="$SCRATCH_DIR/no-toolchain-bin"
mkdir -p "$NO_TOOLCHAIN_BIN"
for tool in jq git sed grep cat dirname basename; do
  ln -s "$(command -v "$tool")" "$NO_TOOLCHAIN_BIN/$tool"
done
MISSING_DART_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$NO_TOOLCHAIN_BIN" "$POST_EDIT_HOOK" <<< "$POST_PAYLOAD")
printf '%s\n' "$MISSING_DART_OUTPUT" | jq -e \
  '.decision == "block" and (.reason | contains("Unable to run the repository Dart SDK"))' >/dev/null

rm -f "$TEST_REPO/mobile/.dart_tool/package_config.json"
: > "$CALL_LOG"
TWO_FILE_PURGED_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: mobile/lib/warning file.dart\n*** Update File: mobile/lib/clean.dart\n*** End Patch' \
  '{tool_input: {command: $command}}')
CODEX_PURGED_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$TWO_FILE_PURGED_PAYLOAD")
if ! printf '%s\n' "$CODEX_PURGED_OUTPUT" | jq -e \
  '.systemMessage
   | contains("Skipped Dart analysis")
     and contains("flutter pub get")' >/dev/null; then
  echo "Codex post-edit hook did not explain the missing package_config.json skip." >&2
  echo "Output was: $CODEX_PURGED_OUTPUT" >&2
  exit 1
fi
# Format needs no package resolution and must still run; only analyze skips.
if grep -q '^analyze ' "$CALL_LOG"; then
  echo "Codex post-edit hook invoked dart analyze without package_config.json." >&2
  exit 1
fi
if ! grep -q '^format ' "$CALL_LOG"; then
  echo "Codex post-edit hook skipped dart format, which needs no package_config.json." >&2
  exit 1
fi
# A skip must not abort the patch loop: both files still get formatted.
if [ "$(grep -c '^format ' "$CALL_LOG")" -ne 2 ]; then
  echo "Codex post-edit hook aborted the file loop at the first purged-worktree file." >&2
  exit 1
fi
touch "$TEST_REPO/mobile/.dart_tool/package_config.json"

CHAINED_COMMIT_PAYLOAD=$(jq -n --arg command '   git commit -m test && echo done' \
  '{tool_input: {command: $command}}')
CODEX_GIT_OUTPUT=$(cd "$TEST_REPO" && \
  "$CODEX_GIT_HOOK" <<< "$CHAINED_COMMIT_PAYLOAD")
CLAUDE_GIT_OUTPUT=$(cd "$TEST_REPO" && \
  env CLAUDE_PROJECT_DIR="$TEST_REPO" \
    "$CLAUDE_GIT_HOOK" <<< "$CHAINED_COMMIT_PAYLOAD")
printf '%s\n' "$CODEX_GIT_OUTPUT" | jq -e \
  '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null
printf '%s\n' "$CLAUDE_GIT_OUTPUT" | jq -e \
  '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null

git -C "$TEST_REPO" add "mobile/lib/with space.dart" mobile/pubspec.yaml
COMMIT_PAYLOAD=$(jq -n --arg command 'git commit -m test' \
  '{tool_input: {command: $command}}')
BUILD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    BUILD_FAIL=1 \
    "$BUILD_HOOK" <<< "$COMMIT_PAYLOAD" 2>"$SCRATCH_DIR/build-failure.stderr")

printf '%s\n' "$BUILD_OUTPUT" | jq -e '
  .hookSpecificOutput.hookEventName == "PreToolUse" and
  .hookSpecificOutput.permissionDecision == "deny" and
  (.hookSpecificOutput.permissionDecisionReason | contains("simulated builder error"))
' >/dev/null

cat > "$TEST_REPO/mobile/lib/with space.g.dart" <<'EOF'
// generated
EOF
SUCCESS_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    BUILD_FAIL=0 \
    "$BUILD_HOOK" <<< "$COMMIT_PAYLOAD" 2>"$SCRATCH_DIR/build-success.stderr")
if [ -n "$SUCCESS_OUTPUT" ]; then
  echo "Successful build hook wrote unexpected stdout: $SUCCESS_OUTPUT" >&2
  exit 1
fi
if ! git -C "$TEST_REPO" diff --cached --name-only \
  | grep -Fxq 'mobile/lib/with space.g.dart'; then
  echo "Generated file with a spaced path was not staged." >&2
  exit 1
fi

GUARD_SOCKET_DIR="$SCRATCH_DIR/cc-socks-test"
GUARD_SESSIONS_DIR="$SCRATCH_DIR/claude-sessions-test"
GUARD_BIN_DIR="$SCRATCH_DIR/guard-bin"
OTHER_REPO="$SCRATCH_DIR/other-repo"
mkdir -p "$GUARD_SOCKET_DIR" "$GUARD_SESSIONS_DIR" "$GUARD_BIN_DIR" "$OTHER_REPO"
git -C "$OTHER_REPO" init -q
python3 - "$GUARD_SOCKET_DIR" <<'PY'
import os
import socket
import sys

socket_dir = sys.argv[1]
for pid in ("111", "222", "333", "444", "555", "666", "777"):
    path = os.path.join(socket_dir, f"{pid}.sock")
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.bind(path)
    finally:
        sock.close()
PY

cat > "$GUARD_BIN_DIR/ps" <<'EOF'
#!/bin/bash
case "$*" in
  "-eo pid=,comm=")
    cat <<'PSOUT'
111 /opt/homebrew/bin/claude
222 sleep
333 claude
444 claude
555 claude
666 claude
777 claude
999 claude
1010 claude
1011 claude
1012 node
PSOUT
    exit 0
    ;;
esac

if [ "$1" = "-o" ] && [ "$2" = "comm=" ] && [ "$3" = "-p" ]; then
  case "$4" in
    111) echo "/opt/homebrew/bin/claude"; exit 0 ;;
    222) echo "sleep"; exit 0 ;;
    333) echo "claude"; exit 0 ;;
    444) echo "claude"; exit 0 ;;
    555) echo "claude"; exit 0 ;;
    666) echo "claude"; exit 0 ;;
    777) echo "claude"; exit 0 ;;
    999) echo "claude"; exit 0 ;;
    1010) echo "claude"; exit 0 ;;
    1011) echo "claude"; exit 0 ;;
    1012) echo "node"; exit 0 ;;
    *) echo "bash"; exit 0 ;;
  esac
fi

if [ "$1" = "-o" ] && [ "$2" = "lstart=" ] && [ "$3" = "-p" ]; then
  # Real `ps -o lstart=` renders through LC_TIME and TZ, while Claude records
  # procStart with LC_ALL=C and TZ=UTC. Match that rendering only when the guard
  # pinned both, so an unpinned locale or timezone fails the suite instead of
  # silently emptying the registry path.
  if [ "${LC_ALL:-}" != "C" ]; then
    printf ' Sa.  5 Sep. 21:24:30 2026 \n'
  elif [ "${TZ:-}" != "UTC" ]; then
    printf ' Sun Sep  6 02:24:30 2026 \n'
  else
    printf ' Sat Sep  5 21:24:30 2026 \n'
  fi
  exit 0
fi

if [ "$1" = "-o" ] && [ "$2" = "ppid=" ] && [ "$3" = "-p" ]; then
  case "$4" in
    777) echo "1"; exit 0 ;;
    *) echo "777"; exit 0 ;;
  esac
fi

exit 1
EOF

cat > "$GUARD_BIN_DIR/lsof" <<'EOF'
#!/bin/bash
pid=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-p" ]; then
    pid="$2"
    break
  fi
  shift
done

case "$pid" in
  111) printf 'n%s\n' "$TEST_REPO" ;;
  222) printf 'n%s\n' "$TEST_REPO" ;;
  333) printf 'n%s\n' "$TEST_REPO/mobile" ;;
  444) printf 'n%s\n' "$OTHER_REPO" ;;
  555) printf 'n%s\n' "$TEST_REPO" ;;
  666) printf 'n%s\n' "$TEST_REPO" ;;
  777) printf 'n%s\n' "$TEST_REPO" ;;
  1010) printf 'n%s\n' "$TEST_REPO" ;;
  1012) printf 'n%s\n' "$TEST_REPO" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$GUARD_BIN_DIR/ps" "$GUARD_BIN_DIR/lsof"

cat > "$GUARD_SESSIONS_DIR/111.json" <<EOF
{"pid":111,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"busy","name":"same\\nroot"}
EOF
cat > "$GUARD_SESSIONS_DIR/333.json" <<EOF
{"pid":333,"cwd":"$OTHER_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"idle","name":"moved-session"}
EOF
cat > "$GUARD_SESSIONS_DIR/444.json" <<EOF
{"pid":444,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli"}
EOF
cat > "$GUARD_SESSIONS_DIR/555.json" <<EOF
{"pid":555,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"sdk-cli","status":"busy","name":"sdk-agent"}
EOF
cat > "$GUARD_SESSIONS_DIR/666.json" <<EOF
{"pid":666,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 20:00:00 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"busy","name":"reused-pid"}
EOF
cat > "$GUARD_SESSIONS_DIR/777.json" <<EOF
{"pid":777,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"busy","name":"self"}
EOF
cat > "$GUARD_SESSIONS_DIR/999.json" <<EOF
{"pid":999,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"idle","name":"active-only"}
EOF
cat > "$GUARD_SESSIONS_DIR/1010.json" <<EOF
{"pid":1010,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"headless","entrypoint":"cli","status":"busy","name":"non-interactive"}
EOF
cat > "$GUARD_SESSIONS_DIR/1011.json" <<EOF
{"pid":1011,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":1,"kind":"interactive","entrypoint":"cli","status":"busy","name":"bad-version"}
EOF
cat > "$GUARD_SESSIONS_DIR/1012.json" <<EOF
{"pid":1012,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"busy","name":"not-claude"}
EOF
printf '{not valid json\n' > "$GUARD_SESSIONS_DIR/888.json"

REGISTRY_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env -u LC_ALL -u TZ PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$GUARD_SESSIONS_DIR" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")

if ! printf '%s\n' "$REGISTRY_GUARD_OUTPUT" | jq -e '
  .systemMessage
  | contains("4 other Claude sessions have a launch or active session root associated with this worktree")
    and contains("same root, pid 111 (busy): launch and session roots both match this worktree")
    and contains("moved-session, pid 333 (idle): launched here, now working in")
    and contains("likely not a conflict, but it can still write here by absolute path")
    and contains("pid 444: now working here after launching from")
    and contains("active worktree match")
    and contains("active-only, pid 999 (idle): active session root matches this worktree; launch root is unavailable")
    and (contains("pid 222") | not)
    and (contains("pid 555") | not)
    and (contains("pid 666") | not)
    and (contains("pid 777") | not)
    and (contains("pid 1010") | not)
    and (contains("pid 1011") | not)
    and (contains("pid 1012") | not)
' >/dev/null; then
  echo "Session worktree guard did not classify registry launch and active roots correctly." >&2
  echo "Output was: $REGISTRY_GUARD_OUTPUT" >&2
  exit 1
fi

# An absent registry preserves the older socket-and-launch-cwd behavior.
LEGACY_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$SCRATCH_DIR/missing-sessions" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")

if ! printf '%s\n' "$LEGACY_GUARD_OUTPUT" | jq -e '
  .systemMessage
  | contains("a launch root matching this worktree according to the legacy socket fallback")
    and contains("pid 111")
    and contains("pid 333")
    and contains("pid 555")
    and contains("pid 666")
    and (contains("pid 222") | not)
    and (contains("pid 444") | not)
    and (contains("pid 777") | not)
' >/dev/null; then
  echo "Session worktree guard did not retain its legacy socket fallback." >&2
  echo "Output was: $LEGACY_GUARD_OUTPUT" >&2
  exit 1
fi

# Claude may leave the registry directory present but empty after all other
# sessions exit. Bash 3.2 must treat that exactly like an absent registry.
EMPTY_SESSIONS_DIR="$SCRATCH_DIR/empty-claude-sessions"
mkdir -p "$EMPTY_SESSIONS_DIR"
EMPTY_REGISTRY_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$EMPTY_SESSIONS_DIR" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")
if ! printf '%s\n' "$EMPTY_REGISTRY_GUARD_OUTPUT" | jq -e \
  '.systemMessage | contains("legacy socket fallback")' >/dev/null; then
  echo "Session worktree guard did not fall back for an empty registry." >&2
  echo "Output was: $EMPTY_REGISTRY_GUARD_OUTPUT" >&2
  exit 1
fi

# Parseable registry records that fail host probes are not "supported": a
# single unpinned locale used to take this path, and an older peer with only a
# socket would stay invisible. Fall back instead of going silent.
PROBE_MISMATCH_SESSIONS_DIR="$SCRATCH_DIR/probe-mismatch-claude-sessions"
mkdir -p "$PROBE_MISMATCH_SESSIONS_DIR"
cat > "$PROBE_MISMATCH_SESSIONS_DIR/111.json" <<EOF
{"pid":111,"cwd":"$TEST_REPO","procStart":"Sat Sep  5 20:00:00 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"busy","name":"stale-start"}
EOF
PROBE_MISMATCH_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$PROBE_MISMATCH_SESSIONS_DIR" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")
if ! printf '%s\n' "$PROBE_MISMATCH_GUARD_OUTPUT" | jq -e '
  .systemMessage
  | contains("legacy socket fallback")
    and contains("pid 111")
    and contains("pid 333")
    and (contains("stale-start") | not)
' >/dev/null; then
  echo "Session worktree guard did not fall back when registry probes failed." >&2
  echo "Output was: $PROBE_MISMATCH_GUARD_OUTPUT" >&2
  exit 1
fi

# A confirmed live record that does not match this worktree must stay silent
# and must not fall through to the socket scan (false positives on peers the
# registry already classified as elsewhere).
ELSEWHERE_SESSIONS_DIR="$SCRATCH_DIR/elsewhere-claude-sessions"
mkdir -p "$ELSEWHERE_SESSIONS_DIR"
cat > "$ELSEWHERE_SESSIONS_DIR/444.json" <<EOF
{"pid":444,"cwd":"$OTHER_REPO","procStart":"Sat Sep  5 21:24:30 2026","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"idle","name":"elsewhere"}
EOF
ELSEWHERE_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$ELSEWHERE_SESSIONS_DIR" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")
if [ -n "$ELSEWHERE_GUARD_OUTPUT" ]; then
  echo "Session worktree guard fell back after confirming a non-matching registry peer." >&2
  echo "Output was: $ELSEWHERE_GUARD_OUTPUT" >&2
  exit 1
fi

# Linux Claude stores procStart as /proc starttime jiffies, not ps lstart text.
JIFFIES_SESSIONS_DIR="$SCRATCH_DIR/jiffies-claude-sessions"
JIFFIES_PROC_DIR="$SCRATCH_DIR/fake-proc"
mkdir -p "$JIFFIES_SESSIONS_DIR" "$JIFFIES_PROC_DIR/111"
cat > "$JIFFIES_SESSIONS_DIR/111.json" <<EOF
{"pid":111,"cwd":"$TEST_REPO","procStart":"174985782","version":"2.1.261","kind":"interactive","entrypoint":"cli","status":"busy","name":"linux-jiffies"}
EOF
printf '111 (claude) S 1 1 1 0 -1 0 0 0 0 0 0 0 0 0 20 0 1 0 174985782\n' \
  > "$JIFFIES_PROC_DIR/111/stat"
JIFFIES_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$JIFFIES_SESSIONS_DIR" \
    CLAUDE_PROC_STAT_DIR="$JIFFIES_PROC_DIR" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")
if ! printf '%s\n' "$JIFFIES_GUARD_OUTPUT" | jq -e '
  .systemMessage
  | contains("linux-jiffies, pid 111")
    and (contains("legacy socket fallback") | not)
' >/dev/null; then
  echo "Session worktree guard did not accept Linux jiffies procStart." >&2
  echo "Output was: $JIFFIES_GUARD_OUTPUT" >&2
  exit 1
fi

# Linux socket fallback lives under $XDG_RUNTIME_DIR/cc-socks, not /tmp.
XDG_RUNTIME="$SCRATCH_DIR/xdg-runtime"
mkdir -p "$XDG_RUNTIME/cc-socks"
python3 - "$XDG_RUNTIME/cc-socks" <<'PY'
import os, socket, sys
path = os.path.join(sys.argv[1], "111.sock")
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    sock.bind(path)
finally:
    sock.close()
PY
XDG_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env -u CC_SOCK_DIR PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$SCRATCH_DIR/missing-sessions" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME" \
    "$WORKTREE_GUARD_HOOK")
if ! printf '%s\n' "$XDG_GUARD_OUTPUT" | jq -e \
  '.systemMessage | contains("legacy socket fallback") and contains("pid 111")' \
  >/dev/null; then
  echo "Session worktree guard did not use XDG_RUNTIME_DIR/cc-socks." >&2
  echo "Output was: $XDG_GUARD_OUTPUT" >&2
  exit 1
fi

# A present registry with no compatible records must also fall back instead of
# silently disabling the guard after an upstream schema change.
INCOMPATIBLE_SESSIONS_DIR="$SCRATCH_DIR/incompatible-claude-sessions"
mkdir -p "$INCOMPATIBLE_SESSIONS_DIR"
printf '{"newSchema":true}\n' > "$INCOMPATIBLE_SESSIONS_DIR/111.json"
INCOMPATIBLE_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$INCOMPATIBLE_SESSIONS_DIR" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")
if ! printf '%s\n' "$INCOMPATIBLE_GUARD_OUTPUT" | jq -e \
  '.systemMessage | contains("legacy socket fallback")' >/dev/null; then
  echo "Session worktree guard did not fall back for an incompatible registry." >&2
  echo "Output was: $INCOMPATIBLE_GUARD_OUTPUT" >&2
  exit 1
fi

# jq is optional: without it, legacy detection still runs and explains why it
# cannot emit the structured SessionStart warning.
GUARD_NO_JQ_BIN="$SCRATCH_DIR/guard-bin-no-jq"
mkdir -p "$GUARD_NO_JQ_BIN"
for tool in bash cat git sed head tr; do
  ln -s "$(command -v "$tool")" "$GUARD_NO_JQ_BIN/$tool"
done
ln -s "$GUARD_BIN_DIR/ps" "$GUARD_NO_JQ_BIN/ps"
ln -s "$GUARD_BIN_DIR/lsof" "$GUARD_NO_JQ_BIN/lsof"
NO_JQ_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_NO_JQ_BIN" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CLAUDE_SESSIONS_DIR="$GUARD_SESSIONS_DIR" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK" 2>&1)
if ! printf '%s\n' "$NO_JQ_GUARD_OUTPUT" \
  | grep -Fq 'but jq is unavailable; skipping JSON warning'; then
  echo "Session worktree guard did not retain detection when jq was unavailable." >&2
  echo "Output was: $NO_JQ_GUARD_OUTPUT" >&2
  exit 1
fi

# The header promises the hook always exits 0. `set -u` plus a bare $HOME broke
# that wherever HOME is not exported, taking the socket fallback down with it.
NO_HOME_STATUS=0
NO_HOME_GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env -u HOME -u CLAUDE_SESSIONS_DIR PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK") || NO_HOME_STATUS=$?
if [ "$NO_HOME_STATUS" -ne 0 ] || ! printf '%s\n' "$NO_HOME_GUARD_OUTPUT" | jq -e \
  '.systemMessage | contains("legacy socket fallback")' >/dev/null; then
  echo "Session worktree guard did not survive an unset HOME." >&2
  echo "Exit status was: $NO_HOME_STATUS" >&2
  echo "Output was: $NO_HOME_GUARD_OUTPUT" >&2
  exit 1
fi

CLAUDE_ANALYZE_PAYLOAD=$(jq -n --arg path "$TEST_REPO/mobile/lib/clean.dart" \
  '{tool_input: {file_path: $path}}')
: > "$CALL_LOG"
rm -f "$TEST_REPO/mobile/.dart_tool/package_config.json"
CLAUDE_ANALYZE_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    DART_CALL_LOG="$CALL_LOG" \
    "$CLAUDE_ANALYZE_HOOK" <<< "$CLAUDE_ANALYZE_PAYLOAD")
if ! printf '%s\n' "$CLAUDE_ANALYZE_OUTPUT" | jq -e \
  '.systemMessage
   | contains("Skipped Dart analysis")
     and contains("flutter pub get")' >/dev/null; then
  echo "Claude post-edit analyze hook did not explain the missing package_config.json skip." >&2
  echo "Output was: $CLAUDE_ANALYZE_OUTPUT" >&2
  exit 1
fi
if grep -q '^analyze ' "$CALL_LOG"; then
  echo "Claude post-edit analyze hook invoked dart without package_config.json." >&2
  exit 1
fi

# Skipping is only half the contract. Without this, widening the guard so it
# always skips -- silently disabling post-edit analysis everywhere -- passes.
: > "$CALL_LOG"
mkdir -p "$TEST_REPO/mobile/.dart_tool"
touch "$TEST_REPO/mobile/.dart_tool/package_config.json"
CLAUDE_ANALYZE_RESOLVED=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    DART_CALL_LOG="$CALL_LOG" \
    "$CLAUDE_ANALYZE_HOOK" <<< "$CLAUDE_ANALYZE_PAYLOAD")
if ! grep -q '^analyze ' "$CALL_LOG"; then
  echo "Claude post-edit analyze hook skipped dart analyze despite package_config.json." >&2
  exit 1
fi
if [ -n "$CLAUDE_ANALYZE_RESOLVED" ]; then
  echo "Claude post-edit analyze hook reported diagnostics for a clean file." >&2
  echo "Output was: $CLAUDE_ANALYZE_RESOLVED" >&2
  exit 1
fi

NON_DIVINE_MAIN="$SCRATCH_DIR/non-divine-main"
NON_DIVINE_LINK="$SCRATCH_DIR/non-divine-linked"
mkdir -p "$NON_DIVINE_MAIN/mobile/build"
git -C "$NON_DIVINE_MAIN" init -q
touch "$NON_DIVINE_MAIN/mobile/build/output.o"
git -C "$NON_DIVINE_MAIN" add mobile/build/output.o
git -C "$NON_DIVINE_MAIN" \
  -c user.email=test@example.com \
  -c user.name=Test \
  commit -q -m init
git -C "$NON_DIVINE_MAIN" worktree add -q "$NON_DIVINE_LINK"
NON_DIVINE_OUTPUT=$(cd "$NON_DIVINE_LINK" && \
  env CLAUDE_PROJECT_DIR="$NON_DIVINE_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
if [ -n "$NON_DIVINE_OUTPUT" ] || [ ! -d "$NON_DIVINE_LINK/mobile/build" ]; then
  echo "Purge hook ran outside a divine-mobile checkout." >&2
  exit 1
fi

MAIN_PURGE_REPO="$SCRATCH_DIR/main-purge"
mkdir -p "$MAIN_PURGE_REPO/mobile/build" "$MAIN_PURGE_REPO/mobile/.dart_tool"
git -C "$MAIN_PURGE_REPO" init -q
cat > "$MAIN_PURGE_REPO/mobile/pubspec.yaml" <<'EOF'
name: main_purge_test
EOF
touch "$MAIN_PURGE_REPO/mobile/build/output.o"
MAIN_PURGE_OUTPUT=$(cd "$MAIN_PURGE_REPO" && \
  env CLAUDE_PROJECT_DIR="$MAIN_PURGE_REPO" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
if [ -n "$MAIN_PURGE_OUTPUT" ] || [ ! -d "$MAIN_PURGE_REPO/mobile/build" ]; then
  echo "Purge hook did not skip the main checkout." >&2
  exit 1
fi

WT_MAIN="$SCRATCH_DIR/purge-main"
WT_LINK="$SCRATCH_DIR/purge-linked"
mkdir -p "$WT_MAIN/mobile/packages/bar"
git -C "$WT_MAIN" init -q
cat > "$WT_MAIN/mobile/pubspec.yaml" <<'EOF'
name: linked_purge_test
EOF
touch "$WT_MAIN/mobile/packages/bar/.keep"
git -C "$WT_MAIN" add mobile/pubspec.yaml mobile/packages/bar/.keep
git -C "$WT_MAIN" \
  -c user.email=test@example.com \
  -c user.name=Test \
  commit -q -m init
git -C "$WT_MAIN" worktree add -q "$WT_LINK"

mkdir -p "$WT_LINK/mobile/build" \
  "$WT_LINK/mobile/.dart_tool" \
  "$WT_LINK/mobile/packages/bar/build"
touch "$WT_LINK/mobile/build/output.o" \
  "$WT_LINK/mobile/.dart_tool/package_config.json" \
  "$WT_LINK/mobile/packages/bar/build/output.o"

CLEAR_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"clear"}')
RESUME_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"resume"}')
if [ -n "$CLEAR_OUTPUT$RESUME_OUTPUT" ] || [ ! -d "$WT_LINK/mobile/build" ] || [ ! -d "$WT_LINK/mobile/.dart_tool" ]; then
  echo "Purge hook did not skip clear/resume SessionEnd reasons." >&2
  exit 1
fi

PURGE_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" \
    "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
printf '%s\n' "$PURGE_OUTPUT" | jq -e \
  '.systemMessage == "Purged 3 build/.dart_tool dirs from purge-linked"' >/dev/null
if [ -d "$WT_LINK/mobile/build" ] || [ -d "$WT_LINK/mobile/.dart_tool" ] || [ -d "$WT_LINK/mobile/packages/bar/build" ]; then
  echo "Purge hook did not remove linked worktree build artifacts." >&2
  exit 1
fi
if [ -n "$(git -C "$WT_LINK" status --short)" ]; then
  echo "Purge hook left the linked worktree dirty." >&2
  exit 1
fi

gitdir=$(git -C "$WT_LINK" rev-parse --absolute-git-dir)

# Staging is only the visible half: the background rm must actually reclaim
# the staged artifacts, or every session-end just moves the disk bill around.
for _ in $(seq 1 100); do
  [ ! -e "$gitdir/claude-purge" ] && break
  sleep 0.1
done
if [ -e "$gitdir/claude-purge" ]; then
  echo "Purge hook staged artifacts but never deleted them." >&2
  exit 1
fi

mkdir -p "$gitdir/claude-purge/old"
touch "$gitdir/claude-purge/old/artifact"
NOOP_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" \
    "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
if [ -n "$NOOP_OUTPUT" ] || [ -d "$gitdir/claude-purge" ]; then
  echo "Purge hook did not clean leftover staging on a no-op run." >&2
  exit 1
fi

# A directory whose name contains a newline must not split find output into
# fragments: without -print0 the hook reads `mobile/pkg\nage/build` as the two
# paths `mobile/pkg` and `age/build`, and `mv`/`rm -rf` then reach the
# non-artifact sibling. The precious file is the discrimination.
NEWLINE_PKG="$WT_LINK/mobile/pkg
age"
mkdir -p "$NEWLINE_PKG/build" "$WT_LINK/mobile/pkg"
touch "$NEWLINE_PKG/build/output.o" "$WT_LINK/mobile/pkg/PRECIOUS_SOURCE.dart"
NEWLINE_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" \
    "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
printf '%s\n' "$NEWLINE_OUTPUT" | jq -e \
  '.systemMessage == "Purged 1 build/.dart_tool dirs from purge-linked"' >/dev/null || {
  echo "Purge hook did not report purging the newline-named build dir." >&2
  echo "Output was: $NEWLINE_OUTPUT" >&2
  exit 1
}
if [ ! -f "$WT_LINK/mobile/pkg/PRECIOUS_SOURCE.dart" ]; then
  echo "Purge hook deleted a non-artifact path through a newline-split find line." >&2
  exit 1
fi
if [ -d "$NEWLINE_PKG/build" ]; then
  echo "Purge hook left the newline-named build dir behind." >&2
  exit 1
fi
for _ in $(seq 1 100); do
  [ ! -e "$gitdir/claude-purge" ] && break
  sleep 0.1
done

# Pin the BSD/macOS stat fallback without requiring a second filesystem. The
# fake rejects GNU `stat -c` and reports different BSD `stat -f` device ids; a
# regular file at the staging path makes any missed cross-device detection fail.
BSD_STAT_BIN="$SCRATCH_DIR/bsd-stat-bin"
mkdir -p "$BSD_STAT_BIN"
cat > "$BSD_STAT_BIN/stat" <<'EOF'
#!/bin/bash
case "$1" in
  -c)
    exit 1
    ;;
  -f)
    case "$3" in
      "$BSD_STAT_WORKTREE_MOBILE") echo 101 ;;
      "$BSD_STAT_GITDIR") echo 202 ;;
      *) echo 101 ;;
    esac
    exit 0
    ;;
esac
exit 1
EOF
chmod +x "$BSD_STAT_BIN/stat"

# Carry the newline discrimination onto the in-place branch too. The staging
# branch is pinned for it above, but the only other test that reaches the
# in-place branch is the /dev/shm one below, which skips wherever /dev/shm is
# absent or read-only -- every macOS run. Faking stat is what makes this pin
# platform-independent.
mkdir -p "$WT_LINK/mobile/build" \
  "$WT_LINK/mobile/.dart_tool" \
  "$NEWLINE_PKG/build" \
  "$WT_LINK/mobile/pkg"
touch "$WT_LINK/mobile/build/output.o" \
  "$WT_LINK/mobile/.dart_tool/package_config.json" \
  "$NEWLINE_PKG/build/output.o" \
  "$WT_LINK/mobile/pkg/PRECIOUS_SOURCE.dart" \
  "$gitdir/claude-purge"
BSD_STAT_OUTPUT=$(cd "$WT_LINK" && \
  env PATH="$BSD_STAT_BIN:/usr/bin:/bin" \
    BSD_STAT_WORKTREE_MOBILE="$WT_LINK/mobile" \
    BSD_STAT_GITDIR="$gitdir" \
    CLAUDE_PROJECT_DIR="$WT_LINK" \
    "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}' || true)
printf '%s\n' "$BSD_STAT_OUTPUT" | jq -e \
  '.systemMessage == "Purged 3 build/.dart_tool dirs from purge-linked"' >/dev/null || {
  echo "Purge hook did not use the BSD stat fallback for device detection." >&2
  echo "Output was: $BSD_STAT_OUTPUT" >&2
  exit 1
}
if [ ! -f "$gitdir/claude-purge" ]; then
  echo "BSD-stat cross-device purge touched the gitdir staging path." >&2
  exit 1
fi
for _ in $(seq 1 100); do
  [ ! -d "$WT_LINK/mobile/build" ] && [ ! -d "$WT_LINK/mobile/.dart_tool" ] \
    && [ ! -d "$NEWLINE_PKG/build" ] && break
  sleep 0.1
done
if [ -d "$WT_LINK/mobile/build" ] || [ -d "$WT_LINK/mobile/.dart_tool" ]; then
  echo "BSD-stat cross-device purge did not delete the artifact dirs." >&2
  exit 1
fi
if [ ! -f "$WT_LINK/mobile/pkg/PRECIOUS_SOURCE.dart" ]; then
  echo "BSD-stat cross-device purge deleted a non-artifact path through a newline-split find line." >&2
  exit 1
fi
if [ -d "$NEWLINE_PKG/build" ]; then
  echo "BSD-stat cross-device purge left the newline-named build dir behind." >&2
  exit 1
fi
rm -f "$gitdir/claude-purge"

# A linked worktree on a different filesystem from the main checkout must
# still purge: the hook detects the cross-device gitdir and deletes in place
# instead of staging (mv would degrade to a synchronous copy that can blow
# the hook timeout). /dev/shm supplies a second filesystem where one exists;
# the probe guards the fixture itself, since `git worktree add` into a missing
# or read-only /dev/shm (macOS, hardened containers) would abort the suite
# before any skip logic could run.
if [ -d /dev/shm ] && [ -w /dev/shm ]; then
  XDEV_MAIN="$SCRATCH_DIR/xdev-main"
  XDEV_LINK="/dev/shm/divine-purge-xdev-$$"
  # Failing runs re-run the most; clean the tmpfs worktree from the EXIT trap
  # so a red assertion does not leak it into RAM.
  trap 'rm -rf "$SCRATCH_DIR" "$XDEV_LINK"' EXIT
  mkdir -p "$XDEV_MAIN/mobile/packages/bar"
  git -C "$XDEV_MAIN" init -q
  cat > "$XDEV_MAIN/mobile/pubspec.yaml" <<'EOF'
name: xdev_purge_test
EOF
  touch "$XDEV_MAIN/mobile/packages/bar/.keep"
  git -C "$XDEV_MAIN" add mobile/pubspec.yaml mobile/packages/bar/.keep
  git -C "$XDEV_MAIN" \
    -c user.email=test@example.com \
    -c user.name=Test \
    commit -q -m init
  git -C "$XDEV_MAIN" worktree add -q "$XDEV_LINK"
  mkdir -p "$XDEV_LINK/mobile/build" "$XDEV_LINK/mobile/.dart_tool"
  touch "$XDEV_LINK/mobile/build/output.o" \
    "$XDEV_LINK/mobile/.dart_tool/package_config.json"
  XDEV_WORKTREE_DEV=$(stat -c %d "$XDEV_LINK/mobile" 2>/dev/null || stat -f %d "$XDEV_LINK/mobile" 2>/dev/null || echo no-dev-1)
  XDEV_GITDIR=$(git -C "$XDEV_LINK" rev-parse --absolute-git-dir)
  XDEV_GITDIR_DEV=$(stat -c %d "$XDEV_GITDIR" 2>/dev/null || stat -f %d "$XDEV_GITDIR" 2>/dev/null || echo no-dev-2)
  if [ "$XDEV_WORKTREE_DEV" != "$XDEV_GITDIR_DEV" ]; then
    # A regular file at the staging path makes any staging attempt fail loudly
    # (mkdir -p cannot succeed), so this test discriminates the in-place path
    # from a cross-device mv even though both eventually delete the artifacts.
    touch "$XDEV_GITDIR/claude-purge"
    XDEV_NAME=$(basename "$XDEV_LINK")
    XDEV_OUTPUT=$(cd "$XDEV_LINK" && \
      env CLAUDE_PROJECT_DIR="$XDEV_LINK" \
        "$CLAUDE_PURGE_HOOK" \
        <<< '{"reason":"prompt_input_exit"}' || true)
    printf '%s\n' "$XDEV_OUTPUT" | jq -e --arg name "$XDEV_NAME" \
      '.systemMessage == ("Purged 2 build/.dart_tool dirs from " + $name)' >/dev/null || {
      echo "Cross-device purge did not report removing both artifact dirs." >&2
      exit 1
    }
    if [ ! -f "$XDEV_GITDIR/claude-purge" ]; then
      echo "Cross-device purge touched the gitdir staging path instead of deleting in place." >&2
      exit 1
    fi
    for _ in $(seq 1 100); do
      [ ! -d "$XDEV_LINK/mobile/build" ] && [ ! -d "$XDEV_LINK/mobile/.dart_tool" ] && break
      sleep 0.1
    done
    if [ -d "$XDEV_LINK/mobile/build" ] || [ -d "$XDEV_LINK/mobile/.dart_tool" ]; then
      echo "Cross-device purge did not delete the artifact dirs." >&2
      exit 1
    fi
    # The in-place branch has its own find loop, so the newline-splitting
    # regression needs a pin here too, not only against the staging branch.
    XDEV_NL_PKG="$XDEV_LINK/mobile/pkg
age"
    mkdir -p "$XDEV_NL_PKG/build" "$XDEV_LINK/mobile/pkg"
    touch "$XDEV_NL_PKG/build/output.o" "$XDEV_LINK/mobile/pkg/PRECIOUS_SOURCE.dart"
    XDEV_NL_OUTPUT=$(cd "$XDEV_LINK" && \
      env CLAUDE_PROJECT_DIR="$XDEV_LINK" \
        "$CLAUDE_PURGE_HOOK" \
        <<< '{"reason":"prompt_input_exit"}' || true)
    printf '%s\n' "$XDEV_NL_OUTPUT" | jq -e --arg name "$XDEV_NAME" \
      '.systemMessage == ("Purged 1 build/.dart_tool dirs from " + $name)' >/dev/null || {
      echo "Cross-device purge did not report purging the newline-named build dir." >&2
      echo "Output was: $XDEV_NL_OUTPUT" >&2
      exit 1
    }
    for _ in $(seq 1 100); do
      [ ! -d "$XDEV_NL_PKG/build" ] && break
      sleep 0.1
    done
    if [ ! -f "$XDEV_LINK/mobile/pkg/PRECIOUS_SOURCE.dart" ]; then
      echo "Cross-device purge deleted a non-artifact path through a newline-split find line." >&2
      exit 1
    fi
    if [ -d "$XDEV_NL_PKG/build" ]; then
      echo "Cross-device purge left the newline-named build dir behind." >&2
      exit 1
    fi
  else
    echo "skip: /dev/shm shares a filesystem with the scratch dir; cross-device purge path not exercised."
  fi
else
  echo "skip: no writable /dev/shm; cross-device purge path not exercised."
fi

echo "Codex configuration checks passed."
