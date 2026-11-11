import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train.store_state import (  # noqa: E402
    ios_submitted_versions,
    play_production_version_codes,
    shorebird_release_versions,
    stable_tag_versions,
)
from release_train.versions import Version  # noqa: E402


def _ios(version, state, key="appVersionState"):
    return {"attributes": {"versionString": version, key: state}}


class StoreStateTest(unittest.TestCase):
    def test_stable_tags_ignore_non_ascii_versions(self):
        self.assertEqual(
            [Version(1, 0, 28)],
            stable_tag_versions([
                "refs/tags/١.0.29", "refs/tags/1.０.30", "refs/tags/1.0.28"
            ]),
        )

    def test_ios_keeps_submitted_and_released_states(self):
        entries = [
            _ios("1.0.1", "WAITING_FOR_REVIEW"),
            _ios("1.0.2", "REJECTED"),
            _ios("1.0.3", "DEVELOPER_REJECTED"),
            _ios("1.0.4", "READY_FOR_DISTRIBUTION"),
            _ios("1.0.5", "READY_FOR_SALE", key="appStoreState"),
        ]
        self.assertEqual(
            ios_submitted_versions(entries),
            [Version(1, 0, 1), Version(1, 0, 2), Version(1, 0, 3),
             Version(1, 0, 4), Version(1, 0, 5)],
        )

    def test_ios_mistyped_values_fail_closed(self):
        for entry in (_ios(120, "READY_FOR_SALE"), _ios("1.2.0", ["X"])):
            with self.subTest(entry=entry):
                with self.assertRaises(ValueError):
                    ios_submitted_versions([entry])

    def test_ios_drops_unsubmitted_states(self):
        entries = [
            _ios("1.0.1", "PREPARE_FOR_SUBMISSION"),
            _ios("1.0.2", "READY_FOR_REVIEW"),
            _ios("1.0.3", "REJECTED"),
        ]
        self.assertEqual(ios_submitted_versions(entries), [Version(1, 0, 3)])

    def test_ios_empty_lookup_fails_closed(self):
        with self.assertRaises(ValueError):
            ios_submitted_versions([])
        with self.assertRaises(ValueError):
            ios_submitted_versions([{"attributes": {"appVersionState": "REJECTED"}}])
        with self.assertRaises(ValueError):
            ios_submitted_versions([{"attributes": {"versionString": "1.0.1"}}])

    def test_play_codes_are_integers_from_every_release(self):
        track = {
            "track": "production",
            "releases": [
                {"name": "1.0.27", "versionCodes": ["844", "845"], "status": "completed"},
                {"name": "1.0.26", "versionCodes": ["800"], "status": "completed"},
                {"name": "draft", "status": "draft"},
            ],
        }
        self.assertEqual(play_production_version_codes(track), [844, 845, 800])

    def test_play_empty_production_view_fails_closed(self):
        for releases in ([], [{"status": "draft"}], [{"status": "completed", "versionCodes": []}]):
            with self.subTest(releases=releases):
                with self.assertRaisesRegex(ValueError, "no version codes"):
                    play_production_version_codes(
                        {"track": "production", "releases": releases}
                    )

    def test_play_drafts_with_codes_do_not_claim_a_version(self):
        self.assertEqual([844], play_production_version_codes({
            "track": "production", "releases": [
                {"status": "completed", "versionCodes": ["844"]},
                {"status": "draft", "versionCodes": ["999"]},
            ]}))
        with self.assertRaisesRegex(ValueError, "no version codes"):
            play_production_version_codes({"track": "production", "releases": [
                {"status": "draft", "versionCodes": ["999"]}]})

    def test_play_submitted_rollouts_remain_claimed(self):
        for status in ("completed", "inProgress", "halted"):
            with self.subTest(status=status):
                self.assertEqual([844], play_production_version_codes({
                    "track": "production", "releases": [
                        {"status": status, "versionCodes": ["844"]}]}))

    def test_play_missing_or_unknown_status_fails_closed(self):
        for status in (None, "statusUnspecified", "future", []):
            with self.subTest(status=status):
                with self.assertRaisesRegex(ValueError, "status"):
                    play_production_version_codes({"track": "production", "releases": [
                        {"status": status, "versionCodes": ["844"]}]})

    def test_play_requires_the_production_track(self):
        with self.assertRaises(ValueError):
            play_production_version_codes({"track": "beta", "releases": []})
        with self.assertRaises(ValueError):
            play_production_version_codes({"track": "production"})

    def test_shorebird_versions_for_platform_only(self):
        payload = {
            "status": "success",
            "data": {
                "releases": [
                    {"version": "1.0.28+906", "platform_statuses": {"ios": "active"}},
                    {"version": "1.0.27+844", "platform_statuses": {"android": "active"}},
                ]
            },
        }
        self.assertEqual(
            shorebird_release_versions(payload, "ios"), frozenset({"1.0.28+906"})
        )

    def test_shorebird_failure_payload_raises(self):
        with self.assertRaises(ValueError):
            shorebird_release_versions(
                {"status": "error", "error": {"message": "boom"}}, "ios"
            )

    def test_play_rejects_malformed_codes_and_releases(self):
        for bad in ("844", ["abc"], [True], [8.9], [""], ["８４"], [None], 844):
            with self.subTest(codes=bad):
                with self.assertRaises(ValueError):
                    play_production_version_codes(
                        {"track": "production", "releases": [{"status": "completed", "versionCodes": bad}]}
                    )
        with self.assertRaises(ValueError):
            play_production_version_codes(
                {"track": "production", "releases": ["844"]}
            )

    def test_shorebird_rejects_malformed_payloads(self):
        def wrap(releases):
            return {"status": "success", "data": {"releases": releases}}

        bad_payloads = [
            {"data": {"releases": []}},
            {"status": "success"},
            {"status": "success", "data": {}},
            {"status": "success", "data": []},
            wrap("x"),
            wrap([{"platform_statuses": {"ios": "active"}}]),
            wrap([{"version": 5, "platform_statuses": {"ios": "active"}}]),
            wrap(["1.0.1"]),
            wrap([{"version": "1.0.1", "platform_statuses": ["ios"]}]),
            wrap([{"version": "1.0.1"}]),
            "nope",
        ]
        for payload in bad_payloads:
            with self.subTest(payload=payload):
                with self.assertRaises(ValueError):
                    shorebird_release_versions(payload, "ios")

    def test_stable_tags_ignore_betas_and_other_refs(self):
        refs = [
            "refs/tags/1.0.27",
            "refs/tags/1.0.27-beta.2",
            "refs/tags/release-candidate/abc",
            "refs/tags/v1.0.1",
            "refs/tags/1.0",
            "refs/tags/1.0.28",
        ]
        self.assertEqual(
            stable_tag_versions(refs), [Version(1, 0, 27), Version(1, 0, 28)]
        )


if __name__ == "__main__":
    unittest.main()
