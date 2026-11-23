#!/usr/bin/env python3
"""Reject unusable direct-distribution apps before creating a public DMG."""

import argparse
import plistlib
from pathlib import Path
import subprocess
import sys


def run_tool(arguments: list[str], failure: str) -> str:
    result = subprocess.run(arguments, capture_output=True, text=True, check=False)
    if result.returncode:
        raise ValueError(failure)
    return result.stdout + result.stderr


def validate(bundle: Path, expected_bundle_id: str) -> None:
    with (bundle / "Contents" / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    if info.get("CFBundleIdentifier") != expected_bundle_id:
        raise ValueError("bundle identity does not match the distribution app")

    run_tool(
        ["codesign", "--verify", "--deep", "--strict", str(bundle)],
        "nested signature verification failed",
    )
    signature = run_tool(
        ["codesign", "--display", "--verbose=4", str(bundle)],
        "signature inspection failed",
    )
    fields = dict(line.split("=", 1) for line in signature.splitlines() if "=" in line)
    team = fields.get("TeamIdentifier", "")
    if fields.get("Signature") == "adhoc" or not team or team == "not set":
        raise ValueError("a usable signed team identity is required")
    if not any(
        line.startswith("Authority=Developer ID Application:")
        for line in signature.splitlines()
    ):
        raise ValueError("direct distribution requires a Developer ID signature")

    # codesign writes the plist to stdout and its diagnostic header to stderr.
    result = subprocess.run(
        ["codesign", "--display", "--entitlements", ":-", str(bundle)],
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise ValueError("keychain entitlement inspection failed")
    entitlements = plistlib.loads(result.stdout)
    if f"{team}.{expected_bundle_id}" not in entitlements.get(
        "keychain-access-groups", []
    ):
        raise ValueError("keychain access group does not match the signed app")

    run_tool(
        ["spctl", "--assess", "--type", "execute", str(bundle)],
        "Gatekeeper rejected the distribution app; verify notarization",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--bundle-id", required=True)
    arguments = parser.parse_args()
    try:
        validate(arguments.bundle, arguments.bundle_id)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"macOS distribution validation failed: {error}", file=sys.stderr)
        return 1
    print("macOS direct-distribution app validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
