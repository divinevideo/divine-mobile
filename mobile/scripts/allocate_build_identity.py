#!/usr/bin/env python3
"""Gather fail-closed provider evidence before invoking the shared allocator."""

import os
import subprocess
import sys
from pathlib import Path

from release_identity import main as identity_main


def allocate_build(platform, env=os.environ, run=subprocess.run):
    directory = Path("build/shorebird")
    directory.mkdir(parents=True, exist_ok=True)

    def capture(name, args):
        result = run(args, capture_output=True, text=True, check=False)
        if result.returncode:
            raise ValueError(
                f"{name} lookup failed; repair provider credentials before rebuilding"
            )
        path = directory / name
        path.write_text(result.stdout)
        return path

    if platform == "ios":
        command = ["app-store-connect", "get-latest-build-number", "6747959501"]
    elif platform == "macos":
        command = [
            "app-store-connect",
            "get-latest-testflight-build-number",
            "--platform",
            "MAC_OS",
            "6747959501",
        ]
    elif platform == "android":
        command = [
            "google-play",
            "get-latest-build-number",
            "--package-name",
            "co.openvine.app",
        ]
    else:
        raise ValueError(f"unsupported release platform: {platform}")
    result = run(command, capture_output=True, text=True, check=False)
    raw_latest = result.stdout.strip()
    if platform == "macos" and result.returncode == 0 and raw_latest == "":
        raw_latest = "0"
    if (
        result.returncode
        or not raw_latest.isascii()
        or not raw_latest.isdigit()
    ):
        raise ValueError(
            "could not read the latest "
            + ("App Store Connect" if platform in {"ios", "macos"} else "Google Play")
            + " build number; refusing to guess"
        )
    latest = raw_latest
    tags = capture("stable_tags.txt", ["git", "ls-remote", "--tags", "origin"])
    # ls-remote includes object IDs; the allocator accepts ref names only.
    tags.write_text(
        "\n".join(line.split()[-1] for line in tags.read_text().splitlines()) + "\n"
    )
    source = run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True, check=True
    ).stdout.strip()
    args = [
        "allocate",
        "--platform",
        platform,
        "--pubspec",
        "pubspec.yaml",
        "--source-sha",
        source,
        "--reservation-key",
        env.get("RELEASE_TRAIN_RESERVATION_KEY") or "manual/" + env["CM_BUILD_ID"],
        "--codemagic-build-id",
        env["CM_BUILD_ID"],
        "--store-latest-build",
        latest,
        "--stable-tags",
        str(tags),
        "--output",
        str(directory / (platform + "_release.env")),
    ]
    if platform != "macos":
        shorebird = capture(
            "release_info.json",
            ["shorebird", "releases", "list", "--platform=" + platform, "--json"],
        )
        args += ["--shorebird-releases", str(shorebird)]
    if platform in {"ios", "macos"}:
        asc_platform = "MAC_OS" if platform == "macos" else "IOS"
        versions = capture(
            "store_versions.json",
            [
                "app-store-connect",
                "apps",
                "app-store-versions",
                "6747959501",
                "--platform",
                asc_platform,
                "--json",
            ],
        )
        args += ["--app-store-versions", str(versions)]
        if platform == "macos" and env.get("PROJECT_BUILD_NUMBER"):
            args += ["--build-number-floor", env["PROJECT_BUILD_NUMBER"]]
    else:
        track = capture(
            "production_track.json",
            [
                "google-play",
                "tracks",
                "get",
                "--package-name",
                "co.openvine.app",
                "--track",
                "production",
                "--json",
            ],
        )
        args += [
            "--play-production-track",
            str(track),
            "--build-number-floor",
            env["PROJECT_BUILD_NUMBER"],
        ]
    return identity_main(args)


if __name__ == "__main__":
    try:
        sys.exit(allocate_build(sys.argv[1]))
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print("ERROR: " + str(error))
        sys.exit(1)
