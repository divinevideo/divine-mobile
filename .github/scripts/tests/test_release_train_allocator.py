import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train_fakes import MemoryLedgerStore  # noqa: E402

from release_train.allocator import (  # noqa: E402
    AllocationError,
    allocate,
    bootstrap,
    claimed_versions,
    derive_version,
    map_play_version_codes,
    reconcile,
    reserve_build_number,
    validate_reservation_key,
)
from release_train.ledger import (  # noqa: E402
    BOOTSTRAP_PATH,
    LedgerError,
    key_path,
    provenance_path,
    reservation_path,
)
from release_train.versions import Version  # noqa: E402

NOW = datetime(2026, 11, 5, 12, 0, tzinfo=timezone.utc)


def v(text):
    return Version(*[int(p) for p in text.split(".")])


class ReconcileTest(unittest.TestCase):
    def test_ios_reconcile_writes_missing_app_store_claims(self) -> None:
        ledger = MemoryLedgerStore()
        created = reconcile(
            "ios", ledger=ledger, store_versions=[v("1.0.27"), v("1.0.28")], now=NOW
        )
        expected = [
            "allocations/claims/1.0.27/app-store.json",
            "allocations/claims/1.0.28/app-store.json",
        ]
        self.assertEqual(created, expected)
        self.assertEqual(ledger.creates, expected)
        self.assertEqual(
            ledger.files[expected[0]],
            {
                "schema": 1,
                "version": "1.0.27",
                "channel": "app-store",
                "platform": "ios",
                "source": "reconciled",
                "observed_at": NOW.isoformat(),
            },
        )

    def test_a_claim_lost_to_a_concurrent_run_is_not_reported(self) -> None:
        lost = "allocations/claims/1.0.27/app-store.json"
        ledger = RacingStore(race=lost)
        created = reconcile(
            "ios", ledger=ledger, store_versions=[v("1.0.27"), v("1.0.28")], now=NOW
        )
        self.assertEqual(created, ["allocations/claims/1.0.28/app-store.json"])

    def test_android_reconcile_maps_codes_through_allocations_then_provenance(
        self,
    ) -> None:
        ledger = MemoryLedgerStore(
            {
                "allocations/builds/android/200.json": {"version": "1.0.29"},
                "releases/android/1.0.28+190.json": {},
            }
        )
        created = reconcile(
            "android", ledger=ledger, store_version_codes=[200, 190], now=NOW
        )
        self.assertEqual(
            created,
            [
                "allocations/claims/1.0.29/play-production.json",
                "allocations/claims/1.0.28/play-production.json",
            ],
        )
        record = ledger.files["allocations/claims/1.0.29/play-production.json"]
        self.assertEqual(record["platform"], "android")
        self.assertEqual(record["channel"], "play-production")

    def test_unmappable_play_code_fails_closed_naming_it(self) -> None:
        ledger = MemoryLedgerStore()
        with self.assertRaises(AllocationError) as caught:
            reconcile("android", ledger=ledger, store_version_codes=[999], now=NOW)
        self.assertIn("999", str(caught.exception))
        self.assertEqual(ledger.creates, [])

    def test_existing_claims_are_not_rewritten(self) -> None:
        ledger = MemoryLedgerStore(
            {"allocations/claims/1.0.27/app-store.json": {"schema": 1}}
        )
        created = reconcile("ios", ledger=ledger, store_versions=[v("1.0.27")], now=NOW)
        self.assertEqual(created, [])
        self.assertEqual(ledger.creates, [])

    def test_dry_run_returns_paths_and_writes_nothing(self) -> None:
        ledger = MemoryLedgerStore(
            {"allocations/claims/1.0.27/app-store.json": {"schema": 1}}
        )
        created = reconcile(
            "ios",
            ledger=ledger,
            store_versions=[v("1.0.27"), v("1.0.28")],
            now=NOW,
            dry_run=True,
        )
        self.assertEqual(created, ["allocations/claims/1.0.28/app-store.json"])
        self.assertEqual(ledger.creates, [])

    def test_duplicate_store_versions_create_one_claim(self) -> None:
        ledger = MemoryLedgerStore()
        created = reconcile(
            "ios", ledger=ledger, store_versions=[v("1.0.27"), v("1.0.27")], now=NOW
        )
        self.assertEqual(len(created), 1)


