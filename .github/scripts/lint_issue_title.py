#!/usr/bin/env python3
"""Lint a GitHub issue title against Divine's conventional-title policy.

Background (divine-mobile#8337): the 2026-08-28 backlog triage rewrote 121
issue titles. A grep-based check passed the same titles twice while a real
linter later found 80 defects, because a text rule is wrong in both
directions. This is that real linter, run as an `issues`-triggered guard that
comments once on a non-conforming title rather than a push-triggered CI
ratchet (issue titles are metadata, not files in the tree).

Scope is the one place this diverges from #8337 as written. Rule 3 in the
issue (2026-08-29) made a scope mandatory. Its author, Liz Sweigart,
subsequently codified the org-wide policy in divine-context
(`PR_REVIEW.md`, `title-conventions.json`, commit 3234369, 2026-09-02) as
`type(scope): summary` OR `type: summary` when no scope applies. That later,
org-canonical statement of the same author's intent wins, so a *missing*
scope is not a defect here. It also keeps the guard from re-failing every
Zendesk-bridged issue once divine-mobile#8335 drops the `(support)` scope
(which produces scopeless titles) — enforcing a stricter-than-policy rule
would recreate the "train people to ignore it" failure #8337 itself warns of.
A scope that IS present must still not be the `support` intake channel; that
provenance belongs on the `zendesk` label (#8335).

The allowed types mirror divine-context's `title-conventions.json`
(`pull_request_types` + `issue_only_types`). That file in divine-context is
the source of truth; this list is a local copy kept aligned the same way the
prose copies in AGENTS.md and PR_REVIEW.md are.
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

# Intake provenance belongs on the `zendesk` label, not the scope slot (#8335).
FORBIDDEN_SCOPES = frozenset({"support"})

# A summary shorter than this reads as a reporter's raw fragment ("Y"), not a
# description. Approximate by design (#8337); the guard comments, never blocks,
# so an occasional terse-but-valid summary costs a comment, not a merge.
MIN_SUMMARY_LENGTH = 12

# type, optional (scope), an optional Conventional-Commit breaking-change `!`,
# then `: summary`. Type is captured permissively so a wrong-case type ("Fix") is
# reported as an unknown type rather than as an unparseable title. The `!` is
# allowed so a valid Conventional-Commit title (`feat!:`, `feat(auth)!:`) is not
# flagged — the org's PR check (commitlint) accepts it too. A space after the
# colon is required by the convention.
_TITLE_RE = re.compile(
    r"^(?P<type>[A-Za-z][A-Za-z]*)"
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
        elif scope.strip().lower() in FORBIDDEN_SCOPES:
            findings.append(
                Finding(
                    "support_scope",
                    "`support` is an intake channel, not a product scope. Put "
                    "intake provenance on the `zendesk` label and use a real "
                    "scope, or drop the scope.",
                )
            )

    summary = match.group("summary").strip()
    if len(summary) <= MIN_SUMMARY_LENGTH:
        findings.append(
            Finding(
                "summary_too_short",
                f"Summary is too short (needs more than {MIN_SUMMARY_LENGTH} "
                "characters). Describe what the issue gets someone, not the "
                "reporter's raw words.",
            )
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
