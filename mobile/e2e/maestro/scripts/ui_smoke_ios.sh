#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Maestro iOS Simulator smoke runner (portable, verbose)
# Location: mobile/e2e/maestro/scripts/ui_smoke_ios.sh
#
# Behavior:
#  - Boots the requested iOS simulator (override with IOS_SIM_DEVICE)
#  - Installs mobile/build/ios/iphonesimulator/Runner.app onto it
#  - Verifies the Debug installation using BUNDLE_ID (co.openvine.app.staging)
#  - Runs Maestro suite: e2e/maestro/suites/smoke.yaml
#
# Build the app first, against STAGING — a PRODUCTION run signs in and writes
# test data to the live relay:
#   cd mobile && flutter build ios --simulator --dart-define=DEFAULT_ENV=STAGING
#
# Credentials are not committed. Supply them for the full smoke suite:
#   MAESTRO_USER_EMAIL=... MAESTRO_USER_PWD=... MAESTRO_SEARCH_USER=... \
#     bash e2e/maestro/scripts/ui_smoke_ios.sh
# ------------------------------------------------------------

# -----------------------------
# Helpers (LOGS -> stderr)
# -----------------------------
fail() { echo "❌ $1" >&2; exit 1; }
info() { echo "ℹ️  $1" >&2; }
ok()   { echo "✅ $1" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing '$1'. ${2:-}"
}

# -----------------------------
# Paths (location independent)
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAESTRO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOBILE_DIR="$(cd "${MAESTRO_DIR}/../.." && pwd)"

SUITE_PATH="${MAESTRO_DIR}/suites/smoke.yaml"
# Same artifact CI installs, so a local run and a Codemagic run exercise the
# same bundle. Nothing copies a Runner.app into e2e/maestro/.
APP_PATH="${MOBILE_DIR}/build/ios/iphonesimulator/Runner.app"
APP_INFO_PLIST="${APP_PATH}/Info.plist"

# -----------------------------
# Config
# -----------------------------
IOS_SIM_DEVICE="${IOS_SIM_DEVICE:-iPhone 16 Pro}"
MAESTRO_CLI="maestro"
BUNDLE_ID="co.openvine.app.staging"

# The official installer drops the binary here and it is not on a
# non-interactive PATH.
export PATH="${PATH}:${HOME}/.maestro/bin"

# -----------------------------
# Preconditions
# -----------------------------
info "Validating prerequisites..."
require_cmd xcrun "Install Xcode + Command Line Tools."
require_cmd plutil "plutil should exist on macOS."
# Not 'brew install maestro' -- that name now resolves to an unrelated cask
# ("Maestro, AI agent command center", ~680 MB) which ships no CLI at all.
require_cmd "${MAESTRO_CLI}" 'Install Maestro: curl -fsSL "https://get.maestro.mobile.dev" | bash'
[[ -f "${SUITE_PATH}" ]] || fail "Suite not found: ${SUITE_PATH}"
[[ -d "${APP_PATH}" ]] || fail "Runner.app not found at: ${APP_PATH}

Fix:
  cd ${MOBILE_DIR} && flutter build ios --simulator --dart-define=DEFAULT_ENV=STAGING"
[[ -f "${APP_INFO_PLIST}" ]] || fail "Info.plist not found at: ${APP_INFO_PLIST}"

for required in MAESTRO_USER_EMAIL MAESTRO_USER_PWD MAESTRO_SEARCH_USER; do
  [[ -n "${!required:-}" ]] || fail "Missing ${required}. The suite reads credentials from the environment; they are not committed."
done
ok "Prerequisites look good"

info "Suite path: ${SUITE_PATH}"
info "Target simulator device name: ${IOS_SIM_DEVICE}"
info "App bundle to install: ${APP_PATH}"
info "Bundle id expected: ${BUNDLE_ID}"

# -----------------------------
# Validate Runner.app is a SIMULATOR build
# -----------------------------
info "Validating Runner.app is a Simulator build..."
SUPPORTED_PLATFORMS="$(/usr/libexec/PlistBuddy -c "Print :CFBundleSupportedPlatforms" "${APP_INFO_PLIST}" 2>/dev/null || true)"

# CFBundleSupportedPlatforms is typically an array like:
#   Array {
#     0 = iPhoneSimulator
#   }
if echo "${SUPPORTED_PLATFORMS}" | grep -q "iPhoneSimulator"; then
  ok "Runner.app supports iPhoneSimulator ✅"
else
  info "CFBundleSupportedPlatforms from Runner.app Info.plist:"
  echo "${SUPPORTED_PLATFORMS:-"(not found)"}" >&2
  fail "Runner.app does NOT look like a Simulator build.

Fix:
  cd ${MOBILE_DIR} && flutter build ios --simulator --dart-define=DEFAULT_ENV=STAGING
"
fi

# -----------------------------
# Simulator helpers
# -----------------------------
get_booted_udid() {
  local json
  json="$(xcrun simctl list devices booted -j 2>/dev/null || true)"
  [[ -n "${json}" ]] || { echo ""; return 0; }

  echo "${json}" \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | awk -F'[<>]' '
        /<key>udid<\/key>/ {
          getline;
          gsub(/.*<string>|<\/string>.*/, "", $0);
          print $0;
          exit
        }'
}

