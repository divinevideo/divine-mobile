"""Regressions from independent whole-diff review at 4bebe659a1."""

import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

import release_train_fakes  # noqa: F401 - scripts import path
from release_train import runner
from release_train.coordinator import plan_tick
from release_train.providers import Apple, ProviderError
from release_train.runner import reconcile_operations
from test_release_train_coordinator import NOW, SHA, build, snapshot

ROOT = Path(__file__).resolve().parents[3]


class ReviewRegressionTest(unittest.TestCase):
    def test_production_needs_each_artifacts_own_ci(self):
        for ci in [False, None]:
            s = snapshot()
            s["changes"] = {"ios": False, "android": False}
            s["ios"]["builds"] = [build() | {"ci_verified": ci}]
            s["android"]["internal"] = [
                {"number": 10, "version": "1.0.31", "sha": SHA, "ci_verified": ci}
            ]
            state = {
                "public_available": {"10": NOW - 21600},
                "internal_periods": {"10": {"completed": True}},
            }
            self.assertFalse(
                plan_tick(s, state, {"ios": "app-store", "android": "production"})[
                    "actions"
                ]
            )

    def test_partial_fanout_resumes_only_missing_groups_without_review(self):
        calls = []

        def http(method, url, headers=None, body=None):
            calls.append((method, url, body))
            return {"data": {"id": "r"}}

        apple = Apple("token", "one", request=http)
        apple.groups = ["one", "two", "three", "four"]
        apple.attach_groups({"id": "10", "groups": ["one"]})
        self.assertEqual(
            [c[1].split("/betaGroups/")[1].split("/")[0] for c in calls],
            ["two", "three", "four"],
        )
        key = "public-beta:ios:10"
        state = {
            "operations": {
                key: {
                    "status": "ambiguous",
                    "action": {
                        "kind": "public-beta",
                        "platform": "ios",
                        "build": build(),
                    },
                }
            },
            "holds": {"ios": key},
        }
        s = snapshot()
        s["changes"]["ios"] = False
        s["ios"]["builds"] = [
            build()
            | {
                "ci_verified": True,
                "groups": ["one"],
                "public_complete": False,
                "external": "IN_BETA_REVIEW",
            }
        ]
        reconcile_operations(state, s)
        self.assertNotEqual(state["operations"][key]["status"], "done")
        self.assertEqual(
            plan_tick(s, state, {"ios": "testflight", "android": "off"})["actions"][0][
                "kind"
            ],
            "attach-beta-groups",
        )

    def test_known_apple_states_are_classified_and_approved_never_resubmits(self):
        for status in [
            "BETA_APPROVED",
            "IN_EXPORT_COMPLIANCE_REVIEW",
            "PROCESSING_EXCEPTION",
        ]:
            s = snapshot()
            s["changes"]["ios"] = False
            s["ios"]["builds"] = [build() | {"external": status, "public": False}]
            self.assertFalse(
                plan_tick(s, {}, {"ios": "testflight", "android": "off"})["errors"],
                status,
            )
        calls = []

        def http(method, url, headers=None, body=None):
            calls.append((method, url))
            return {"data": [] if method == "GET" else {"id": "r"}}

        apple = Apple("token", "one", request=http)
        apple.submit_beta(build() | {"external": "BETA_APPROVED"}, "Changes")
        self.assertFalse(any("/betaAppReviewSubmissions" in url for _, url in calls))

    def test_newest_baseline_survives_sorted_restart(self):
        old = "f" * 40
        new = "1" * 40
        state = {
            "operations": {
                f"build:ios:{sha}:1": {
                    "status": "done",
                    "started_at": stamp,
                    "action": {
                        "kind": "build",
                        "platform": "ios",
                        "sha": sha,
                        "attempt": 1,
                    },
                }
                for sha, stamp in [(old, 100), (new, 200)]
            }
        }
        state = json.loads(json.dumps(state, sort_keys=True))
        reconcile_operations(
            state,
            {
                "cm": [
                    {
                        "platform": "ios",
                        "sha": sha,
                        "attempt": 1,
                        "status": "finished",
                        "id": sha[:24],
                    }
                    for sha in [old, new]
                ]
            },
        )
        self.assertEqual(state["last_built_source"]["ios"], new)

    def test_interrupted_start_has_named_hold_and_ack_allows_bounded_retry(self):
        key = "build:ios:" + SHA + ":1"
        state = {
            "operations": {
                key: {
                    "status": "started",
                    "started_at": NOW - 3600,
                    "action": {
                        "kind": "build",
                        "platform": "ios",
                        "sha": SHA,
                        "attempt": 1,
                    },
                }
            },
            "attempts": {"ios": {SHA: {"count": 1, "status": "starting"}}},
        }
        s = snapshot()
        reconcile_operations(state, s)
        self.assertEqual(state["holds"]["ios"], key)
        self.assertFalse(
            plan_tick(s, state, {"ios": "build", "android": "off"})["actions"]
        )
        runner.acknowledge(state, key, s)
        self.assertEqual(
            plan_tick(s, state, {"ios": "build", "android": "off"})["actions"][0][
                "attempt"
            ],
            2,
        )

    def test_effective_identity_is_retained_and_retry_command_uses_it(self):
        config = json.loads(
            subprocess.check_output(
                [
                    "ruby",
                    "-ryaml",
                    "-rjson",
                    "-e",
                    "puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))",
                    str(ROOT / "codemagic.yaml"),
                ],
                text=True,
            )
        )
        for platform in ["ios", "android", "macos"]:
            self.assertIn(
                "build/shorebird/" + platform + "_release.env",
                config["workflows"][platform + "-build"]["artifacts"],
            )
        guide = (
            (ROOT / "release-notes/README.md")
            .read_text()
            .split("## Retry publication with the original files", 1)[1]
        )
        self.assertIn("--release-env", guide)


