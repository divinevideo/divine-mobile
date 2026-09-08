#!/usr/bin/env python3
"""Detector for Apple required-reason API use without a privacy declaration.

Apple requires every bundle that ships an executable using a "required reason
API" to declare that API, and its reason, in that bundle's own
`PrivacyInfo.xcprivacy`. An SDK may not rely on the host app's manifest
(https://developer.apple.com/documentation/bundleresources/
describing-use-of-required-reason-api). App Store Connect rejects submissions
that miss a declaration.

The failure this guards against is *drift*, not authoring mistakes. #8803 found
`divine_camera`'s manifest was written on 2026-01-14 (#890) with an empty
`NSPrivacyAccessedAPITypes`, and `ProcessInfo.systemUptime` arrived six weeks
later in #1783 without anyone revisiting it. The manifest was correct when
written and silently became wrong. A well-formedness check would not have
noticed.

Precision note, because the naive version of this detector is actively harmful:
Apple's required-reason `creationDate` / `modificationDate` are
`FileAttributeKey.creationDate` / `.modificationDate`. They are NOT
`PHAsset.creationDate` / `.modificationDate`, which are photo metadata and carry
no declaration duty. `LibProofMode/Classes/MediaItem.swift` uses both kinds a few
lines apart. Matching a bare `.creationDate` would flag the PHAsset lines and
push the author into declaring a reason the code does not need -- and Apple says
you may use an API only for a declared reason, so an unused declaration is
inaccurate rather than cautious. Bare accessors are therefore reported as
REVIEW (non-fatal) and never as a failure.
"""

from __future__ import annotations

import argparse
import os
import plistlib
import re
import sys

# --- Apple's required-reason API catalogue -------------------------------
# Symbols verified against Apple's DocC payload for
# bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/
# nsprivacyaccessedapitype (symbol reference links resolved), 2026-09-08.

FILE_TIMESTAMP = "NSPrivacyAccessedAPICategoryFileTimestamp"
SYSTEM_BOOT_TIME = "NSPrivacyAccessedAPICategorySystemBootTime"
DISK_SPACE = "NSPrivacyAccessedAPICategoryDiskSpace"
ACTIVE_KEYBOARDS = "NSPrivacyAccessedAPICategoryActiveKeyboards"
USER_DEFAULTS = "NSPrivacyAccessedAPICategoryUserDefaults"

ALL_CATEGORIES = {
    FILE_TIMESTAMP,
    SYSTEM_BOOT_TIME,
    DISK_SPACE,
    ACTIVE_KEYBOARDS,
    USER_DEFAULTS,
}

VALID_REASONS = {
    FILE_TIMESTAMP: {"DDA9.1", "C617.1", "3B52.1", "0A2A.1"},
    SYSTEM_BOOT_TIME: {"35F9.1", "8FFB.1", "3D61.1"},
    DISK_SPACE: {"85F4.1", "E174.1", "7D9E.1", "B728.1"},
    ACTIVE_KEYBOARDS: {"3EC4.1", "54BD.1"},
    USER_DEFAULTS: {"CA92.1", "1C8F.1", "C56D.1", "AC6B.1"},
}

# Unambiguous: each pattern can only mean the required-reason API.
DEFINITE = [
    (USER_DEFAULTS, re.compile(r"\b(?:NS)?UserDefaults\b")),
    (SYSTEM_BOOT_TIME, re.compile(r"\bsystemUptime\b|\bmach_absolute_time\b")),
    (
        FILE_TIMESTAMP,
        re.compile(
            r"\bcontentModificationDateKey\b|\bcreationDateKey\b"
            r"|\bfileModificationDate\b"
            r"|\bFileAttributeKey\.(?:creationDate|modificationDate)\b"
            r"|\bgetattrlist(?:bulk|at)?\s*\(|\bfgetattrlist\s*\("
            r"|\bfstatat\s*\(|\blstat\s*\(|\bfstat\s*\(|(?<![\w.])stat\s*\("
        ),
    ),
    (
        DISK_SPACE,
        re.compile(
            r"\bvolumeAvailableCapacity(?:ForImportantUsage|ForOpportunisticUsage)?Key\b"
            r"|\bvolumeTotalCapacityKey\b|\bsystemFreeSize\b|\bsystemSize\b"
            r"|\bstatfs\s*\(|\bstatvfs\s*\(|\bfstatfs\s*\(|\bfstatvfs\s*\("
        ),
    ),
    (ACTIVE_KEYBOARDS, re.compile(r"\bactiveInputModes\b")),
]

