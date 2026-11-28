#!/usr/bin/env bash
# Sets up Mac App Store code signing on a Codemagic macOS runner.
#
# Fetches the Mac App Distribution certificate + Mac App Store provisioning
# profile and the Mac Installer Distribution certificate using the workflow's
# App Store Connect API integration, imports them into the build keychain,
# wires Xcode's signing settings, and writes:
#   - macos/Runner/Configs/LocalRelease.xcconfig (consumed by Release.xcconfig)
#   - build/macos/ExportOptions.plist (consumed by xcodebuild -exportArchive)
#
# Required environment variables:
#   BUNDLE_ID                - macOS bundle identifier (e.g. co.openvine.app)
#   CERTIFICATE_PRIVATE_KEY  - RSA PEM private key from the app-level
#                              `macos_signing_credentials` group matching the
#                              team's Mac App Distribution / Mac Installer
#                              Distribution certificates.
#   App Store Connect API credentials (injected automatically by Codemagic's
#   `integrations: app_store_connect: API key for Codemagic`).
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-co.openvine.app}"
PROFILES_DIR="${PROFILES_DIR:-$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles}"
LOCAL_RELEASE_XCCONFIG="macos/Runner/Configs/LocalRelease.xcconfig"
EXPORT_OPTIONS_PLIST="build/macos/ExportOptions.plist"

if [ -z "${CERTIFICATE_PRIVATE_KEY:-}" ]; then
  cat >&2 <<'EOF'
ERROR: CERTIFICATE_PRIVATE_KEY is not set in the Codemagic build environment.

Mac App Store signing requires a persistent RSA private key in PEM format so
Codemagic can match (or create once) the team's Mac App Distribution and Mac
Installer Distribution certificates without exhausting Apple's certificate limit.

One-time Codemagic setup:
  1. Generate a 2048-bit RSA key outside any git checkout (or extract the
     private key from an existing Mac Distribution .p12):
       ssh-keygen -t rsa -b 2048 -m PEM -f "$HOME/.ssh/divine_macos_dist_key" -q -N ""
  2. In Codemagic UI -> App Settings -> Environment variables, create the
     app-level group `macos_signing_credentials` with a secure variable named
     `CERTIFICATE_PRIVATE_KEY` containing the full PEM text.
  3. Ensure bundle ID co.openvine.app has macOS enabled in Apple Developer
     Portal / App Store Connect, then re-run macos-build.
EOF
  exit 1
fi

find_app_signing_identity() {
  security find-identity -v -p codesigning \
    | sed -En 's/.*"((Apple Distribution|3rd Party Mac Developer Application):[^"]*)".*/\1/p' \
    | head -1
}

find_installer_signing_identity() {
  security find-identity -v \
    | sed -En 's/.*"((Mac Installer Distribution|3rd Party Mac Developer Installer):[^"]*)".*/\1/p' \
    | head -1
}

mkdir -p "$PROFILES_DIR"
keychain initialize

echo "Fetching Mac App Distribution certificate and Mac App Store profile for $BUNDLE_ID..."
app-store-connect fetch-signing-files "$BUNDLE_ID" \
  --platform MAC_OS \
  --type MAC_APP_STORE \
  --profiles-dir "$PROFILES_DIR" \
  --certificate-key="@env:CERTIFICATE_PRIVATE_KEY" \
  --create

echo "Fetching Mac Installer Distribution certificate..."
app-store-connect certificates list \
  --type MAC_INSTALLER_DISTRIBUTION \
  --certificate-key="@env:CERTIFICATE_PRIVATE_KEY" \
  --save

# `keychain add-certificates` defaults to allowing only `codesign` and
# `productsign`. Mac App Store `.pkg` export invokes `/usr/bin/productbuild`,
# which fails headlessly unless it is on the key ACL and partition list.
keychain add-certificates --allow-app codesign productsign productbuild

# `certificates list --save` exits 0 with an empty list when no matching
# installer certificate exists yet for this private key. Inspect the keychain
# after import and create the certificate on demand.
INSTALLER_SIGNING_IDENTITY="$(find_installer_signing_identity)"
if [ -z "$INSTALLER_SIGNING_IDENTITY" ]; then
  echo "No matching Mac Installer Distribution certificate found; creating one..."
  app-store-connect certificates create \
    --type MAC_INSTALLER_DISTRIBUTION \
    --certificate-key="@env:CERTIFICATE_PRIVATE_KEY" \
    --save
  keychain add-certificates --allow-app codesign productsign productbuild
  INSTALLER_SIGNING_IDENTITY="$(find_installer_signing_identity)"
