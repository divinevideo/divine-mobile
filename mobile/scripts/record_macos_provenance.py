#!/usr/bin/env python3
"""Record create-only private provenance for a signed Mac App Store .pkg."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

from release_train.ledger import GhLedgerStore, LedgerError, provenance_path

DEFAULT_REPOSITORY = "divinevideo/divine-release-provenance"
_SHA_RE = re.compile(r"[0-9a-f]{40}")
_VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$")


def _read_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def record_provenance(
    *,
    release_env_path: Path = Path("build/shorebird/macos_release.env"),
    pkg_dir: Path = Path("build/macos/pkg"),
    output_path: Path = Path("build/shorebird/macos_provenance.json"),
    env=os.environ,
    ledger=None,
    source_sha: str | None = None,
    now: datetime | None = None,
) -> dict:
    values = _read_env_file(release_env_path)
    release_version = values.get("SHOREBIRD_RELEASE_VERSION", "")
    if not _VERSION_RE.fullmatch(release_version):
        raise ValueError(f"invalid macOS release version: {release_version!r}")
    version_name, build_number = release_version.split("+", 1)

    source = source_sha or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True
    ).strip()
    if not _SHA_RE.fullmatch(source):
        raise ValueError("invalid git source SHA")
    expected = values.get("RELEASE_SOURCE_SHA", "")
    if expected != source:
        raise ValueError("allocated macOS source SHA does not match checked-out HEAD")

    pkgs = sorted(pkg_dir.glob("*.pkg"))
    if len(pkgs) != 1 or not pkgs[0].is_file():
        raise ValueError(f"expected exactly one signed .pkg in {pkg_dir}, found {len(pkgs)}")
    pkg = pkgs[0]
    pkg_sha256 = _sha256_file(pkg)

    record = {
        "schema": 1,
        "platform": "macos",
        "release_version": release_version,
        "build_name": version_name,
        "build_number": int(build_number),
        "build_source_commit": source,
        "patchable": False,
        "pkg_name": pkg.name,
        "pkg_sha256": pkg_sha256,
        "pkg_size_bytes": pkg.stat().st_size,
        "codemagic_build_id": env.get("CM_BUILD_ID", ""),
        "workflow_id": env.get("CM_WORKFLOW_ID", ""),
        "recorded_at": (now or datetime.now(UTC)).isoformat(),
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    repo = env.get("SHOREBIRD_PROVENANCE_REPOSITORY") or DEFAULT_REPOSITORY
    store = ledger or GhLedgerStore(repo, token=env.get("PROVENANCE_TOKEN"))
    remote = provenance_path("macos", version_name, int(build_number))
    created = store.create_json(
        remote,
        record,
        f"Record macOS App Store release {release_version}",
    )
    if not created:
        raise ValueError(
            f"provenance already exists for macOS release {release_version}; refusing to overwrite it"
        )
    return record


def main() -> int:
    try:
        record = record_provenance()
    except (ValueError, KeyError, OSError, LedgerError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Recorded macOS provenance: {record['release_version']} ({record['pkg_sha256'][:12]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
