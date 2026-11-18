"""Actual Play availability must win over configured rollout status."""

import unittest
from unittest.mock import MagicMock, patch

import release_train_fakes  # noqa: F401
from release_train import release_notes
from release_train.coordinator import PLAY_PUBLICATION_VERSION, observe, plan_tick
from release_train.providers import Play, ProviderError, request_json
from release_train.runner import Runtime
from test_release_train_coordinator import NOW, snapshot

PREFIX = "RELEASE_LIFECYCLE_STATE_"


def release(state, *numbers, track="production"):
    return {
        "track": track,
        "releaseLifecycleState": PREFIX + state,
        "activeArtifacts": [{"versionCode": n} for n in numbers],
    }


def identity(platform, number):
    return {
        "number": number,
        "version": "1.0.29" if number == 10 else "1.0.31" if number == 30 else "1.0.30",
        "sha": f"{number:040x}",
        "ci_verified": True,
    }


def runtime_for(production, internal=None, failures=()):
    runtime = Runtime.__new__(Runtime)
    runtime.env = {"PLAY_MANAGED_PUBLISHING": "off"}
    runtime.identity = identity
    calls = []

    def request(method, url, headers, body):
        calls.append((method, url))
        # The old API labels even a rejected release as completed.
        if url.endswith("/edits"):
            return {"id": "edit"}
        if url.endswith("/edits/edit/tracks"):
            return {
                "tracks": [
                    {
                        "track": "production",
                        "releases": [{"status": "completed", "versionCodes": ["20"]}],
                    }
                ]
            }
        if method == "DELETE":
            return {}
        track = url.split("/")[-2]
        if track in failures:
            raise ProviderError("unavailable")
        return {"releases": production if track == "production" else (internal or [])}

    runtime.play = Play("test-token", request=request)
    return runtime, calls


