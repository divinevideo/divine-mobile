import io
import json
import unittest
import urllib.error
from unittest.mock import patch

import release_train_fakes  # noqa: F401 - adds repository scripts to sys.path
from release_train.providers import Play, ProviderError, request_json
from test_release_train_providers import play_notes


class PlayDiagnosticTest(unittest.TestCase):
    def test_http_error_keeps_details_private_and_reports_request_stage(self):
        private_message = 'Invalid release notes for "private account@example.test"'
        payload = {
            "error": {
                "code": 400,
                "message": private_message,
                "status": "INVALID_ARGUMENT",
                "errors": [{"reason": "badRequest"}],
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
            with self.assertRaises(ProviderError) as caught:
                request_json("PUT", "https://androidpublisher.googleapis.com/x")
        self.assertNotIn(private_message, str(caught.exception))
        self.assertEqual(caught.exception.diagnostic["message"], private_message)
        self.assertEqual(caught.exception.diagnostic["reasons"], ["badRequest"])

    def test_diagnostic_inspects_inventory_validates_notes_and_never_commits(self):
        calls = []

        def request(method, url, headers=None, body=None):
            calls.append((method, url, body))
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
                return {"bundles": [{"versionCode": 879}, {"versionCode": 876}]}
            return {}

        report = Play("private-token", request=request).diagnose_upload(
            notes=play_notes()
        )
        self.assertEqual(report["bundles"], [876, 879])
        self.assertEqual(report["notes_validation_build"], 879)
        self.assertEqual(report["stage"], "complete")
        self.assertEqual(calls[-1][0], "DELETE")
        self.assertFalse(
            any(":commit" in url or "/upload/" in url for _, url, _ in calls)
        )
        put = next(body for method, _, body in calls if method == "PUT")
        self.assertEqual(put["releases"][0]["versionCodes"], ["879"])
        self.assertEqual(put["releases"][0]["releaseNotes"], play_notes())

    def test_diagnostic_preserves_primary_failure_and_always_deletes_edit(self):
        calls = []
        failure = ProviderError("HTTP 400")
        failure.diagnostic = {"code": 400, "message": "private validation detail"}

        def request(method, url, headers=None, body=None):
            calls.append((method, url))
            if method == "DELETE":
                raise ProviderError("cleanup unavailable")
            if url.endswith("/edits"):
                return {"id": "temporary-edit"}
            if url.endswith("/tracks"):
                raise failure
            return {}

        report = Play("private-token", request=request).diagnose_upload(
            notes=play_notes()
        )
        self.assertEqual(report["stage"], "inventory tracks")
        self.assertEqual(report["error"]["message"], "private validation detail")
        self.assertIn("cleanup unavailable", report["cleanup_error"])
        self.assertEqual(calls[-1][0], "DELETE")
        self.assertFalse(any(":commit" in url for _, url in calls))

    def test_invalid_notes_do_not_create_edit(self):
        calls = []
        with self.assertRaises(ProviderError):
            Play("token", request=lambda *args: calls.append(args)).diagnose_upload(
                notes=[]
            )
        self.assertEqual(calls, [])


class ProtectedDiagnosticTest(unittest.TestCase):
    def test_report_is_private_and_no_coordinator_or_state_write_is_called(self):
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
        )
        runtime.store = Mock()
        runtime.store.load.return_value = {"holds": {"android": "android-upload:881"}}
        runtime.list_builds = Mock(return_value=[])
        runtime.ledger.read_json.return_value = {
            "number": 881,
            "status": "failed",
            "sha": SOURCE,
            "release_notes": android_bundle(),
        }
        private = {
            "stage": "validate retained notes",
            "error": {"message": "private detail"},
        }
        with (
            patch("release_train.runner.Play") as play,
            patch("release_train.runner.play_token", return_value="token"),
            patch("builtins.print") as output,
        ):
            play.return_value.diagnose_upload.return_value = private
            self.assertEqual(diagnose_android_upload(runtime, "881"), 1)
        saved = runtime.ledger.create_json.call_args.args
        self.assertEqual(saved[0], "diagnostics/android/881/100-1.json")
        self.assertEqual(saved[1]["error"]["message"], "private detail")
        self.assertNotIn("private detail", str(output.call_args_list))
        self.assertEqual(play.return_value.method_calls[0][0], "diagnose_upload")
        self.assertEqual(len(play.return_value.method_calls), 1)

    def test_invalid_version_and_unrelated_upload_stop_before_provider_access(self):
        from types import SimpleNamespace
        from unittest.mock import Mock

        from release_train.runner import diagnose_android_upload

        runtime = SimpleNamespace(env={}, ledger=Mock())
        for value in ["../881", "0", "2100000001"]:
            with self.assertRaises(ProviderError):
                diagnose_android_upload(runtime, value)
        runtime.ledger.read_json.assert_not_called()
        runtime.ledger.read_json.return_value = {"number": 880, "status": "failed"}
        with self.assertRaises(ProviderError):
            diagnose_android_upload(runtime, "881")
        runtime.ledger.create_json.assert_not_called()

    def test_manual_diagnostic_returns_before_release_state_load_or_actions(self):
        from unittest.mock import Mock

        from release_train import runner

        env = {
            "GITHUB_REPOSITORY": "divinevideo/divine-mobile",
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_EVENT_NAME": "workflow_dispatch",
            "GITHUB_WORKFLOW_REF": "divinevideo/divine-mobile/.github/workflows/release_train.yml@refs/heads/main",
            "GITHUB_SHA": "a" * 40,
            "GITHUB_WORKFLOW_SHA": "a" * 40,
            "RELEASE_DIAGNOSE_ANDROID_UPLOAD": "881",
        }
        runtime = Mock()
        with (
            patch.object(runner.subprocess, "check_output", return_value="a" * 40),
            patch.object(runner, "Runtime", return_value=runtime),
            patch.object(runner, "diagnose_android_upload", return_value=0) as diagnose,
        ):
            self.assertEqual(runner.main(env), 0)
        diagnose.assert_called_once_with(runtime, "881")
        self.assertEqual(runtime.method_calls, [])
        for conflict in [
            "RELEASE_ACKNOWLEDGE",
            "RELEASE_BOOTSTRAP",
            "RELEASE_SETUP_CODEMAGIC",
        ]:
            with (
                patch.object(runner.subprocess, "check_output", return_value="a" * 40),
                patch.object(runner, "Runtime", return_value=runtime),
                self.assertRaises(ProviderError),
            ):
                runner.main(env | {conflict: "true"})

    def test_diagnostic_blocks_unheld_or_active_upload_before_play_authentication(self):
        from types import SimpleNamespace
        from unittest.mock import Mock

        from release_train.runner import diagnose_android_upload
        from test_publish_play_bundle import SOURCE, android_bundle

        runtime = SimpleNamespace(
            env={}, ledger=Mock(), store=Mock(), list_builds=Mock()
        )
        runtime.ledger.read_json.return_value = {
            "number": 881,
            "status": "failed",
            "sha": SOURCE,
            "release_notes": android_bundle(),
        }
        for state, builds in [
            ({}, []),
            (
                {"holds": {"android": "android-upload:881"}},
                [{"platform": "android", "status": "building"}],
            ),
        ]:
            runtime.store.load.return_value = state
            runtime.list_builds.return_value = builds
            with (
                patch("release_train.runner.play_token") as token,
                self.assertRaises(ProviderError),
            ):
                diagnose_android_upload(runtime, "881")
            token.assert_not_called()
        runtime.ledger.create_json.assert_not_called()

    def test_manual_android_driver_and_diagnostic_share_non_cancelling_workflow_lock(
        self,
    ):
        import subprocess
        from pathlib import Path

        root = Path(__file__).resolve().parents[3]
        locks = []
        for name in ["release_train.yml", "android_store_release.yml"]:
            workflow = json.loads(
                subprocess.check_output(
                    [
                        "ruby",
                        "-ryaml",
                        "-rjson",
                        "-e",
                        "print JSON.generate(YAML.load_file(ARGV[0]))",
                        str(root / ".github/workflows" / name),
                    ],
                    text=True,
                )
            )
            locks.append(workflow["concurrency"])
        self.assertEqual(
            locks,
            [
                {
                    "group": "store-release-train",
                    "cancel-in-progress": False,
                    "queue": "max",
                }
            ]
            * 2,
        )
