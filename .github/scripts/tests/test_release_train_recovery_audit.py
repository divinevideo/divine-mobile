"""Bounded sibling audit of rejection acknowledgement and interrupted recovery."""

import unittest

import release_train_fakes  # scripts import path
from release_train import runner
from release_train.coordinator import plan_tick
from release_train.providers import Apple, ProviderError
from test_release_train_coordinator import NOW, build, snapshot


def rejected_snapshot(version="1.0.30", item_state="REJECTED"):
    s = snapshot()
    s["changes"] = {"ios": False, "android": False}
    s["ios"]["builds"] = [build()]
    s["ios"]["versions"] = [
        {"id": "v", "version": version, "state": "REJECTED", "build_id": "10"}
    ]
    s["ios"]["review_submissions"] = [
        {
            "id": "review",
            "attributes": {"state": "UNRESOLVED_ISSUES", "submittedDate": NOW - 190000},
            "items": [{"id": "item", "version_id": "v", "state": item_state}],
        }
    ]
    return s


def soaked_state():
    return {"public_available": {"10": NOW - 21600}}


class RecoveryAuditTest(unittest.TestCase):
    def test_acknowledged_rejection_can_resubmit_existing_unresolved_item(self):
        s = rejected_snapshot()
        state = soaked_state()
        self.assertFalse(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"]
        )
        runner.acknowledge(state, "ios-version:v", s)
        self.assertEqual(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"][0][
                "kind"
            ],
            "app-store",
        )

    def test_version_ack_does_not_authorize_future_rejection_on_reused_record(self):
        s = rejected_snapshot()
        state = soaked_state()
        runner.acknowledge(state, "ios-version:v", s)
        self.assertIn("ios-version:v:1.0.30", state["acknowledged"])
        s["ios"]["versions"][0]["version"] = "1.0.31"
        s["ios"]["builds"][0]["version"] = "1.0.32"
        self.assertFalse(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"]
        )

    def test_unrelated_rejected_item_holds_queue(self):
        s = rejected_snapshot()
        state = soaked_state()
        runner.acknowledge(state, "ios-version:v", s)
        s["ios"]["review_submissions"][0]["items"].append(
            {"id": "other", "version_id": None, "state": "REJECTED"}
        )
        self.assertFalse(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"]
        )

    def test_rejected_resubmission_reuses_item_and_submission_without_removal(self):
        for item_state in ["REJECTED", "READY_FOR_REVIEW"]:
            with self.subTest(item_state=item_state):
                s = rejected_snapshot(item_state=item_state)
                calls = []

                def http(method, url, headers=None, body=None, calls=calls):
                    calls.append((method, url, body))
                    if method == "GET":
                        return {
                            "data": None
                            if url.endswith("/appStoreVersionPhasedRelease")
                            else [{"id": "loc", "attributes": {"locale": "en-US"}}]
                        }
                    return {"data": {"id": "unexpected-new-resource"}}

                apple = Apple("token", "g", request=http)
                apple.submit_store(
                    build(),
                    s["ios"]["versions"],
                    ["ios-version:v:1.0.30"],
                    reviews=s["ios"]["review_submissions"],
                    notes=[{"language": "en-US", "text": "Videos load more smoothly."}],
                )
                self.assertTrue(
                    any(
                        method == "PATCH"
                        and url.endswith("/reviewSubmissions/review")
                        and body["data"]["attributes"] == {"submitted": True}
                        for method, url, body in calls
                    )
                )
                resolves = [
                    body
                    for method, url, body in calls
                    if method == "PATCH" and url.endswith("/reviewSubmissionItems/item")
                ]
                self.assertEqual(len(resolves), int(item_state == "REJECTED"))
                if resolves:
                    self.assertEqual(
                        resolves[0]["data"]["attributes"], {"resolved": True}
                    )
                self.assertFalse(
                    any(
                        method in {"POST", "DELETE"} and ("reviewSubmission" in url)
                        for method, url, _ in calls
                    )
                )

    def test_partial_record_edits_are_not_accepted_submission_evidence(self):
        s = rejected_snapshot(version="1.0.31", item_state="READY_FOR_REVIEW")
        key = "app-store:ios:10"
        state = {
            "operations": {
                key: {
                    "status": "started",
                    "started_at": NOW - 20,
                    "action": {
                        "kind": "app-store",
                        "platform": "ios",
                        "build": build(),
                    },
                }
            }
        }
        runner.reconcile_operations(state, s)
        self.assertNotEqual(state["operations"][key]["status"], "done")
        self.assertEqual(state["holds"]["ios"], key)

    def test_positive_waiting_state_reconciles_accepted_submission(self):
        s = rejected_snapshot()
        s["ios"]["versions"][0]["state"] = "WAITING_FOR_REVIEW"
        key = "app-store:ios:10"
        state = {
            "operations": {
                key: {
                    "status": "ambiguous",
                    "started_at": NOW - 20,
                    "action": {
                        "kind": "app-store",
                        "platform": "ios",
                        "build": build(),
                    },
                }
            },
            "holds": {"ios": key},
        }
        runner.reconcile_operations(state, s)
        self.assertEqual(state["operations"][key]["status"], "done")
        self.assertFalse(state["holds"])

    def test_acknowledged_interruption_resumes_same_build_after_item_was_resolved(self):
        s = rejected_snapshot(version="1.0.31", item_state="READY_FOR_REVIEW")
        state = soaked_state()
        key = "app-store:ios:10"
        state["operations"] = {
            key: {
                "status": "ambiguous",
                "action": {"kind": "app-store", "platform": "ios", "build": build()},
            }
        }
        state["holds"] = {"ios": key}
        runner.acknowledge(state, "ios-version:v", s)
        runner.acknowledge(state, key, s)
        actions = plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"]
        self.assertEqual(
            [(a["kind"], a["build"]["number"]) for a in actions], [("app-store", 10)]
        )

    def test_repeated_provider_error_requires_new_ack_even_after_old_ack(self):
        for kind, platform in [
            ("public-beta", "ios"),
            ("app-store", "ios"),
            ("play-production", "android"),
            ("retry-android-upload", "android"),
        ]:
            with self.subTest(kind=kind):
                action = (
                    {"kind": kind, "platform": platform, "build": build()}
                    if kind != "retry-android-upload"
                    else {"kind": kind, "platform": platform, "number": 10}
                )
                key = runner.operation_key(action)
                state = {"acknowledged": [key]}
                s = snapshot()

                class Store:
                    def save(self, state):
                        pass

                class Provider:
                    def execute(self, *args):
                        raise ProviderError("new failure")

                runner.execute_plan(
                    {"actions": [action]}, state, s, Store(), Provider()
                )
                result = plan_tick(
                    s, state, {"ios": "app-store", "android": "production"}
                )
                self.assertFalse(
                    any(a["platform"] == platform for a in result["actions"])
                )
                self.assertTrue(any(platform in error for error in result["errors"]))


