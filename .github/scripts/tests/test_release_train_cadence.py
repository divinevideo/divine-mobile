"""Rolling release limits, including accepted writes recovered after a restart."""

import unittest
from unittest.mock import patch

import release_train_fakes  # noqa: F401 - scripts import path
from release_train.coordinator import PLAY_PUBLICATION_VERSION, observe, plan_tick
from release_train.runner import Runtime, execute_plan
from test_release_train_coordinator import NOW, build, snapshot
from test_release_train_runner import Store

HOUR = 3600
DAY = 24 * HOUR


def operation(kind, stamp, status="done"):
    return {
        "action": {
            "kind": kind,
            "platform": "android" if kind == "play-production" else "ios",
            "build": build(),
        },
        "started_at": stamp,
        "status": status,
    }


class ReleaseCadenceTest(unittest.TestCase):
    def public_snapshot(self):
        s = snapshot()
        s["changes"] = {"ios": False, "android": False}
        s["ios"]["builds"] = [build() | {"public": False}]
        return s

    def test_public_beta_limit_is_two_in_a_rolling_day(self):
        s = self.public_snapshot()
        s["ios"]["submissions"] = [NOW - 13 * HOUR, NOW - 14 * HOUR]
        self.assertFalse(plan_tick(s, {}, {"ios": "testflight"})["actions"])
        s["now"] = NOW + 10 * HOUR - 1
        self.assertFalse(plan_tick(s, {}, {"ios": "testflight"})["actions"])
        s["now"] = NOW + 10 * HOUR
        self.assertEqual(
            [a["kind"] for a in plan_tick(s, {}, {"ios": "testflight"})["actions"]],
            ["public-beta"],
        )

    def test_public_beta_waits_twelve_hours_across_midnight(self):
        s = self.public_snapshot()
        # The UTC date changes after one second; the rolling wait does not reset.
        last = (NOW // DAY) * DAY - 1
        s["ios"]["submissions"] = [last]
        for elapsed in [1, 4 * HOUR, 12 * HOUR - 1, 12 * HOUR]:
            with self.subTest(elapsed=elapsed):
                s["now"] = last + elapsed
                self.assertEqual(
                    bool(plan_tick(s, {}, {"ios": "testflight"})["actions"]),
                    elapsed >= 12 * HOUR,
                )

    def test_beta_journal_preserves_spacing_without_a_new_review_submission(self):
        s = self.public_snapshot()
        s["ios"]["builds"][0]["external"] = "BETA_APPROVED"
        for status in ["done", "deferred", "ambiguous", "acknowledged"]:
            for elapsed in [12 * HOUR - 1, 12 * HOUR]:
                with self.subTest(status=status, elapsed=elapsed):
                    state = {"operations": {"prior": operation("public-beta", NOW, status)}}
                    state["operations"]["prior"]["action"]["build"] = build() | {
                        "id": "9", "number": 9,
                    }
                    s["now"] = NOW + elapsed
                    self.assertEqual(
                        bool(plan_tick(s, state, {"ios": "testflight"})["actions"]),
                        elapsed >= 12 * HOUR,
                    )

    def test_first_public_group_recovery_obeys_the_release_budget(self):
        for dates, started, allowed in [
            ([], NOW - HOUR, False),
            ([NOW - 13 * HOUR, NOW - 14 * HOUR], NOW - DAY, False),
            ([], NOW - 12 * HOUR, True),
        ]:
            with self.subTest(dates=dates, started=started):
                s = self.public_snapshot()
                s["ios"]["submissions"] = dates
                state = {"operations": {"prior": operation("public-beta", started)}}
                self.assertEqual(
                    [a["kind"] for a in plan_tick(s, state, {"ios": "testflight"})["actions"]],
                    ["attach-beta-groups"] if allowed else [],
                )

    def test_first_public_recovery_reserves_the_tick_and_survives_restart(self):
        s = self.public_snapshot()
        first = s["ios"]["builds"][0]
        second = first | {"id": "11", "number": 11}
        third = first | {"id": "12", "number": 12}
        s["ios"]["builds"] = [first, second, third]
        state = {"operations": {"prior": operation("public-beta", NOW - DAY)}}
        state["operations"]["second"] = operation("public-beta", NOW - DAY)
        state["operations"]["second"]["action"]["build"] = second
        plan = plan_tick(s, state, {"ios": "testflight"})
        self.assertEqual(
            [(a["kind"], a["build"]["id"]) for a in plan["actions"]],
            [("attach-beta-groups", "10")],
        )

        class Attached:
            def execute(self, action, state, snapshot):
                return {}

        store = Store()
        execute_plan(plan, state, s, store, Attached())
        state = store.saves[-1]
        first.update(public=True, public_complete=True)
        for elapsed in [12 * HOUR - 1, 12 * HOUR]:
            with self.subTest(elapsed=elapsed):
                s["now"] = NOW + elapsed
                actions = plan_tick(s, state, {"ios": "testflight"})["actions"]
                self.assertEqual(
                    [(a["kind"], a["build"]["id"]) for a in actions],
                    [("attach-beta-groups", "11")] if elapsed == 12 * HOUR else [],
                )

    def test_already_public_group_recovery_does_not_consume_release_budget(self):
        for dates in [[], [NOW - HOUR]]:
            with self.subTest(dates=dates):
                s = self.public_snapshot()
                partial = build() | {"groups": ["public"], "public_complete": False}
                s["ios"]["builds"] = [partial, build() | {
                    "id": "11", "number": 11, "public": False,
                }]
                s["ios"]["submissions"] = dates
                self.assertEqual(
                    [a["kind"] for a in plan_tick(s, {}, {"ios": "testflight"})["actions"]],
                    ["attach-beta-groups"] + ([] if dates else ["public-beta"]),
                )

        s["ios"]["submissions"] = []
        s["ios"]["builds"] = s["ios"]["builds"][1:]
        state = {"operations": {"recovered": operation("attach-beta-groups", NOW)}}
        self.assertEqual(
            [a["kind"] for a in plan_tick(s, state, {"ios": "testflight"})["actions"]],
            ["public-beta"],
        )

    def test_app_store_waits_48_hours_for_provider_state_and_journal(self):
        for source in ["review", "version", "saved", "journal", "publication"]:
            for elapsed in [DAY, 2 * DAY - 1, 2 * DAY]:
                with self.subTest(source=source, elapsed=elapsed):
                    s = self.public_snapshot()
                    s["ios"]["builds"][0]["public"] = True
                    s["now"] = NOW + elapsed
                    state = {}
                    if source == "review":
                        s["ios"]["review_submissions"] = [
                            {"attributes": {"state": "COMPLETE", "submittedDate": NOW}}
                        ]
                    elif source == "version":
                        s["ios"]["versions"] = [
                            {"id": "old", "version": "1.0.30", "state": "READY_FOR_SALE", "submitted_at": NOW}
                        ]
                    elif source == "saved":
                        state["app_store_submissions"] = [NOW]
                    elif source == "publication":
                        state["last_app_store_publication"] = NOW
                    else:
                        state["operations"] = {"prior": operation("app-store", NOW, "acknowledged")}
                    self.assertEqual(
                        bool(plan_tick(s, state, {"ios": "app-store"})["actions"]),
                        elapsed >= 2 * DAY,
                    )

    def test_play_waits_48_hours_for_saved_manual_and_recovered_promotions(self):
        for source in ["saved", "manual", "journal"]:
            for elapsed in [DAY, 2 * DAY - 1, 2 * DAY]:
                with self.subTest(source=source, elapsed=elapsed):
                    s = snapshot()
                    s["changes"]["android"] = False
                    s["android"]["internal"] = [build()]
                    state = {"play_publication": {
                        "version": PLAY_PUBLICATION_VERSION,
                        "highest_production_build": 0,
                        "internal_periods": {"10": {"since": NOW - DAY, "completed": True}},
                    }}
                    if source == "manual":
                        s["android"]["production"] = [{"number": 8, "version": "1.0.30"}]
                        state = observe(s, state)
                    elif source == "saved":
                        state["last_play_promotion"] = NOW
                    else:
                        state["operations"] = {"prior": operation("play-production", NOW, "acknowledged")}
                    s["now"] = NOW + elapsed
                    self.assertEqual(
                        bool(plan_tick(s, state, {"android": "production"})["actions"]),
                        elapsed >= 2 * DAY,
                    )

    def test_new_ios_publication_starts_wait_independently_of_android(self):
        for status in ["READY_FOR_SALE", "READY_FOR_DISTRIBUTION"]:
            with self.subTest(status=status):
                s = self.public_snapshot()
                s["ios"]["builds"][0]["public"] = True
                s["android"] = {"error": "unavailable"}
                s["ios"]["versions"] = [{"id": "old", "version": "1.0.30", "state": status}]
                state = observe(s, {})
                self.assertEqual(state.get("last_app_store_publication"), NOW)
                self.assertFalse(plan_tick(s, state, {"ios": "app-store"})["actions"])
                s["now"] += 2 * DAY
                state = observe(s, state)
                self.assertEqual(state["last_app_store_publication"], NOW)
                self.assertEqual(
                    [a["kind"] for a in plan_tick(s, state, {"ios": "app-store"})["actions"]],
                    ["app-store"],
                )
                s["ios"]["versions"][0]["version"] = "1.0.31"
                self.assertEqual(observe(s, state)["last_app_store_publication"], s["now"])

    def test_old_or_missing_ios_publication_does_not_restart_wait(self):
        s = snapshot()
        state = {"highest_app_store_version": "1.0.31", "last_app_store_publication": NOW - DAY}
        for versions in [[], [{"id": "old", "version": "1.0.30", "state": "READY_FOR_SALE"}],
                         [{"id": "next", "version": "1.0.32", "state": "IN_REVIEW"}]]:
            with self.subTest(versions=versions):
                s["ios"]["versions"] = versions
                self.assertEqual(observe(s, state)["last_app_store_publication"], NOW - DAY)

    def test_ios_publication_wait_starts_after_the_apple_read(self):
        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.list_builds = list
        runtime.candidate = lambda: "a" * 40
        runtime.source_ci = lambda sha: True
        clock = [NOW]
        ios = self.public_snapshot()["ios"]
        ios["builds"][0]["public"] = True
        ios["versions"] = [{
            "id": "old", "version": "1.0.30", "state": "READY_FOR_SALE",
        }]

        def apple_read():
            clock[0] += HOUR
            return ios

        runtime.apple_snapshot = apple_read
        with patch("release_train.runner.time.time", side_effect=lambda: clock[0]), patch(
            "release_train.runner.apple_token", return_value="test-token"
        ):
            s = runtime.snapshot({}, {"ios": "app-store", "android": "off"})

        self.assertEqual(s["now"], NOW)
        self.assertEqual(s["ios"].get("observed_at"), NOW + HOUR)
        state = observe(s, {})
        self.assertEqual(state["last_app_store_publication"], NOW + HOUR)
        s["changes"] = {"ios": False, "android": False}
        for elapsed in [2 * DAY, HOUR + 2 * DAY - 1, HOUR + 2 * DAY]:
            with self.subTest(elapsed=elapsed):
                s["now"] = NOW + elapsed
                self.assertEqual(
                    [a["kind"] for a in plan_tick(s, state, {"ios": "app-store"})["actions"]],
                    ["app-store"] if elapsed == HOUR + 2 * DAY else [],
                )
