"""Concurrency and publication identities stay safe across interrupted builds."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'mobile/scripts'))
import release_identity
from release_train import allocator
from release_train.ledger import reservation_path
from release_train.versions import Version
from release_train_fakes import MemoryLedgerStore

spec = importlib.util.spec_from_file_location('publisher_hardening', ROOT / 'mobile/scripts/publish_github_release.py')
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)
SHA = 'a' * 40
NOW = datetime(2026, 11, 17, tzinfo=timezone.utc)
KEY = 'scheduled/ios/' + SHA


class OwnershipTests(unittest.TestCase):
    def own(self, ledger, build='first', status=lambda _: 'building'):
        return allocator.claim_builder('ios', ledger=ledger, source_sha=SHA,
            reservation_key=KEY, codemagic_build_id=build, owner_status=status,
            now=NOW, sleep=lambda _: None)

    def test_active_owner_blocks_another_builder(self):
        ledger = MemoryLedgerStore()
        self.own(ledger)
        with self.assertRaisesRegex(allocator.AllocationError, 'active builder'):
            self.own(ledger, 'second')
        self.assertEqual(len(ledger.creates), 1)

    def test_terminal_owner_allows_atomic_retry_generation(self):
        ledger = MemoryLedgerStore()
        first = self.own(ledger)
        self.assertEqual(first, self.own(ledger))
        second = self.own(ledger, 'second', lambda _: 'failed')
        self.assertNotEqual(first, second)
        with self.assertRaisesRegex(allocator.AllocationError, 'active builder'):
            self.own(ledger, 'third')

    def test_unknown_owner_state_fails_closed(self):
        ledger = MemoryLedgerStore()
        self.own(ledger)
        with self.assertRaisesRegex(allocator.AllocationError, 'unknown'):
            self.own(ledger, 'second', lambda _: 'mystery')

    def test_racing_retry_cannot_reuse_a_winners_identity(self):
        ledger = MemoryLedgerStore()
        self.own(ledger)
        create = ledger.create_json
        def race(path, record, message):
            if '/1.json' in path:
                winner = dict(record, codemagic_build_id='winner')
                create(path, winner, message)
                return False
            return create(path, record, message)
        ledger.create_json = race
        with self.assertRaisesRegex(allocator.AllocationError, 'active builder'):
            self.own(ledger, 'loser', lambda owner: 'failed' if owner == 'first' else 'building')

    def test_allocation_rereads_conflicting_high_water_mark(self):
        class Race(MemoryLedgerStore):
            def create_json(self, path, record, message):
                if path == reservation_path('ios', 2):
                    self.files[reservation_path('ios', 20)] = {}
                    self.files[path] = {}
                    return False
                return super().create_json(path, record, message)
        ledger = Race()
        number, _ = allocator.reserve_build_number('ios', Version(1, 0, 1),
            ledger=ledger, source_sha=SHA, reservation_key='manual/one',
            codemagic_build_id='one', store_latest=1, shorebird_versions=frozenset(),
            now=NOW, sleep=lambda _: None)
        self.assertEqual(number, 21)


class OwnerProviderTests(unittest.TestCase):
    def test_owner_lookup_rejects_unrelated_workflow_or_source(self):
        import io
        build_id = "0" * 24
        for field, value in (("app_id", "different"), ("workflow", {"id": "android-build"}),
                             ("commit", {"hash": "b" * 40})):
            build = {"id": build_id, "app_id": "69370e59eac15e6c367b661b",
                     "workflow": {"id": "ios-build"}, "commit": {"hash": SHA}, "status": "failed"}
            build[field] = value
            response = io.BytesIO(json.dumps({"data": build}).encode())
            with patch.dict(release_identity.os.environ, {"CODEMAGIC_API_TOKEN": "secret-value"}), \
                 patch.object(release_identity.urllib.request, "urlopen", return_value=response):
                with self.assertRaisesRegex(allocator.AllocationError, "verify prior") as error:
                    release_identity.codemagic_owner_status(build_id, platform="ios", source_sha=SHA)
                self.assertNotIn("secret-value", str(error.exception))

    def test_owner_lookup_accepts_dedicated_scheduled_ios_workflow(self):
        import io
        build_id = "0" * 24
        build = {"id": build_id, "app_id": "69370e59eac15e6c367b661b",
                 "workflow": {"id": "ios-scheduled-build"}, "commit": {"hash": SHA}, "status": "failed"}
        response = io.BytesIO(json.dumps({"data": build}).encode())
        with patch.dict(release_identity.os.environ, {"CODEMAGIC_API_TOKEN": "secret-value"}), \
             patch.object(release_identity.urllib.request, "urlopen", return_value=response):
            self.assertEqual(release_identity.codemagic_owner_status(build_id, platform="ios", source_sha=SHA), "failed")

    def test_owner_lookup_accepts_failed_prefetch_without_commit(self):
        import io
        build_id = "0" * 24
        build = {"id": build_id, "app_id": "69370e59eac15e6c367b661b",
                 "workflow": {"id": "ios-build"}, "commit": None, "status": "failed"}
        response = io.BytesIO(json.dumps({"data": build}).encode())
        with patch.dict(release_identity.os.environ, {"CODEMAGIC_API_TOKEN": "secret-value"}), \
             patch.object(release_identity.urllib.request, "urlopen", return_value=response):
            self.assertEqual(release_identity.codemagic_owner_status(build_id, platform="ios", source_sha=SHA), "failed")


class DirectIdentityTests(unittest.TestCase):
    def test_macos_uses_shared_train_and_ci_build_number(self):
        from release_train.ledger import BOOTSTRAP_PATH
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text("version: 1.0.1+9\n")
            (root / "tags").write_text("refs/tags/1.0.88\n")
            ledger = MemoryLedgerStore({BOOTSTRAP_PATH: {}, "allocations/claims/1.0.90/app-store.json": {}})
            result = release_identity.main(["direct", "--pubspec", str(root / "pubspec.yaml"),
                "--stable-tags", str(root / "tags"), "--source-sha", SHA,
                "--build-number", "1234", "--output", str(root / "macos_release.env")],
                ledger_factory=lambda _: ledger, now=NOW)
            self.assertEqual(result, 0)
            text = (root / "macos_release.env").read_text()
            self.assertIn("SHOREBIRD_BUILD_NAME=1.0.91\n", text)
            self.assertIn("SHOREBIRD_BUILD_NUMBER=1234\n", text)
            self.assertIn("RELEASE_SOURCE_SHA=" + SHA + "\n", text)
            self.assertEqual(ledger.creates, [])

    def test_macos_fails_before_bootstrap(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text("version: 1.0.1+9\n")
            (root / "tags").write_text("")
            result = release_identity.main(["direct", "--pubspec", str(root / "pubspec.yaml"),
                "--stable-tags", str(root / "tags"), "--source-sha", SHA,
                "--build-number", "1234", "--output", str(root / "out.env")],
                ledger_factory=lambda _: MemoryLedgerStore(), now=NOW)
            self.assertEqual(result, 1)
            self.assertFalse((root / "out.env").exists())

    def test_stable_publication_records_immutable_channel_claim(self):
        ledger = MemoryLedgerStore()
        publisher.record_stable_claim(ledger, "1.2.99", SHA)
        self.assertEqual(ledger.creates, ["allocations/claims/1.2.99/github-stable.json"])
        publisher.record_stable_claim(ledger, "1.2.99", SHA)
        self.assertEqual(len(ledger.creates), 1)
        self.assertEqual(ledger.read_json(ledger.creates[0])["source_sha"], SHA)


class AtomicOutputTests(unittest.TestCase):
    def test_failed_replace_preserves_old_complete_output_and_removes_tempfile(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'release.env'
            path.write_text('previous complete identity\n')
            with patch.object(release_identity.os, 'replace', side_effect=OSError('disk error')):
                with self.assertRaises(OSError):
                    release_identity.atomic_write(path, 'new complete identity\n')
            self.assertEqual(path.read_text(), 'previous complete identity\n')
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_atomic_output_contains_complete_new_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'release.env'
            release_identity.atomic_write(path, 'complete\n')
            self.assertEqual(path.read_text(), 'complete\n')


class EffectiveVersionTests(unittest.TestCase):
    def test_effective_identity_uses_allocated_version_and_checks_source(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ios_release.env'
            path.write_text('SHOREBIRD_BUILD_NAME=1.2.99\nSHOREBIRD_BUILD_NUMBER=22\n'
                'SHOREBIRD_RELEASE_VERSION=1.2.99+22\nRELEASE_SOURCE_SHA=' + SHA + '\n')
            self.assertEqual(publisher.effective_version(path, SHA), '1.2.99')
            with self.assertRaisesRegex(ValueError, 'source'):
                publisher.effective_version(path, 'b' * 40)

    def test_effective_identity_rejects_inconsistent_or_executable_env(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'android_release.env'
            for text in ('SHOREBIRD_BUILD_NAME=$(secret)\n',
                         'SHOREBIRD_BUILD_NAME=1.2.99\nSHOREBIRD_BUILD_NUMBER=22\nSHOREBIRD_RELEASE_VERSION=1.2.98+22\n'):
                path.write_text(text)
                with self.assertRaises(ValueError):
                    publisher.effective_version(path, SHA)

    def test_new_publication_requires_effective_identity_and_selects_its_notes(self):
        with tempfile.TemporaryDirectory() as directory:
            mobile = Path(directory) / 'mobile'
            scripts = mobile / 'scripts'
            scripts.mkdir(parents=True)
            output = mobile / 'build/shorebird/ios_release.env'
            output.parent.mkdir(parents=True)
            output.write_text('SHOREBIRD_BUILD_NAME=1.2.99\nSHOREBIRD_BUILD_NUMBER=22\n'
                'SHOREBIRD_RELEASE_VERSION=1.2.99+22\nRELEASE_SOURCE_SHA=' + SHA + '\n')
            (mobile / 'pubspec.yaml').write_text('version: 1.0.0+1\n')
            with patch.object(publisher, '__file__', str(scripts / 'publish_github_release.py')), \
                 patch.object(sys, 'argv', ['publish', '--repo', 'owner/repo', '--release-env', str(output)]), \
                 patch.object(publisher, 'run', return_value=SHA), \
                 patch.object(publisher, 'publish', return_value='ok') as publish:
                publisher.main()
                self.assertEqual(publish.call_args.args[1], '1.2.99')
                self.assertEqual(publish.call_args.args[5], mobile.parent.resolve() / 'release-notes/1.2.99.md')

if __name__ == '__main__':
    unittest.main()