if __name__ == "__main__":
    unittest.main()


class DraftRecoveryAuditTest(unittest.TestCase):
    def call_provider(self, version_state, review_state, items):
        calls = []
        versions = [
            {"id": "v", "version": "1.0.31", "state": version_state, "build_id": "10"}
        ]
        reviews = [
            {
                "id": "review",
                "attributes": {"state": review_state, "submittedDate": None},
                "items": items,
            }
        ]

        def http(method, url, headers=None, body=None):
            calls.append((method, url, body))
            if method == "GET":
                return {
                    "data": None
                    if url.endswith("/appStoreVersionPhasedRelease")
                    else [{"id": "loc", "attributes": {"locale": "en-US"}}]
                }
            return {"data": {"id": "unexpected-new-resource"}}

        Apple("token", "g", request=http).submit_store(
            build(), versions, [], reviews=reviews,
            notes=[{"language": "en-US", "text": "Videos load more smoothly."}]
        )
        return calls

    def test_ready_version_after_resolution_reuses_existing_review_item(self):
        calls = self.call_provider(
            "READY_FOR_REVIEW",
            "UNRESOLVED_ISSUES",
            [{"id": "item", "version_id": "v", "state": "READY_FOR_REVIEW"}],
        )
        self.assertFalse(any(method == "POST" for method, _, _ in calls))
        self.assertTrue(
            any(
                method == "PATCH" and url.endswith("/reviewSubmissions/review")
                for method, url, _ in calls
            )
        )

    def test_created_draft_and_item_are_reused_after_interruption(self):
        for items in [
            [],
            [{"id": "item", "version_id": "v", "state": "READY_FOR_REVIEW"}],
        ]:
            calls = self.call_provider(
                "PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", items
            )
            self.assertFalse(
                any(
                    method == "POST" and url.endswith("/reviewSubmissions")
                    for method, url, _ in calls
                )
            )
            creates = [
                1
                for method, url, _ in calls
                if method == "POST" and url.endswith("/reviewSubmissionItems")
            ]
            self.assertEqual(len(creates), int(not items))

    def test_unknown_draft_ownership_stops_before_mutation(self):
        with self.assertRaises(ProviderError):
            self.call_provider(
                "PREPARE_FOR_SUBMISSION",
                "READY_FOR_REVIEW",
                [{"id": "other", "version_id": None, "state": "READY_FOR_REVIEW"}],
            )

    def test_null_old_submission_timestamp_does_not_confirm_partial_mutation(self):
        s = rejected_snapshot()
        s["ios"]["review_submissions"][0]["attributes"]["submittedDate"] = None
        key = "app-store:ios:10"
        state = {
            "operations": {
                key: {
                    "status": "started",
                    "started_at": NOW - 20,
                    "action": {
                        "kind": "app-store",
                        "platform": "ios",
                        "build": build(),
                    },
                }
            }
        }
        runner.reconcile_operations(state, s)
        self.assertNotEqual(state["operations"][key]["status"], "done")
        self.assertEqual(state["holds"]["ios"], key)