class MapPlayVersionCodesTest(unittest.TestCase):
    def test_maps_through_allocation_and_provenance(self) -> None:
        ledger = MemoryLedgerStore(
            {
                "allocations/builds/android/200.json": {"version": "1.0.29"},
                "releases/android/1.0.28+190.json": {},
            }
        )
        self.assertEqual(
            map_play_version_codes(ledger, [200, 190]),
            {200: v("1.0.29"), 190: v("1.0.28")},
        )

    def test_allocation_without_version_falls_back_to_provenance(self) -> None:
        ledger = MemoryLedgerStore(
            {
                "allocations/builds/android/190.json": {},
                "releases/android/1.0.28+190.json": {},
            }
        )
        self.assertEqual(map_play_version_codes(ledger, [190]), {190: v("1.0.28")})

    def test_unmappable_codes_raise_one_error_naming_all(self) -> None:
        ledger = MemoryLedgerStore(
            {"allocations/builds/android/200.json": {"version": "1.0.29"}}
        )
        with self.assertRaises(AllocationError) as caught:
            map_play_version_codes(ledger, [200, 777, 888])
        message = str(caught.exception)
        self.assertIn("777", message)
        self.assertIn("888", message)
        self.assertNotIn("200", message)
        self.assertIn("allocations/builds/android/<code>.json", message)
        # releases/ is patch provenance; operators must not hand-write it.
        self.assertNotIn("releases/", message)

    def test_malformed_allocation_version_names_code_and_path(self) -> None:
        path = "allocations/builds/android/200.json"
        ledger = MemoryLedgerStore({path: {"version": "1.x"}})
        with self.assertRaises(AllocationError) as caught:
            map_play_version_codes(ledger, [200])
        message = str(caught.exception)
        self.assertIn("200", message)
        self.assertIn(path, message)
        self.assertIn("'1.x'", message)

    def test_non_ascii_digits_are_not_build_numbers(self) -> None:
        ledger = MemoryLedgerStore({"releases/android/1.0.28+\u0669.json": {}})
        with self.assertRaises(AllocationError):
            map_play_version_codes(ledger, [9])

    def test_non_string_allocation_version_is_an_error_naming_code_and_path(
        self,
    ) -> None:
        path = "allocations/builds/android/200.json"
        ledger = MemoryLedgerStore(
            {path: {"version": 120}, "releases/android/1.0.28+190.json": {}}
        )
        with self.assertRaises(AllocationError) as caught:
            map_play_version_codes(ledger, [190, 200])
        message = str(caught.exception)
        self.assertIn("200", message)
        self.assertIn(path, message)
        self.assertNotIn("190", message)


class _UnreadableStore(MemoryLedgerStore):
    def __init__(self, files, unreadable):
        super().__init__(files)
        self._unreadable = unreadable

    def read_json(self, path):
        if path == self._unreadable:
            raise LedgerError(f"HTTP 502 reading {path}")
        return super().read_json(path)


