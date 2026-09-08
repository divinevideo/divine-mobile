#!/usr/bin/env bash
# Behavioural checks for preflight.sh and up.sh.
#
# Every case runs the real code against a sandboxed PATH holding a stubbed
# `docker` (plus whichever of `ss`/`lsof` the case wants to exist), so the
# outcome depends only on the fixtures — no daemon, no listening sockets, same
# result on macOS and Linux.
#
#   bash local_stack/test_stack_scripts.sh
#
# shellcheck disable=SC2016  # snippets expand inside the sandboxed shell, not here
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${SCRIPT_DIR}/preflight.sh"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
BASH_BIN="$(command -v bash)"

tmp_dir="$(mktemp -d)"
ENV_FILE="${SCRIPT_DIR}/.env"
ENV_BACKUP="${tmp_dir}/env.backup"
ENV_HAD_FILE=0
if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "$ENV_BACKUP"
    ENV_HAD_FILE=1
fi
cleanup() {
    if [[ "$ENV_HAD_FILE" -eq 1 ]]; then
        cp "$ENV_BACKUP" "$ENV_FILE"
    else
        rm -f "$ENV_FILE"
    fi
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

BIN="${tmp_dir}/bin"
FIXTURES="${tmp_dir}/fixtures"
mkdir -p "$BIN" "$FIXTURES"

failures=0

fail() {
    echo "FAIL: $1" >&2
    shift
    local line
    for line in "$@"; do
        echo "  ${line}" >&2
    done
    failures=$((failures + 1))
}

assert_status() {
    local expected="$1" actual="$2" message="$3"

    if [[ "$actual" != "$expected" ]]; then
        fail "$message" "expected exit ${expected}, got ${actual}" \
            "stderr:" "$(sed 's/^/    /' "${tmp_dir}/err")"
    fi
}

assert_stderr_contains() {
    local needle="$1" message="$2"

    if ! grep -qF -- "$needle" "${tmp_dir}/err"; then
        fail "$message" "missing from stderr: ${needle}" \
            "stderr:" "$(sed 's/^/    /' "${tmp_dir}/err")"
    fi
}

assert_stderr_lacks() {
    local needle="$1" message="$2"

    if grep -qF -- "$needle" "${tmp_dir}/err"; then
        fail "$message" "unexpected in stderr: ${needle}" \
            "stderr:" "$(sed 's/^/    /' "${tmp_dir}/err")"
    fi
}

assert_file_matches() {
    local pattern="$1" file="$2" message="$3"

    if ! grep -qE -- "$pattern" "$file"; then
        fail "$message" "missing from ${file}: ${pattern}"
    fi
}

# The full interpolation is the behavior: amd64 by default, with a native
# platform override for locally built images.
assert_file_matches '^[[:space:]]+platform: \$\{INVITE_PLATFORM:-linux/amd64\}$' "$COMPOSE_FILE" \
    "the invite image platform default and override should remain configured"

# --- Sandbox ----------------------------------------------------------------

# Only what these scripts and the stubs actually shell out to. `ss` and `lsof`
# are left out on purpose: each case links in the ones it wants to exist.
link_core_tools() {
    local tool path
    for tool in bash cat awk sed grep tr uname python3 dirname mktemp tee tail rm; do
        path="$(command -v "$tool" || true)"
        if [[ -z "$path" ]]; then
            echo "ERROR: ${tool} is required to run these checks" >&2
            exit 1
        fi
        ln -sf "$path" "${BIN}/${tool}"
    done
}

cat >"${BIN}/docker" <<'STUB'
#!/usr/bin/env bash
# Serves canned output and exit codes from $STUB_FIXTURES. Unknown invocations
# succeed silently, which is close enough to the real client for the paths
# under test.
set -u

emit() { [[ -f "$1" ]] && cat "$1"; return 0; }
emit_err() { [[ -f "$1" ]] && cat "$1" >&2; return 0; }

# Exit code for a stubbed subcommand, 0 unless the case asked otherwise.
stub_rc() {
    local rc_file="${STUB_FIXTURES}/rc_$1"
    if [[ -f "$rc_file" ]]; then
        cat "$rc_file"
    else
        echo 0
    fi
}

case "${1:-}" in
  ps)
    # The daemon liveness probe: `docker ps --format '{{.Names}}'`.
    if [[ "${3:-}" == '{{.Names}}' ]]; then
      exit "$(stub_rc daemon)"
    fi
    emit "${STUB_FIXTURES}/docker_ps.txt"
    ;;
  compose)
    shift
    while (($# > 0)); do
      case "$1" in
        config)
          emit_err "${STUB_FIXTURES}/compose_config.stderr"
          emit "${STUB_FIXTURES}/compose_config.json"
          exit "$(stub_rc config)"
          ;;
        up)
          up_count_file="${STUB_FIXTURES}/up_count"
          if [[ -f "$up_count_file" ]]; then
            up_count="$(cat "$up_count_file")"
          else
            up_count=0
          fi
          up_count=$((up_count + 1))
          echo "$up_count" >"$up_count_file"
          emit "${STUB_FIXTURES}/up_output_${up_count}.txt"
          emit "${STUB_FIXTURES}/up_output.txt"
          if [[ -f "${STUB_FIXTURES}/rc_up_${up_count}" ]]; then
            up_rc="$(cat "${STUB_FIXTURES}/rc_up_${up_count}")"
          else
            up_rc="$(stub_rc up)"
          fi
          exit "$up_rc"
          ;;
        run)
          if printf '%s\n' "$@" | grep -q 'funnelcake-local-tuning'; then
            emit "${STUB_FIXTURES}/tuning_output.txt"
            exit "$(stub_rc tuning)"
          fi
          emit "${STUB_FIXTURES}/seed_output.txt"
          exit "$(stub_rc run)"
          ;;
        exec)
          if printf '%s\n' "$@" | grep -q 'funnelcake-clickhouse'; then
            emit "${STUB_FIXTURES}/schema_version.txt"
            exit "$(stub_rc exec)"
          fi
          exit 0
          ;;
        ps)
          # Two different --format strings; ExitCode marks the pipe-delimited one.
          if printf '%s\n' "$@" | grep -q 'ExitCode'; then
            emit "${STUB_FIXTURES}/compose_ps_pipe.txt"
          else
            emit "${STUB_FIXTURES}/compose_ps_table.txt"
          fi
          exit 0
          ;;
        logs)
          shift
          for arg in "$@"; do
            [[ "$arg" == --* ]] && continue
            emit "${STUB_FIXTURES}/logs_${arg}.txt"
          done
          exit 0
          ;;
      esac
      shift
    done
    ;;