class ActionableRejectionSummaryTest(unittest.TestCase):
    def test_rejection_summary_names_exact_acknowledgement_items(self):
        s = rejected_snapshot()
        result = plan_tick(s, soaked_state(), {"ios": "app-store", "android": "off"})
        reason = next(line for line in result["reasons"] if "ios-version:v" in line)
        self.assertIn("APPLE_REVIEW_RESPONSE.md#replying-to-a-rejection", reason)
        self.assertIn("reply to App Review before acknowledging ios-version:v", reason)
        self.assertFalse(any(a["kind"] == "app-store" for a in result["actions"]))
        s["ios"]["builds"] = [build() | {"external": "BETA_REJECTED"}]
        result = plan_tick(s, {}, {"ios": "testflight", "android": "off"})
        self.assertTrue(any("ios-build:10" in reason for reason in result["reasons"]))


class RecoveryIntegrationAuditTest(unittest.TestCase):
    def test_runtime_passes_observed_review_ownership_to_store_publisher(self):
        s = rejected_snapshot()
        runtime = runner.Runtime.__new__(runner.Runtime)

        class Client:
            def submit_store(self, build, versions, acknowledged, *, notes, reviews):
                if reviews != s["ios"]["review_submissions"]:
                    raise AssertionError("review snapshot missing")
                return "v"

        runtime.release_bundle = lambda *args: release_train_fakes.release_notes_bundle()
        runtime.apple = Client()
        runtime.claim = lambda *args: None
        runtime.deploy = lambda *args: None
        action = {"kind": "app-store", "platform": "ios", "build": build()}
        runtime.prepare_action(action, s)
        runtime.execute(action, {}, s)

    def test_scoped_version_ack_is_audited_on_rejected_version(self):
        s = rejected_snapshot()
        state = {}
        runner.acknowledge(state, "ios-version:v", s)
        calls = []
        runtime = runner.Runtime.__new__(runner.Runtime)
        runtime.deploy = lambda *args: calls.append(args)
        runtime.audit_observations(s, state)
        store_calls = [c for c in calls if c[0] == "ios-app-store"]
        self.assertEqual(store_calls[-1][2], "inactive")
        self.assertEqual(store_calls[-1][-1], "acknowledged")