class FailClosedMappingTest(unittest.TestCase):
    def test_unreadable_allocation_does_not_fall_back_to_provenance(self) -> None:
        path = "allocations/builds/android/200.json"
        ledger = _UnreadableStore(
            {path: {"version": "1.0.29"}, "releases/android/1.0.28+200.json": {}},
            path,
        )
        with self.assertRaises((LedgerError, AllocationError)) as caught:
            map_play_version_codes(ledger, [200])
        self.assertIn("200", str(caught.exception))
        self.assertIn(path, str(caught.exception))

    def test_unreadable_allocation_without_provenance_is_not_unmappable(self) -> None:
        path = "allocations/builds/android/201.json"
        ledger = _UnreadableStore({path: {"version": "1.0.29"}}, path)
        with self.assertRaises((LedgerError, AllocationError)) as caught:
            reconcile("android", ledger=ledger, store_version_codes=[201], now=NOW)
        self.assertNotIn("cannot map", str(caught.exception))
        self.assertEqual(ledger.creates, [])

    def test_ambiguous_provenance_is_unmappable_naming_versions(self) -> None:
        ledger = MemoryLedgerStore(
            {
                "releases/android/1.0.28+190.json": {},
                "releases/android/1.0.29+190.json": {},
                "releases/android/1.0.30+190.json": {},
                "releases/android/1.0.27+180.json": {},
            }
        )
        with self.assertRaises(AllocationError) as caught:
            map_play_version_codes(ledger, [180, 190, 999])
        message = str(caught.exception)
        self.assertIn("ambiguous", message)
        for text in ("190", "1.0.28", "1.0.29", "1.0.30", "999"):
            self.assertIn(text, message)
        self.assertNotIn("180", message)

    def test_allocation_wins_over_provenance(self) -> None:
        ledger = MemoryLedgerStore(
            {
                "allocations/builds/android/200.json": {"version": "1.0.29"},
                "releases/android/1.0.28+200.json": {},
            }
        )
        self.assertEqual(map_play_version_codes(ledger, [200]), {200: v("1.0.29")})
        created = reconcile(
            "android", ledger=ledger, store_version_codes=[200], now=NOW
        )
        self.assertEqual(
            created, ["allocations/claims/1.0.29/play-production.json"]
        )
        self.assertEqual(ledger.creates, created)


class ClaimedVersionsTest(unittest.TestCase):
    def test_parses_versions_from_claim_paths_only(self) -> None:
        paths = frozenset(
            {
                "allocations/claims/1.0.27/app-store.json",
                "allocations/claims/1.0.29/play-production.json",
                "allocations/builds/ios/5.json",
            }
        )
        self.assertEqual(
            sorted(claimed_versions(paths)), [v("1.0.27"), v("1.0.29")]
        )


class DeriveVersionTest(unittest.TestCase):
    def test_derive_version_uses_next_patch_after_highest_claim(self) -> None:
        self.assertEqual(
            derive_version(v("1.0.28"), [v("1.0.27"), v("1.0.29")]), v("1.0.30")
        )

    def test_derive_version_respects_a_higher_pubspec_floor(self) -> None:
        self.assertEqual(derive_version(v("1.1.0"), [v("1.0.40")]), v("1.1.0"))

    def test_derive_version_without_claims_is_the_floor(self) -> None:
        self.assertEqual(derive_version(v("1.0.28"), []), v("1.0.28"))

    def test_derive_version_floor_equal_to_claim_bumps(self) -> None:
        self.assertEqual(derive_version(v("1.1.0"), [v("1.1.0")]), v("1.1.1"))

    def test_derive_version_uses_max_not_last_claim(self) -> None:
        self.assertEqual(
            derive_version(v("1.0.28"), [v("1.0.29"), v("1.0.27")]), v("1.0.30")
        )


SHA = "a" * 40
SCHED = f"scheduled/ios/{SHA}"


def reserve(ledger, key=SCHED, version="1.0.28", store_latest=906, shorebird=(), platform="ios", build_floor=0):
    return reserve_build_number(
        platform,
        v(version),
        ledger=ledger,
        source_sha=SHA,
        reservation_key=key,
        codemagic_build_id="cm-1",
        store_latest=store_latest,
        build_floor=build_floor,
        shorebird_versions=frozenset(shorebird),
        now=NOW,
    )


def reserved(n, version="1.0.28", key=SCHED, platform="ios"):
    return {
        reservation_path(platform, n): {"version": version, "reservation_key": key, "source_sha": SHA},
        key_path(platform, key, n): {"schema": 1},
    }


