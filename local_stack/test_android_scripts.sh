#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=android_sdk.sh
source "${SCRIPT_DIR}/android_sdk.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: ${message}" >&2
    echo "  expected: ${expected}" >&2
    echo "  actual:   ${actual}" >&2
    exit 1
  fi
}

assert_contains() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! grep -qF -- "$needle" "$file"; then
    echo "FAIL: ${message}" >&2
    echo "  missing: ${needle}" >&2
    echo "  file:    ${file}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if grep -qF -- "$needle" "$file"; then
    echo "FAIL: ${message}" >&2
    echo "  unexpected: ${needle}" >&2
    echo "  file:       ${file}" >&2
    exit 1
  fi
}

assert_not_file_exists() {
  local file="$1"
  local message="$2"

  if [[ -e "$file" ]]; then
    echo "FAIL: ${message}" >&2
    echo "  unexpected file: ${file}" >&2
    exit 1
  fi
}

assert_line_before() {
  local first="$1"
  local second="$2"
  local file="$3"
  local message="$4"
  local first_line
  local second_line

  first_line="$(grep -nF -- "$first" "$file" | head -1 | cut -d: -f1)"
  second_line="$(grep -nF -- "$second" "$file" | head -1 | cut -d: -f1)"

  if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    echo "FAIL: ${message}" >&2
    echo "  first:  ${first} (${first_line:-missing})" >&2
    echo "  second: ${second} (${second_line:-missing})" >&2
    echo "  file:   ${file}" >&2
    exit 1
  fi
}

extract_mise_task() {
  local task_name="$1"
  local file="$2"

  awk -v task="[tasks.${task_name}]" '
    $0 == task { in_task = 1 }
    in_task && $0 ~ /^\[tasks\./ && $0 != task { exit }
    in_task { print }
  ' "$file"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
local_reset_task="${tmp_dir}/local_reset.mise-task"
local_android_task="${tmp_dir}/local_android.mise-task"
extract_mise_task local_reset "${REPO_ROOT}/mobile/mise.toml" > "$local_reset_task"
extract_mise_task local_android "${REPO_ROOT}/mobile/mise.toml" > "$local_android_task"

mkdir -p "${tmp_dir}/home"
set +e
env -u ANDROID_HOME -u ANDROID_SDK_ROOT HOME="${tmp_dir}/home" PATH="/usr/bin:/bin" \
  bash "${SCRIPT_DIR}/emulator.sh" --bogus >/dev/null 2>&1
bogus_exit=$?
set -e
assert_eq "2" "$bogus_exit" \
  "emulator.sh should reject unknown arguments before checking emulator availability"

assert_eq "/tmp/.X11-unix/X1" "$(x11_socket_path ':1.0')" \
  "DISPLAY screen suffix should map to the base X socket"
assert_eq "/tmp/.X11-unix/X10" "$(x11_socket_path ':10')" \
  "SSH-forwarded DISPLAY values should map to their X socket"

mkdir -p "${tmp_dir}/bin"
cat > "${tmp_dir}/bin/emulator" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-list-avds" ]]; then
  printf '%s\n' Pixel_API_35 Medium_Phone_API_36
fi
STUB
chmod +x "${tmp_dir}/bin/emulator"

PATH="${tmp_dir}/bin:${PATH}"
assert_eq "Pixel_API_35" "$(first_available_avd_name)" \
  "default AVD should come from emulator -list-avds"

cat > "${tmp_dir}/bin/docker" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "compose" && "${2:-}" == "-f" && "${4:-}" == "ps" ]]; then
  printf '%s\n' local-stack-container
  exit 0
fi
exit 2
STUB
cat > "${tmp_dir}/bin/adb" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${ADB_ARGS_FILE:-/dev/null}"
if [[ "${1:-}" == "devices" ]]; then
  printf '%s\n' "List of devices attached"
  printf '%b' "${ADB_DEVICES_OUTPUT:-}"
  exit 0
fi
if [[ "${1:-}" == "-s" && "${3:-}" == "shell" && "${4:-}" == "pm" && "${5:-}" == "clear" ]]; then
  if [[ "${ADB_PM_CLEAR_FAIL:-}" == "1" ]]; then
    printf '%s\n' Failed >&2
    exit 1
  fi
  printf '%s\n' Success
  exit 0
fi
if [[ "${1:-}" == "-s" && "${3:-}" == "shell" && "${4:-}" == "pm" && "${5:-}" == "path" ]]; then
  if [[ "${ADB_PM_PATH_ABSENT:-}" == "1" ]]; then
    exit 1
  fi
  printf '%s\n' 'package:/data/app/co.openvine.app/base.apk'
  exit 0
fi
exit 2
STUB
cat > "${tmp_dir}/bin/flutter" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${FLUTTER_ARGS_FILE:?}"
STUB
chmod +x "${tmp_dir}/bin/docker" "${tmp_dir}/bin/adb" "${tmp_dir}/bin/flutter"