if __name__ == "__main__":
    unittest.main()


class ProviderBatchTest(unittest.TestCase):
    def test_paginated_included_resources_are_preserved(self):
        pages = [
            {
                "data": [{"id": "a"}],
                "included": [
                    {
                        "type": "buildBetaDetails",
                        "id": "d",
                        "attributes": {"externalBuildState": "BETA_APPROVED"},
                    }
                ],
                "links": {
                    "next": "https://api.appstoreconnect.apple.com/v1/builds?page=2"
                },
            },
            {
                "data": [{"id": "b"}],
                "included": [
                    {
                        "type": "preReleaseVersions",
                        "id": "v",
                        "attributes": {"version": "1.0.31"},
                    }
                ],
            },
        ]
        apple = Apple("token", "g", request=lambda *args: pages.pop(0))
        builds, included = apple.pages_including("/builds")
        self.assertEqual(len(builds), 2)
        self.assertEqual(
            included[("buildBetaDetails", "d")]["attributes"]["externalBuildState"],
            "BETA_APPROVED",
        )
        self.assertIn(("preReleaseVersions", "v"), included)

    def test_public_distribution_enables_notifications_without_altering_audience(self):
        calls = []

        def http(method, url, headers=None, body=None):
            calls.append((method, url, body))
            return {"data": [] if method == "GET" else {"id": "r"}}

        apple = Apple("token", "g", request=http)
        apple.submit_beta(
            build() | {"external": "BETA_APPROVED", "beta_detail_id": "d"}, "Notes"
        )
        self.assertTrue(
            any(
                method == "PATCH"
                and url.endswith("/buildBetaDetails/d")
                and body["data"]["attributes"] == {"autoNotifyEnabled": True}
                for method, url, body in calls
            )
        )