class RacingStore(MemoryLedgerStore):
    def __init__(self, files=None, race=None):
        super().__init__(files)
        self.race = race
        self.raced = False

    def create_json(self, path, record, message):
        if path == self.race and not self.raced:
            self.raced = True
            self.files[path] = {"winner": True}
            return False
        return super().create_json(path, record, message)


class ReserveBuildNumberTest(unittest.TestCase):
    def test_first_reservation_is_above_store_and_ledger(self) -> None:
        ledger = MemoryLedgerStore(
            {reservation_path("ios", 908): {"version": "1.0.27"},
             reservation_path("android", 990): {"version": "1.0.27"}}
        )
        self.assertEqual(reserve(ledger), (909, False))
        record = ledger.files[reservation_path("ios", 909)]
        self.assertEqual(
            record,
            {
                "schema": 1,
                "platform": "ios",
                "build_number": 909,
                "version": "1.0.28",
                "source_sha": SHA,
                "origin": "scheduled",
                "reservation_key": SCHED,
                "codemagic_build_id": "cm-1",
                "reserved_at": NOW.isoformat(),
            },
        )
        self.assertEqual(
            ledger.files[key_path("ios", SCHED, 909)],
            {"schema": 1, "reservation_key": SCHED, "build_number": 909},
        )

    def test_build_floor_sets_first_number_without_spending_a_retry(self):
        ledger = MemoryLedgerStore()
        self.assertEqual(reserve(ledger, build_floor=950), (950, False))
        self.assertEqual(reserve(ledger, build_floor=950), (950, True))
        self.assertEqual(reserve(ledger, build_floor=951), (951, False))

    def test_non_ascii_reservation_and_key_numbers_are_ignored(self):
        for path in (
            "allocations/builds/ios/٩٠٩.json",
            key_path("ios", SCHED, 0).replace("/0.json", "/٩٠٩.json"),
        ):
            with self.subTest(path=path):
                ledger = MemoryLedgerStore({path: {}})
                self.assertEqual(reserve(ledger), (907, False))

    def test_reuse_requires_the_recorded_source_and_key(self):
        for field, value in (("source_sha", "b" * 40), ("reservation_key", "manual/other")):
            with self.subTest(field=field):
                files = reserved(909)
                files[reservation_path("ios", 909)][field] = value
                ledger = MemoryLedgerStore(files)
                with self.assertRaisesRegex(AllocationError, "reservation.*mismatch"):
                    reserve(ledger)
                self.assertEqual([], ledger.creates)

    def test_store_latest_above_ledger_wins(self) -> None:
        ledger = MemoryLedgerStore({reservation_path("ios", 5): {}})
        self.assertEqual(reserve(ledger, store_latest=906), (907, False))

    def test_manual_origin(self) -> None:
        ledger = MemoryLedgerStore()
        reserve(ledger, key="manual/abc123")
        self.assertEqual(
            ledger.files[reservation_path("ios", 907)]["origin"], "manual"
        )

    def test_racing_reservation_takes_the_next_number(self) -> None:
        ledger = RacingStore(race=reservation_path("ios", 907))
        self.assertEqual(reserve(ledger), (908, False))
        self.assertEqual(ledger.files[reservation_path("ios", 907)], {"winner": True})
        self.assertIn(reservation_path("ios", 908), ledger.files)

    def test_exhausted_attempts_raise(self) -> None:
        ledger = MemoryLedgerStore()

        class Always(MemoryLedgerStore):
            def create_json(self, path, record, message):
                return False

        with self.assertRaisesRegex(AllocationError, "no free build number after 3"):
            reserve_build_number(
                "ios", v("1.0.28"), ledger=Always(), source_sha=SHA,
                reservation_key=SCHED, codemagic_build_id="c", store_latest=1,
                shorebird_versions=frozenset(), now=NOW, attempts=3,
            )
        del ledger

    def test_key_index_conflict_raises(self) -> None:
        class Conflict(MemoryLedgerStore):
            def create_json(self, path, record, message):
                if path.startswith("allocations/keys/"):
                    return False
                return super().create_json(path, record, message)

        with self.assertRaisesRegex(AllocationError, "allocations/keys/ios"):
            reserve(Conflict())

    def test_retry_reuses_an_unspent_reservation(self) -> None:
        ledger = MemoryLedgerStore(reserved(909))
        self.assertEqual(reserve(ledger), (909, True))
        self.assertEqual(ledger.creates, [])

    def test_retry_after_shorebird_release_reserves_a_new_number(self) -> None:
        ledger = MemoryLedgerStore(reserved(909))
        self.assertEqual(reserve(ledger, shorebird={"1.0.28+909"}), (910, False))

    def test_retry_after_provenance_reserves_a_new_number(self) -> None:
        files = reserved(909)
        files[provenance_path("ios", v("1.0.28"), 909)] = {}
        self.assertEqual(reserve(MemoryLedgerStore(files)), (910, False))

    def test_retry_after_store_upload_reserves_a_new_number(self) -> None:
        ledger = MemoryLedgerStore(reserved(909))
        self.assertEqual(reserve(ledger, store_latest=909), (910, False))

    def test_retry_after_the_train_moved_reserves_a_new_number(self) -> None:
        ledger = MemoryLedgerStore(reserved(909, version="1.0.27"))
        self.assertEqual(reserve(ledger), (910, False))

    def test_fresh_number_skips_a_pre_ledger_shorebird_release(self) -> None:
        ledger = MemoryLedgerStore()
        self.assertEqual(reserve(ledger, shorebird={"1.0.28+907"}), (908, False))
        self.assertNotIn(reservation_path("ios", 907), ledger.files)

    def test_fresh_number_skips_pre_ledger_provenance(self) -> None:
        ledger = MemoryLedgerStore(
            {provenance_path("ios", v("1.0.28"), 907): {}}
        )
        self.assertEqual(reserve(ledger), (908, False))

    def test_manual_builds_never_share_a_number_with_a_scheduled_build(self) -> None:
        ledger = MemoryLedgerStore()
        first = reserve(ledger)
        second = reserve(ledger, key="manual/run42")
        self.assertNotEqual(first[0], second[0])

    def test_key_prefix_does_not_match_a_longer_key(self) -> None:
        ledger = MemoryLedgerStore(reserved(909, key="manual/abcd"))
        self.assertEqual(reserve(ledger, key="manual/abc"), (910, False))

    def test_missing_reservation_for_an_indexed_key_fails_closed(self) -> None:
        ledger = MemoryLedgerStore({key_path("ios", SCHED, 909): {"schema": 1}})
        with self.assertRaises(LedgerError):
            reserve(ledger)
        self.assertEqual(ledger.creates, [])

    def test_retry_considers_the_latest_reservation_for_the_key(self) -> None:
        files = reserved(909)
        files.update(reserved(910))
        ledger = MemoryLedgerStore(files)
        self.assertEqual(reserve(ledger, shorebird={"1.0.28+909"}), (910, True))

    def test_reserve_validates_the_key(self) -> None:
        ledger = MemoryLedgerStore()
        with self.assertRaises(AllocationError):
            reserve(ledger, key=f"scheduled/ios/{'b' * 40}")
        self.assertEqual(ledger.creates, [])

    def test_reserve_rejects_a_malformed_sha_without_writing(self) -> None:
        ledger = MemoryLedgerStore()
        with self.assertRaises(AllocationError):
            reserve_build_number(
                "ios", v("1.0.28"), ledger=ledger, source_sha="",
                reservation_key="scheduled/ios/", codemagic_build_id="c",
                store_latest=1, shorebird_versions=frozenset(), now=NOW,
            )
        self.assertEqual(ledger.creates, [])

    def test_other_paths_are_ignored(self) -> None:
        ledger = MemoryLedgerStore(
            {
                "allocations/builds/ios/9999.txt": {},
                "allocations/builds/ios/abc.json": {},
                "allocations/builds/ios/12/13.json": {},
            }
        )
        self.assertEqual(reserve(ledger), (907, False))


