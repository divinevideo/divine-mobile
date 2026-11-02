#!/bin/bash
# Regression checks for the validate-issue skill: it must stay opt-in, and its
# helper scripts must keep working. Run from test-config.sh (CI job
# `Codex Configuration`) or on its own.
#
# The Dart checks (format, analyze, the proxy selftest) run only where `dart`
# is on PATH. That job's runner has none, so there they print a skip line and a
# local run of this script is what covers them.

set -e
trap 'echo "test-validate-issue-skill.sh failed at line $LINENO: $BASH_COMMAND" >&2' ERR

REPO_ROOT=$(git rev-parse --show-toplevel)
SKILL="$REPO_ROOT/.claude/skills/validate-issue"
MIRROR="$REPO_ROOT/.agents/skills/validate-issue"
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/validate-issue-skill.XXXXXX")

cleanup() {
  local pidfile
  # A failing step must not leave a fake `flutter run` behind.
  for pidfile in "$SCRATCH"/fm/*/pid "$SCRATCH"/fm/*/holder.pid; do
    # Most of these runs have stopped already, so a failed kill is expected.
    if [ -f "$pidfile" ]; then kill "$(cat "$pidfile")" 2>/dev/null || true; fi
  done
  rm -rf "$SCRATCH"
  return 0
}
trap cleanup EXIT

fail() {
  echo "$1" >&2
  exit 1
}

# 1. Opt-in. The skill asks 10-20 questions and drives devices, so it may only
# start when someone types /validate-issue. Claude Code reads
# disable-model-invocation in SKILL.md, Codex reads agents/openai.yaml; losing
# either one lets the skill fire from a prompt match in every session.
is_opt_in() {
  local dir=$1
  awk '/^---$/ { n++; next } n == 1' "$dir/SKILL.md" \
    | grep -qx 'disable-model-invocation: true' || return 1
  grep -Eq '^[[:space:]]+allow_implicit_invocation: false[[:space:]]*$' \
    "$dir/agents/openai.yaml"
}

for dir in "$SKILL" "$MIRROR"; do
  is_opt_in "$dir" || fail "validate-issue is no longer opt-in in $dir: SKILL.md needs 'disable-model-invocation: true' in its frontmatter and agents/openai.yaml needs 'allow_implicit_invocation: false'."
done

# The check must be able to fail, or it protects nothing.
mkdir -p "$SCRATCH/optin/agents"
cp "$SKILL/agents/openai.yaml" "$SCRATCH/optin/agents/openai.yaml"
sed '/^disable-model-invocation: true$/d' "$SKILL/SKILL.md" > "$SCRATCH/optin/SKILL.md"
if is_opt_in "$SCRATCH/optin"; then
  fail "The opt-in check accepted a SKILL.md without disable-model-invocation."
fi
cp "$SKILL/SKILL.md" "$SCRATCH/optin/SKILL.md"
sed 's/allow_implicit_invocation: false/allow_implicit_invocation: true/' \
  "$SKILL/agents/openai.yaml" > "$SCRATCH/optin/agents/openai.yaml"
if is_opt_in "$SCRATCH/optin"; then
  fail "The opt-in check accepted allow_implicit_invocation: true."
fi

# 2. The shell helper parses and passes shellcheck's warning level.
FM="$SKILL/scripts/flutter-machine.sh"
bash -n "$FM"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning "$FM"
else
  echo "skip: shellcheck is not installed; flutter-machine.sh lint not run."
fi

# 3. The helper against a stand-in for `flutter run --machine` (FLUTTER is its
# documented override), so start, wait, status, ext, taint and stop run on a
# machine with no Flutter, device or app.
FM_DIR="$SCRATCH/fm"
mkdir -p "$FM_DIR"
cat > "$SCRATCH/fake-flutter" <<'EOF'
#!/bin/bash
# Answers like `flutter run --machine`: events on stdout, one reply per request.
if [ "${FAKE_NO_START:-}" != 1 ]; then
  echo '[{"event":"app.start","params":{"appId":"fake-app-1"}}]'
  echo '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:9/ws"}}]'
  echo '[{"event":"app.log","params":{"log":"hello from the fake app"}}]'
  [ "${FAKE_TAINT:-}" = 1 ] && echo '[{"event":"app.log","params":{"log":"Build scheduled during frame"}}]'
  echo '[{"event":"app.started","params":{}}]'
fi
while IFS= read -r line; do
  id=$(printf '%s' "$line" | jq -r '.[0].id')
  method=$(printf '%s' "$line" | jq -r '.[0].method')
  printf '[{"id":%s,"result":true}]\n' "$id"
  [ "$method" = app.stop ] && exit 0
done
EOF
chmod +x "$SCRATCH/fake-flutter"