esac
exit 0
STUB
chmod +x "${BIN}/docker"

cat >"${BIN}/ss.stub" <<'STUB'
#!/usr/bin/env bash
# `ss -Hltn`: State Recv-Q Send-Q Local Peer
[[ -f "${STUB_FIXTURES}/ss.stderr" ]] && cat "${STUB_FIXTURES}/ss.stderr" >&2
[[ -f "${STUB_FIXTURES}/ss.txt" ]] && cat "${STUB_FIXTURES}/ss.txt"
if [[ -f "${STUB_FIXTURES}/rc_ss" ]]; then
  exit "$(cat "${STUB_FIXTURES}/rc_ss")"
fi
exit 0
STUB

cat >"${BIN}/lsof.stub" <<'STUB'
#!/usr/bin/env bash
# `lsof -nP -iTCP -sTCP:LISTEN -Fn`: one n<address>:<port> record per socket.
[[ -f "${STUB_FIXTURES}/lsof.stderr" ]] && cat "${STUB_FIXTURES}/lsof.stderr" >&2
[[ -f "${STUB_FIXTURES}/lsof.txt" ]] && cat "${STUB_FIXTURES}/lsof.txt"
if [[ -f "${STUB_FIXTURES}/rc_lsof" ]]; then
  exit "$(cat "${STUB_FIXTURES}/rc_lsof")"
fi
exit 0
STUB

link_core_tools

cat >"${BIN}/sleep" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "${BIN}/sleep"

# Serves canned GHCR responses off the requested URL. `rc_curl` makes every
# request fail, which is how the offline / rate-limited / GHCR-outage paths are
# exercised.
cat >"${BIN}/curl" <<'STUB'
#!/usr/bin/env bash
set -u