class ValidateReservationKeyTest(unittest.TestCase):
    def test_accepts_manual_and_scheduled(self) -> None:
        validate_reservation_key("manual/Abc123", "ios", SHA)
        validate_reservation_key(SCHED, "ios", SHA)

    def test_scheduled_key_must_match_the_source_sha(self) -> None:
        with self.assertRaises(AllocationError):
            validate_reservation_key(f"scheduled/ios/{'b' * 40}", "ios", SHA)

    def test_scheduled_key_must_match_the_platform(self) -> None:
        with self.assertRaises(AllocationError):
            validate_reservation_key(SCHED, "android", SHA)

    def test_scheduled_sha_must_be_40_lowercase_hex(self) -> None:
        for sha in ("", "HEAD", "main", "a" * 39, "A" * 40, "a" * 41):
            with self.assertRaises(AllocationError, msg=sha):
                validate_reservation_key(f"scheduled/ios/{sha}", "ios", sha)

    def test_manual_keys_also_require_a_full_source_sha(self):
        for sha in ("", "HEAD", "a" * 39, "A" * 40, "a" * 41):
            with self.subTest(sha=sha):
                with self.assertRaises(AllocationError):
                    validate_reservation_key("manual/abc123", "ios", sha)

    def test_rejects_malformed_keys(self) -> None:
        for key in ("manual/", "manual/a/b", "manual/a-b", "other/x", "", "manual/x\n"):
            with self.assertRaises(AllocationError, msg=key):
                validate_reservation_key(key, "ios", SHA)


