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
)
from release_train.ledger import LedgerError  # noqa: E402
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


if __name__ == "__main__":
    unittest.main()
