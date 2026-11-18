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

        result = Play("token", request=request).release_states()
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