if [[ -f "${STUB_FIXTURES}/rc_curl" ]]; then
    exit "$(cat "${STUB_FIXTURES}/rc_curl")"
fi

url=""
for arg in "$@"; do
    case "$arg" in https://*) url="$arg" ;; esac
done

case "$url" in
  *"/token?scope"*)  cat "${STUB_FIXTURES}/ghcr_token.json" ;;
  *"/manifests/"*)   cat "${STUB_FIXTURES}/ghcr_manifest.json" ;;
  *"/blobs/"*)       cat "${STUB_FIXTURES}/ghcr_config.json" ;;
  *"/tags/list"*)    cat "${STUB_FIXTURES}/ghcr_tags.json" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "${BIN}/curl"

# ghcr_fixtures <created_iso8601> <tag_count>
ghcr_fixtures() {
    local created="$1" tag_count="$2" tags i
    echo '{"token":"stub-token"}' >"${FIXTURES}/ghcr_token.json"
    echo '{"config":{"digest":"sha256:deadbeef"}}' >"${FIXTURES}/ghcr_manifest.json"
    printf '{"created":"%s"}\n' "$created" >"${FIXTURES}/ghcr_config.json"
    tags=""
    for ((i = 0; i < tag_count; i++)); do
        tags="${tags}\"t${i}\","
    done
    printf '{"tags":[%s]}\n' "${tags%,}" >"${FIXTURES}/ghcr_tags.json"
}

run_staleness() {
    set +e
    run_in_sandbox 'preflight_image_staleness "$(dirname "$1")"'
    last_status=$?
    set -e
}

run_failure_report() {
    set +e
    run_in_sandbox 'stack_failure_report "$2" "$(dirname "$1")" funnelcake-migrate funnelcake-relay funnelcake-api'
    last_status=$?
    set -e
}

# with_tools <tool>... — exactly these of ss/lsof exist for the next run.
with_tools() {
    rm -f "${BIN}/ss" "${BIN}/lsof"
    local tool
    for tool in "$@"; do
        cp "${BIN}/${tool}.stub" "${BIN}/${tool}"
        chmod +x "${BIN}/${tool}"
    done
}

# drop_python — the next run has no python3 on PATH.
drop_python() { rm -f "${BIN}/python3"; }