# Ambiguous: could be the required-reason symbol or an unrelated property of the
# same name (PHAsset, a model type, a JSON field). Reported, never fatal.
AMBIGUOUS = [
    (
        FILE_TIMESTAMP,
        re.compile(r"\battributesOfItem\b|\.(?:creationDate|modificationDate)\b"),
    ),
]

SOURCE_SUFFIXES = (".swift", ".m", ".mm", ".h", ".c")

def strip_noise(text: str) -> str:
    """Blank out comments and string literals, preserving line numbers.

    A comment mentioning `UserDefaults`, or a log string naming `statfs`, calls
    nothing. This file's own module docstring names most of the catalogue, and
    `AppDelegate.swift` documents its DEBUG-only `UserDefaults` bridge in prose
    directly above the call -- so without this the guard fails on the very repo
    it protects.
    """

    chars = list(text)

    def blank(start: int, end: int) -> None:
        for index in range(start, end):
            if chars[index] != "\n":
                chars[index] = " "

    def quoted_end(start: int, delimiter: str, *, escaped: bool) -> int:
        index = start + len(delimiter)
        while index < len(text):
            if escaped and text[index] == "\\":
                index += 2
                continue
            if text.startswith(delimiter, index):
                return index + len(delimiter)
            index += 1
        return len(text)

    index = 0
    while index < len(text):
        if text.startswith("//", index):
            end = text.find("\n", index)
            end = len(text) if end == -1 else end
            blank(index, end)
            index = end
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            end = len(text) if end == -1 else end + 2
            blank(index, end)
            index = end
            continue

        raw = re.match(r'(#+)("""|")', text[index:])
        if raw:
            hashes, quote = raw.groups()
            delimiter = quote + hashes
            close = text.find(delimiter, index + len(hashes) + len(quote))
            end = len(text) if close == -1 else close + len(delimiter)
            blank(index, end)
            index = end
            continue
        if text.startswith('"""', index):
            end = quoted_end(index, '"""', escaped=False)
            blank(index, end)
            index = end
            continue
        if text[index] == '"':
            end = quoted_end(index, '"', escaped=True)
            blank(index, end)
            index = end
            continue
        index += 1

    return "".join(chars)


_IF_DEBUG = re.compile(r"^\s*#if\s+DEBUG\s*$")
_IF_ANY = re.compile(r"^\s*#if\b")
_ELSEIF = re.compile(r"^\s*#elseif\b")
_ELSE = re.compile(r"^\s*#else\s*$")
_ENDIF = re.compile(r"^\s*#endif\b")


def strip_debug_only(text: str) -> str:
    """Blank out `#if DEBUG` branches, preserving line numbers.

    Apple's requirement is about the shipped binary. `AppDelegate.swift` reaches
    `UserDefaults` only inside `#if DEBUG`, to bridge the App Store screenshot
    pipeline's launch environment into shared_preferences, and that code is
    absent from Release -- proven by `strings` over
    build/ios/iphoneos/Runner.app/Runner, which finds zero occurrences of
    `flutter.screenshot_initial_route`. Counting it would force the app manifest
    to declare a reason the shipped app never exercises.

    Only a bare `#if DEBUG` is understood. Any other condition
    (`#if canImport(X)`, `#if !DEBUG`, `#if targetEnvironment(simulator)`) is
    left intact, so the guard errs toward reporting rather than hiding a use.
    The matching `#else` branch is kept: it IS the Release branch.
    """
    out: list[str] = []
    stack: list[str] = []  # one entry per open #if: "debug-skip", "debug-keep", "other"
    for line in text.splitlines():
        if _ENDIF.match(line):
            if stack:
                stack.pop()
            out.append(line)
            continue
        if _ELSE.match(line) or _ELSEIF.match(line):
            if stack and stack[-1] in ("debug-skip", "debug-keep"):
                stack[-1] = "debug-keep"
            out.append(line)
            continue
        if _IF_ANY.match(line):
            stack.append("debug-skip" if _IF_DEBUG.match(line) else "other")
            out.append(line)
            continue
        if "debug-skip" in stack:
            out.append(re.sub(r"[^\n]", " ", line))
        else:
            out.append(line)
    return "\n".join(out)


class Unit:
    """One bundle that must carry its own manifest."""

    def __init__(
        self,
        name: str,
        roots: list[str],
        manifest: str,
        podspec: str | None,
        selected_subspec: str | None = None,
        xcodeproj: str | None = None,
    ):
        self.name = name
        self.roots = roots
        self.manifest = manifest
        self.podspec = podspec
        self.selected_subspec = selected_subspec
        self.xcodeproj = xcodeproj


