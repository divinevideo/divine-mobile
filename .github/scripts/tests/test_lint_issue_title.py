"""Tests for the issue-title linter (divine-mobile#8337).

The linter reconstructs the rules #8337 spells out. The one deliberate
divergence from the issue body is scope: #8337 rule 3 made a scope mandatory
(2026-08-29), but its author later codified the org-wide policy in
divine-context PR_REVIEW.md / title-conventions.json (2026-09-02) as
`type(scope): summary` OR `type: summary` when no scope applies. The later,
org-canonical policy wins, so a missing scope is NOT a failure here. A scope
that IS present must still not be the `support` intake channel (#8335).
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lint_issue_title import check_issue_title  # noqa: E402


def codes(title: str) -> list[str]:
    return [f.code for f in check_issue_title(title)]


class ConformingTitles(unittest.TestCase):
    def test_type_scope_summary(self):
        self.assertEqual(codes("fix(auth): username taken with no recovery path"), [])

    def test_no_scope_passes(self):
        # The core of the scope-optional decision: a scopeless title conforms.
        self.assertEqual(
            codes("feat: document how Divine counts followers and following"), []
        )

    def test_issue_only_types(self):
        self.assertEqual(codes("task(dm): guard the unscoped DmRepository methods"), [])
        self.assertEqual(codes("epic(l10n): launch Divine in Telugu for real"), [])

    def test_proper_noun_summary_not_flagged(self):
        # Lowercase-first-word is deliberately NOT enforced (proper nouns).
        self.assertEqual(
            codes("fix(verify): TikTok verification fails with non_sandbox_target"), []
        )

    def test_long_title_not_flagged_for_length(self):
        long_summary = "the editor drops the last second of every clip when " * 3
        self.assertEqual(codes(f"fix(editor): {long_summary}".strip()), [])


class NonConformingTitles(unittest.TestCase):
    def test_support_scope_flagged(self):
        self.assertEqual(
            codes("fix(support): the app crashes on the upload screen every time"),
            ["support_scope"],
        )

    def test_empty_scope_flagged(self):
        self.assertEqual(
            codes("fix(): the app crashes on the upload screen every time"),
            ["empty_scope"],
        )

    def test_unknown_type_flagged(self):
        self.assertEqual(
            codes("decision: pick the retention window for parent emails"),
            ["unknown_type"],
        )

    def test_wrong_case_type_flagged_as_unknown(self):
        self.assertEqual(
            codes("Fix: the upload button does nothing on android"),
            ["unknown_type"],
        )

    def test_unparseable_title(self):
        self.assertEqual(
            codes("Investigate and fix follower count instability across relays"),
            ["unparseable"],
        )

    def test_short_summary_flagged(self):
        self.assertEqual(codes("fix: Y"), ["summary_too_short"])

    def test_support_scope_and_short_summary(self):
        self.assertEqual(
            sorted(codes("fix(support): Y")),
            ["summary_too_short", "support_scope"],
        )


if __name__ == "__main__":
    unittest.main()