reset_fixtures() {
    rm -f "${FIXTURES}"/*
    cat >"${FIXTURES}/compose_config.json" <<'JSON'
{
  "name": "local_stack",
  "services": {
    "funnelcake-redis": {
      "ports": [{"published": "16380", "target": 6379, "protocol": "tcp"}]
    },
    "keycast": {
      "ports": [{"published": "45173", "target": 5173, "protocol": "tcp"}]
    }
  }
}
JSON
}

sandbox_env() {
    env -i PATH="$BIN" HOME="$tmp_dir" STUB_FIXTURES="$FIXTURES" "$@"
}

# run_in_sandbox <snippet> [arg]...
# The snippet runs in a fresh shell with preflight.sh sourced; $1 is the script
# itself, $2 the compose file, $3.. whatever the caller passes. Errexit is the
# caller's business, so the exit status survives.
run_in_sandbox() {
    local snippet="$1"
    shift

    sandbox_env "$BASH_BIN" -c "source \"\$1\"; ${snippet}" \
        _ "$PREFLIGHT" "$COMPOSE_FILE" "$@" \
        >"${tmp_dir}/out" 2>"${tmp_dir}/err"
}

run_preflight() {
    set +e
    run_in_sandbox 'preflight_ports "$2"'
    last_status=$?
    set -e
}

run_transient() {
    set +e
    run_in_sandbox 'stack_failure_is_transient "$2" "$3" "${@:4}"' "$@"
    last_status=$?
    set -e
}

run_up_sh() {
    set +e
    sandbox_env "$BASH_BIN" "${SCRIPT_DIR}/up.sh" \
        >"${tmp_dir}/out" 2>"${tmp_dir}/err"
    last_status=$?
    set -e
}

# --- A stale container holding a stack port is a conflict -------------------
# The bug this replaces: with no `ss` on the box the listener map stayed empty,
# every port was skipped, and pre-flight returned 0 into a doomed `up`.

reset_fixtures
with_tools lsof
echo 'stale-redis||0.0.0.0:16380->6379/tcp, [::]:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
echo 'n*:16380' >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 1 "$last_status" "a container on a stack port should fail pre-flight without ss"
assert_stderr_contains 'port 16380' "the conflicting port should be named"
assert_stderr_contains 'wanted by service "funnelcake-redis"' "the service that wanted the port should be named"
assert_stderr_contains 'held by container "stale-redis"' "the holding container should be named"
assert_stderr_contains 'standalone container (no compose project)' "a container with no compose label should be called standalone"
assert_stderr_contains 'docker rm -f stale-redis' "the remedy should be printed"
# bash 3.2 is the only bash on macOS, and `mise run local_up` runs plain `bash`.
assert_stderr_lacks 'invalid option' "no bash-4-only syntax should reach stderr"

# --- Same conflict, no ss and no lsof ---------------------------------------
# Container-held ports come from `docker ps`, so they are still caught; the
# host-process blind spot is stated rather than passed over.

reset_fixtures
with_tools
echo 'stale-redis||0.0.0.0:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
run_preflight

assert_status 1 "$last_status" "a container conflict should be caught with neither ss nor lsof"
assert_stderr_contains 'held by container "stale-redis"' "the holding container should still be named"
assert_stderr_contains 'host listener enumeration is unavailable' "the blind spot should be stated out loud"

# --- A host process holding a stack port ------------------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
echo 'n127.0.0.1:45173' >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 1 "$last_status" "a host process on a stack port should fail pre-flight"
assert_stderr_contains 'held by a host process (not a container)' "a non-container holder should be described as one"
assert_stderr_contains '127.0.0.1:45173' "the listening address should be shown"
assert_stderr_contains 'sudo lsof -nP -iTCP:45173 -sTCP:LISTEN' "the remedy should use lsof where ss is absent"

# --- ...and the remedy follows the tool the machine has ---------------------

reset_fixtures
with_tools ss
: >"${FIXTURES}/docker_ps.txt"
echo 'LISTEN 0 4096 127.0.0.1:45173 0.0.0.0:*' >"${FIXTURES}/ss.txt"
run_preflight

assert_status 1 "$last_status" "ss output should drive the same conflict report"
assert_stderr_contains 'ss -ltnp "sport = :45173"' "the remedy should use ss where it exists"

# --- Our own stack is not a conflict ----------------------------------------

reset_fixtures
with_tools lsof
echo 'local_stack-funnelcake-redis-1|local_stack|0.0.0.0:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
echo 'n*:16380' >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 0 "$last_status" "a port already published by this project should not be a conflict"

# --- Nothing holding anything -----------------------------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
run_preflight

assert_status 0 "$last_status" "a clean machine should pass pre-flight"

# --- lsof's no-listeners status is not a tool failure -----------------------
# lsof exits 1 with no stderr when no sockets match. That should stay a clean
# empty listener list, not a blind-spot warning.

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
echo 1 >"${FIXTURES}/rc_lsof"
run_preflight

assert_status 0 "$last_status" "lsof exit 1 with empty stderr means no listeners"
assert_stderr_lacks 'host listener enumeration is unavailable' "an empty lsof result should not warn"

# --- A real listener-tool error is not an empty listener list ----------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
echo 1 >"${FIXTURES}/rc_lsof"
echo 'lsof: unacceptable port specification' >"${FIXTURES}/lsof.stderr"
run_preflight

assert_status 1 "$last_status" "a real listener-tool error should fail pre-flight"
assert_stderr_contains 'lsof failed while enumerating listeners' "the listener tool failure should be shown"
assert_stderr_contains 'port safety is unknown' "the unknown host-port state should fail closed"

# --- Compose config warnings are not JSON -----------------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
echo 'WARN[0000] the attribute `version` is obsolete' >"${FIXTURES}/compose_config.stderr"
run_preflight

assert_status 0 "$last_status" "compose warnings on stderr should not corrupt the JSON config"
assert_stderr_lacks 'could not read the published ports' "a compose warning should not become a JSON parse failure"

# --- An unreadable port list fails closed -----------------------------------
# Empty output from a broken extractor reads exactly like "publishes no ports".

reset_fixtures
with_tools lsof
echo 'stale-redis||0.0.0.0:16380->6379/tcp' >"${FIXTURES}/docker_ps.txt"
drop_python
run_preflight
link_core_tools

assert_status 1 "$last_status" "pre-flight should fail closed when it cannot read the port list"
assert_stderr_contains 'needs python3' "the missing dependency should be named"

# --- An unreachable daemon fails closed -------------------------------------

reset_fixtures
with_tools lsof
echo 1 >"${FIXTURES}/rc_daemon"
run_preflight

assert_status 1 "$last_status" "pre-flight should fail closed when the daemon is unreachable"
assert_stderr_contains 'cannot talk to the Docker daemon' "the daemon should be named as the problem"

# --- Transience is judged on the failed service's own log -------------------
# A retry-worthy signature in a service that came up fine is not evidence, and
# acting on it costs two more `up --wait` cycles before the real report prints.

reset_fixtures
with_tools lsof
cat >"${FIXTURES}/compose_ps_pipe.txt" <<'PS'
keycast|running|0
funnelcake-migrate|exited|1
minio-init|exited|0
PS
echo 'dial tcp: i/o timeout' >"${FIXTURES}/logs_keycast.txt"
echo 'migration failed: permission denied' >"${FIXTURES}/logs_funnelcake-migrate.txt"
echo 'dependency failed to start' >"${tmp_dir}/up.log"

run_transient "${tmp_dir}/up.log" keycast funnelcake-migrate minio-init
assert_status 1 "$last_status" "a healthy service's log should not make a hard failure look transient"

echo 'lookup funnelcake-clickhouse on 127.0.0.11:53: no such host' >"${FIXTURES}/logs_funnelcake-migrate.txt"

run_transient "${tmp_dir}/up.log" keycast funnelcake-migrate minio-init
assert_status 0 "$last_status" "a name-resolution failure in the down service should be transient"

# --- Nothing down means nothing to retry ------------------------------------

reset_fixtures
with_tools lsof
cat >"${FIXTURES}/compose_ps_pipe.txt" <<'PS'
keycast|running|0
minio-init|exited|0
PS
echo 'dial tcp: i/o timeout' >"${FIXTURES}/logs_keycast.txt"

run_transient "${tmp_dir}/up.log" keycast minio-init
assert_status 1 "$last_status" "with every service up there is no failed log to call transient"

# --- A dirty migration ledger names the destructive local recovery ----------

reset_fixtures
cat >"${FIXTURES}/compose_ps_pipe.txt" <<'PS'
funnelcake-migrate|exited|1
funnelcake-relay|created|0
funnelcake-api|created|0
PS
echo 'migration failed: Dirty database version 70' >"${FIXTURES}/logs_funnelcake-migrate.txt"
run_failure_report

assert_status 0 "$last_status" "a failure report should remain diagnostic"
assert_stderr_contains 'migration ledger is dirty' "the dirty ledger should be classified"
assert_stderr_contains 'mise run local_reset' "the dirty ledger should name its recovery"
assert_stderr_contains 'docker volume rm local_stack_funnelcake-ch-data' "the Funnelcake-only recovery should come first"
assert_stderr_lacks 'keycast-pg-data' "the narrow recovery must not touch the keycast volume"

# The migrate image runs funnelcake-migrate, which reaches only
# crates/migrations. Its two dirty bails are the native ledger (lib.rs:391) and
# the bootstrapped legacy one (lib.rs:740). The similar strings in
# crates/clickhouse belong to the janitor binary, which local_stack does not
# run, so they can never reach a funnelcake-migrate log.
for migration_error in \
    'migration 259 is dirty; refusing to apply more migrations' \
    'legacy schema_migrations latest row is dirty at version 70'; do
    echo "$migration_error" >"${FIXTURES}/logs_funnelcake-migrate.txt"
    run_failure_report

    assert_status 0 "$last_status" "a Rust migration failure report should remain diagnostic"
    assert_stderr_contains 'migration ledger is dirty' "a Rust dirty ledger should be classified"
    assert_stderr_contains 'mise run local_reset' "a Rust dirty ledger should name its recovery"
    assert_stderr_contains 'deletes all local stack data' "the reset scope should be explicit"
done

# --- A ledger/image mismatch is not a dirty ledger --------------------------
#
# compute_pending_with_options bails four ways; only two of them say "dirty".
# These two are what you get from building a funnelcake branch locally, letting
# it record its migration, and then dropping the .env overrides — the workflow
# build_funnelcake.sh exists for. Wiping the volume is the last resort here,
# not the first, because aligning the overrides recovers the ledger intact.
for mismatch_error in \
    'applied migration 000260_mybranch is missing from the migration directory' \
    'checksum changed for applied migration 000257: database=abc disk=def'; do
    echo "$mismatch_error" >"${FIXTURES}/logs_funnelcake-migrate.txt"
    run_failure_report

    assert_status 0 "$last_status" "a ledger mismatch report should remain diagnostic"
    assert_stderr_contains 'ledger and the migrate image disagree' "a ledger mismatch should be classified"
    assert_stderr_contains 'FUNNELCAKE_(MIGRATE|RELAY|API)_IMAGE' "the mismatch should name the override check"
    assert_stderr_contains 'docker volume rm local_stack_funnelcake-ch-data' "the mismatch should name the last-resort recovery"
    assert_stderr_lacks 'migration ledger is dirty' "a mismatch is not a dirty ledger"
    assert_stderr_lacks 'mise run local_reset' "a mismatch should not recommend deleting keycast data"
done

echo 'migration failed: permission denied' >"${FIXTURES}/logs_funnelcake-migrate.txt"
echo 'migration 259 is dirty; refusing to apply more migrations' >"${FIXTURES}/logs_funnelcake-api.txt"
run_failure_report
assert_stderr_lacks 'mise run local_reset' "an unrelated migration error should not recommend deleting data"

# --- up.sh retries transient startup failures --------------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
echo 1 >"${FIXTURES}/rc_up_1"
echo 0 >"${FIXTURES}/rc_up_2"
echo 'dependency failed to start' >"${FIXTURES}/up_output_1.txt"
cat >"${FIXTURES}/compose_ps_pipe.txt" <<'PS'
funnelcake-migrate|exited|1
PS
echo 'lookup funnelcake-clickhouse on 127.0.0.11:53: no such host' >"${FIXTURES}/logs_funnelcake-migrate.txt"
echo 'seed ok' >"${FIXTURES}/seed_output.txt"
run_up_sh

assert_status 0 "$last_status" "up.sh should retry a transient startup failure and continue after success"
if [[ "$(cat "${FIXTURES}/up_count")" != "2" ]]; then
    fail "up.sh should stop retrying after a successful second attempt" \
        "up attempts: $(cat "${FIXTURES}/up_count")"
fi
assert_stderr_contains 'Retrying in 5s (attempt 2 of 3).' "the retry should be announced"

# --- Current schema with partial tuning warns --------------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
echo 'refresh-interval tuning: applied=3 skipped=1' >"${FIXTURES}/tuning_output.txt"
echo 259 >"${FIXTURES}/schema_version.txt"
echo 'seed ok' >"${FIXTURES}/seed_output.txt"
run_up_sh

assert_status 0 "$last_status" "partial tuning should not block local_up"
assert_stderr_contains 'refresh-interval tuning applied 3/4 expected statements on schema 259' "current-schema tuning drift should be visible"

# --- Legacy schema with skipped tuning stays quiet ---------------------------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
echo 'refresh-interval tuning: applied=0 skipped=4' >"${FIXTURES}/tuning_output.txt"
echo 70 >"${FIXTURES}/schema_version.txt"
echo 'seed ok' >"${FIXTURES}/seed_output.txt"
run_up_sh

assert_status 0 "$last_status" "skipped tuning should not block a legacy schema"
assert_stderr_lacks 'refresh-interval tuning applied' "a legacy schema should not warn about missing current MVs"

# --- .env overrides suppress the stale-image warning through up.sh -----------

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
ghcr_fixtures "$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=163)).isoformat())')" 2
echo 'refresh-interval tuning: applied=0 skipped=4' >"${FIXTURES}/tuning_output.txt"
echo 70 >"${FIXTURES}/schema_version.txt"
echo 'seed ok' >"${FIXTURES}/seed_output.txt"
cat >"$ENV_FILE" <<'ENV'
FUNNELCAKE_RELAY_IMAGE=funnelcake-relay:local
FUNNELCAKE_API_IMAGE=funnelcake-api:local
FUNNELCAKE_MIGRATE_IMAGE=funnelcake-migrate:local
FUNNELCAKE_PULL_POLICY=never
STACK_STALE_AFTER_DAYS=9999
ENV
run_up_sh
rm -f "$ENV_FILE"

assert_status 0 "$last_status" "up.sh should load .env overrides"
assert_stderr_lacks 'the pinned funnelcake images are stale' ".env image overrides should suppress the stale-image warning"

# --- A failed seed reports the seed, not the healthy services ---------------
# The services came up; saying "Local stack failed to come up" over a list of
# 15 healthy ones buries the one log that explains the failure.

reset_fixtures
with_tools lsof
: >"${FIXTURES}/docker_ps.txt"
: >"${FIXTURES}/lsof.txt"
echo 'Container local_stack-keycast-1  Healthy' >"${FIXTURES}/up_output.txt"
cat >"${FIXTURES}/seed_output.txt" <<'SEED'
seeding 100 videos
error: blossom upload failed: connection refused
SEED
echo 3 >"${FIXTURES}/rc_run"
cat >"${FIXTURES}/compose_ps_table.txt" <<'PS'
keycast	running	Up 2 minutes (healthy)
PS
run_up_sh

assert_status 3 "$last_status" "up.sh should exit with the seed's own status"
assert_stderr_contains '=== e2e-seed failed ===' "the seed should be named as what failed"
assert_stderr_contains 'blossom upload failed: connection refused' "the seed's own error should be shown"
assert_stderr_lacks '=== Local stack failed to come up ===' "the stack came up, so it should not claim otherwise"
assert_stderr_contains 'Service status:' "the service table still helps explain a seed failure"
assert_stderr_contains 'profile.sh' "the bypass command should still be offered"

# --- A frozen image warns, and names the escape hatch ------------------------

reset_fixtures
with_tools lsof
ghcr_fixtures "$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=163)).isoformat())')" 2
run_staleness

assert_status 0 "$last_status" "a stale image must never block the stack"
assert_stderr_contains 'the pinned funnelcake images are stale' "the warning should fire"
assert_stderr_contains '163 days ago' "the warning should say how stale"
assert_stderr_contains 'build_funnelcake.sh' "the warning should name the escape hatch"
assert_stderr_contains 'divine-funnelcake' "the warning should identify where publishing failed"
assert_stderr_contains 'GHCR login and push steps' "the warning should name the registry checks"

# --- A freshly published image says nothing ---------------------------------

reset_fixtures
with_tools lsof
ghcr_fixtures "$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=1)).isoformat())')" 107
run_staleness

assert_status 0 "$last_status" "a fresh image is not an error"
assert_stderr_lacks 'stale' "a fresh image must not warn"

# --- Nanosecond precision and a numeric offset still parse -------------------
# GHCR stamps e.g. 2026-02-24T12:31:46.817075705-03:00; fromisoformat rejects a
# 9-digit fraction, so the parser has to drop it.

reset_fixtures
with_tools lsof
ghcr_fixtures "2026-02-24T12:31:46.817075705-03:00" 2
run_staleness

assert_status 0 "$last_status" "an odd timestamp must not break the check"
assert_stderr_contains 'the pinned funnelcake images are stale' "a 2026-02-24 build is stale and must warn"

# --- An unreachable registry fails open -------------------------------------
# Offline, rate-limited, or GHCR down: warn about nothing, never block.

reset_fixtures
with_tools lsof
ghcr_fixtures "2026-02-24T12:31:46Z" 2
echo 6 >"${FIXTURES}/rc_curl"
run_staleness

assert_status 0 "$last_status" "an unreachable registry must not block the stack"
assert_stderr_lacks 'stale' "nothing is known, so nothing should be claimed"

# ----------------------------------------------------------------------------

if ((failures > 0)); then
    echo "${failures} local stack check(s) failed" >&2
    exit 1
fi

echo "local stack script checks passed"