def discover(mobile: str) -> list[Unit]:
    units: list[Unit] = []
    ios = os.path.join(mobile, "ios")
    selected_subspecs: dict[str, str] = {}
    podfile = os.path.join(ios, "Podfile")
    try:
        with open(podfile, "r", encoding="utf-8") as handle:
            podfile_text = handle.read()
    except OSError:
        podfile_text = ""
    # Podfile declarations are Ruby: retain quoted names and ignore comment lines.
    for _, pod, subspec in re.findall(
        r"^[ \t]*pod[ \t]+(['\"])([^/'\"\n]+)/([^'\"\n]+)\1",
        podfile_text,
        re.M,
    ):
        selected_subspecs[pod] = subspec

    units.append(
        Unit(
            "app:Runner",
            [os.path.join(ios, "Runner")],
            os.path.join(ios, "Runner", "PrivacyInfo.xcprivacy"),
            None,
            xcodeproj=os.path.join(ios, "Runner.xcodeproj", "project.pbxproj"),
        )
    )
    for ext in ("NotificationServiceExtension", "CameraQuickActionWidget"):
        path = os.path.join(ios, ext)
        if os.path.isdir(path):
            units.append(
                Unit(f"extension:{ext}", [path],
                     os.path.join(path, "PrivacyInfo.xcprivacy"), None)
            )

    local_pods = os.path.join(ios, "LocalPods")
    if os.path.isdir(local_pods):
        for pod in sorted(os.listdir(local_pods)):
            path = os.path.join(local_pods, pod)
            if not os.path.isdir(path):
                continue
            specs = [f for f in os.listdir(path) if f.endswith(".podspec")]
            units.append(
                Unit(f"localpod:{pod}", [path],
                     os.path.join(path, "Resources", "PrivacyInfo.xcprivacy"),
                     os.path.join(path, specs[0]) if specs else None,
                     selected_subspec=selected_subspecs.get(pod))
            )

    packages = os.path.join(mobile, "packages")
    if os.path.isdir(packages):
        for pkg in sorted(os.listdir(packages)):
            pkg_ios = os.path.join(packages, pkg, "ios")
            if not os.path.isdir(pkg_ios):
                continue
            specs = [f for f in os.listdir(pkg_ios) if f.endswith(".podspec")]
            units.append(
                Unit(f"package:{pkg}", [pkg_ios],
                     os.path.join(pkg_ios, "Resources", "PrivacyInfo.xcprivacy"),
                     os.path.join(pkg_ios, specs[0]) if specs else None,
                     selected_subspec=selected_subspecs.get(pkg))
            )
    return units


def scan_sources(roots: list[str]) -> tuple[dict, dict]:
    definite: dict[str, list[str]] = {}
    ambiguous: dict[str, list[str]] = {}
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [
                d for d in dirnames
                if d not in {"Pods", "build", ".symlinks", "DerivedData", ".git"}
            ]
            for filename in sorted(filenames):
                if not filename.endswith(SOURCE_SUFFIXES):
                    continue
                full = os.path.join(dirpath, filename)
                try:
                    with open(full, "r", encoding="utf-8", errors="replace") as handle:
                        code = strip_debug_only(strip_noise(handle.read()))
                except OSError:
                    continue
                for lineno, line in enumerate(code.splitlines(), 1):
                    for category, pattern in DEFINITE:
                        if pattern.search(line):
                            definite.setdefault(category, []).append(f"{full}:{lineno}")
                    for category, pattern in AMBIGUOUS:
                        if pattern.search(line):
                            ambiguous.setdefault(category, []).append(f"{full}:{lineno}")
    return definite, ambiguous


def read_manifest(path: str) -> tuple[dict[str, set[str]] | None, list[str]]:
    """Return declared {category: reasons} plus structural problems."""
    if not os.path.exists(path):
        return None, []
    problems: list[str] = []
    try:
        with open(path, "rb") as handle:
            data = plistlib.load(handle)
    except Exception as error:  # noqa: BLE001 - surface any parse failure
        return {}, [f"{path}: not a readable plist ({error})"]

    declared: dict[str, set[str]] = {}
    for entry in data.get("NSPrivacyAccessedAPITypes", []) or []:
        category = entry.get("NSPrivacyAccessedAPIType")
        reasons = set(entry.get("NSPrivacyAccessedAPITypeReasons", []) or [])
        if category not in ALL_CATEGORIES:
            problems.append(f"{path}: unknown API category {category!r}")
            continue
        bad = reasons - VALID_REASONS[category]
        if bad:
            problems.append(
                f"{path}: {category} declares invalid reason code(s) "
                f"{sorted(bad)}; allowed: {sorted(VALID_REASONS[category])}"
            )
        if not reasons:
            problems.append(f"{path}: {category} declares no reason code")
        declared[category] = reasons
    return declared, problems


