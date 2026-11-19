"""Release announcements require store availability, not submission or track state."""

import copy
import http.client
import io
import json
import unittest
import urllib.error
from unittest.mock import Mock, patch

import release_train_fakes  # noqa: F401 - scripts import path
from release_train.campaign_drafts import publish_release_drafts

ENV = {
    "ENGAGEMENT_DRAFT_API_URL": "https://campaigns.example",
    "ENGAGEMENT_DRAFT_ACCESS_CLIENT_ID": "synthetic-client",
    "ENGAGEMENT_DRAFT_ACCESS_CLIENT_SECRET": "synthetic-secret",
}
LEVELS = {"ios": "app-store", "android": "production"}


def snapshot(state="READY_FOR_SALE", version="1.2.3"):
    return {
        "ios": {"versions": [{"version": version, "state": state}]},
        "android": {"production": [{"version": version, "number": 42}]},
    }


class ConfirmedPlay:
    def __init__(self, version):
        self.version = version

    def confirmed_version(self):
        return self.version


class DraftProducerTest(unittest.TestCase):
    def capture(self, source, **kwargs):
        requests = []

        class Opener:
            def open(self, request, timeout):
                requests.append((request, timeout))
                response = io.BytesIO(b"")
                response.status = 200
                return response

        with patch("urllib.request.build_opener", return_value=Opener()):
            messages = publish_release_drafts(source, ENV, LEVELS, **kwargs)
        return requests, messages

    def test_confirmed_apple_availability_posts_bounded_safe_contract_and_retries_each_tick(self):
        for state in ["READY_FOR_SALE", "READY_FOR_DISTRIBUTION"]:
            with self.subTest(state=state):
                source = snapshot(state)
                original = copy.deepcopy(source)
                first, messages = self.capture(source)
                second, _ = self.capture(source)
                self.assertEqual(len(first), 1)
                self.assertEqual(first[0][0].data, second[0][0].data)
                request, timeout = first[0]
                self.assertEqual(request.full_url, "https://campaigns.example/api/internal/campaign-drafts")
                self.assertEqual(request.method, "POST")
                self.assertEqual(timeout, 10)
                self.assertEqual(request.get_header("Cf-access-client-id"), "synthetic-client")
                self.assertEqual(request.get_header("Cf-access-client-secret"), "synthetic-secret")
                self.assertEqual(json.loads(request.data), {
                    "sourceType": "app_release",
                    "sourceId": "ios:app_store",
                    "sourceRevision": "1.2.3",
                    "title": "Divine 1.2.3 is available",
                    "body": "Update Divine from the App Store.",
                    "details": {
                        "title": "Divine 1.2.3 is available",
                        "body": "Divine 1.2.3 is available from the App Store.",
                        "action": {
                            "type": "update_app", "platform": "ios",
                            "channel": "app_store", "version": "1.2.3",
                        },
                    },
                    "releaseEligibility": {
                        "platform": "ios", "channel": "app_store", "version": "1.2.3",
                    },
                })
                self.assertEqual(source, original)
                self.assertTrue(messages)

    def test_unconfirmed_apple_states_and_play_track_never_announce(self):
        for state in [
            "WAITING_FOR_REVIEW", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_DISTRIBUTION",
            "REJECTED", "REMOVED_FROM_SALE", "IN_BETA_TESTING", "unknown",
        ]:
            with self.subTest(state=state):
                self.assertEqual(self.capture(snapshot(state))[0], [])

    def test_play_requires_explicit_matching_confirmation_adapter(self):
        source = snapshot("WAITING_FOR_REVIEW")
        self.assertEqual(self.capture(source)[0], [])
        self.assertEqual(self.capture(source, play_availability=ConfirmedPlay(None))[0], [])
        self.assertEqual(self.capture(source, play_availability=ConfirmedPlay("1.2.2"))[0], [])
        requests, _ = self.capture(source, play_availability=ConfirmedPlay("1.2.3"))
        self.assertEqual(len(requests), 1)
        payload = json.loads(requests[0][0].data)
        self.assertEqual(payload["sourceId"], "android:google_play")
        self.assertEqual(payload["sourceRevision"], "1.2.3")
        self.assertEqual(payload["releaseEligibility"], {
            "platform": "android", "channel": "google_play", "version": "1.2.3",
        })
        self.assertEqual(payload["details"]["action"], {
            "type": "update_app", "platform": "android",
            "channel": "google_play", "version": "1.2.3",
        })

    def test_only_latest_confirmed_version_is_announced(self):
        source = snapshot()
        source["ios"]["versions"] += [
            {"version": "1.10.0", "state": "READY_FOR_SALE"},
            {"version": "2.0.0", "state": "IN_REVIEW"},
        ]
        requests, _ = self.capture(source)
        self.assertEqual(len(requests), 1)
        self.assertEqual(json.loads(requests[0][0].data)["sourceRevision"], "1.10.0")

    def test_noncanonical_or_unbounded_versions_never_announce(self):
        for version in [
            "1.2", "01.2.3", "1.02.3", "1.2.03", "1.2.3-beta", "1.2.3+42",
            "1000000.0.0", "1.2.3\n", "١.٢.٣", None,
        ]:
            with self.subTest(version=version):
                self.assertEqual(self.capture(snapshot(version=version))[0], [])

    def test_largest_canonical_version_preserves_campaign_copy_limits(self):
        requests, _ = self.capture(snapshot(version="999999.999999.999999"))
        self.assertEqual(len(requests), 1)
        payload = json.loads(requests[0][0].data)
        self.assertEqual(payload["sourceRevision"], "999999.999999.999999")
        self.assertLessEqual(len(payload["title"]), 80)
        self.assertLessEqual(len(payload["body"]), 180)
        self.assertLessEqual(len(payload["details"]["title"]), 120)
        self.assertLessEqual(len(payload["details"]["body"]), 8000)

    def test_missing_configuration_dry_run_disabled_levels_and_read_errors_never_post(self):
        with patch("urllib.request.build_opener") as opener:
            for missing in ENV:
                env = {key: value for key, value in ENV.items() if key != missing}
                publish_release_drafts(snapshot(), env, LEVELS)
            publish_release_drafts(snapshot(), ENV, LEVELS, dry_run=True)
            publish_release_drafts(snapshot(), ENV, {"ios": "dry-run", "android": "off"})
            source = snapshot()
            source["ios"]["error"] = "provider read failed"
            publish_release_drafts(source, ENV, LEVELS)
            opener.assert_not_called()

    def test_invalid_endpoint_does_not_send_credentials(self):
        with patch("urllib.request.build_opener") as opener:
            for url in [
                "http://campaigns.example", "https://user:password@campaigns.example",
                "https://campaigns.example/?token=private", "https://campaigns.example/#fragment",
            ]:
                messages = publish_release_drafts(snapshot(), ENV | {"ENGAGEMENT_DRAFT_API_URL": url}, LEVELS)
                self.assertTrue(messages)
            opener.assert_not_called()

    def test_failures_are_safe_nonfatal_and_retried(self):
        for error in [
            TimeoutError("synthetic-secret"), urllib.error.URLError("synthetic-secret"),
            http.client.BadStatusLine("private payload synthetic-secret"),
            urllib.error.HTTPError(
                "https://campaigns.example", 500, "synthetic-secret", {},
                io.BytesIO(b"private payload"),
            ),
        ]:
            with self.subTest(error=type(error).__name__):
                with patch("urllib.request.build_opener") as opener:
                    opener.return_value.open.side_effect = error
                    messages = publish_release_drafts(snapshot(), ENV, LEVELS)
                    self.assertTrue(messages)
                    self.assertNotIn("synthetic-secret", " ".join(messages))
                    self.assertNotIn("private payload", " ".join(messages))
                self.assertEqual(len(self.capture(snapshot())[0]), 1)

    def test_availability_adapter_failure_is_nonfatal(self):
        class Unavailable:
            def confirmed_version(self):
                raise RuntimeError("private provider detail")

        requests, messages = self.capture(snapshot("IN_REVIEW"), play_availability=Unavailable())
        self.assertEqual(requests, [])
        self.assertTrue(messages)
        self.assertNotIn("private provider detail", " ".join(messages))


