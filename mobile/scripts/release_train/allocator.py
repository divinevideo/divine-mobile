import re
from collections.abc import Iterable
from datetime import datetime

from release_train.ledger import LedgerError, LedgerStore, claim_path, reservation_path
from release_train.versions import Version, bump_patch, parse_version

CHANNEL = {"ios": "app-store", "android": "play-production"}

_CLAIM_RE = re.compile(r"^allocations/claims/([^/]+)/[^/]+\.json$")
_PROVENANCE_RE = re.compile(r"^releases/android/(\d+\.\d+\.\d+)\+(\d+)\.json$")


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
            provenance.setdefault(int(match.group(2)), match.group(1))
    mapped = {}
    unmappable = []
    for code in codes:
        text = None
        allocation = reservation_path("android", code)
        if allocation in paths:
            try:
                text = ledger.read_json(allocation).get("version")
            except LedgerError:
                text = None
        if not text:
            text = provenance.get(code)
        if not text:
            unmappable.append(code)
            continue
        mapped[code] = parse_version(text)
    if unmappable:
        listed = ", ".join(str(code) for code in sorted(set(unmappable)))
        raise AllocationError(
            f"cannot map Play version codes to a version: {listed}"
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
        if path in existing or path in created:
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
            ledger.create_json(path, record, f"claim {version} ({channel})")
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
