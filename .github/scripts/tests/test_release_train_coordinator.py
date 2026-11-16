import release_train_fakes  # noqa: F401 - adds repository scripts to sys.path

"""Policy tests use snapshots; no store credentials or timing sleeps."""

import copy
import unittest

from release_train.coordinator import affects_app, observe, plan_tick

SHA = "a" * 40
NOW = 2000000000


def snapshot():
    return {
        "now": NOW,
        "candidate": SHA,
        "ci_passed": True,
        "changes": {"ios": True, "android": True},
        "cm": [],
        "ios": {"builds": [], "versions": [], "submissions": [], "group_valid": True},
        "android": {"internal": [], "production": [], "managed_publishing": False},
    }


def build(**changes):
    return dict(
        id="10",
        number=10,
        version="1.0.31",
        sha=SHA,
        ci_verified=True,
        valid=True,
        external="READY_FOR_BETA_TESTING",
        public=True,
        **changes,
    )


class CoordinatorTest(unittest.TestCase):
    def test_off_and_dry_run_do_not_execute(self):
        for mode in ["off", "dry-run"]:
            result = plan_tick(snapshot(), {}, {"ios": mode, "android": mode})
            self.assertFalse(result["actions"])

    def test_main_candidate_exact_ci_required(self):
        s = snapshot()
        s["ci_passed"] = False
        self.assertFalse(
            plan_tick(s, {}, {"ios": "build", "android": "build"})["actions"]
        )

    def test_active_manual_build_stops_platform(self):
        s = snapshot()
        s["cm"] = [{"platform": "ios", "status": "building"}]
        actions = plan_tick(s, {}, {"ios": "build", "android": "off"})["actions"]
        self.assertFalse(actions)

    def test_changed_source_builds_both_platforms(self):
        actions = plan_tick(snapshot(), {}, {"ios": "build", "android": "build"})[
            "actions"
        ]
        self.assertEqual([a["kind"] for a in actions], ["build", "build"])
        self.assertEqual({a["platform"] for a in actions}, {"ios", "android"})

    def test_no_changes_does_not_build(self):
        s = snapshot()
        s["changes"] = {"ios": False, "android": False}
        self.assertFalse(
            plan_tick(s, {}, {"ios": "build", "android": "build"})["actions"]
        )

    def test_retry_once_and_ambiguous_start_hold(self):
        for attempts, status, expected in [
            (1, "failed", True),
            (2, "failed", False),
            (1, "starting", False),
        ]:
            state = {"attempts": {"ios": {SHA: {"count": attempts, "status": status}}}}
            actions = plan_tick(snapshot(), state, {"ios": "build", "android": "off"})[
                "actions"
            ]
            self.assertEqual(bool(actions), expected)

    def test_ios_internal_hourly(self):
        state = {"last_build_started": {"ios": NOW - 3599}}
        self.assertFalse(
            plan_tick(snapshot(), state, {"ios": "build", "android": "off"})["actions"]
        )

    def test_public_waiting_rejection_budget_and_spacing(self):
        for external, dates in [
            ("WAITING_FOR_BETA_REVIEW", []),
            ("BETA_REJECTED", []),
            ("READY_FOR_BETA_TESTING", [NOW - 100]),
            ("READY_FOR_BETA_TESTING", [NOW - 15000 - i for i in range(6)]),
        ]:
            s = snapshot()
            s["changes"]["ios"] = False
            s["ios"]["builds"] = [build() | {"external": external, "public": False}]
            s["ios"]["submissions"] = dates
            self.assertFalse(
                plan_tick(s, {}, {"ios": "testflight", "android": "off"})["actions"]
            )

    def test_public_selects_newest_valid_and_unsubmitted(self):
        s = snapshot()
        s["changes"]["ios"] = False
        s["ios"]["builds"] = [build() | {"public": False}]
        self.assertEqual(
            plan_tick(s, {}, {"ios": "testflight", "android": "off"})["actions"][0][
                "kind"
            ],
            "public-beta",
        )

    def test_apple_unknown_stops_only_apple_queue(self):
        s = snapshot()
        s["ios"]["versions"] = [
            {"id": "v", "state": "NEW_UNKNOWN_STATE", "version": "1.0.30"}
        ]
        result = plan_tick(s, {}, {"ios": "app-store", "android": "build"})
        self.assertEqual([a["platform"] for a in result["actions"]], ["android"])
        self.assertTrue(result["errors"])

    def test_app_store_waiting_live_soak_rejected_and_ack(self):
        s = snapshot()
        s["changes"]["ios"] = False
        s["ios"]["builds"] = [build()]
        state = {"public_available": {"10": NOW - 21600}}
        self.assertEqual(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"][0][
                "kind"
            ],
            "app-store",
        )
        for status in [
            "WAITING_FOR_REVIEW",
            "IN_REVIEW",
            "PENDING_DEVELOPER_RELEASE",
            "REJECTED",
        ]:
            s["ios"]["versions"] = [{"id": "v", "state": status, "version": "1.0.30"}]
            self.assertFalse(
                plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"]
            )
        state["acknowledged"] = ["ios-version:v"]
        self.assertEqual(
            plan_tick(s, state, {"ios": "app-store", "android": "off"})["actions"][0][
                "kind"
            ],
            "app-store",
        )

    def test_manual_promotion_starts_daily_wait(self):
        s = snapshot()
        s["android"]["production"] = [{"number": 8, "version": "1.0.30"}]
        state = observe(s, {})
        s["android"]["internal"] = [
            {"number": 10, "version": "1.0.31", "sha": SHA, "ci_verified": True}
        ]
        state["internal_periods"] = {"10": {"since": NOW - 21600, "completed": True}}
        self.assertFalse(
            any(
                a["kind"] == "play-production"
                for a in plan_tick(s, state, {"ios": "off", "android": "production"})[
                    "actions"
                ]
            )
        )

    def test_android_six_hour_continuous_exposure_and_replacement(self):
        s = snapshot()
        s["android"]["internal"] = [
            {"number": 10, "version": "1.0.31", "sha": SHA, "ci_verified": True}
        ]
        state = observe(s, {})
        s["now"] += 14400
        self.assertFalse(
            plan_tick(s, state, {"ios": "off", "android": "build"})["actions"]
        )
        s["android"]["internal"] = [
            {"number": 11, "version": "1.0.31", "sha": SHA, "ci_verified": True}
        ]
        state = observe(s, state)
        s["now"] += 21600
        state = observe(s, state)
        self.assertFalse(state["internal_periods"]["10"]["completed"])
        self.assertTrue(state["internal_periods"]["11"]["completed"])

    def test_deferred_upload_survives_restart_pauses_builds(self):
        state = {
            "deferred_android": {"number": 10, "digest": "a" * 64, "build_id": "b"}
        }
        result = plan_tick(
            snapshot(), copy.deepcopy(state), {"ios": "off", "android": "build"}
        )
        self.assertEqual(
            [a["kind"] for a in result["actions"]], ["retry-android-upload"]
        )

    def test_production_kill_switch_and_managed_publish(self):
        s = snapshot()
        s["changes"]["android"] = False
        s["android"]["internal"] = [
            {"number": 10, "version": "1.0.31", "sha": SHA, "ci_verified": True}
        ]
        state = {"internal_periods": {"10": {"since": NOW - 21600, "completed": True}}}
        self.assertFalse(
            plan_tick(s, state, {"ios": "off", "android": "build"})["actions"]
        )
        self.assertEqual(
            plan_tick(s, state, {"ios": "off", "android": "production"})["actions"][0][
                "kind"
            ],
            "play-production",
        )
        s["android"]["managed_publishing"] = True
        result = plan_tick(s, state, {"ios": "off", "android": "production"})
        self.assertFalse(result["actions"])
        self.assertTrue(result["errors"])

    def test_path_policy(self):
        for path in [
            "mobile/lib/main.dart",
            "mobile/android/build.gradle",
            "codemagic.yaml",
            "mobile/scripts/build.sh",
        ]:
            self.assertTrue(affects_app(path), path)
        for path in [
            "mobile/test/a.dart",
            "mobile/docs/setup.txt",
            "mobile/README.md",
            "README.md",
            "mobile/packages/x/test/a.dart",
        ]:
            self.assertFalse(affects_app(path), path)