class CoordinatorDraftIntegrationTest(unittest.TestCase):
    def test_tick_only_drafts_confirmed_ios_availability_even_at_android_production_level(self):
        from release_train import runner

        source = snapshot()
        source.update(now=100, cm=[], changes={}, candidate=None)
        source["ios"]["versions"][0]["id"] = "synthetic-version"
        source["ios"].update(builds=[], group_valid=True, review_submissions=[])
        source["android"].update(internal=[], lifecycle_complete=True, managed_publishing=False)
        source["android"]["production"][0].update(sha="a" * 40, status="completed")
        for dry_run in [False, True]:
            with self.subTest(dry_run=dry_run):
                runtime = Mock()
                runtime.snapshot.return_value = source
                runtime.store.load.return_value = {}
                runtime.ledger.paths.return_value = []
                env = ENV | {
                    "GITHUB_REF": "refs/heads/main",
                    "GITHUB_EVENT_NAME": "schedule",
                    "GITHUB_REPOSITORY": "synthetic/repository",
                    "GITHUB_WORKFLOW_REF": "synthetic/repository/.github/workflows/release_train.yml@refs/heads/main",
                    "GITHUB_SHA": "a" * 40,
                    "GITHUB_WORKFLOW_SHA": "a" * 40,
                    "RELEASE_TRAIN_IOS": "app-store",
                    "RELEASE_TRAIN_ANDROID": "production",
                    "RELEASE_DRY_RUN": "true" if dry_run else "false",
                }
                with (
                    patch.object(runner, "Runtime", return_value=runtime),
                    patch.object(runner.subprocess, "check_output", return_value="a" * 40),
                    patch.object(runner, "reconcile"),
                    patch("urllib.request.build_opener") as opener,
                    patch("sys.stdout", new_callable=io.StringIO) as output,
                ):
                    opener.return_value.open.side_effect = http.client.BadStatusLine("synthetic-secret")
                    self.assertEqual(runner.main(env), 0, output.getvalue())
                    self.assertNotIn("synthetic-secret", output.getvalue())
                    if dry_run:
                        opener.assert_not_called()
                    else:
                        opener.return_value.open.assert_called_once()
                        request = opener.return_value.open.call_args.args[0]
                        self.assertEqual(json.loads(request.data)["sourceId"], "ios:app_store")
                        self.assertIn("will retry next tick", output.getvalue())