# Bounded so a hang in the helper fails this script instead of the CI job.
fm() { perl -e 'alarm 60; exec @ARGV' bash "$FM" "$@"; }
export FLUTTER="$SCRATCH/fake-flutter"

run=$FM_DIR/ok
fm start "$run" "$SCRATCH" fake-device >/dev/null
waited=$(fm wait "$run" 20)
printf '%s\n' "$waited" | grep -qx 'appId=fake-app-1' || fail "wait did not print the appId: $waited"
printf '%s\n' "$waited" | grep -qx 'wsUri=ws://127.0.0.1:9/ws' || fail "wait did not print the wsUri: $waited"

status=0; state=$(fm status "$run") || status=$?
[ "$status" -eq 0 ] && printf '%s\n' "$state" | grep -q 'state=running' \
  || fail "status of a started run should be running, exit 0: exit $status, $state"

status=0; refusal=$(fm start "$run" "$SCRATCH" fake-device 2>&1) || status=$?
[ "$status" -eq 3 ] && printf '%s\n' "$refusal" | grep -q 'still alive' \
  || fail "start reused a live run directory: exit $status, $refusal"

fm ext "$run" ext.flutter.debugDumpApp | grep -q '"result":true' || fail "ext got no reply"
fm logs "$run" | grep -qx 'hello from the fake app' || fail "logs lost the app.log line"

# vmlog reads the VM Logging stream through websocat. Without -E, websocat keeps
# the socket open after stdin closes, so the command only ends on its safety
# alarm (secs + 15) and "vmlog 3" takes 18 s. A stand-in websocat records its
# arguments and ends when stdin does, as `websocat -E` does.
mkdir -p "$SCRATCH/bin"
cat > "$SCRATCH/bin/websocat" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" > "$FAKE_WEBSOCAT_ARGS"
cat > /dev/null
echo '{"jsonrpc":"2.0","method":"streamNotify","params":{"streamId":"Logging","event":{"kind":"Logging","logRecord":{"level":800,"loggerName":{"valueAsString":"probe"},"message":{"valueAsString":"hello"}}}}}'
EOF
chmod +x "$SCRATCH/bin/websocat"
vmlog=$(PATH="$SCRATCH/bin:$PATH" FAKE_WEBSOCAT_ARGS="$SCRATCH/websocat.args" fm vmlog "$run" 1)
printf '%s\n' "$vmlog" | grep -q "$(printf '^800\tprobe\thello')" || fail "vmlog did not format a Logging event: $vmlog"
grep -q -- ' -E ' "$SCRATCH/websocat.args" || fail "vmlog must start websocat with -E so it exits when its input ends: $(cat "$SCRATCH/websocat.args")"
fm taint "$run" | grep -q '^clean' || fail "taint flagged a clean run"
fm stop "$run" | grep -qx 'stopped' || fail "stop did not report stopped"
status=0; fm status "$run" >/dev/null 2>&1 || status=$?
[ "$status" -eq 3 ] || fail "status after stop should exit 3, got $status"

run=$FM_DIR/tainted
FAKE_TAINT=1 fm start "$run" "$SCRATCH" fake-device >/dev/null
fm wait "$run" 20 >/dev/null
status=0; fm taint "$run" >/dev/null || status=$?
[ "$status" -eq 1 ] || fail "taint should exit 1 on a corrupted tree, got $status"
fm stop "$run" >/dev/null

# A run that never reaches app.start has no appId: stop must end it, not hang.
run=$FM_DIR/stuck
FAKE_NO_START=1 fm start "$run" "$SCRATCH" fake-device >/dev/null
status=0; fm wait "$run" 2 >/dev/null 2>&1 || status=$?
[ "$status" -eq 1 ] || fail "wait on a run that never starts should time out with exit 1, got $status"
pid=$(cat "$run/pid")
fm stop "$run" 2>/dev/null | grep -qx 'stopped' || fail "stop did not end a run that never started"
if kill -0 "$pid" 2>/dev/null; then
  fail "stop left the never-started run (pid $pid) running."
fi
unset FLUTTER

# 4. The fault proxy and its selftest, where a Dart SDK is available.
DART_FILES=("$SKILL/scripts/relay-fault-proxy.dart" "$SKILL/scripts/relay-fault-proxy-selftest.dart")
if command -v dart >/dev/null 2>&1; then
  dart format --output=none --set-exit-if-changed "${DART_FILES[@]}"
  dart analyze --fatal-warnings "${DART_FILES[@]}"
  perl -e 'alarm 180; exec @ARGV' dart "$SKILL/scripts/relay-fault-proxy-selftest.dart"
else
  echo "skip: no dart on PATH; relay-fault-proxy format, analyze and selftest not run."
fi

echo "validate-issue skill checks passed."
