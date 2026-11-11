from __future__ import annotations

import re
from typing import NamedTuple

_VERSION_RE = re.compile(r"^\d+(\.\d+){0,2}$", re.ASCII)
_PUBSPEC_RE = re.compile(
    r"^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$", re.MULTILINE | re.ASCII
)


class Version(NamedTuple):
    major: int
    minor: int
    patch: int

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}"


def parse_version(text: str) -> Version:
    if not _VERSION_RE.fullmatch(text):
        raise ValueError(f"invalid version: {text!r}")
    parts = [int(part) for part in text.split(".")]
    parts += [0] * (3 - len(parts))
    return Version(*parts)


def bump_patch(version: Version) -> Version:
    return Version(version.major, version.minor, version.patch + 1)


def pubspec_version(pubspec_text: str) -> Version:
    match = _PUBSPEC_RE.search(pubspec_text)
    if match is None:
        raise ValueError("pubspec has no version: X.Y.Z+N line")
    return parse_version(match.group(1))
