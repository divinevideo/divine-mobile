#!/usr/bin/env python3
"""Fail when vendored LibProofMode records network fields outside its privacy gate."""

from __future__ import annotations

import argparse
from pathlib import Path


FIELDS = ("ipv4", "ipv6", "dataType", "network", "networkType")
DEFAULT_SOURCE = Path("ios/LocalPods/LibProofMode/Classes/Proof.swift")


def matching_brace(source: str, opening: int) -> int:
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("unclosed brace")


def validate(source: str) -> list[str]:
    failures: list[str] = []
    function_marker = "private func buildProof("
    function_start = source.find(function_marker)
    if function_start == -1:
        return ["buildProof was not found"]

    function_open = source.find("{", function_start)
    try:
        function_close = matching_brace(source, function_open)
    except ValueError:
        return ["buildProof has an unclosed body"]
    function_body = source[function_open + 1 : function_close]

    gate_marker = "if showMobileNetwork {"
    gate_start = function_body.find(gate_marker)
    if gate_start == -1:
        return ["buildProof has no showMobileNetwork gate"]

    gate_open = function_body.find("{", gate_start)
    try:
        gate_close = matching_brace(function_body, gate_open)
    except ValueError:
        return ["showMobileNetwork has an unclosed body"]

    for field in FIELDS:
        assignment = f"proof[.{field}] ="
        positions: list[int] = []
        cursor = 0
        while (position := function_body.find(assignment, cursor)) != -1:
            positions.append(position)
            cursor = position + len(assignment)

        if len(positions) != 1:
            failures.append(
                f"{assignment} must appear exactly once in buildProof; "
                f"found {len(positions)}"
            )
        elif not gate_open < positions[0] < gate_close:
            failures.append(f"{assignment} must stay inside the showMobileNetwork gate")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", type=Path, default=DEFAULT_SOURCE)
    args = parser.parse_args()

    if not args.source.is_file():
        print(f"ERROR: missing {args.source}")
        return 1

    failures = validate(args.source.read_text(encoding="utf-8"))
    if failures:
        print("ERROR: LibProofMode network-field privacy gate regressed.")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("LibProofMode network fields remain behind showMobileNetwork.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
