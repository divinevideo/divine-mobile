import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train_fakes import MemoryLedgerStore  # noqa: E402

from release_train.allocator import (  # noqa: E402
    AllocationError,
    claimed_versions,
    derive_version,
    map_play_version_codes,
    reconcile,
    reserve_build_number,
    validate_reservation_key,
)
from release_train.ledger import (  # noqa: E402
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

    def test_reconcile_repairs_a_claim_missing_beside_an_existing_allocation(
        self,
    ) -> None:
        ledger = MemoryLedgerStore(
            {"allocations/builds/ios/55.json": {"version": "1.0.29"}}
        )
        created = reconcile("ios", ledger=ledger, store_versions=[v("1.0.29")], now=NOW)
        self.assertEqual(created, ["allocations/claims/1.0.29/app-store.json"])

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


def reserve(ledger, key=SCHED, version="1.0.28", store_latest=906, shorebird=(), platform="ios"):
    return reserve_build_number(
        platform,
        v(version),
        ledger=ledger,
        source_sha=SHA,
        reservation_key=key,
        codemagic_build_id="cm-1",
        store_latest=store_latest,
        shorebird_versions=frozenset(shorebird),
        now=NOW,
    )


def reserved(n, version="1.0.28", key=SCHED, platform="ios"):
    return {
        reservation_path(platform, n): {"version": version, "reservation_key": key},
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

    def test_manual_builds_never_share_a_number_with_a_scheduled_build(self) -> None:
        ledger = MemoryLedgerStore()
        first = reserve(ledger)
        second = reserve(ledger, key="manual/run42")
        self.assertNotEqual(first[0], second[0])

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

    def test_rejects_malformed_keys(self) -> None:
        for key in ("manual/", "manual/a/b", "manual/a-b", "other/x", "", "manual/x\n"):
            with self.assertRaises(AllocationError, msg=key):
                validate_reservation_key(key, "ios", SHA)


if __name__ == "__main__":
    unittest.main()