fi

if [ -z "$INSTALLER_SIGNING_IDENTITY" ]; then
  echo "ERROR: No Mac Installer Distribution or 3rd Party Mac Developer Installer certificate found in keychain." >&2
  security find-identity -v >&2 || true
  exit 1
fi

APP_SIGNING_IDENTITY="$(find_app_signing_identity)"
if [ -z "$APP_SIGNING_IDENTITY" ]; then
  echo "ERROR: No Apple Distribution or 3rd Party Mac Developer Application certificate found in keychain." >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

# Authorize Apple signing tools (`codesign`, `productbuild`, `productsign`) to
# access the imported private key non-interactively (`keychain initialize` uses
# an empty password by default). `keychain get-default` prints the raw path on
# stdout without mangling paths that contain spaces.
BUILD_KEYCHAIN="$(keychain get-default)"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$BUILD_KEYCHAIN" >/dev/null

xcode-project use-profiles --project macos/Runner.xcodeproj

# Inspect installed macOS provisioning profiles in PROFILES_DIR and find the
# Mac App Store profile matching BUNDLE_ID.
PROFILE_INFO=$(python3 - "$PROFILES_DIR" "$BUNDLE_ID" <<'PY'
import glob
import os
import plistlib
import subprocess
import sys

profiles_dir, bundle_id = sys.argv[1], sys.argv[2]
candidates = []

for path in sorted(glob.glob(os.path.join(profiles_dir, "*.provisionprofile"))):
    raw = subprocess.check_output(["security", "cms", "-D", "-i", path])
    plist = plistlib.loads(raw)
    entitlements = plist.get("Entitlements", {})
    app_id = entitlements.get("com.apple.application-identifier", "")
    teams = plist.get("TeamIdentifier") or []
    team_id = teams[0] if teams else ""
    expected_app_id = f"{team_id}.{bundle_id}" if team_id else bundle_id
    if app_id != expected_app_id:
        continue
    # Exclude development/ad-hoc profiles that carry ProvisionedDevices.
    if plist.get("ProvisionedDevices"):
        continue
    candidates.append((
        plist.get("ExpirationDate"),
        team_id,
        plist.get("Name", ""),
        plist.get("UUID", ""),
    ))

if not candidates:
    sys.stderr.write(
        f"ERROR: No Mac App Store provisioning profile found for {bundle_id} in {profiles_dir}\n"
    )
    sys.exit(1)

candidates.sort(key=lambda item: item[0], reverse=True)
_, team_id, name, uuid = candidates[0]
print(f"{team_id}|{name}|{uuid}")
PY
)

IFS='|' read -r TEAM_ID PROFILE_NAME PROFILE_UUID <<<"$PROFILE_INFO"

echo "Configured Mac App Store signing:"
echo "  Team ID:   $TEAM_ID"
echo "  Profile:   $PROFILE_NAME ($PROFILE_UUID)"
echo "  App cert:  $APP_SIGNING_IDENTITY"
echo "  Pkg cert:  $INSTALLER_SIGNING_IDENTITY"

# Override the tracked Release.xcconfig defaults via the git-ignored
# LocalRelease.xcconfig include so both `flutter build macos` and `xcodebuild
# archive` resolve SDK-qualified CODE_SIGN_IDENTITY[sdk=macosx*] cleanly.
cat > "$LOCAL_RELEASE_XCCONFIG" <<EOF
DIVINE_RELEASE_CODE_SIGN_STYLE = Manual
DIVINE_RELEASE_DEVELOPMENT_TEAM = $TEAM_ID
DIVINE_RELEASE_CODE_SIGN_IDENTITY = $APP_SIGNING_IDENTITY
PROVISIONING_PROFILE_SPECIFIER = $PROFILE_NAME
EOF

mkdir -p "$(dirname "$EXPORT_OPTIONS_PLIST")"
cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>signingCertificate</key>
	<string>$APP_SIGNING_IDENTITY</string>
	<key>installerSigningCertificate</key>
	<string>$INSTALLER_SIGNING_IDENTITY</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>$BUNDLE_ID</key>
		<string>$PROFILE_NAME</string>
	</dict>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
EOF

plutil -lint "$EXPORT_OPTIONS_PLIST"