find_device_udid_by_name() {
  local name="$1"
  local json
  json="$(xcrun simctl list devices -j 2>/dev/null || true)"
  [[ -n "${json}" ]] || { echo ""; return 0; }

  echo "${json}" \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | awk -v target="${name}" '
      BEGIN { inDevice=0; nameMatch=0; udid=""; available=0 }
      /<dict>/ { inDevice=1; nameMatch=0; udid=""; available=0 }
      /<\/dict>/ {
        if (inDevice && nameMatch && available && udid != "") { print udid; exit }
        inDevice=0
      }
      inDevice && /<key>isAvailable<\/key>/ { getline; if ($0 ~ /<true\/>/) available=1 }
      inDevice && /<key>name<\/key>/ { getline; if ($0 ~ "<string>" target "</string>") nameMatch=1 }
      inDevice && /<key>udid<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); udid=$0 }
    '
}

print_simulator_info() {
  local udid="$1"
  info "Simulator details (UDID: ${udid}):"

  local json
  json="$(xcrun simctl list devices -j 2>/dev/null || true)"
  [[ -n "${json}" ]] || { info "  • (unable to load simctl devices json)"; return 0; }

  echo "${json}" \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | awk -v target="$udid" '
      /<dict>/ { inDict=0 }
      /<key>udid<\/key>/ {
        getline;
        gsub(/.*<string>|<\/string>.*/, "", $0);
        if ($0 == target) inDict=1
      }
      inDict && /<key>name<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); print "  • Name: " $0 }
      inDict && /<key>state<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); print "  • State: " $0 }
      inDict && /<key>runtime<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); print "  • Runtime: " $0 }
    ' >&2
}

boot_simulator_if_needed() {
  # Always resolve IOS_SIM_DEVICE by name. Adopting whichever simulator
  # happened to be booted meant the run silently targeted someone else's
  # device, and with two booted simulators Maestro could then pick a
  # different one from the one we installed onto.
  local udid
  udid="$(find_device_udid_by_name "${IOS_SIM_DEVICE}")"
  [[ -n "${udid}" ]] || fail "Could not find an available simulator named '${IOS_SIM_DEVICE}'.
Run 'xcrun simctl list devices available' and set IOS_SIM_DEVICE to one of them."

  info "Booting simulator UDID: ${udid}"
  xcrun simctl boot "${udid}" 2>/dev/null || true
  open -a Simulator >/dev/null 2>&1 || true

  # Wait for the boot to actually complete rather than guessing at a sleep.
  xcrun simctl bootstatus "${udid}" -b >/dev/null 2>&1 \
    || fail "Simulator ${IOS_SIM_DEVICE} (${udid}) failed to boot."

  ok "Simulator booted successfully"
  print_simulator_info "${udid}"
  echo "${udid}"
}

install_app_on_simulator() {
  local udid="$1"

  info "Installing app on simulator..."
  info "Best-effort uninstall of existing app (if present): ${BUNDLE_ID}"
  xcrun simctl uninstall "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true

  info "Install command: xcrun simctl install ${udid} ${APP_PATH}"
  # IMPORTANT: do NOT suppress output — we want errors to be visible
  xcrun simctl install "${udid}" "${APP_PATH}" || fail "Failed to install Runner.app onto simulator."
  ok "Install step completed"
}

verify_app_installed() {
  local udid="$1"
  info "Verifying app installation..."
  info "Bundle id: ${BUNDLE_ID}"

  if xcrun simctl get_app_container "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1; then
    ok "App is installed on the simulator"
    return 0
  fi

  info "App not found under bundle id '${BUNDLE_ID}'. Dumping installed apps (filtered):"
  xcrun simctl listapps "${udid}" 2>/dev/null \
    | grep -Ei "CFBundle(DisplayName|Identifier|Name)" \
    | head -n 200 >&2 || true

  fail "Installation verification failed.
This usually means:
  • Runner.app bundle id is not '${BUNDLE_ID}', OR
  • install failed silently earlier (now visible above)."
}

# -----------------------------
# Main
# -----------------------------
info "Resolving iOS Simulator..."
SIM_UDID="$(boot_simulator_if_needed)"
ok "Using simulator UDID: ${SIM_UDID}"

install_app_on_simulator "${SIM_UDID}"
verify_app_installed "${SIM_UDID}"

info "Running Maestro suite..."
info "Command: ${MAESTRO_CLI} --device ${SIM_UDID} test ${SUITE_PATH}"
# --device is required: without it Maestro picks its own target and can run
# against a different simulator from the one we just installed onto.
"${MAESTRO_CLI}" --device "${SIM_UDID}" test \
  -e USER_EMAIL="${MAESTRO_USER_EMAIL}" \
  -e USER_PWD="${MAESTRO_USER_PWD}" \
  -e SEARCH_USER="${MAESTRO_SEARCH_USER}" \
  "${SUITE_PATH}"

ok "Maestro smoke suite completed successfully 🎉"
