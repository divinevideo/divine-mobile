from __future__ import annotations

import re
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime

from release_train.ledger import (
    BOOTSTRAP_PATH,
    LedgerError,
    LedgerStore,
    claim_path,
    key_path,
    provenance_path,
    reservation_path,
)
from release_train.versions import Version, bump_patch, parse_version

CHANNEL = {"ios": "app-store", "android": "play-production"}

_CLAIM_RE = re.compile(r"^allocations/claims/([^/]+)/[^/]+\.json$")
_PROVENANCE_RE = re.compile(
    r"^releases/android/(\d+\.\d+\.\d+)\+(\d+)\.json$", re.ASCII
)
_BUILD_RE = re.compile(r"^allocations/builds/([^/]+)/(\d+)\.json$", re.ASCII)
_DIGITS_RE = re.compile(r"[0-9]+")
_SHA_RE = re.compile(r"[0-9a-f]{40}")
_MANUAL_KEY_RE = re.compile(r"[A-Za-z0-9]+")


class AllocationError(RuntimeError):
    pass


def claimed_versions(paths: frozenset[str]) -> list[Version]:
    found = []
    for path in paths:
        match = _CLAIM_RE.match(path)
        if match:
            found.append(parse_version(match.group(1)))
    return found


def map_play_version_codes(
    ledger: LedgerStore, codes: Iterable[int]
) -> dict[int, Version]:
    paths = ledger.paths()
    provenance = {}
    for path in paths:
        match = _PROVENANCE_RE.match(path)
        if match:
            provenance.setdefault(int(match.group(2)), set()).add(match.group(1))
    mapped = {}
    unmappable = []
    for code in codes:
        text = None
        allocation = reservation_path("android", code)
        if allocation in paths:
            try:
                record = ledger.read_json(allocation)
            except LedgerError as error:
                raise AllocationError(
                    f"cannot read allocation for Play version code {code} "
                    f"at {allocation}: {error}"
                ) from error
            if "version" in record:
                text = record["version"]
                if not isinstance(text, str) or not text:
                    unmappable.append(
                        f"{code} (version at {allocation} is not a "
                        f"non-empty string)"
                    )
                    continue
        if text:
            try:
                mapped[code] = parse_version(text)
            except ValueError:
                unmappable.append(
                    f"{code} (version {text!r} at {allocation} is not X.Y.Z)"
                )
            continue
        candidates = provenance.get(code, set())
        if len(candidates) == 1:
            mapped[code] = parse_version(next(iter(candidates)))
        elif candidates:
            names = ", ".join(
                str(version) for version in sorted(map(parse_version, candidates))
            )
            unmappable.append(f"{code} (ambiguous provenance: {names})")
        else:
            unmappable.append(str(code))
    if unmappable:
        listed = ", ".join(sorted(set(unmappable)))
        raise AllocationError(
            f"cannot map Play version codes to a version: {listed} "
            "\u2014 for each code, add allocations/builds/android/<code>.json "
            'with a "version" string, then rerun'
        )
    return mapped


def reconcile(
    platform: str,
    *,
    ledger: LedgerStore,
    store_versions: Iterable[Version] = (),
    store_version_codes: Iterable[int] = (),
    now: datetime,
    dry_run: bool = False,
) -> list[str]:
    channel = CHANNEL[platform]
    if platform == "ios":
        versions = list(store_versions)
    else:
        versions = list(map_play_version_codes(ledger, store_version_codes).values())
    existing = ledger.paths()
    created = []
    for version in _unique(versions):
        path = claim_path(version, channel)
        if path in existing:
            continue
        if not dry_run:
            record = {
                "schema": 1,
                "version": str(version),
                "channel": channel,
                "platform": platform,
                "source": "reconciled",
                "observed_at": now.isoformat(),
            }
            if not ledger.create_json(path, record, f"claim {version} ({channel})"):
                # A concurrent run made this claim first; it is not ours.
                continue
        created.append(path)
    return created


def _unique(versions):
    seen = []
    for version in versions:
        if version not in seen:
            seen.append(version)
    return seen


def derive_version(floor: Version, claimed: Iterable[Version]) -> Version:
    claimed = list(claimed)
    if not claimed:
        return floor
    return max(floor, bump_patch(max(claimed)))


def validate_reservation_key(key: str, platform: str, source_sha: str) -> None:
    if not _SHA_RE.fullmatch(source_sha):
        raise AllocationError(
            "invalid reservation key source SHA: expected 40 lowercase hex digits"
        )
    if key == f"scheduled/{platform}/{source_sha}":
        return
    if key.startswith("manual/") and _MANUAL_KEY_RE.fullmatch(key[len("manual/") :]):
        return
    raise AllocationError(
        f"invalid reservation key {key!r}: expected manual/<alphanumeric> "
        f"or scheduled/{platform}/{source_sha}"
    )


def _numbers(paths: frozenset[str], platform: str) -> list[int]:
    found = []
    for path in paths:
        match = _BUILD_RE.match(path)
        if match and match.group(1) == platform:
            found.append(int(match.group(2)))
    return found


def _key_numbers(paths: frozenset[str], platform: str, key: str) -> list[int]:
    prefix = key_path(platform, key, 0)[: -len("0.json")]
    found = []
    for path in paths:
        if path.startswith(prefix) and path.endswith(".json"):
            number = path[len(prefix) : -len(".json")]
            if _DIGITS_RE.fullmatch(number):
                found.append(int(number))
    return found


