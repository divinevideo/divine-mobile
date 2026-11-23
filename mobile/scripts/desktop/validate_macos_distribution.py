#!/usr/bin/env python3
"""Reject unusable direct-distribution apps before creating a public DMG."""

import argparse
from datetime import datetime, timezone
import plistlib
from pathlib import Path
import subprocess
import sys
import tempfile


def run_tool(arguments: list[str], failure: str) -> str:
    result = subprocess.run(arguments, capture_output=True, text=True, check=False)
    if result.returncode:
        raise ValueError(failure)
    return result.stdout + result.stderr


def permits(claim: str, allowed: str) -> bool:
    return claim == allowed or (
        allowed.endswith("*") and claim.startswith(allowed[:-1])
    )


def signing_certificate(bundle: Path) -> bytes:
    with tempfile.TemporaryDirectory(prefix="divine-signing-certificate-") as temporary:
        prefix = str(Path(temporary) / "certificate-")
        run_tool(
            ["codesign", "--display", f"--extract-certificates={prefix}", str(bundle)],
            "provisioning profile signing certificate could not be inspected",
        )
        certificate = Path(f"{prefix}0")
        if not certificate.is_file():
            raise ValueError("provisioning profile signing certificate is missing")
        return certificate.read_bytes()


def verify_profile(bundle: Path, bundle_id: str, team: str, entitlements: dict) -> None:
    profile_path = next(
        (
            bundle / "Contents" / name
            for name in ("embedded.provisionprofile", "embedded.mobileprovision")
            if (bundle / "Contents" / name).is_file()
        ),
        None,
    )
    if profile_path is None:
        raise ValueError("a provisioning profile is required for keychain authorization")
    result = subprocess.run(
        ["security", "cms", "-D", "-i", str(profile_path)],
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise ValueError("provisioning profile could not be decoded")
    profile = plistlib.loads(result.stdout)
    expiry = profile.get("ExpirationDate")
    if (
        not isinstance(expiry, datetime)
        or expiry.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc)
    ):
        raise ValueError("provisioning profile is expired or has no expiry")
    if team not in profile.get("TeamIdentifier", []):
        raise ValueError("provisioning profile belongs to another signing team")
    allowed = profile.get("Entitlements", {})
    application = allowed.get("com.apple.application-identifier", "")
    if not permits(f"{team}.{bundle_id}", application):
        raise ValueError("provisioning profile does not authorize this app")
    for key, claims in entitlements.items():
        if key != "keychain-access-groups" and not key.startswith(
            "com.apple.developer."
        ):
            continue
        authorization = allowed.get(key)
        if (
            key == "com.apple.developer.associated-domains"
            and authorization == "*"
            and isinstance(claims, list)
        ):
            authorized = all(isinstance(claim, str) for claim in claims)
        elif isinstance(claims, list) and isinstance(authorization, list):
            authorized = all(
                any(
                    isinstance(pattern, str) and permits(claim, pattern)
                    for pattern in authorization
                )
                for claim in claims
            )
        else:
            authorized = claims == authorization
        if not authorized:
            raise ValueError(
                "provisioning profile does not authorize a restricted entitlement"
            )
    if signing_certificate(bundle) not in profile.get("DeveloperCertificates", []):
        raise ValueError("provisioning profile does not authorize the signing certificate")


def verify_notarization(bundle: Path) -> None:
    # Fetching ticket status does not itself enforce a notarized requirement.
    run_tool(
        ["codesign", "--verify", "--check-notarization", "-R=notarized", str(bundle)],
        "an Apple notarization ticket is required for the distribution app",
    )


def validate(bundle: Path, expected_bundle_id: str, expected_team_id: str) -> None:
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
    if team != expected_team_id:
        raise ValueError("signing team does not match the configured distribution app")
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

    verify_profile(bundle, expected_bundle_id, expected_team_id, entitlements)

    # Local policy may permit this code without an Apple notarization ticket.
    verify_notarization(bundle)
    run_tool(
        ["spctl", "--assess", "--type", "execute", str(bundle)],
        "Gatekeeper rejected the distribution app; verify notarization",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--team-id", required=True)
    arguments = parser.parse_args()
    try:
        validate(arguments.bundle, arguments.bundle_id, arguments.team_id)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"macOS distribution validation failed: {error}", file=sys.stderr)
        return 1
    print("macOS direct-distribution app validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
