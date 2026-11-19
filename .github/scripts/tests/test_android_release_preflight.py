"""Exercise the release workflow's evidence collector and real shared allocator."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from xml.etree import ElementTree

from release_train_fakes import MemoryLedgerStore

# isort: split
import allocate_build_identity
import release_identity
from release_train.ledger import BOOTSTRAP_PATH

SHA = 'a' * 40


class AndroidManifestTest(unittest.TestCase):
    def test_portrait_orientation_does_not_filter_play_devices(self):
        root = Path(__file__).resolve().parents[3]
        path = root / 'mobile/android/app/src/main/AndroidManifest.xml'
        manifest = ElementTree.parse(path).getroot()
        android = '{http://schemas.android.com/apk/res/android}'
        features = [
            feature.get(android + 'required')
            for feature in manifest.findall('uses-feature')
            if feature.get(android + 'name') == 'android.hardware.screen.portrait'
        ]
        self.assertEqual(features, ['false'])


class AndroidReleasePreflightTest(unittest.TestCase):
    def run_preflight(self, *, latest='500\n', counter='900', failure=None, scheduled=False):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / 'pubspec.yaml').write_text('name: openvine\nversion: 1.0.28+820\n')
        ledger = MemoryLedgerStore({BOOTSTRAP_PATH: {}, 'releases/android/1.0.31+500.json': {}})
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            if command[:2] == ['google-play', 'get-latest-build-number']:
                return subprocess.CompletedProcess(command, 1 if failure == 'latest' else 0, latest, 'private provider details')
            responses = {
                'shorebird': json.dumps({'status': 'success', 'data': {'releases': []}}),
                'git': (SHA + '\trefs/tags/1.0.30\n' if 'ls-remote' in command else SHA + '\n'),
                'google-play': json.dumps({'track': 'production', 'releases': [{'status': 'completed', 'versionCodes': ['500']}]}),
            }
            code = 1 if failure == command[0] else 0
            return subprocess.CompletedProcess(command, code, responses[command[0]], '')
        env = {'CM_BUILD_ID': 'a' * 24, 'PROJECT_BUILD_NUMBER': counter}
        if scheduled:
            env['RELEASE_TRAIN_RESERVATION_KEY'] = 'scheduled/android/' + SHA
        def identity(args):
            return release_identity.main(args, ledger_factory=lambda _: ledger)
        previous = Path.cwd()
        try:
            os.chdir(root)
            with patch.object(allocate_build_identity, 'identity_main', side_effect=identity):
                result = allocate_build_identity.allocate_build('android', env=env, run=run)
        finally:
            os.chdir(previous)
        output = root / 'build/shorebird/android_release.env'
        return result, output.read_text() if output.exists() else None, ledger, calls

    def test_play_lookup_failure_stops_before_allocation(self):
        with self.assertRaisesRegex(ValueError, 'could not read the latest Google Play build number'):
            self.run_preflight(failure='latest')

    def test_unreadable_or_non_ascii_play_number_fails_closed(self):
        for latest in ('No builds found\n', '', '٩٠٠\n', '-1\n'):
            with self.subTest(latest=latest), self.assertRaisesRegex(ValueError, 'refusing to guess'):
                self.run_preflight(latest=latest)

    def test_provider_evidence_failure_never_reaches_allocator(self):
        for provider in ('shorebird', 'git', 'google-play'):
            with self.subTest(provider=provider), self.assertRaisesRegex(ValueError, 'lookup failed'):
                self.run_preflight(failure=provider)

    def test_next_play_number_wins_and_marketing_version_uses_shared_claims(self):
        result, output, ledger, calls = self.run_preflight(latest='1000\n')
        self.assertEqual(result, 0)
        self.assertIn('SHOREBIRD_BUILD_NUMBER=1001\n', output)
        self.assertIn('SHOREBIRD_RELEASE_VERSION=1.0.32+1001\n', output)
        self.assertIn('RELEASE_SOURCE_SHA=' + SHA + '\n', output)
        self.assertIn('allocations/claims/1.0.31/play-production.json', ledger.creates)
        self.assertIn(['google-play', 'tracks', 'get', '--package-name', 'co.openvine.app', '--track', 'production', '--json'], calls)
        self.assertIn(['shorebird', 'releases', 'list', '--platform=android', '--json'], calls)

    def test_ci_counter_is_a_floor_not_upload_evidence(self):
        result, output, _, _ = self.run_preflight(latest='500\n', counter='900')
        self.assertEqual(result, 0)
        self.assertIn('SHOREBIRD_BUILD_NUMBER=900\n', output)
        self.assertIn('RELEASE_TRAIN_RESERVATION_KEY=manual/' + 'a' * 24 + '\n', output)

    def test_scheduled_build_uses_same_allocator_and_single_flight_owner(self):
        result, output, ledger, _ = self.run_preflight(scheduled=True)
        self.assertEqual(result, 0)
        self.assertIn('RELEASE_TRAIN_RESERVATION_KEY=scheduled/android/' + SHA + '\n', output)
        self.assertIn('allocations/owners/android/' + SHA + '/0.json', ledger.creates)


if __name__ == '__main__':
    unittest.main()