class ManualPromotionRecoveryAuditTest(unittest.TestCase):
    def test_manual_claim_supersedes_interrupted_intent_without_replaying_old_artifact(
        self,
    ):
        for status in ["WAITING_FOR_REVIEW", "READY_FOR_DISTRIBUTION"]:
            s = rejected_snapshot(version="1.0.31")
            s["ios"]["versions"][0] |= {
                "state": status,
                "build_id": "manual-other-build",
            }
            key = "app-store:ios:10"
            state = {
                "operations": {
                    key: {
                        "status": "ambiguous",
                        "started_at": NOW - 20,
                        "action": {
                            "kind": "app-store",
                            "platform": "ios",
                            "build": build(),
                        },
                    }
                },
                "holds": {"ios": key},
            }
            runner.reconcile_operations(state, s)
            self.assertEqual(state["operations"][key]["status"], "superseded")
            self.assertFalse(state["holds"])


class ResumptionGateAuditTest(unittest.TestCase):
    def test_resumption_keeps_review_cadence_ci_and_kill_switch_gates(self):
        for gate in ["waiting", "cadence", "ci", "kill-switch"]:
            with self.subTest(gate=gate):
                s = rejected_snapshot(version="1.0.31", item_state="READY_FOR_REVIEW")
                state = soaked_state()
                key = "app-store:ios:10"
                state["operations"] = {
                    key: {
                        "status": "acknowledged",
                        "action": {
                            "kind": "app-store",
                            "platform": "ios",
                            "build": build(),
                        },
                    }
                }
                runner.acknowledge(state, "ios-version:v", s)
                level = "app-store"
                if gate == "waiting":
                    s["ios"]["review_submissions"][0]["attributes"]["state"] = (
                        "WAITING_FOR_REVIEW"
                    )
                if gate == "cadence":
                    s["ios"]["review_submissions"][0]["attributes"]["submittedDate"] = (
                        NOW - 1
                    )
                if gate == "ci":
                    s["ios"]["builds"][0]["ci_verified"] = False
                if gate == "kill-switch":
                    level = "build"
                self.assertFalse(
                    any(
                        a["kind"] == "app-store"
                        for a in plan_tick(s, state, {"ios": level, "android": "off"})[
                            "actions"
                        ]
                    )
                )

    def test_rejection_holds_submission_queues_but_internal_builds_continue(self):
        for rejection in ["beta", "store"]:
            s = rejected_snapshot()
            s["candidate"] = "b" * 40
            s["changes"]["ios"] = True
            if rejection == "beta":
                s["ios"]["builds"][0]["external"] = "BETA_REJECTED"
            actions = plan_tick(s, {}, {"ios": "app-store", "android": "off"})[
                "actions"
            ]
            self.assertTrue(
                any(a["kind"] == "build" and a["platform"] == "ios" for a in actions)
            )
            self.assertFalse(any(a["kind"] == "app-store" for a in actions))