class PlayLifecycleTest(unittest.TestCase):
    def test_rejected_configured_release_is_not_the_published_baseline(self):
        runtime, calls = runtime_for(
            [release("NOT_APPROVED", 20), release("PUBLISHED", 10)],
            [release("PUBLISHED", 30, track="internal")],
        )
        data = runtime.play_snapshot()
        self.assertEqual([b["number"] for b in data["production"]], [10])
        self.assertEqual([b["number"] for b in data["internal"]], [30])
        self.assertIn("rejected", data["error"])
        s = snapshot()
        s["android"] = data
        self.assertFalse(plan_tick(s, {}, {"android": "production"})["actions"])
        self.assertTrue(
            all(method == "GET" and "/edits" not in url for method, url in calls)
        )
        self.assertEqual(
            release_notes.production_baseline("android", data),
            {"version": "1.0.29", "sha": f"{10:040x}"},
        )

    def test_pending_internal_release_does_not_start_exposure_or_get_replaced(self):
        runtime, _ = runtime_for(
            [release("PUBLISHED", 10)], [release("IN_REVIEW", 30, track="internal")]
        )
        s = snapshot()
        s["android"] = runtime.play_snapshot()
        state = observe(s, {})
        self.assertNotIn("30", state["play_publication"]["internal_periods"])
        self.assertFalse(plan_tick(s, state, {"android": "production"})["actions"])

    def test_pending_production_review_is_preserved(self):
        for status in [
            "DRAFT",
            "NOT_SENT_FOR_REVIEW",
            "IN_REVIEW",
            "APPROVED_NOT_PUBLISHED",
        ]:
            with self.subTest(status=status):
                runtime, _ = runtime_for(
                    [release(status, 20), release("PUBLISHED", 10)],
                    [release("PUBLISHED", 30, track="internal")],
                )
                s = snapshot()
                s["changes"]["android"] = False
                s["android"] = runtime.play_snapshot()
                state = {
                    "play_publication": {
                        "version": PLAY_PUBLICATION_VERSION,
                        "internal_periods": {"30": {"completed": True}},
                    },
                }
                self.assertFalse(
                    plan_tick(s, state, {"android": "production"})["actions"]
                )

    def test_provider_error_preserves_published_evidence_but_stops_actions(self):
        runtime, _ = runtime_for([release("PUBLISHED", 10)], failures=["internal"])
        data = runtime.play_snapshot()
        self.assertEqual([b["number"] for b in data["production"]], [10])
        self.assertIn("error", data)
        s = snapshot()
        s["android"] = data
        self.assertFalse(plan_tick(s, {}, {"android": "production"})["actions"])

    def test_empty_get_body_is_not_an_empty_lifecycle_object(self):
        with patch("release_train.providers.urllib.request.build_opener") as opener:
            response = MagicMock()
            response.read.return_value = b""
            opener.return_value.open.return_value.__enter__.return_value = response
            with self.assertRaises(ProviderError):
                request_json("GET", "https://example.com/tracks/internal/releases")

    def test_unrecognized_lifecycle_object_stops_actions(self):
        runtime, _ = runtime_for([release("PUBLISHED", 10)])
        with patch.object(
            runtime.play,
            "call",
            side_effect=[{"warning": "no lifecycle data"}, {"releases": [release("PUBLISHED", 10)]}],
        ):
            data = runtime.play_snapshot()
        self.assertFalse(data["lifecycle_complete"])
        self.assertIn("internal", data["release_state_errors"])
        s = snapshot()
        s["android"] = data
        self.assertFalse(plan_tick(s, observe(s, {}), {"android": "production"})["actions"])

    def test_superseded_rejection_does_not_block_published_replacement(self):
        runtime, _ = runtime_for(
            [release("NOT_APPROVED", 20), release("PUBLISHED", 40)]
        )
        self.assertNotIn("error", runtime.play_snapshot())

    def test_unmapped_superseded_rejection_does_not_block_published_replacement(self):
        runtime, _ = runtime_for(
            [release("NOT_APPROVED", 20), release("PUBLISHED", 40)]
        )
        runtime.identity = Runtime.identity.__get__(runtime)
        runtime.ledger = MagicMock()
        runtime.ledger.paths.return_value = {"releases/android/1.0.32+40.json"}
        runtime.ledger.read_json.return_value = {
            "release_version": "1.0.32+40",
            "build_source_commit": f"{40:040x}",
        }
        data = runtime.play_snapshot()
        self.assertTrue(data["lifecycle_complete"])
        self.assertNotIn("error", data)
        self.assertEqual([b["number"] for b in data["production"]], [40])
        runtime.ledger.paths.return_value = set()
        with self.assertRaisesRegex(ProviderError, "Unreconciled android build 40"):
            runtime.play_snapshot()

    def test_malformed_or_unknown_lifecycle_fails_closed(self):
        for item in [
            release("FUTURE", 20),
            release("UNSPECIFIED", 20),
            None,
            release("PUBLISHED", True),
            release("PUBLISHED", "20"),
            release("PUBLISHED", 0),
            release("PUBLISHED"),
            release("PUBLISHED", 20, track="other"),
            release("PUBLISHED", 2100000001),
            release("PUBLISHED", 20) | {"releaseLifecycleState": "PUBLISHED"},
        ]:
            with self.subTest(item=item):
                runtime, _ = runtime_for([item])
                self.assertIn("error", runtime.play_snapshot())

    def test_audit_reports_published_rejected_and_pending_states(self):
        runtime, _ = runtime_for(
            [
                release("PUBLISHED", 10),
                release("NOT_APPROVED", 20),
                release("IN_REVIEW", 40),
            ],
            [release("PUBLISHED", 30, track="internal")],
        )
        events = []
        runtime.deploy = lambda env, build, status, state, description: events.append(
            (env, build["number"], status, description)
        )
        runtime.audit_observations({"android": runtime.play_snapshot()}, {})
        self.assertIn(("android-play-production", 10, "success", "available"), events)
        self.assertIn(("android-play-production", 20, "failure", "rejected"), events)
        self.assertIn(
            ("android-play-production", 40, "in_progress", "in review"), events
        )

    def test_manual_notes_use_same_actual_published_release(self):
        runtime, calls = runtime_for(
            [release("NOT_APPROVED", 20), release("PUBLISHED", 10)]
        )
        with (
            patch.object(release_notes, "Play", return_value=runtime.play),
            patch.object(release_notes, "play_token", return_value="test-token"),
            patch.object(
                release_notes,
                "_identity",
                side_effect=lambda ledger, p, n: identity(p, n),
            ),
        ):
            data = release_notes._production_data(
                "android", {"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": "protected"}, object()
            )
        self.assertEqual([b["number"] for b in data["production"]], [10])
        self.assertTrue(all(method == "GET" for method, _ in calls))

    def test_older_published_build_does_not_restart_daily_promotion_clock(self):
        runtime, _ = runtime_for([release("PUBLISHED", 20)])
        s = snapshot()
        s["android"] = runtime.play_snapshot()
        state = observe(s, {})
        runtime, _ = runtime_for([release("PUBLISHED", 10), release("PUBLISHED", 20)])
        s["now"] += 3600
        s["android"] = runtime.play_snapshot()
        result = observe(s, state)
        self.assertEqual(result["last_play_promotion"], NOW)
        self.assertEqual(result["play_publication"]["highest_production_build"], 20)
        s["now"] += 3600
        self.assertEqual(observe(s, result), result)

    def test_first_complete_observation_preserves_later_promotion_time(self):
        runtime, _ = runtime_for([release("PUBLISHED", 10)])
        s = snapshot()
        s["android"] = runtime.play_snapshot()
        previous = {"last_play_promotion": NOW + 600}
        state = observe(s, previous)
        self.assertEqual(state["last_play_promotion"], NOW + 600)
        self.assertEqual(state["play_publication"]["highest_production_build"], 10)

    def test_timers_start_at_play_observation_after_tick_started(self):
        runtime, _ = runtime_for(
            [release("PUBLISHED", 10)], [release("PUBLISHED", 30, track="internal")]
        )
        s = snapshot()
        s["android"] = runtime.play_snapshot() | {"observed_at": NOW + 600}
        state = observe(s, {})
        self.assertEqual(state["last_play_promotion"], NOW + 600)
        self.assertEqual(
            state["play_publication"]["internal_periods"]["30"]["since"], NOW + 600
        )

    def test_incomplete_snapshot_cannot_initialize_or_advance_publication(self):
        s = snapshot()
        runtime, _ = runtime_for(
            [release("PUBLISHED", 10)], [release("PUBLISHED", 30, track="internal")]
        )
        s["android"] = runtime.play_snapshot()
        certified = observe(s, {})
        s["now"] += 21600
        for production, internal, failures in [
            ([release("PUBLISHED", 20)], [], ["internal"]),
            ([], [release("PUBLISHED", 30, track="internal")], ["production"]),
            ([release("FUTURE", 20)], [release("PUBLISHED", 30, track="internal")], []),
            ([], [release("PUBLISHED", 30, track="internal")], []),
        ]:
            with self.subTest(production=production, internal=internal, failures=failures):
                runtime, _ = runtime_for(production, internal, failures)
                s["android"] = runtime.play_snapshot()
                legacy = {"last_play_promotion": NOW - 90000}
                self.assertEqual(observe(s, legacy), legacy)
                self.assertEqual(observe(s, certified), certified)
                self.assertFalse(plan_tick(s, certified, {"android": "production"})["actions"])

    def test_pending_metadata_for_published_artifact_preserves_review(self):
        runtime, _ = runtime_for([release("IN_REVIEW", 10), release("PUBLISHED", 10)])
        data = runtime.play_snapshot()
        self.assertTrue(data["production_pending"])

    def test_empty_draft_preserves_pending_publication(self):
        runtime, _ = runtime_for([release("DRAFT"), release("PUBLISHED", 10)])
        self.assertTrue(runtime.play_snapshot()["production_pending"])

    def test_manual_notes_fail_closed_on_production_lifecycle_error(self):
        runtime, _ = runtime_for([], failures=["production"])
        with (
            patch.object(release_notes, "Play", return_value=runtime.play),
            patch.object(release_notes, "play_token", return_value="test-token"),
            self.assertRaisesRegex(ProviderError, "lifecycle"),
        ):
            release_notes._production_data(
                "android",
                {"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": "protected"},
                object(),
            )

    def test_published_artifact_stays_available_during_metadata_review(self):
        runtime, _ = runtime_for([release("IN_REVIEW", 10), release("PUBLISHED", 10)])
        statuses = {}
        runtime.deploy = lambda env, build, status, state, description: statuses.update(
            {(env, build["number"]): status}
        )
        runtime.audit_observations({"android": runtime.play_snapshot()}, {})
        self.assertEqual(statuses[("android-play-production", 10)], "success")

    def test_pending_internal_release_is_named_as_the_hold(self):
        for status in ["DRAFT", "IN_REVIEW"]:
            with self.subTest(status=status):
                runtime, _ = runtime_for(
                    [release("PUBLISHED", 10)], [release(status, 30, track="internal")]
                )
                s = snapshot()
                s["android"] = runtime.play_snapshot()
                self.assertIn(
                    "android: preserve the pending Google Play internal release (draft or review)",
                    plan_tick(s, observe(s, {}), {"android": "production"})["reasons"],
                )

    def test_old_track_exposure_is_restarted_at_first_lifecycle_publication(self):
        # The old configured-track reader counted a pending internal build and
        # a rejected production build as available.
        legacy = {
            "internal_periods": {"30": {"completed": True, "since": NOW - 90000}},
            "play_production_seen": {"20": NOW - 90000},
            "last_play_promotion": NOW - 90000,
        }
        # Actual lifecycle still says rejected / pending, then both publish.
        runtime, _ = runtime_for(
            [release("NOT_APPROVED", 20), release("PUBLISHED", 10)],
            [release("IN_REVIEW", 30, track="internal")],
        )
        s = snapshot()
        s["changes"]["android"] = False
        s["android"] = runtime.play_snapshot()
        migrated = observe(s, legacy)
        self.assertEqual(migrated["last_play_promotion"], NOW)
        runtime, _ = runtime_for(
            [release("PUBLISHED", 20)], [release("PUBLISHED", 30, track="internal")]
        )
        s["now"] += 3600
        s["android"] = runtime.play_snapshot()
        state = observe(s, migrated)
        period = state["play_publication"]["internal_periods"]["30"]
        self.assertFalse(period["completed"])
        self.assertEqual(period["since"], s["now"])
        self.assertEqual(state["last_play_promotion"], s["now"])
        self.assertFalse(plan_tick(s, state, {"android": "production"})["actions"])
        s["now"] += 21600
        state = observe(s, state)
        self.assertTrue(state["play_publication"]["internal_periods"]["30"]["completed"])
        self.assertFalse(plan_tick(s, state, {"android": "production"})["actions"])
        s["now"] += 86400 - 21600
        state = observe(s, state)
        self.assertEqual(
            plan_tick(s, state, {"android": "production"})["actions"][0]["kind"],
            "play-production",
        )

    def test_first_lifecycle_read_does_not_certify_legacy_completed_exposure(self):
        runtime, _ = runtime_for(
            [release("PUBLISHED", 20)], [release("PUBLISHED", 30, track="internal")]
        )
        s = snapshot()
        s["android"] = runtime.play_snapshot()
        legacy = {
            "internal_periods": {"30": {"completed": True, "since": NOW - 90000}},
            "play_production_seen": {"20": NOW - 90000},
            "last_play_promotion": NOW - 90000,
        }
        state = observe(s, legacy)
        self.assertFalse(state["play_publication"]["internal_periods"]["30"]["completed"])
        self.assertEqual(state["last_play_promotion"], NOW)

    def test_empty_lifecycle_read_does_not_certify_a_production_migration(self):
        runtime, _ = runtime_for([])
        s = snapshot()
        s["android"] = runtime.play_snapshot()
        legacy = {
            "play_production_seen": {"20": NOW - 90000},
            "last_play_promotion": NOW - 90000,
        }
        state = observe(s, legacy)
        runtime, _ = runtime_for([release("PUBLISHED", 10)])
        s["now"] += 3600
        s["android"] = runtime.play_snapshot()
        state = observe(s, state)
        self.assertEqual(state["last_play_promotion"], s["now"])