def xcode_manifest_is_runner_resource(project: str) -> bool:
    """Return whether Runner's Resources phase contains its privacy manifest."""
    file_refs = set(
        re.findall(
            r"^\s*([A-F0-9]+) /\* PrivacyInfo\.xcprivacy \*/ = "
            r"\{isa = PBXFileReference;[^\n]*\bpath = PrivacyInfo\.xcprivacy;",
            project,
            re.M,
        )
    )
    build_files = set()
    for build_id, file_ref in re.findall(
        r"^\s*([A-F0-9]+) /\* PrivacyInfo\.xcprivacy in Resources \*/ = "
        r"\{isa = PBXBuildFile; fileRef = ([A-F0-9]+)",
        project,
        re.M,
    ):
        if file_ref in file_refs:
            build_files.add(build_id)

    runner = re.search(
        r"^\s*[A-F0-9]+ /\* Runner \*/ = \{\s*\n"
        r"\s*isa = PBXNativeTarget;(?P<body>.*?)^\s*\};",
        project,
        re.M | re.S,
    )
    if not runner:
        return False
    phases = re.search(r"buildPhases = \((?P<ids>.*?)\);", runner.group("body"), re.S)
    if not phases:
        return False
    resource_ids = re.findall(r"([A-F0-9]+) /\* Resources \*/", phases.group("ids"))
    for resource_id in resource_ids:
        phase = re.search(
            rf"^\s*{re.escape(resource_id)} /\* Resources \*/ = \{{\s*\n"
            r"\s*isa = PBXResourcesBuildPhase;(?P<body>.*?)^\s*\};",
            project,
            re.M | re.S,
        )
        if not phase:
            continue
        files = re.search(r"files = \((?P<ids>.*?)\);", phase.group("body"), re.S)
        if files and any(build_id in files.group("ids") for build_id in build_files):
            return True
    return False


def podspec_bundles_manifest(spec: str, selected_subspec: str | None) -> bool:
    """Return whether the selected pod specification bundles the manifest."""
    uncommented = "\n".join(
        line for line in spec.splitlines() if not line.lstrip().startswith("#")
    )
    if selected_subspec:
        subspec = re.search(
            rf"\bs\.subspec\s+['\"]{re.escape(selected_subspec)}['\"]\s+do\s+"
            r"\|(?P<var>\w+)\|(?P<body>.*?)^\s*end\b",
            uncommented,
            re.M | re.S,
        )
        if not subspec:
            return False
        variable = re.escape(subspec.group("var"))
        return bool(
            re.search(
                rf"\b{variable}\.resource_bundles\s*=\s*"
                r"\{[^}]*PrivacyInfo\.xcprivacy[^}]*\}",
                subspec.group("body"),
                re.S,
            )
        )
    return bool(
        re.search(
            r"\b\w+\.resource_bundles\s*=\s*\{[^}]*PrivacyInfo\.xcprivacy[^}]*\}",
            uncommented,
            re.S,
        )
    )


