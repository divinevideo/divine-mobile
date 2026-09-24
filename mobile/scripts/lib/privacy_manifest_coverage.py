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
import json
import os
import plistlib
import re
import sys

# --- Apple's required-reason API catalogue -------------------------------

CATALOGUE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "data",
    "apple_required_reason_catalogue.json",
)

with open(CATALOGUE_PATH, encoding="utf-8") as catalogue_file:
    CATALOGUE = json.load(catalogue_file)

CATEGORIES = {category["id"]: category for category in CATALOGUE["categories"]}

FILE_TIMESTAMP = "NSPrivacyAccessedAPICategoryFileTimestamp"
SYSTEM_BOOT_TIME = "NSPrivacyAccessedAPICategorySystemBootTime"
DISK_SPACE = "NSPrivacyAccessedAPICategoryDiskSpace"
ACTIVE_KEYBOARDS = "NSPrivacyAccessedAPICategoryActiveKeyboards"
USER_DEFAULTS = "NSPrivacyAccessedAPICategoryUserDefaults"

ALL_CATEGORIES = set(CATEGORIES)
VALID_REASONS = {
    category_id: set(category["reasons"])
    for category_id, category in CATEGORIES.items()
}

# Unambiguous: each pattern can only mean the required-reason API.
DEFINITE = [
    (USER_DEFAULTS, re.compile(r"\b(?:NS)?UserDefaults\b")),
    (SYSTEM_BOOT_TIME, re.compile(r"\bsystemUptime\b|\bmach_absolute_time\b")),
    (
        FILE_TIMESTAMP,
        re.compile(
            r"\b(?:contentModificationDateKey|NSURLContentModificationDateKey)\b"
            r"|\b(?:creationDateKey|NSURLCreationDateKey)\b"
            r"|\bNSFile(?:CreationDate|ModificationDate)\b"
            r"|\bfileModificationDate\b"
            r"|\bFileAttributeKey\.(?:creationDate|modificationDate)\b"
            r"|\bgetattrlistbulk\s*\("
            r"|\bfstatat\s*\(|\blstat\s*\(|\bfstat\s*\(|(?<![\w.])stat\s*\("
        ),
    ),
    (
        DISK_SPACE,
        re.compile(
            r"\b(?:volume|NSURLVolume)AvailableCapacity"
            r"(?:ForImportantUsage|ForOpportunisticUsage)?Key\b"
            r"|\b(?:volume|NSURLVolume)TotalCapacityKey\b"
            r"|\bNSFileSystem(?:FreeSize|Size)\b"
            r"|\bsystemFreeSize\b|\bsystemSize\b"
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
    (
        FILE_TIMESTAMP,
        re.compile(r"\b(?:f?getattrlist|getattrlistat)\s*\("),
    ),
    (
        DISK_SPACE,
        re.compile(r"\b(?:f?getattrlist|getattrlistat)\s*\("),
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
        swift_package: str | None = None,
        swift_target: str | None = None,
    ):
        self.name = name
        self.roots = roots
        self.manifest = manifest
        self.podspec = podspec
        self.selected_subspec = selected_subspec
        self.xcodeproj = xcodeproj
        self.swift_package = swift_package
        self.swift_target = swift_target


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
            if os.path.isdir(pkg_ios):
                specs = [f for f in os.listdir(pkg_ios) if f.endswith(".podspec")]
                units.append(
                    Unit(f"package:{pkg}", [pkg_ios],
                         os.path.join(pkg_ios, "Resources", "PrivacyInfo.xcprivacy"),
                         os.path.join(pkg_ios, specs[0]) if specs else None,
                         selected_subspec=selected_subspecs.get(pkg))
                )
            # A plugin with `sharedDarwinSource: true` keeps its iOS code under
            # darwin/, laid out as a Swift package whose target resources hold
            # the manifest. Scanning only ios/ would drop it from the guard.
            pkg_darwin = os.path.join(packages, pkg, "darwin")
            if os.path.isdir(pkg_darwin):
                specs = [f for f in os.listdir(pkg_darwin) if f.endswith(".podspec")]
                target_dir = os.path.join(pkg_darwin, pkg, "Sources", pkg)
                package_swift = os.path.join(pkg_darwin, pkg, "Package.swift")
                units.append(
                    Unit(f"package:{pkg}", [pkg_darwin],
                         os.path.join(target_dir, "Resources", "PrivacyInfo.xcprivacy"),
                         os.path.join(pkg_darwin, specs[0]) if specs else None,
                         selected_subspec=selected_subspecs.get(pkg),
                         swift_package=package_swift
                         if os.path.exists(package_swift) else None,
                         swift_target=pkg)
                )
    return units


def uses_swift_package_manager(mobile: str) -> bool:
    """Return whether the app links plugins through Swift Package Manager.

    With it enabled, Flutter links every plugin that ships a Package.swift as a
    Swift package, and SwiftPM names the resource bundle it copies into the app
    `<package>_<target>.bundle` -- not the podspec's resource_bundles name.
    """
    try:
        with open(os.path.join(mobile, "pubspec.yaml"), "r", encoding="utf-8") as handle:
            pubspec = handle.read()
    except OSError:
        return False
    return re.search(r"^\s*enable-swift-package-manager:\s*true\b", pubspec, re.M) is not None


def swift_package_name(package_swift: str) -> str | None:
    """Return the `name:` a Package.swift declares for its package."""
    match = re.search(r"\bPackage\s*\(\s*name:\s*\"([^\"]+)\"", package_swift)
    return match.group(1) if match else None


def swift_package_bundles_manifest(package_swift: str) -> bool:
    """Return whether a Package.swift target resource covers the manifest.

    Accepts the manifest itself or its `Resources` directory, processed or
    copied. A mention in a comment ships nothing, so comments are ignored.
    """
    code = strip_noise_keep_strings(package_swift)
    return re.search(
        r"\.(?:process|copy)\(\s*\"(?:Resources(?:/PrivacyInfo\.xcprivacy)?"
        r"|PrivacyInfo\.xcprivacy)/?\"",
        code,
    ) is not None


def strip_noise_keep_strings(text: str) -> str:
    """Blank out `//` and `/* */` comments, keeping string literals."""
    text = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def scan_sources(roots: list[str]) -> tuple[dict, dict]:
    definite: dict[str, list[str]] = {}
    ambiguous: dict[str, list[str]] = {}
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [
                d for d in dirnames
                if d not in {"Pods", "build", ".symlinks", "DerivedData", ".git", ".build", ".swiftpm"}
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


def podspec_manifest_bundle(spec: str, selected_subspec: str | None) -> str | None:
    """Return the selected pod specification's privacy resource-bundle name."""
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
            return None
        variable = subspec.group("var")
        scope = subspec.group("body")
    else:
        variable = r"\w+"
        scope = uncommented

    for bundles in re.finditer(
        rf"\b{variable}\.resource_bundles\s*=\s*\{{(?P<body>[^}}]*)\}}",
        scope,
        re.S,
    ):
        for bundle_name, resources in re.findall(
            r"['\"]([^'\"]+)['\"]\s*=>\s*(\[[^]]*\]|['\"][^'\"]*['\"])",
            bundles.group("body"),
            re.S,
        ):
            if "PrivacyInfo.xcprivacy" in resources:
                return bundle_name
    return None


def podspec_bundles_manifest(spec: str, selected_subspec: str | None) -> bool:
    """Return whether the selected pod specification bundles the manifest."""
    return podspec_manifest_bundle(spec, selected_subspec) is not None


def expected_archive_manifests(mobile: str) -> dict[str, str]:
    """Derive archive expectations from manifests wired into source targets."""
    expected: dict[str, str] = {}
    spm = uses_swift_package_manager(mobile)
    for unit in discover(mobile):
        if not os.path.exists(unit.manifest):
            continue
        if unit.xcodeproj:
            expected[unit.name] = os.path.basename(unit.manifest)
            continue
        if spm and unit.swift_package:
            try:
                with open(unit.swift_package, "r", encoding="utf-8") as handle:
                    package_swift = handle.read()
            except OSError:
                continue
            package = swift_package_name(package_swift)
            if package and swift_package_bundles_manifest(package_swift):
                expected[unit.name] = os.path.join(
                    f"{package}_{unit.swift_target}.bundle", "PrivacyInfo.xcprivacy"
                )
            continue
        if not unit.podspec:
            continue
        try:
            with open(unit.podspec, "r", encoding="utf-8") as handle:
                spec = handle.read()
        except OSError:
            continue
        bundle = podspec_manifest_bundle(spec, unit.selected_subspec)
        if bundle:
            expected[unit.name] = os.path.join(
                f"{bundle}.bundle", "PrivacyInfo.xcprivacy"
            )
    return expected


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
            for category in sorted(set(declared) - set(definite) - set(ambiguous)):
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
            # The same plugin reaches the archive through its Package.swift
            # when the app links it with Swift Package Manager, so that route
            # must carry the manifest too.
            if declared and unit.swift_package:
                try:
                    with open(unit.swift_package, "r", encoding="utf-8") as handle:
                        package_swift = handle.read()
                except OSError:
                    package_swift = ""
                if not swift_package_bundles_manifest(package_swift):
                    failures.append(
                        f"{unit.name}: {unit.manifest} exists but "
                        f"{unit.swift_package} has no target resource for it, "
                        f"so it never reaches the archive"
                    )

        for category, sites in sorted(ambiguous.items()):
            if declared and category in declared:
                continue
            warnings.append(
                f"{unit.name}: possible {category} use (review required) at "
                + ", ".join(sites[:3])
                + (f" (+{len(sites) - 3} more)" if len(sites) > 3 else "")
                + " -- inspect the concrete type or requested attributes, then "
                  "declare only the category actually accessed"
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

    failures = []
    expected = expected_archive_manifests(mobile)
    if not expected:
        print(f"❌ no first-party privacy manifest discovered under {mobile}")
        return 1
    for label, rel in expected.items():
        if rel in found:
            print(f"  ✅ {label}: {rel}")
        else:
            failures.append(f"{label}: expected {rel} in the built app, not found")

    for rel in sorted(found & set(expected.values())):
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