BOOT = {BOOTSTRAP_PATH: {"schema": 1}}


def run_allocate(ledger, platform="ios", **kw):
    args = dict(
        ledger=ledger,
        pubspec=v("1.0.28"),
        source_sha=SHA,
        reservation_key=f"scheduled/{platform}/{SHA}",
        codemagic_build_id="cm1",
        store_latest=0,
        shorebird_versions=frozenset(),
        stable_tags=[],
        now=NOW,
    )
    args.update(kw)
    return allocate(platform, **args)


class AllocateTest(unittest.TestCase):
    def test_allocate_refuses_an_unbootstrapped_ledger(self) -> None:
        ledger = MemoryLedgerStore()
        with self.assertRaisesRegex(AllocationError, "not bootstrapped"):
            run_allocate(ledger)
        self.assertEqual(ledger.creates, [])

    def test_allocate_validates_the_key_before_any_write(self) -> None:
        ledger = MemoryLedgerStore(dict(BOOT))
        with self.assertRaisesRegex(AllocationError, "invalid reservation key"):
            run_allocate(
                ledger,
                reservation_key="bogus/key",
                store_versions=[v("1.0.27")],
            )
        self.assertEqual(ledger.creates, [])

    def test_allocate_reconciles_before_deriving(self) -> None:
        ledger = MemoryLedgerStore(dict(BOOT))
        result = run_allocate(ledger, store_versions=[v("1.0.29")])
        self.assertEqual(result.version, v("1.0.30"))
        self.assertIn("allocations/claims/1.0.29/app-store.json", ledger.creates)
        self.assertEqual(result.release_version, "1.0.30+1")
        self.assertFalse(result.reused)

    def test_allocate_counts_stable_tags_as_claims(self) -> None:
        ledger = MemoryLedgerStore(dict(BOOT))
        result = run_allocate(ledger, stable_tags=[v("1.0.40")])
        self.assertEqual(result.version, v("1.0.41"))

    def test_manual_build_after_ios_ran_ahead_of_pubspec_gets_the_train_version(
        self,
    ) -> None:
        ledger = MemoryLedgerStore(
            {**BOOT, "allocations/claims/1.0.31/app-store.json": {}}
        )
        result = run_allocate(
            ledger, "android", reservation_key="manual/abc123", pubspec=v("1.0.28")
        )
        self.assertEqual(result.version, v("1.0.32"))

    def test_two_android_internal_builds_share_a_version_with_increasing_codes(
        self,
    ) -> None:
        ledger = MemoryLedgerStore(dict(BOOT))
        first = run_allocate(ledger, "android", reservation_key="manual/one")
        second = run_allocate(ledger, "android", reservation_key="manual/two")
        self.assertEqual(first.version, second.version)
        self.assertEqual(second.build_number, first.build_number + 1)

    def test_android_production_version_is_claimed_and_exceeded(self) -> None:
        ledger = MemoryLedgerStore(
            {**BOOT, "releases/android/1.0.50+300.json": {}}
        )
        result = run_allocate(
            ledger,
            "android",
            store_version_codes=[300],
            reservation_key="manual/abc",
        )
        self.assertEqual(result.version, v("1.0.51"))
        self.assertIn(
            "allocations/claims/1.0.50/play-production.json", ledger.creates
        )

    def test_android_unmappable_code_raises_before_reserving(self) -> None:
        ledger = MemoryLedgerStore(dict(BOOT))
        with self.assertRaises(AllocationError):
            run_allocate(
                ledger, "android", store_version_codes=[9], reservation_key="manual/a"
            )
        self.assertEqual(ledger.creates, [])

    def test_android_without_codes_skips_the_floor_check(self) -> None:
        ledger = MemoryLedgerStore(dict(BOOT))
        result = run_allocate(ledger, "android", reservation_key="manual/abc")
        self.assertEqual(result.version, v("1.0.28"))