def check_sources(mobile: str) -> int:
    failures: list[str] = []
    warnings: list[str] = []

    for unit in discover(mobile):
        definite, ambiguous = scan_sources(unit.roots)
        declared, problems = read_manifest(unit.manifest)
        failures.extend(problems)

        if definite and declared is None:
            for category, sites in sorted(definite.items()):
                failures.append(
                    f"{unit.name}: uses {category} at {sites[0]} "
                    f"({len(sites)} site(s)) but has NO manifest at {unit.manifest}"
                )
        elif declared is not None:
            for category, sites in sorted(definite.items()):
                if category not in declared:
                    failures.append(
                        f"{unit.name}: uses {category} at "
                        + ", ".join(sites[:3])
                        + (f" (+{len(sites) - 3} more)" if len(sites) > 3 else "")
                        + f" but {unit.manifest} does not declare it"
                    )
            for category in sorted(set(declared) - set(definite)):
                warnings.append(
                    f"{unit.name}: {unit.manifest} declares {category} but no "
                    f"call site was detected -- confirm it is still used, or "
                    f"remove it (Apple permits use only for declared reasons)"
                )
            # A manifest nothing bundles is a manifest Apple never reads. For
            # the app target that wiring lives in Copy Bundle Resources, so a
            # file added to ios/Runner/ but never added to the Xcode target
            # looks correct in git and ships nothing.
            if os.path.exists(unit.manifest) and unit.xcodeproj:
                try:
                    with open(unit.xcodeproj, "r", encoding="utf-8") as handle:
                        project = handle.read()
                except OSError:
                    project = ""
                if not xcode_manifest_is_runner_resource(project):
                    failures.append(
                        f"{unit.name}: {unit.manifest} exists but "
                        f"{unit.xcodeproj} never references it, so it is not in "
                        f"Copy Bundle Resources and never reaches the archive"
                    )
            if declared and unit.podspec:
                try:
                    with open(unit.podspec, "r", encoding="utf-8") as handle:
                        spec = handle.read()
                except OSError:
                    spec = ""
                if not podspec_bundles_manifest(spec, unit.selected_subspec):
                    failures.append(
                        f"{unit.name}: {unit.manifest} exists but "
                        f"{unit.podspec} has no resource_bundles entry for it, "
                        f"so it never reaches the archive"
                    )

        for category, sites in sorted(ambiguous.items()):
            if declared and category in declared:
                continue
            warnings.append(
                f"{unit.name}: possible {category} use (ambiguous accessor) at "
                + ", ".join(sites[:3])
                + (f" (+{len(sites) - 3} more)" if len(sites) > 3 else "")
                + " -- confirm whether this is FileAttributeKey/URLResourceKey "
                  "(declare it) or unrelated metadata such as PHAsset (ignore)"
            )

    for warning in warnings:
        print(f"⚠️  {warning}")
    for failure in failures:
        print(f"❌ {failure}")
    if failures:
        print(
            "\nDeclare the API in the owning bundle's PrivacyInfo.xcprivacy. "
            "Reason codes and their exact meanings: "
            "mobile/docs/IOS_PRIVACY_MANIFESTS.md"
        )
        return 1
    print("✅ every detected required-reason API use is declared in its own bundle")
    return 0


def check_archive(app: str, mobile: str) -> int:
    """Prove the manifests a source scan trusts actually reach the product."""
    if not os.path.isdir(app):
        print(f"❌ archive path is not a directory: {app}")
        return 1

    found = set()
    for dirpath, _dirnames, filenames in os.walk(app):
        for filename in filenames:
            if filename == "PrivacyInfo.xcprivacy":
                found.add(os.path.relpath(os.path.join(dirpath, filename), app))
    print(f"ℹ️  {len(found)} privacy manifest(s) in {os.path.basename(app)}")

    expected = {
        "app manifest": "PrivacyInfo.xcprivacy",
        "divine_camera": "divine_camera_privacy.bundle/PrivacyInfo.xcprivacy",
        "divine_quick_actions": "divine_quick_actions_privacy.bundle/PrivacyInfo.xcprivacy",
        "LibProofMode": "LibProofMode_privacy.bundle/PrivacyInfo.xcprivacy",
    }
    failures = []
    for label, rel in expected.items():
        if rel in found:
            print(f"  ✅ {label}: {rel}")
        else:
            failures.append(f"{label}: expected {rel} in the built app, not found")

    for rel in sorted(found):
        if not rel.startswith(("divine_", "LibProofMode_")) and rel != "PrivacyInfo.xcprivacy":
            continue
        try:
            with open(os.path.join(app, rel), "rb") as handle:
                plistlib.load(handle)
        except Exception as error:  # noqa: BLE001
            failures.append(f"{rel}: bundled manifest is unreadable ({error})")

    for failure in failures:
        print(f"❌ {failure}")
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mobile", default=".", help="path to the mobile/ directory")
    parser.add_argument("--archive", help="path to a built .app to verify")
    parser.add_argument("--detail", action="store_true", help="list every call site")
    args = parser.parse_args()

    if args.archive:
        return check_archive(args.archive, args.mobile)

    if args.detail:
        for unit in discover(args.mobile):
            definite, ambiguous = scan_sources(unit.roots)
            if not definite and not ambiguous:
                continue
            print(f"\n## {unit.name}  (manifest: {unit.manifest})")
            for category, sites in sorted(definite.items()):
                print(f"  {category}")
                for site in sites:
                    print(f"    {site}")
            for category, sites in sorted(ambiguous.items()):
                print(f"  [ambiguous] {category}")
                for site in sites:
                    print(f"    {site}")
        print()

    return check_sources(args.mobile)


if __name__ == "__main__":
    sys.exit(main())
