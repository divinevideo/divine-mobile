"""Google's review-only restriction remains distinct from artifact delivery."""

import io
import json
import unittest
import urllib.error
from unittest.mock import patch

import release_train_fakes  # noqa: F401 - adds repository scripts to sys.path
from release_train.providers import Play, ProviderError, request_json
from test_release_train_providers import play_notes


class PlayReviewStateTest(unittest.TestCase):
    def test_google_console_submission_requirement_has_a_safe_actionable_error(self):
        payload = {
            "error": {
                "code": 400,
                "status": "INVALID_ARGUMENT",
                "message": "Changes cannot be sent for review automatically. Please set changesNotSentForReview to true.",
            }
        }
        error = urllib.error.HTTPError(
            "https://androidpublisher.googleapis.com/x",
            400,
            "",
            {},
            io.BytesIO(json.dumps(payload).encode()),
        )
        with patch("urllib.request.build_opener") as opener:
            opener.return_value.open.side_effect = error
            with self.assertRaisesRegex(
                ProviderError, "requires.*Play Console"
            ) as caught:
                request_json("POST", "https://androidpublisher.googleapis.com/x")
        self.assertEqual(caught.exception.diagnostic["status"], "INVALID_ARGUMENT")
        self.assertEqual(opener.return_value.open.call_count, 1)

    def test_release_state_read_is_outside_an_edit_and_covers_both_release_tracks(self):
        calls = []

        def request(method, url, headers=None, body=None):
            calls.append((method, url))
            return {
                "releases": [
                    {
                        "track": url.split("/")[-2],
                        "activeArtifacts": [{"versionCode": 876}],
                        "releaseLifecycleState": "RELEASE_LIFECYCLE_STATE_NOT_APPROVED",
                    }
                ]
            }

        result, errors = Play("token", request=request).release_states()
        self.assertEqual(errors, {})
        self.assertEqual(set(result), {"internal", "production"})
        self.assertEqual(
            result["production"][0]["releaseLifecycleState"],
            "RELEASE_LIFECYCLE_STATE_NOT_APPROVED",
        )
        self.assertTrue(
            all(method == "GET" and "/edits" not in url for method, url in calls)
        )
        self.assertTrue(calls[0][1].endswith("/tracks/internal/releases"))
        self.assertTrue(calls[1][1].endswith("/tracks/production/releases"))

    def test_diagnostic_retains_review_states_even_when_validation_requires_console(
        self,
    ):
        calls = []

        def request(method, url, headers=None, body=None):
            calls.append((method, url))
            if url.endswith("/releases"):
                return {
                    "releases": [
                        {
                            "activeArtifacts": [{"versionCode": 876}],
                            "releaseLifecycleState": "RELEASE_LIFECYCLE_STATE_NOT_APPROVED",
                        }
                    ]
                }
            if url.endswith("/edits"):
                return {"id": "edit"}
            if url.endswith("/tracks"):
                return {"tracks": []}
            if url.endswith("/bundles"):
                return {"bundles": []}
            if ":validate" in url:
                raise ProviderError("requires Play Console", diagnostic={"code": 400})
            return {}

        report = Play("token", request=request).diagnose_upload(notes=play_notes())
        self.assertEqual(
            report["release_states"]["production"][0]["releaseLifecycleState"],
            "RELEASE_LIFECYCLE_STATE_NOT_APPROVED",
        )
        self.assertEqual(report["stage"], "validate current edit")
        self.assertEqual(report["error"]["code"], 400)
        self.assertTrue(all(method == "GET" for method, _ in calls[:2]))
        self.assertEqual(calls[-1][0], "DELETE")
        self.assertFalse(any(":commit" in url for _, url in calls))

    def test_each_failed_review_read_retains_other_track_and_all_existing_diagnostics(
        self,
    ):
        for failed_track in ["internal", "production", "both"]:
            with self.subTest(track=failed_track):
                calls = []

                def request(
                    method,
                    url,
                    headers=None,
                    body=None,
                    *,
                    calls=calls,
                    failed_track=failed_track,
                ):
                    calls.append((method, url))
                    if url.endswith("/releases"):
                        track = url.split("/")[-2]
                        if track == failed_track or failed_track == "both":
                            raise ProviderError("unavailable", diagnostic={"code": 403})
                        return {
                            "releases": [
                                {
                                    "track": track,
                                    "activeArtifacts": [{"versionCode": 879}],
                                    "releaseLifecycleState": "RELEASE_LIFECYCLE_STATE_PUBLISHED",
                                }
                            ]
                        }
                    if url.endswith("/edits"):
                        return {"id": "temporary-edit"}
                    if url.endswith("/tracks"):
                        return {
                            "tracks": [
                                {
                                    "track": "internal",
                                    "releases": [
                                        {"status": "completed", "versionCodes": ["879"]}
                                    ],
                                }
                            ]
                        }
                    if url.endswith("/bundles"):
                        return {"bundles": [{"versionCode": 879}]}
                    return {}

                report = Play("token", request=request).diagnose_upload(
                    notes=play_notes()
                )
                failed = (
                    {"internal", "production"}
                    if failed_track == "both"
                    else {failed_track}
                )
                self.assertEqual(
                    set(report["release_states"]), {"internal", "production"} - failed
                )
                self.assertEqual(
                    report["release_state_errors"],
                    {track: {"code": 403} for track in failed},
                )
                self.assertEqual(report["bundles"], [879])
                self.assertEqual(report["notes_validation_build"], 879)
                self.assertEqual(report["stage"], "complete")
                self.assertEqual(sum(":validate" in url for _, url in calls), 2)
                self.assertEqual(calls[-1][0], "DELETE")
                self.assertFalse(any(":commit" in url for _, url in calls))

    def test_incomplete_review_state_report_is_private_and_returns_failed_status(self):
        from types import SimpleNamespace
        from unittest.mock import Mock

        from release_train.runner import diagnose_android_upload
        from test_publish_play_bundle import SOURCE, android_bundle

        runtime = SimpleNamespace(
            env={
                "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": "service-secret",
                "GITHUB_RUN_ID": "100",
                "GITHUB_RUN_ATTEMPT": "1",
            },
            ledger=Mock(),
            store=Mock(),
            list_builds=Mock(return_value=[]),
        )
        runtime.ledger.read_json.return_value = {
            "number": 881,
            "status": "failed",
            "sha": SOURCE,
            "release_notes": android_bundle(),
        }
        runtime.store.load.return_value = {"holds": {"android": "android-upload:881"}}
        report = {
            "stage": "complete",
            "release_states": {"internal": []},
            "release_state_errors": {
                "production": {"code": 403, "message": "private detail"}
            },
        }
        with (
            patch("release_train.runner.Play") as play,
            patch("release_train.runner.play_token", return_value="token"),
            patch("builtins.print") as output,
        ):
            play.return_value.diagnose_upload.return_value = report
            self.assertEqual(diagnose_android_upload(runtime, "881"), 1)
        self.assertEqual(
            runtime.ledger.create_json.call_args.args[1]["release_state_errors"],
            report["release_state_errors"],
        )
        self.assertNotIn("private detail", str(output.call_args_list))

    def test_malformed_lifecycle_response_is_recorded_per_track(self):
        for result in [[], {"releases": "invalid"}]:
            with self.subTest(result=result):
                states, errors = Play(
                    "token", request=lambda *args, result=result: result
                ).release_states()
                self.assertEqual(states, {})
                self.assertEqual(set(errors), {"internal", "production"})
                self.assertTrue(
                    all("Malformed" in value["message"] for value in errors.values())
                )