class StaleViewStore(MemoryLedgerStore):
    """Loses the create race for one claim and keeps a stale paths() view."""

    def __init__(self, files, lost):
        super().__init__(files)
        self.lost = lost
        self.snapshot = frozenset(self.files)

    def paths(self):
        return self.snapshot

    def create_json(self, path, record, message):
        if path == self.lost:
            self.files[path] = record
            return False
        created = super().create_json(path, record, message)
        self.snapshot = self.snapshot | {path}
        return created


class IosFloorGuardTest(unittest.TestCase):
    def test_lost_race_claim_missing_from_view_stops_before_reserving(self):
        lost = "allocations/claims/1.0.50/app-store.json"
        ledger = StaleViewStore(dict(BOOT), lost)
        with self.assertRaisesRegex(AllocationError, "1.0.28.*1.0.50"):
            run_allocate(ledger, store_versions=iter([v("1.0.50")]))
        self.assertFalse([p for p in ledger.creates if p.startswith("allocations/builds/")])

    def test_lost_race_with_equal_submitted_version_stops_before_reserving(self):
        # Pending/rejected iOS submissions are permanently claimed by the
        # allocator, even though the later store preflight permits reuse.
        lost = "allocations/claims/1.0.50/app-store.json"
        ledger = StaleViewStore(dict(BOOT), lost)
        with self.assertRaisesRegex(AllocationError, "1.0.50.*1.0.50"):
            run_allocate(
                ledger, pubspec=v("1.0.50"), store_versions=[v("1.0.50")]
            )
        self.assertFalse([p for p in ledger.creates if p.startswith("allocations/builds/")])


class AndroidFloorGuardTest(unittest.TestCase):
    def test_lost_race_claim_missing_from_view_trips_the_floor_check(self) -> None:
        lost = "allocations/claims/1.0.50/play-production.json"
        ledger = StaleViewStore(
            {**BOOT, "releases/android/1.0.50+300.json": {}}, lost
        )
        with self.assertRaisesRegex(AllocationError, "1.0.50.*1.0.28|1.0.28.*1.0.50"):
            run_allocate(
                ledger,
                "android",
                store_version_codes=[300],
                reservation_key="manual/abc",
            )
        self.assertFalse(
            [p for p in ledger.creates if p.startswith("allocations/builds/")]
        )


    def test_derived_version_equal_to_highest_play_version_is_allowed(
        self,
    ) -> None:
        # Play accepts a higher code under the same versionName, so only a
        # version strictly below production trips the guard.
        lost = "allocations/claims/1.0.50/play-production.json"
        ledger = StaleViewStore(
            {**BOOT, "releases/android/1.0.50+300.json": {}}, lost
        )
        result = run_allocate(
            ledger,
            "android",
            pubspec=v("1.0.50"),
            store_version_codes=[300],
            reservation_key="manual/abc",
        )
        self.assertEqual(result.version, v("1.0.50"))