def reserve_build_number(
    platform: str,
    version: Version,
    *,
    ledger: LedgerStore,
    source_sha: str,
    reservation_key: str,
    codemagic_build_id: str,
    store_latest: int,
    build_floor: int = 0,
    shorebird_versions: frozenset[str],
    now: datetime,
    attempts: int = 20,
) -> tuple[int, bool]:
    validate_reservation_key(reservation_key, platform, source_sha)
    paths = ledger.paths()

    def spent(n: int) -> bool:
        return (
            store_latest >= n
            or f"{version}+{n}" in shorebird_versions
            or provenance_path(platform, version, n) in paths
        )

    mine = _key_numbers(paths, platform, reservation_key)
    if mine:
        n = max(mine)
        record = ledger.read_json(reservation_path(platform, n))
        if (
            record.get("source_sha") != source_sha
            or record.get("reservation_key") != reservation_key
        ):
            raise AllocationError(
                f"reservation identity mismatch at {reservation_path(platform, n)}"
            )
        if record.get("version") == str(version) and n >= build_floor and not spent(n):
            return n, True
    n = max(store_latest, build_floor - 1, max(_numbers(paths, platform), default=0)) + 1
    origin = "manual" if reservation_key.startswith("manual/") else "scheduled"
    message = f"chore(release): reserve {platform} build {{}} for {version}"
    for _ in range(attempts):
        # A pre-ledger Shorebird release or provenance record can already
        # hold this identity; building it again would only fail later.
        while spent(n):
            n += 1
        record = {
            "schema": 1,
            "platform": platform,
            "build_number": n,
            "version": str(version),
            "source_sha": source_sha,
            "origin": origin,
            "reservation_key": reservation_key,
            "codemagic_build_id": codemagic_build_id,
            "reserved_at": now.isoformat(),
        }
        if ledger.create_json(
            reservation_path(platform, n), record, message.format(n)
        ):
            index = key_path(platform, reservation_key, n)
            created = ledger.create_json(
                index,
                {"schema": 1, "reservation_key": reservation_key, "build_number": n},
                message.format(n),
            )
            if not created:
                raise AllocationError(
                    f"ledger inconsistent: key index {index} already exists "
                    f"after reserving build {n}"
                )
            return n, False
        n += 1
    raise AllocationError(f"no free build number after {attempts} attempts")


@dataclass(frozen=True)
class Allocation:
    platform: str
    version: Version
    build_number: int
    reservation_key: str
    reused: bool

    @property
    def release_version(self) -> str:
        return f"{self.version}+{self.build_number}"


def allocate(
    platform: str,
    *,
    ledger: LedgerStore,
    pubspec: Version,
    source_sha: str,
    reservation_key: str,
    codemagic_build_id: str,
    store_latest: int,
    build_floor: int = 0,
    shorebird_versions: frozenset[str],
    stable_tags: list[Version],
    store_versions: Iterable[Version] = (),
    store_version_codes: Iterable[int] = (),
    now: datetime,
) -> Allocation:
    validate_reservation_key(reservation_key, platform, source_sha)
    if BOOTSTRAP_PATH not in ledger.paths():
        raise AllocationError(
            "the release ledger is not bootstrapped; run the "
            "release-identity-bootstrap workflow in Codemagic"
        )
    codes = list(store_version_codes)
    observed_versions = list(store_versions)
    reconcile(
        platform,
        ledger=ledger,
        store_versions=observed_versions,
        store_version_codes=codes,
        now=now,
    )
    version = derive_version(
        pubspec, claimed_versions(ledger.paths()) + list(stable_tags)
    )
    if platform == "ios" and observed_versions and version <= max(observed_versions):
        raise AllocationError(
            f"derived version {version} is not newer than the highest App Store "
            f"submitted version {max(observed_versions)}"
        )
    if platform == "android" and codes:
        mapped = map_play_version_codes(ledger, codes)
        highest = max(mapped.values(), default=None)
        if highest is not None and version < highest:
            raise AllocationError(
                f"derived version {version} is below the highest Play "
                f"production version {highest}"
            )
    number, reused = reserve_build_number(
        platform,
        version,
        ledger=ledger,
        source_sha=source_sha,
        reservation_key=reservation_key,
        codemagic_build_id=codemagic_build_id,
        store_latest=store_latest,
        build_floor=build_floor,
        shorebird_versions=shorebird_versions,
        now=now,
    )
    return Allocation(platform, version, number, reservation_key, reused)


def bootstrap(
    *,
    ledger: LedgerStore,
    ios_store_versions: list[Version],
    android_version_codes: list[int],
    now: datetime,
    dry_run: bool,
) -> list[str]:
    # Raises before any write if an Android code cannot be mapped.
    map_play_version_codes(ledger, android_version_codes)
    created = reconcile(
        "ios",
        ledger=ledger,
        store_versions=ios_store_versions,
        now=now,
        dry_run=dry_run,
    )
    created += reconcile(
        "android",
        ledger=ledger,
        store_version_codes=android_version_codes,
        now=now,
        dry_run=dry_run,
    )
    if BOOTSTRAP_PATH in ledger.paths():
        return created
    if not dry_run:
        record = {
            "schema": 1,
            "bootstrapped_at": now.isoformat(),
            "claims": sorted(created),
        }
        if not ledger.create_json(BOOTSTRAP_PATH, record, "bootstrap the release ledger"):
            return created
    return created + [BOOTSTRAP_PATH]
