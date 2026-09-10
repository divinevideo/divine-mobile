#!/usr/bin/env python3
"""Lint a GitHub issue title against Divine's conventional-title policy.

Background (divine-mobile#8337): the 2026-08-28 backlog triage rewrote 121
issue titles. A grep-based check passed the same titles twice while a real
linter later found 80 defects, because a text rule is wrong in both
directions. This is that real linter, run as an `issues`-triggered guard that
comments once on a non-conforming title rather than a push-triggered CI
ratchet (issue titles are metadata, not files in the tree).

Scope is one place this diverges from #8337 as written. Rule 3 in the
issue (2026-08-29) made a scope mandatory. Its author, Liz Sweigart,
subsequently codified the org-wide policy in divine-context
(`PR_REVIEW.md`, `title-conventions.json`, commit 3234369, 2026-09-02) as
`type(scope): summary` OR `type: summary` when no scope applies. That later,
org-canonical statement of the same author's intent wins, so a *missing*
scope is not a defect here. It also keeps the guard from re-failing every
Zendesk-bridged issue once divine-mobile#8335 drops the `(support)` scope
(which produces scopeless titles) — enforcing a stricter-than-policy rule
would recreate the "train people to ignore it" failure #8337 itself warns of.
The linter does not infer intake provenance from a scope name. `support` is
also a real product area in divine-mobile, while Zendesk provenance belongs on
the `zendesk` label (#8335).

The allowed types mirror divine-context's `title-conventions.json`
(`pull_request_types` + `issue_only_types`). That file in divine-context is
the source of truth. The workflow cannot read that private sibling repository
with this repository's `GITHUB_TOKEN`, so this runtime list is a deliberately
manual mirror and changes to it must be checked against the canonical manifest.
"""

from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass

# Mirror of divine-context/title-conventions.json: pull_request_types + issue_only_types.
ALLOWED_TYPES = frozenset(
    {
        "feat",
        "fix",
        "chore",
        "docs",
        "refactor",
        "test",
        "perf",
        "build",
        "ci",
        "style",
        "revert",
        # issue_only_types
        "task",
        "epic",
    }
)

# type, optional (scope), an optional Conventional-Commit breaking-change `!`,
# then `: summary`. Type is captured permissively according to the canonical
# type-token grammar so wrong-case and unsupported types such as `Fix`, `l10n`,
# and `release-candidate` are reported as unknown rather than unparseable.
_TITLE_RE = re.compile(
    r"^(?P<type>[A-Za-z][A-Za-z0-9-]*)"
    r"(?:\((?P<scope>[^)]*)\))?"
    r"!?"
    r":[ \t]+(?P<summary>\S.*)$"
)


@dataclass(frozen=True)
class Finding:
    code: str
    message: str


def check_issue_title(title: str) -> list[Finding]:
    """Return findings for a title; an empty list means it conforms."""
    stripped = title.strip()
    match = _TITLE_RE.match(stripped)
    if match is None:
        return [
            Finding(
                "unparseable",
                "Title does not parse as `type: summary` or "
                "`type(scope): summary`.",
            )
        ]

    findings: list[Finding] = []

    type_ = match.group("type")
    if type_ not in ALLOWED_TYPES:
        findings.append(
            Finding(
                "unknown_type",
                f"`{type_}` is not an allowed type. Use one of: "
                f"{', '.join(sorted(ALLOWED_TYPES))}.",
            )
        )

    scope = match.group("scope")
    if scope is not None:
        # The `(...)` group is present; absence (a scopeless title) is allowed.
        if scope.strip() == "":
            findings.append(
                Finding("empty_scope", "Scope parentheses are empty; drop them or name a scope.")
            )
    return findings


def main(argv: list[str]) -> int:
    title = argv[1] if len(argv) > 1 else os.environ.get("ISSUE_TITLE", "")
    findings = check_issue_title(title)
    for finding in findings:
        print(finding.message)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