adb_args_file="${tmp_dir}/adb.args"
flutter_args_file="${tmp_dir}/flutter.args"
env ADB_DEVICES_OUTPUT=$'R58N1234567\tdevice\nemulator-5554\tdevice\n' \
  ADB_ARGS_FILE="$adb_args_file" FLUTTER_ARGS_FILE="$flutter_args_file" \
  PATH="${tmp_dir}/bin:${PATH}" \
  bash "${SCRIPT_DIR}/run_android_local.sh" >/dev/null 2>"${tmp_dir}/emulator-selection.err"
assert_contains '-d emulator-5554' "$flutter_args_file" \
  "local Android runner should default to the first emulator instead of a physical device"
assert_contains 'shell pm clear co.openvine.app.staging' "$adb_args_file" \
  "debug local Android runner should clear staging app data before launching"
assert_contains 'Clearing persisted app data for co.openvine.app.staging' "${tmp_dir}/emulator-selection.err" \
  "local Android runner should make the deterministic reset visible"

rm -f "$adb_args_file" "$flutter_args_file"
env ADB_DEVICES_OUTPUT=$'emulator-5554\tdevice\n' ADB_ARGS_FILE="$adb_args_file" \
  FLUTTER_ARGS_FILE="$flutter_args_file" PATH="${tmp_dir}/bin:${PATH}" \
  bash "${SCRIPT_DIR}/run_android_local.sh" emulator-5554 profile >/dev/null 2>"${tmp_dir}/profile.err"
assert_contains 'shell pm clear co.openvine.app' "$adb_args_file" \
  "profile local Android runner should clear production-identity app data"
assert_contains '--profile' "$flutter_args_file" \
  "profile local Android runner should preserve the requested build mode"

rm -f "$adb_args_file" "$flutter_args_file"
env ADB_DEVICES_OUTPUT=$'emulator-5554\tdevice\n' ADB_ARGS_FILE="$adb_args_file" \
  ADB_PM_CLEAR_FAIL=1 ADB_PM_PATH_ABSENT=1 FLUTTER_ARGS_FILE="$flutter_args_file" \
  PATH="${tmp_dir}/bin:${PATH}" \
  bash "${SCRIPT_DIR}/run_android_local.sh" >/dev/null 2>"${tmp_dir}/missing-package-reset.err"
assert_contains '-d emulator-5554' "$flutter_args_file" \
  "local Android runner should still launch Flutter when no app data exists yet"
assert_contains '--dart-define=DEFAULT_ENV=LOCAL' "$flutter_args_file" \
  "missing app data should not bypass the LOCAL dart define"
assert_contains 'No existing app install found for co.openvine.app.staging' "${tmp_dir}/missing-package-reset.err" \
  "missing app data should be reported as an idempotent first-run reset"

rm -f "$adb_args_file" "$flutter_args_file"
set +e
env ADB_DEVICES_OUTPUT=$'emulator-5554\tdevice\n' ADB_ARGS_FILE="$adb_args_file" \
  ADB_PM_CLEAR_FAIL=1 FLUTTER_ARGS_FILE="$flutter_args_file" \
  PATH="${tmp_dir}/bin:${PATH}" \
  bash "${SCRIPT_DIR}/run_android_local.sh" >/dev/null 2>"${tmp_dir}/clear-failure.err"
clear_failure_exit=$?
set -e
assert_eq "1" "$clear_failure_exit" \
  "local Android runner should fail when app data exists but cannot be cleared"
assert_contains 'Failed to clear persisted app data for co.openvine.app.staging' "${tmp_dir}/clear-failure.err" \
  "clear failure should preserve the underlying hard adb error"
assert_not_file_exists "$flutter_args_file" \
  "local Android runner should not launch Flutter after a real app-data clear failure"

rm -f "$adb_args_file" "$flutter_args_file"
set +e
env ADB_DEVICES_OUTPUT=$'R58N1234567\tdevice\n' ADB_ARGS_FILE="$adb_args_file" \
  FLUTTER_ARGS_FILE="$flutter_args_file" \
  PATH="${tmp_dir}/bin:${PATH}" \
  bash "${SCRIPT_DIR}/run_android_local.sh" >/dev/null 2>"${tmp_dir}/physical-only.err"
physical_only_exit=$?
set -e
assert_eq "1" "$physical_only_exit" \
  "local Android runner should fail when only a physical Android device is connected"
assert_contains 'No Android emulator connected' "${tmp_dir}/physical-only.err" \
  "physical-only failure should explain that an emulator is required"
assert_not_file_exists "$flutter_args_file" \
  "local Android runner should not start Flutter for physical-only adb output"

set +e
env ADB_DEVICES_OUTPUT=$'R58N1234567\tdevice\nemulator-5554\tdevice\n' \
  ADB_ARGS_FILE="$adb_args_file" FLUTTER_ARGS_FILE="$flutter_args_file" \
  PATH="${tmp_dir}/bin:${PATH}" \
  bash "${SCRIPT_DIR}/run_android_local.sh" R58N1234567 >/dev/null 2>"${tmp_dir}/explicit-physical.err"
