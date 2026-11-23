#!/usr/bin/env bash
# Verifies macOS Runner configuration stays compliant with Mac App Store rules:
#   - Release.entitlements keeps App Sandbox + keychain-access-groups and never
#     carries forbidden temporary exceptions (/tmp/) or Hardened Runtime CS
#     exceptions that App Store review rejects.
#   - Info.plist declares LSApplicationCategoryType, ITSAppUsesNonExemptEncryption=false,
#     NSSpeechRecognitionUsageDescription, and CFBundleLocalizations.
#   - PrivacyInfo.xcprivacy exists and is wired into Runner.xcodeproj Resources.
#   - NativeCameraPlugin.swift does not spawn subprocesses via Process().
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - "$MOBILE_DIR" <<'PY'
import os
import plistlib
import re
import sys

mobile_dir = sys.argv[1]
errors = []

entitlements_path = os.path.join(mobile_dir, "macos/Runner/Release.entitlements")
info_plist_path = os.path.join(mobile_dir, "macos/Runner/Info.plist")
privacy_path = os.path.join(mobile_dir, "macos/Runner/PrivacyInfo.xcprivacy")
pbxproj_path = os.path.join(mobile_dir, "macos/Runner.xcodeproj/project.pbxproj")
native_cam_path = os.path.join(mobile_dir, "macos/NativeCameraPlugin.swift")

with open(entitlements_path, "rb") as f:
    ent = plistlib.load(f)

if ent.get("com.apple.security.app-sandbox") is not True:
    errors.append("Release.entitlements must set com.apple.security.app-sandbox=true")

keychain_groups = ent.get("keychain-access-groups") or []
if "$(AppIdentifierPrefix)$(CFBundleIdentifier)" not in keychain_groups:
    errors.append(
        "Release.entitlements must include $(AppIdentifierPrefix)$(CFBundleIdentifier) "
        "in keychain-access-groups so Data Protection Keychain works in signed release builds"
    )

forbidden_entitlements = [
    "com.apple.security.temporary-exception.files.absolute-path.read-write",
    "com.apple.security.temporary-exception.files.absolute-path.read-only",
    "com.apple.security.cs.disable-executable-page-protection",
    "com.apple.security.cs.allow-unsigned-executable-memory",
    "com.apple.security.cs.disable-library-validation",
]
for key in forbidden_entitlements:
    if key in ent:
        errors.append(f"Release.entitlements carries Mac App Store-rejected key: {key}")

with open(info_plist_path, "rb") as f:
    info = plistlib.load(f)

category = info.get("LSApplicationCategoryType", "")
if not isinstance(category, str) or not category.startswith("public.app-category."):
    errors.append("macos/Runner/Info.plist must declare a valid LSApplicationCategoryType")

if info.get("ITSAppUsesNonExemptEncryption") is not False:
    errors.append("macos/Runner/Info.plist must set ITSAppUsesNonExemptEncryption=false")

if not info.get("NSSpeechRecognitionUsageDescription"):
    errors.append(
        "macos/Runner/Info.plist must declare NSSpeechRecognitionUsageDescription "
        "(required by ITMS-90683 for caption_generator's Speech framework link)"
    )

localizations = info.get("CFBundleLocalizations") or []
if "en" not in localizations or len(localizations) < 10:
    errors.append("macos/Runner/Info.plist must declare CFBundleLocalizations")

if not os.path.isfile(privacy_path):
    errors.append("Missing macos/Runner/PrivacyInfo.xcprivacy")
else:
    with open(privacy_path, "rb") as f:
        privacy = plistlib.load(f)
    if privacy.get("NSPrivacyTracking") is not False:
        errors.append("macos/Runner/PrivacyInfo.xcprivacy must set NSPrivacyTracking=false")
    if not isinstance(privacy.get("NSPrivacyCollectedDataTypes"), list) or not privacy["NSPrivacyCollectedDataTypes"]:
        errors.append("macos/Runner/PrivacyInfo.xcprivacy must declare NSPrivacyCollectedDataTypes")

pbxproj = open(pbxproj_path, encoding="utf-8").read()
if "PrivacyInfo.xcprivacy in Resources" not in pbxproj:
    errors.append("macos/Runner.xcodeproj/project.pbxproj must include PrivacyInfo.xcprivacy in Resources")

native_cam = open(native_cam_path, encoding="utf-8").read()
if re.search(r"\bProcess\s*\(", native_cam):
    errors.append("macos/NativeCameraPlugin.swift must not spawn subprocesses via Process() under App Sandbox")

if errors:
    for err in errors:
        sys.stderr.write(f"FAIL: {err}\n")
    sys.exit(1)

print("check_macos_app_store_config: OK")
PY
