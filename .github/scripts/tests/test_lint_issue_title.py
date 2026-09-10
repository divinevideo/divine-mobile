"""Tests for the issue-title linter (divine-mobile#8337).

The linter reconstructs the rules #8337 spells out. The one deliberate
divergence from the issue body is scope: #8337 rule 3 made a scope mandatory
(2026-08-29), but its author later codified the org-wide policy in
divine-context PR_REVIEW.md / title-conventions.json (2026-09-02) as
`type(scope): summary` OR `type: summary` when no scope applies. The later,
org-canonical policy wins, so a missing scope is NOT a failure here. `support`
is also a real product area, while intake provenance belongs on the `zendesk`
label (#8335).
"""

import os
import subprocess
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

    def test_support_product_scope_passes(self):
        self.assertEqual(
            codes("epic(support): make the support and bug-report pipeline trustworthy"),
            [],
        )

    def test_short_complete_summary_passes(self):
        self.assertEqual(codes("feat: 機能要望"), [])
        self.assertEqual(codes("fix: Audio Delays"), [])

    def test_long_title_not_flagged_for_length(self):
        long_summary = "the editor drops the last second of every clip when " * 3
        self.assertEqual(codes(f"fix(editor): {long_summary}".strip()), [])

    def test_breaking_change_marker_allowed(self):
        # Conventional-Commit `!` is valid and accepted by the org's PR check.
        self.assertEqual(codes("feat!: drop the legacy upload path for everyone"), [])
        self.assertEqual(
            codes("feat(auth)!: require re-login after a password reset now"), []
        )
        # ...but `!` does not excuse an unknown type — it's still a type error.
        self.assertEqual(
            codes("wibble!: change something in a way nobody can route"),
            ["unknown_type"],
        )


class NonConformingTitles(unittest.TestCase):
    def test_digit_type_flagged_as_unknown(self):
        self.assertEqual(
            codes("l10n(inbox): review machine-translated strings from PR #6286"),
            ["unknown_type"],
        )

    def test_hyphenated_type_flagged_as_unknown(self):
        self.assertEqual(
            codes("release-candidate: prepare the next mobile release"),
            ["unknown_type"],
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


class CommandLineInterface(unittest.TestCase):
    def run_linter(self, title: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["ISSUE_TITLE"] = title
        return subprocess.run(
            ["python3", str(Path(__file__).resolve().parents[1] / "lint_issue_title.py")],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

    def test_environment_title_succeeds_silently(self):
        result = self.run_linter("fix(auth): restore account recovery after logout")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def test_environment_title_prints_findings_and_fails(self):
        result = self.run_linter("l10n(inbox): review translated strings")

        self.assertEqual(result.returncode, 1)
        self.assertIn("`l10n` is not an allowed type", result.stdout)
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
