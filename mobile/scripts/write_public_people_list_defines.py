#!/usr/bin/env python3
"""Validate public-discovery policy without logging identifying values."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

POLICY_NAME = "DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--merge", action="store_true")
    parser.add_argument("--github-repository")
    args = parser.parse_args()

    raw = os.environ.get(POLICY_NAME)
    if not raw and args.github_repository:
        # Codemagic already has gh and github_credentials. Keep the same policy
        # as Actions, without duplicating its identifying values in this repo.
        try:
            result = subprocess.run(
                ["gh", "api", f"repos/{args.github_repository}/actions/variables/{POLICY_NAME}"],
                capture_output=True, text=True, check=True,
            )
            raw = json.loads(result.stdout)["value"]
        except (OSError, subprocess.CalledProcessError, ValueError, KeyError, TypeError):
            raise ValueError("public people-list policy could not be read") from None
    if not raw:
        raise ValueError(f"missing {POLICY_NAME}; set a JSON array (explicit [] is allowed)")
    try:
        tags = json.loads(raw)
    except (ValueError, TypeError):
        raise ValueError(f"invalid {POLICY_NAME}: expected a JSON array of nonempty strings") from None
    if not isinstance(tags, list) or any(not isinstance(tag, str) or not tag.strip() for tag in tags):
        raise ValueError(f"invalid {POLICY_NAME}: expected a JSON array of nonempty strings")

    # Canonicalize for deterministic builds and Shorebird provenance. Reading
    # and validating happens before replacing a file that may contain secrets.
    defines = json.loads(args.output.read_text()) if args.merge else {}
    if not isinstance(defines, dict):
        raise ValueError("dart-defines file must contain a JSON object")
    defines[POLICY_NAME] = json.dumps(sorted(set(tags)), separators=(",", ":"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".public-list-defines-", dir=args.output.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(defines, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(temporary, args.output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError):
        # Exception strings from JSON/file parsing can contain private values.
        print("Public people-list build policy is unavailable or invalid. Check the configured JSON array and file access.", file=sys.stderr)
        sys.exit(1)