class RejectionEpisodeAuditTest(unittest.TestCase):
    def test_new_submission_episode_same_version_needs_fresh_ack(self):
        s = rejected_snapshot(version="1.0.31")
        s["ios"]["builds"][0]["version"] = "1.0.32"
        state = soaked_state()
        s["now"] = NOW - 200000
        s["ios"]["review_submissions"][0]["attributes"]["submittedDate"] = NOW - 210000
        runner.acknowledge(state, "ios-version:v", s)
        s["now"] = NOW
        s["ios"]["review_submissions"][0]["attributes"]["submittedDate"] = NOW - 190000
        self.assertFalse(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"]
        )
        runner.acknowledge(state, "ios-version:v", s)
        self.assertTrue(
            any(
                a["kind"] == "app-store"
                for a in plan_tick(s, state, {"ios": "app-store", "android": "off"})[
                    "actions"
                ]
            )
        )

    def test_positive_acceptance_consumes_acknowledgement_during_reconciliation(self):
        s = rejected_snapshot(version="1.0.31")
        s["ios"]["versions"][0]["state"] = "WAITING_FOR_REVIEW"
        key = "app-store:ios:10"
        ack = "ios-version:v:1.0.31"
        state = {
            "acknowledged": [ack],
            "operations": {
                key: {
                    "status": "ambiguous",
                    "started_at": NOW - 20,
                    "action": {
                        "kind": "app-store",
                        "platform": "ios",
                        "build": build(),
                    },
                }
            },
        }
        runner.reconcile_operations(state, s)
        self.assertNotIn(ack, state["acknowledged"])

    def test_successful_publishing_consumes_grant_and_preserves_audit_history(self):
        s = rejected_snapshot()
        key = "ios-version:v:1.0.30"
        state = {
            "acknowledged": [key],
            "acknowledgement_events": [{"item": key, "observed_at": NOW}],
        }
        runtime = runner.Runtime.__new__(runner.Runtime)

        class Client:
            def submit_store(self, build, versions, acknowledged, *, notes, reviews):
                if key not in acknowledged:
                    raise AssertionError("original rejected item was not authorized")
                return "v"

        runtime.release_bundle = lambda *args: release_train_fakes.release_notes_bundle()
        runtime.apple = Client()
        runtime.claim = lambda *args: None
        runtime.deploy = lambda *args: None
        action = {"kind": "app-store", "platform": "ios", "build": build()}
        runtime.prepare_action(action, s)
        runtime.execute(action, state, s)
        self.assertNotIn(key, state["acknowledged"])
        self.assertEqual(state["acknowledgement_events"][0]["item"], key)

    def test_parked_acknowledged_intent_is_superseded_by_newer_manual_release(self):
        s = rejected_snapshot(version="1.0.32")
        s["ios"]["versions"][0] |= {
            "state": "READY_FOR_DISTRIBUTION",
            "build_id": "other-build",
        }
        key = "app-store:ios:10"
        state = {
            "operations": {
                key: {
                    "status": "acknowledged",
                    "started_at": NOW - 20,
                    "action": {
                        "kind": "app-store",
                        "platform": "ios",
                        "build": build(),
                    },
                }
            }
        }
        runner.reconcile_operations(state, s)
        self.assertEqual(state["operations"][key]["status"], "superseded")
        self.assertNotIn("ios", state.get("holds", {}))


class AmbiguousAcknowledgementTimeAuditTest(unittest.TestCase):
    def test_equal_submission_and_ack_second_does_not_authorize_unknown_episode(self):
        s = rejected_snapshot(version="1.0.31")
        s["ios"]["builds"][0]["version"] = "1.0.32"
        state = soaked_state()
        s["now"] = NOW - 190000
        s["ios"]["review_submissions"][0]["attributes"]["submittedDate"] = NOW - 190000
        runner.acknowledge(state, "ios-version:v", s)
        s["now"] = NOW
        self.assertFalse(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"]
        )


class FutureAcknowledgementAuditTest(unittest.TestCase):
    def test_only_observed_rejections_or_current_failure_holds_can_be_acknowledged(
        self,
    ):
        s = snapshot()
        s["ios"]["builds"] = [build()]
        s["ios"]["versions"] = [
            {"id": "v", "version": "1.0.31", "state": "WAITING_FOR_REVIEW"}
        ]
        for target in ["ios-build:10", "ios-version:v", "play-production:android:10"]:
            state = {}
            with self.assertRaises(ProviderError):
                runner.acknowledge(state, target, s)
            self.assertFalse(state.get("acknowledged"))
