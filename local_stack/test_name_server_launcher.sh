#!/usr/bin/env bash
# Launch contracts only: the Docker function is a fixture, never a live daemon.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/name-server/run-smoke.sh"
COMPOSE=(docker compose -p fixture-project -f "$SCRIPT_DIR/docker-compose.yml")
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
calls="$scratch/calls"
failures=0

docker() {
  case "$1" in
    compose)
      if [[ " $* " == *" ps -q name-server "* ]]; then
        printf '%s\n' "$fixture_container"
      elif [[ " $* " == *" run "* ]]; then
        printf '%s\n' "$@" >> "$calls"
      else
        echo "Unexpected Compose invocation" >&2
        return 1
      fi
      ;;
    inspect)
      [[ "${@: -1}" == "$fixture_container" ]] || return 1
      printf '%s|%s|%s|%s|%s\n' "$fixture_image" "$fixture_health" \
        "$fixture_config" "$fixture_service" "$fixture_binding"
      ;;
    info)
      [[ "$fixture_info_failure" == false ]] || return 1
      case "$3" in
        '{{.OperatingSystem}}') printf '%s\n' "$fixture_engine" ;;
        '{{.OSType}}') printf '%s\n' "$fixture_os" ;;
        *) return 1 ;;
      esac
      ;;
    context) printf '%s\n' "$fixture_endpoint" ;;
    run) printf '%s\n' "$@" >> "$calls" ;;
    *) echo "Unexpected Docker invocation" >&2; return 1 ;;
  esac
}

reset_fixture() {
  fixture_container=fixture-container
  fixture_image=sha256:synthetic-image
  fixture_health=healthy
  fixture_config="$SCRIPT_DIR/docker-compose.yml"
  fixture_service=name-server
  fixture_binding=127.0.0.1:43005
  fixture_engine='Ubuntu 24.04'
  fixture_os=linux
  fixture_info_failure=false
  fixture_endpoint=unix:///var/run/docker.sock
  : > "$calls"
}

assert_calls() {
  if ! diff -u "$scratch/expected" "$calls"; then
    echo "FAIL: $1" >&2
    failures=$((failures + 1))
  fi
}

assert_refused() {
  if run_name_server_smoke --seed > "$scratch/out" 2>&1; then
    echo "FAIL: $1 was accepted" >&2
    failures=$((failures + 1))
  fi
  if [[ -s "$calls" ]]; then
    echo "FAIL: $1 launched a smoke container" >&2
    failures=$((failures + 1))
  fi
}

# Do not inherit a caller's real Docker override into these synthetic cases.
unset DOCKER_HOST
reset_fixture
run_name_server_smoke --verify-seed 'argument with spaces'
cat > "$scratch/expected" <<'EOF'
run
--rm
--network
host
-e
NAME_SERVER_TRANSPORT=http://127.0.0.1:43005
--entrypoint
node
sha256:synthetic-image
/app/smoke.mjs
--verify-seed
argument with spaces
EOF
assert_calls 'native Linux must use disposable host networking and the verified image'

for engine in 'Docker Desktop' 'Docker Desktop for Linux'; do
  reset_fixture
  fixture_engine="$engine"
  run_name_server_smoke --seed
  printf '%s\n' "${COMPOSE[@]:1}" run --rm --no-deps name-server-smoke --seed > "$scratch/expected"
  assert_calls 'Desktop must retain Compose transport even with Linux OSType'
done

for defect in absent multiple unhealthy other-checkout wrong-service public-binding remote override unknown failed-info; do
  reset_fixture
  case "$defect" in
    absent) fixture_container='' ;;
    multiple) fixture_container=$'one\ntwo' ;;
    unhealthy) fixture_health=starting ;;
    other-checkout) fixture_config=/another-checkout/local_stack/docker-compose.yml ;;
    wrong-service) fixture_service=another-service ;;
    public-binding) fixture_binding=0.0.0.0:43005 ;;
    remote) fixture_endpoint=ssh://synthetic-remote ;;
    override) DOCKER_HOST=synthetic-override ;;
    unknown) fixture_engine='' ;;
    failed-info) fixture_info_failure=true ;;
  esac
  assert_refused "$defect"
  unset DOCKER_HOST
done

# Both runners must use the same verified launcher, not bypass it for seeding.
for runner in test_name_server.sh test_username_ui.sh; do
  if ! grep -q '^source "$SCRIPT_DIR/name-server/run-smoke.sh"$' "$SCRIPT_DIR/$runner" ||
     ! grep -q '^run_name_server_smoke --seed$' "$SCRIPT_DIR/$runner" ||
     grep -q 'run --rm --no-deps name-server-smoke' "$SCRIPT_DIR/$runner"; then
    echo "FAIL: $runner bypasses the shared seed launcher" >&2
    failures=$((failures + 1))
  fi
done

# Occupied resources and failed ownership reads must stop before up or cleanup.
mkdir "$scratch/bin"
cat > "$scratch/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$LAUNCH_CALLS"
case "$1" in
  ps) [[ "$OCCUPIED" != port ]] || echo fixture ;;
  compose) [[ "$OCCUPIED" != project ]] || echo fixture ;;
  volume) [[ "$OCCUPIED" != volume ]] || echo fixture ;;
  network)
    if [[ "$OCCUPIED" == failed-read ]]; then exit 1; fi
    [[ "$OCCUPIED" != network ]] || echo fixture
    ;;
  *) exit 1 ;;
esac
exit 0
EOF
chmod +x "$scratch/bin/docker"
for occupied in port project volume network failed-read; do
  : > "$calls"
  if PATH="$scratch/bin:$PATH" LAUNCH_CALLS="$calls" OCCUPIED="$occupied" \
      bash "$SCRIPT_DIR/test_name_server.sh" > "$scratch/out" 2>&1; then
    echo "FAIL: $occupied resource preflight was accepted" >&2
    failures=$((failures + 1))
  fi
  if grep -Eq '(^| )(up|down|run|restart)( |$)' "$calls"; then
    echo "FAIL: $occupied resource preflight performed a mutation" >&2
    failures=$((failures + 1))
  fi
done
if [[ "$failures" -ne 0 ]]; then
  echo "$failures name-server launcher contract(s) failed" >&2
  exit 1
fi
echo 'name-server launcher contracts passed'
