"""Normalize raw store, Shorebird, and tag listings into plain Python values."""

import re
from typing import Iterable

from .versions import Version, parse_version

_UNSUBMITTED_IOS_STATES = frozenset({"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"})
_ASCII_DIGITS = re.compile(r"[0-9]+")
_STABLE_TAG = re.compile(r"refs/tags/(\d+\.\d+\.\d+)")


def ios_submitted_versions(app_store_versions: list) -> list[Version]:
    if not isinstance(app_store_versions, list) or not app_store_versions:
        raise ValueError("App Store versions lookup returned no entries")
    versions = []
    for entry in app_store_versions:
        attrs = entry.get("attributes") if isinstance(entry, dict) else None
        if not isinstance(attrs, dict):
            raise ValueError(f"App Store version entry has no attributes: {entry!r}")
        version = attrs.get("versionString")
        state = attrs.get("appVersionState") or attrs.get("appStoreState")
        if not version or not state:
            raise ValueError(
                f"App Store version entry missing versionString or state: {entry!r}"
            )
        if state in _UNSUBMITTED_IOS_STATES:
            continue
        versions.append(parse_version(version))
    return versions


def play_production_version_codes(track: dict) -> list[int]:
    if not isinstance(track, dict) or track.get("track") != "production":
        raise ValueError("Play track payload is not the production track")
    releases = track.get("releases")
    if not isinstance(releases, list):
        raise ValueError("Play track payload has no releases list")
    codes = []
    for release in releases:
        if not isinstance(release, dict):
            raise ValueError(f"Play release is not an object: {release!r}")
        version_codes = release.get("versionCodes", [])
        if not isinstance(version_codes, list):
            raise ValueError(f"Play versionCodes is not a list: {version_codes!r}")
        for code in version_codes:
            if not isinstance(code, str) or not _ASCII_DIGITS.fullmatch(code):
                raise ValueError(f"Play versionCode is not a digit string: {code!r}")
            codes.append(int(code))
    return codes


def shorebird_release_versions(payload: dict, platform: str) -> frozenset[str]:
    if not isinstance(payload, dict) or payload.get("status") != "success":
        raise ValueError(
            f"Shorebird releases lookup failed: {payload.get('error') if isinstance(payload, dict) else payload!r}"
        )
    data = payload.get("data")
    releases = data.get("releases") if isinstance(data, dict) else None
    if not isinstance(releases, list):
        raise ValueError("Shorebird payload has no data.releases list")
    versions = set()
    for release in releases:
        if not isinstance(release, dict):
            raise ValueError(f"Shorebird release is not an object: {release!r}")
        version = release.get("version")
        if not isinstance(version, str) or not version:
            raise ValueError(f"Shorebird release has no version: {release!r}")
        statuses = release.get("platform_statuses")
        if not isinstance(statuses, dict):
            raise ValueError(f"Shorebird release has no platform_statuses: {release!r}")
        if platform in statuses:
            versions.add(version)
    return frozenset(versions)


def stable_tag_versions(refs: Iterable[str]) -> list[Version]:
    versions = []
    for ref in refs:
        match = _STABLE_TAG.fullmatch(ref.strip())
        if match:
            versions.append(parse_version(match.group(1)))
    return versions