class ExactCIEvidenceTest(unittest.TestCase):
    def test_failed_missing_cancelled_unrelated_and_successful_evidence(self):
        from types import SimpleNamespace

        for conclusion, check_sha, expected in [
            ("failure", SHA, False),
            ("cancelled", SHA, False),
            (None, SHA, False),
            ("success", "b" * 40, False),
            ("success", SHA, True),
        ]:
            runtime = runner.Runtime.__new__(runner.Runtime)
            runtime.env = {"GITHUB_REPOSITORY": "owner/repo"}

            class GH:
                def pages(
                    self, path, field, conclusion=conclusion, check_sha=check_sha
                ):
                    if field == "workflow_runs":
                        return (
                            []
                            if conclusion is None
                            else [
                                {
                                    "id": 7,
                                    "head_sha": SHA,
                                    "status": "completed",
                                    "conclusion": conclusion,
                                    "event": "merge_group",
                                    "head_branch": "queue",
                                }
                            ]
                        )
                    return [
                        {
                            "name": "Mobile CI",
                            "head_sha": check_sha,
                            "status": "completed",
                            "conclusion": "success",
                            "app": {"id": 15368},
                            "details_url": "https://github.com/owner/repo/actions/runs/7/job/8",
                        }
                    ]

            runtime.gh = GH()
            with patch.object(
                runner.subprocess, "run", return_value=SimpleNamespace(returncode=0)
            ):
                self.assertEqual(
                    runtime.source_ci(SHA), expected, (conclusion, check_sha)
                )

    def test_source_not_reachable_from_main_never_uses_green_ci(self):
        from types import SimpleNamespace

        runtime = runner.Runtime.__new__(runner.Runtime)
        with patch.object(
            runner.subprocess, "run", return_value=SimpleNamespace(returncode=1)
        ):
            self.assertFalse(runtime.source_ci(SHA))


class HistoricalProviderStateTest(unittest.TestCase):
    def test_missing_detail_is_safe_only_for_known_unavailable_builds(self):
        self.assertEqual(
            runner.beta_attributes(
                {"processingState": "VALID", "expired": True}, None, False
            )["externalBuildState"],
            "EXPIRED",
        )
        self.assertEqual(
            runner.beta_attributes({"processingState": "PROCESSING"}, None, False)[
                "externalBuildState"
            ],
            "PROCESSING",
        )
        self.assertEqual(
            runner.beta_attributes({"processingState": "FAILED"}, None, False)[
                "externalBuildState"
            ],
            "PROCESSING_EXCEPTION",
        )
        with self.assertRaises(ProviderError):
            runner.beta_attributes({"processingState": "VALID"}, None, False)


class SparseIncludedRelationTest(unittest.TestCase):
    def test_sparse_beta_detail_uses_single_authoritative_related_read(self):
        calls = []
        resource = {"id": "d", "attributes": {"externalBuildState": "IN_BETA_TESTING"}}
        apple = Apple(
            "token",
            "g",
            request=lambda method, url, *args: (
                calls.append((method, url)) or {"data": resource}
            ),
        )
        self.assertEqual(apple.beta_detail("b", None), resource)
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0][1].endswith("/builds/b/buildBetaDetail"))
        self.assertEqual(apple.beta_detail("b", resource), resource)
        self.assertEqual(len(calls), 1)


class LargePrivateStateTest(unittest.TestCase):
    def test_large_state_reads_exact_blob_when_contents_encoding_is_none(self):
        import base64

        calls = []
        expected = {"schema": 1, "operations": {"synthetic": {"status": "started"}}}

        class GH:
            def call(self, method, path, payload=None):
                calls.append(path)
                if path.startswith("/contents/"):
                    return {
                        "sha": "b" * 40,
                        "encoding": "none",
                        "content": "",
                        "size": 2000000,
                    }
                self_expected = "/git/blobs/" + ("b" * 40)
                if path != self_expected:
                    raise AssertionError(path)
                return {
                    "encoding": "base64",
                    "content": base64.b64encode(json.dumps(expected).encode()).decode(),
                }

        store = runner.StateStore(GH())
        self.assertEqual(store.load(), expected)
        self.assertEqual(store.sha, "b" * 40)
        self.assertEqual(len(calls), 2)


class AssignedGroupRejectionTest(unittest.TestCase):
    def test_rejected_build_still_in_groups_holds_new_submissions_until_ack(self):
        s = snapshot()
        s["changes"]["ios"] = False
        rejected = build() | {
            "external": "BETA_REJECTED",
            "public": True,
            "public_complete": True,
        }
        newer = build() | {
            "id": "11",
            "number": 11,
            "public": False,
            "external": "READY_FOR_BETA_SUBMISSION",
        }
        s["ios"]["builds"] = [rejected, newer]
        self.assertFalse(
            plan_tick(s, {}, {"ios": "testflight", "android": "off"})["actions"]
        )
        actions = plan_tick(
            s,
            {"acknowledged": ["ios-build:10"]},
            {"ios": "testflight", "android": "off"},
        )["actions"]
        self.assertEqual([a["kind"] for a in actions], ["public-beta"])