class QueueRaceTest(unittest.TestCase):
    def test_deferred_upload_cannot_interrupt_manual_internal_soak(self):
        s = snapshot()
        s["android"]["internal"] = [
            {"number": 11, "version": "1.0.31", "sha": SHA, "ci_verified": True}
        ]
        state = {
            "deferred_android": {"number": 10},
            "internal_periods": {"11": {"since": NOW - 10, "completed": False}},
        }
        self.assertFalse(
            plan_tick(s, state, {"ios": "off", "android": "build"})["actions"]
        )

    def test_review_submission_blocks_before_version_state_catches_up(self):
        s = snapshot()
        s["changes"]["ios"] = False
        s["ios"]["builds"] = [build()]
        s["ios"]["review_submissions"] = [
            {"attributes": {"state": "WAITING_FOR_REVIEW", "submittedDate": None}}
        ]
        self.assertFalse(
            plan_tick(
                s,
                {"public_available": {"10": NOW - 21600}},
                {"ios": "app-store", "android": "off"},
            )["actions"]
        )

    def test_manual_app_store_submission_date_applies_trailing_day(self):
        s = snapshot()
        s["changes"]["ios"] = False
        s["ios"]["builds"] = [build()]
        s["ios"]["review_submissions"] = [
            {"attributes": {"state": "COMPLETE", "submittedDate": NOW - 200}}
        ]
        self.assertFalse(
            plan_tick(
                s,
                {"public_available": {"10": NOW - 21600}},
                {"ios": "app-store", "android": "off"},
            )["actions"]
        )


class UploadedSourceTest(unittest.TestCase):
    def test_successful_upload_after_codemagic_timeout_resumes_store_state(self):
        s = snapshot()
        s["ios"]["builds"] = [build()]
        state = {"attempts": {"ios": {SHA: {"count": 1, "status": "timeout"}}}}
        actions = plan_tick(s, state, {"ios": "build", "android": "off"})["actions"]
        self.assertFalse(actions)

    def test_dry_run_shows_proposed_work_without_actions(self):
        result = plan_tick(snapshot(), {}, {"ios": "dry-run", "android": "dry-run"})
        self.assertFalse(result["actions"])
        self.assertEqual(len(result["proposed"]), 2)


if __name__ == "__main__":
    unittest.main()
