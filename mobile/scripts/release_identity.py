#!/usr/bin/env python3
"""Bootstrap the release ledger or allocate release versions and build numbers."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from release_train.allocator import AllocationError, allocate, bootstrap
from release_train.ledger import GhLedgerStore, LedgerError
from release_train.store_state import (
    ios_submitted_versions,
    play_production_version_codes,
    shorebird_release_versions,
    stable_tag_versions,
)
from release_train.versions import pubspec_version

DEFAULT_REPOSITORY = "divinevideo/divine-release-provenance"


def _build_number(text):
    if not re.fullmatch(r"[0-9]+", text, re.ASCII):
        raise argparse.ArgumentTypeError(
            f"expected a non-negative integer of ASCII digits, got {text!r}"
        )
    return int(text)


def _json(path):
    return json.loads(Path(path).read_text())


def _parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ledger-repository",
        default=os.environ.get("SHOREBIRD_PROVENANCE_REPOSITORY")
        or DEFAULT_REPOSITORY,
    )
    commands = parser.add_subparsers(dest="command", required=True)

    alloc = commands.add_parser("allocate", help="reserve a version and build number")
    alloc.add_argument("--platform", choices=("ios", "android"), required=True)
    alloc.add_argument("--pubspec", required=True)
    alloc.add_argument("--source-sha", required=True)
    alloc.add_argument("--reservation-key", required=True)
    alloc.add_argument("--codemagic-build-id", required=True)
    alloc.add_argument("--store-latest-build", type=_build_number, required=True)
    alloc.add_argument(
        "--build-number-floor",
        type=_build_number,
        default=0,
        help="minimum build number to allocate; separate from observed store uploads",
    )
    alloc.add_argument("--shorebird-releases", required=True)
    alloc.add_argument("--stable-tags", required=True)
    alloc.add_argument("--app-store-versions")
    alloc.add_argument("--play-production-track")
    alloc.add_argument("--output", required=True)

    boot = commands.add_parser("bootstrap", help="seed the ledger from store state")
    boot.add_argument("--app-store-versions", required=True)
    boot.add_argument("--play-production-track", required=True)
    boot.add_argument("--dry-run", action="store_true")
    return parser


def _check_platform_inputs(parser, args):
    wanted, other = (
        ("app_store_versions", "play_production_track")
        if args.platform == "ios"
        else ("play_production_track", "app_store_versions")
    )
    flag = lambda name: "--" + name.replace("_", "-")
    if getattr(args, wanted) is None:
        parser.error(f"{flag(wanted)} is required for --platform {args.platform}")
    if getattr(args, other) is not None:
        parser.error(f"{flag(other)} is not valid for --platform {args.platform}")


def _allocate(args, ledger, now):
    ios = args.platform == "ios"
    result = allocate(
        args.platform,
        ledger=ledger,
        pubspec=pubspec_version(Path(args.pubspec).read_text()),
        source_sha=args.source_sha,
        reservation_key=args.reservation_key,
        codemagic_build_id=args.codemagic_build_id,
        store_latest=args.store_latest_build,
        build_floor=args.build_number_floor,
        shorebird_versions=shorebird_release_versions(
            _json(args.shorebird_releases), args.platform
        ),
        stable_tags=stable_tag_versions(
            Path(args.stable_tags).read_text().splitlines()
        ),
        store_versions=(
            ios_submitted_versions(_json(args.app_store_versions)) if ios else ()
        ),
        store_version_codes=(
            () if ios else play_production_version_codes(_json(args.play_production_track))
        ),
        now=now,
    )
    lines = [
        f"SHOREBIRD_BUILD_NAME={result.version}",
        f"SHOREBIRD_BUILD_NUMBER={result.build_number}",
        f"SHOREBIRD_RELEASE_VERSION={result.release_version}",
        f"RELEASE_TRAIN_RESERVATION_KEY={result.reservation_key}",
        f"RELEASE_TRAIN_RESERVATION_REUSED={'true' if result.reused else 'false'}",
    ]
    Path(args.output).write_text("\n".join(lines) + "\n")


def _bootstrap(args, ledger, now):
    created = bootstrap(
        ledger=ledger,
        ios_store_versions=ios_submitted_versions(_json(args.app_store_versions)),
        android_version_codes=play_production_version_codes(
            _json(args.play_production_track)
        ),
        now=now,
        dry_run=args.dry_run,
    )
    if not created:
        print("ledger already bootstrapped; nothing to create")
        return
    print("would create:" if args.dry_run else "created:")
    for path in created:
        print(path)


def main(argv=None, *, ledger_factory=GhLedgerStore, now: datetime | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    if args.command == "allocate":
        _check_platform_inputs(parser, args)
    if now is None:
        now = datetime.now(timezone.utc)
    try:
        ledger = ledger_factory(args.ledger_repository)
        if args.command == "allocate":
            _allocate(args, ledger, now)
        else:
            _bootstrap(args, ledger, now)
    except (AllocationError, LedgerError, ValueError, OSError) as error:
        print(f"ERROR: {error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
