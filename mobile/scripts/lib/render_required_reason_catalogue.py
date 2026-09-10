#!/usr/bin/env python3
"""Verify the generated catalogue tables in IOS_PRIVACY_MANIFESTS.md."""

from __future__ import annotations

import argparse
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.dirname(__file__))
CATALOGUE_PATH = os.path.join(
    SCRIPT_DIR, "data", "apple_required_reason_catalogue.json"
)
DOC_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "docs", "IOS_PRIVACY_MANIFESTS.md"))
START = "<!-- apple-required-reason-catalogue:start -->"
END = "<!-- apple-required-reason-catalogue:end -->"


def render(catalogue: dict) -> str:
    lines = [
        START,
        "| Category | Swift APIs | Objective-C APIs |",
        "|---|---|---|",
    ]
    for category in catalogue["categories"]:
        swift = ", ".join(f"`{symbol}`" for symbol in category["symbols"]["swift"])
        objective_c = ", ".join(
            f"`{symbol}`" for symbol in category["symbols"]["objectiveC"]
        )
        lines.append(f"| `{category['name']}` | {swift} | {objective_c} |")
    lines.extend(["", "Reason codes:", "", "| Code | Category | Meaning |", "|---|---|---|"])
    for category in catalogue["categories"]:
        for code, meaning in category["reasons"].items():
            lines.append(f"| `{code}` | {category['name']} | {meaning} |")
    lines.append(END)
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail instead of printing")
    args = parser.parse_args()
    with open(CATALOGUE_PATH, encoding="utf-8") as handle:
        generated = render(json.load(handle))
    with open(DOC_PATH, encoding="utf-8") as handle:
        document = handle.read()
    try:
        current = START + document.split(START, 1)[1].split(END, 1)[0] + END
    except IndexError:
        if args.check:
            print("catalogue markers are missing from IOS_PRIVACY_MANIFESTS.md")
            return 1
        print(generated)
        return 0
    if current != generated:
        if args.check:
            print("IOS_PRIVACY_MANIFESTS.md catalogue tables are stale")
            return 1
        print(generated)
        return 0
    print("IOS_PRIVACY_MANIFESTS.md matches the pinned catalogue")
    return 0


if __name__ == "__main__":
    sys.exit(main())