class BootstrapTest(unittest.TestCase):
    def test_bootstrap_dry_run_writes_nothing(self) -> None:
        ledger = MemoryLedgerStore()
        paths = bootstrap(
            ledger=ledger,
            ios_store_versions=[v("1.0.27")],
            android_version_codes=[],
            now=NOW,
            dry_run=True,
        )
        self.assertEqual(ledger.creates, [])
        self.assertEqual(
            paths, ["allocations/claims/1.0.27/app-store.json", BOOTSTRAP_PATH]
        )

    def test_lost_marker_race_is_not_reported_as_created(self):
        ledger = RacingStore(race=BOOTSTRAP_PATH)
        paths = bootstrap(ledger=ledger, ios_store_versions=[], android_version_codes=[], now=NOW, dry_run=False)
        self.assertEqual([], paths)
        self.assertEqual({"winner": True}, ledger.files[BOOTSTRAP_PATH])

    def test_bootstrap_reports_every_unmappable_identity(self) -> None:
        ledger = MemoryLedgerStore()
        with self.assertRaises(AllocationError) as caught:
            bootstrap(
                ledger=ledger,
                ios_store_versions=[v("1.0.27")],
                android_version_codes=[7, 8],
                now=NOW,
                dry_run=False,
            )
        self.assertIn("7", str(caught.exception))
        self.assertIn("8", str(caught.exception))
        self.assertEqual(ledger.creates, [])

    def test_bootstrap_writes_claims_then_the_marker(self) -> None:
        ledger = MemoryLedgerStore({"releases/android/1.0.26+190.json": {}})
        paths = bootstrap(
            ledger=ledger,
            ios_store_versions=[v("1.0.27")],
            android_version_codes=[190],
            now=NOW,
            dry_run=False,
        )
        self.assertEqual(ledger.creates[-1], BOOTSTRAP_PATH)
        self.assertEqual(paths, ledger.creates)
        self.assertEqual(
            ledger.files[BOOTSTRAP_PATH],
            {
                "schema": 1,
                "bootstrapped_at": NOW.isoformat(),
                "claims": [
                    "allocations/claims/1.0.26/play-production.json",
                    "allocations/claims/1.0.27/app-store.json",
                ],
            },
        )

    def test_bootstrap_marker_lists_only_this_runs_claims(self) -> None:
        old = "allocations/claims/1.0.20/app-store.json"
        ledger = MemoryLedgerStore({old: {}})
        paths = bootstrap(
            ledger=ledger,
            ios_store_versions=[v("1.0.20"), v("1.0.27")],
            android_version_codes=[],
            now=NOW,
            dry_run=False,
        )
        new = ["allocations/claims/1.0.27/app-store.json"]
        self.assertEqual(ledger.files[BOOTSTRAP_PATH]["claims"], new)
        self.assertEqual(paths, new + [BOOTSTRAP_PATH])
        self.assertEqual(ledger.creates[-1], BOOTSTRAP_PATH)

    def test_bootstrap_with_marker_present_repairs_claims_only(self) -> None:
        ledger = MemoryLedgerStore(dict(BOOT))
        paths = bootstrap(
            ledger=ledger,
            ios_store_versions=[v("1.0.27")],
            android_version_codes=[],
            now=NOW,
            dry_run=False,
        )
        self.assertEqual(paths, ["allocations/claims/1.0.27/app-store.json"])
        self.assertNotIn(BOOTSTRAP_PATH, ledger.creates)


if __name__ == "__main__":
    unittest.main()
