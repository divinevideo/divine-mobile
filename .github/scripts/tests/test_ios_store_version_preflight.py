import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "scripts"
    / "ios_store_version_preflight.rb"
)


def app_store_version(
    version_string: str,
    state: str | None = None,
    legacy_state: bool = False,
    include_attributes: bool = True,
) -> dict:
    entry: dict = {"type": "appStoreVersions", "id": f"version-{version_string}"}
    if include_attributes:
        attributes: dict = {"versionString": version_string}
        if state is not None:
            attributes["appStoreState" if legacy_state else "appVersionState"] = state
        entry["attributes"] = attributes
    return entry


class IosStoreVersionPreflightTest(unittest.TestCase):
    def run_preflight(
        self,
        payload: dict | list | str,
        candidate_version: str = "1.0.23",
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as file:
            json.dump(payload, file)
            file.flush()
            return subprocess.run(
                ["ruby", str(SCRIPT_PATH), file.name, candidate_version],
                check=False,
                text=True,
                capture_output=True,
            )

    def test_allows_version_above_released_version(self) -> None:
        result = self.run_preflight(
            [app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION")]
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("newer than released App Store version 1.0.22", result.stdout)

    def test_blocks_same_version_as_released_version(self) -> None:
        result = self.run_preflight(
            [app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION")],
            candidate_version="1.0.22",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "must be newer than released App Store version 1.0.22", result.stderr
        )

    def test_blocks_version_below_released_version(self) -> None:
        result = self.run_preflight(
            [app_store_version("1.2.0", state="READY_FOR_DISTRIBUTION")],
            candidate_version="1.1.99",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "must be newer than released App Store version 1.2.0", result.stderr
        )

    def test_uses_the_highest_released_version(self) -> None:
        result = self.run_preflight(
            [
                app_store_version("1.0.20", state="READY_FOR_DISTRIBUTION"),
                app_store_version("1.0.22", state="REPLACED_WITH_NEW_VERSION"),
                app_store_version("1.0.21", state="READY_FOR_DISTRIBUTION"),
            ],
            candidate_version="1.0.22",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("released App Store version 1.0.22", result.stderr)

    def test_recognises_the_deprecated_app_store_state_field(self) -> None:
        result = self.run_preflight(
            [app_store_version("1.0.22", state="READY_FOR_SALE", legacy_state=True)]
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("newer than released App Store version 1.0.22", result.stdout)

    def test_compares_numeric_components_instead_of_lexically(self) -> None:
        result = self.run_preflight(
            [app_store_version("1.9.9", state="READY_FOR_DISTRIBUTION")],
            candidate_version="1.10.0",
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_allows_version_that_only_reached_testflight(self) -> None:
        # Regression: a 1.0.23 appStoreVersion record in a pre-release state
        # made the preflight reject a 1.0.23 candidate even though the released
        # version was 1.0.22.
        result = self.run_preflight(
            [
                app_store_version("1.0.23", state="PREPARE_FOR_SUBMISSION"),
                app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION"),
            ],
            candidate_version="1.0.23",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("newer than released App Store version 1.0.22", result.stdout)

    def test_allows_version_that_is_still_in_review(self) -> None:
        result = self.run_preflight(
            [
                app_store_version("1.0.23", state="WAITING_FOR_REVIEW"),
                app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION"),
            ],
            candidate_version="1.0.23",
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_allows_release_with_no_released_version(self) -> None:
        result = self.run_preflight(
            [app_store_version("1.0.23", state="PREPARE_FOR_SUBMISSION")]
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("first release on this train", result.stdout)

    def test_blocks_version_equal_to_approved_but_unreleased_version(self) -> None:
        result = self.run_preflight(
            [
                app_store_version("1.0.23", state="PENDING_DEVELOPER_RELEASE"),
                app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION"),
            ],
            candidate_version="1.0.23",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "must be newer than released App Store version 1.0.23", result.stderr
        )

    def test_blocks_version_equal_to_accepted_version(self) -> None:
        # ACCEPTED means App Review passed while a sibling submission item is
        # still outstanding, so the version string is taken.
        result = self.run_preflight(
            [
                app_store_version("1.0.23", state="ACCEPTED"),
                app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION"),
            ],
            candidate_version="1.0.23",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "must be newer than released App Store version 1.0.23", result.stderr
        )

    def test_fails_closed_on_empty_version_list(self) -> None:
        result = self.run_preflight([])

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("returned no App Store versions", result.stderr)

    def test_fails_closed_on_invalid_json_shape(self) -> None:
        result = self.run_preflight({"buildId": "build-id", "version": "1.0.22"})

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected a JSON array", result.stderr)

    def test_fails_closed_on_invalid_version(self) -> None:
        result = self.run_preflight(
            [app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION")],
            candidate_version="next",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid candidate version", result.stderr)

    def test_skips_entries_without_readable_attributes(self) -> None:
        result = self.run_preflight(
            [
                app_store_version("1.0.23", include_attributes=False),
                app_store_version("1.0.22", state="READY_FOR_DISTRIBUTION"),
            ],
            candidate_version="1.0.23",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("newer than released App Store version 1.0.22", result.stdout)


if __name__ == "__main__":
    unittest.main()