explicit_physical_exit=$?
set -e
assert_eq "1" "$explicit_physical_exit" \
  "local Android runner should reject an explicit physical Android device"
assert_contains 'is not an Android emulator' "${tmp_dir}/explicit-physical.err" \
  "explicit physical-device rejection should explain why the device is invalid"
assert_not_file_exists "$flutter_args_file" \
  "local Android runner should not start Flutter for explicit physical devices"

assert_contains 'bash ../local_stack/up.sh' "${REPO_ROOT}/mobile/mise.toml" \
  "mise local_up tasks should delegate to the shared stack launcher"
assert_contains 'bash ../local_stack/run_android_local.sh' "$local_android_task" \
  "mise local_android should delegate to the shared local Android runner"
assert_contains 'docker compose -f ../local_stack/docker-compose.yml down -v' "$local_reset_task" \
  "mise local_reset should wipe local stack volumes before restart"
assert_contains 'bash ../local_stack/up.sh' "$local_reset_task" \
  "mise local_reset should delegate restart to the shared stack launcher"
assert_not_contains 'rm -rf "$SCRIPT_DIR/master.key"' "${SCRIPT_DIR}/setup.sh" \
  "setup should not recursively delete a non-empty master.key directory"
assert_not_contains 'docker compose -f "$COMPOSE_FILE" up -d "${PULL_ARGS[@]}"' "${SCRIPT_DIR}/up.sh" \
  "up.sh should not start one-shot seed containers during default stack startup"
assert_contains 'docker compose -f "$COMPOSE_FILE" run --rm e2e-seed' "${SCRIPT_DIR}/up.sh" \
  "up.sh should run e2e-seed as an explicit lifecycle step"
assert_contains 'profiles: ["seed"]' "${SCRIPT_DIR}/docker-compose.yml" \
  "e2e-seed should be excluded from default compose up"
assert_contains 'source "${SCRIPT_DIR}/android_sdk.sh"' "${SCRIPT_DIR}/run_android_local.sh" \
  "local Android runner should reuse Android SDK discovery"
assert_contains 'Start with: mise run local_up' "${SCRIPT_DIR}/run_android_local.sh" \
  "local Android runner should point to the local stack startup task when services are down"
assert_contains '--dart-define=DEFAULT_ENV=LOCAL' "${SCRIPT_DIR}/run_android_local.sh" \
  "local Android runner should force the app into LOCAL environment"
assert_contains 'local_stack_has_running_container "$COMPOSE_FILE"' "${SCRIPT_DIR}/run_android_local.sh" \
  "local Android runner should reuse the shared local stack status check"
assert_contains 'local_stack_has_running_container "$COMPOSE_FILE"' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should reuse the shared local stack status check"
assert_contains 'PATROL_CLI_VERSION=4.7.0' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should pin patrol_cli to the version paired with the patrol package"
assert_contains ')" || true' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should tolerate offline patrol --version update-check failures"
assert_line_before 'PATROL_CLI_VERSION=4.7.0' 'Starting docker log capture' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should activate patrol_cli before profiler log capture starts"
assert_contains "if grep -rq 'patrolTest' \"\$TEST_PATH\"; then" "${SCRIPT_DIR}/profile.sh" \
  "profile runner should recurse so directory targets dispatch correctly"
assert_contains 'PATH="$PUB_CACHE_BIN:$PATH" patrol test' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should invoke patrol from the configured PUB_CACHE"
assert_contains '--device "$DEVICE"' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should pass the detected device to patrol so it never prompts"
assert_contains '"${PATROL_EXTRA_ARGS[@]+"${PATROL_EXTRA_ARGS[@]}"}"' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should guard the optional patrol args for bash 3.2 (macOS) under set -u"
assert_not_contains '    "${PATROL_EXTRA_ARGS[@]}" \' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should not expand the optional patrol args unguarded"
assert_contains 'flutter test "$TEST_PATH"' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should send plain integration_test suites through flutter test"
assert_contains '--device-id "$DEVICE"' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should pass the detected device to flutter test"
assert_contains 'flutter install --device-id "$DEVICE"' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should install before pre-granting notification permission"
assert_line_before 'flutter install --device-id "$DEVICE"' 'android.permission.POST_NOTIFICATIONS' "${SCRIPT_DIR}/profile.sh" \
  "profile runner should grant notification permission only after the app exists"

cat > "${tmp_dir}/bin/uname" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' Darwin
STUB
chmod +x "${tmp_dir}/bin/uname"

set +e
env -u DISPLAY AVD_NAME=Pixel_API_35 X11_SOCKET_DIR="${tmp_dir}/missing-x11" \
  PATH="${tmp_dir}/bin:${PATH}" HOME="${tmp_dir}/home" \
  bash "${SCRIPT_DIR}/emulator.sh" >/dev/null 2>"${tmp_dir}/darwin-emulator.err"
darwin_emulator_exit=$?
set -e
assert_eq "0" "$darwin_emulator_exit" \
  "Darwin emulator launch should not require Linux X11 socket discovery"

echo "android script checks passed"
