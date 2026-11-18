"""The native Android artifact retains one source-bound localized note bundle."""
import copy
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "mobile" / "scripts"))

import publish_play_bundle
from release_train.providers import DeferredReview, ProviderError
from release_train_fakes import TRANSLATED_SEARCH_NOTES, MemoryLedgerStore

SOURCE = 'a' * 40


def android_bundle():
    from release_train.release_notes import PLAY_LOCALES
    return {'schema': 1, 'platform': 'android', 'source_sha': SOURCE,
            'baseline': {'version': '1.0.0', 'sha': 'b' * 40}, 'locales': [],
            'testflight': [], 'app_store': [],
            'google_play': [{'language': lang, 'text': TRANSLATED_SEARCH_NOTES[lang]}
                            for lang in PLAY_LOCALES],
            'changes': [], 'policy_sha256': 'c' * 64}


class RecordingPlay:
    def __init__(self):
        self.calls = []
        self.deferred = False

    def upload(self, path, number, digest, *, notes=None):
        self.calls.append((path, number, digest, notes))
        if self.deferred:
            raise DeferredReview('Review in progress')


class PublishBundleTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        old = Path.cwd()
        os.chdir(self.directory.name)
        self.addCleanup(os.chdir, old)
        Path('build/shorebird').mkdir(parents=True)
        Path('build/shorebird/android_release.env').write_text(
            'SHOREBIRD_BUILD_NAME=1.0.1\nSHOREBIRD_BUILD_NUMBER=123\n'
            'SHOREBIRD_RELEASE_VERSION=1.0.1+123\nRELEASE_SOURCE_SHA=' + SOURCE + '\n')
        artifacts = Path('build/app/outputs/bundle/release')
        artifacts.mkdir(parents=True)
        (artifacts / 'app.aab').write_bytes(b'original signed artifact')
        self.ledger = MemoryLedgerStore()
        self.play = RecordingPlay()
        self.env = {'CM_BUILD_ID': 'synthetic-build', 'RELEASE_NOTES_BUNDLE': json.dumps(android_bundle())}
        self.sha_patch = patch.object(publish_play_bundle.subprocess, 'check_output', return_value=SOURCE)
        self.sha_patch.start()
        self.addCleanup(self.sha_patch.stop)

    def publish(self):
        publish_play_bundle.publish_bundle(self.env, ledger=self.ledger, play=self.play)

    def test_provider_failure_retains_private_diagnostic_with_original_artifact(self):
        from unittest.mock import Mock
        self.play.upload = Mock(side_effect=ProviderError(
            'Google Play internal track failed: HTTP 400',
            diagnostic={'code': 400, 'message': 'private provider detail'}))
        with self.assertRaises(ProviderError):
            self.publish()
        failure = self.ledger.files['uploads/android/123.json']
        self.assertEqual(failure['status'], 'failed')
        self.assertEqual(failure['diagnostic']['message'], 'private provider detail')
        self.assertEqual(failure['digest'], self.ledger.files['artifacts/android/123.json']['digest'])
        self.assertEqual(self.play.upload.call_count, 1)

    def test_native_upload_retains_complete_bundle_and_passes_every_locale(self):
        self.publish()
        bundle = json.loads(self.env['RELEASE_NOTES_BUNDLE'])
        self.assertEqual(self.ledger.files['artifacts/android/123.json'].get('release_notes'), bundle)
        self.assertEqual(self.play.calls[0][3], bundle['google_play'])
        self.assertEqual(self.ledger.files['uploads/android/123.json']['release_notes'], bundle)

    def test_different_source_or_missing_locale_fails_before_record_or_upload(self):
        for invalid in ['source', 'locale']:
            bundle = android_bundle()
            if invalid == 'source':
                bundle['source_sha'] = 'd' * 40
            else:
                bundle['google_play'].pop()
            self.env['RELEASE_NOTES_BUNDLE'] = json.dumps(bundle)
            with self.subTest(invalid=invalid), self.assertRaises(ProviderError):
                self.publish()
            self.assertFalse(self.ledger.creates)
            self.assertFalse(self.play.calls)

    def test_deferred_retry_uses_original_notes_even_after_new_baseline(self):
        original = android_bundle()
        self.play.deferred = True
        self.publish()
        updated = copy.deepcopy(original)
        updated['baseline'] = {'version': '1.0.1', 'sha': 'e' * 40}
        updated['google_play'][0]['text'] = 'Different release notes'
        self.env['RELEASE_NOTES_BUNDLE'] = json.dumps(updated)
        self.play.deferred = False
        self.publish()
        self.assertEqual([call[3] for call in self.play.calls], [original['google_play']] * 2)
        self.assertEqual(self.ledger.files['artifacts/android/123.json']['release_notes'], original)

    def test_legacy_retained_artifact_without_notes_stops_before_retry(self):
        self.publish()
        del self.ledger.files['artifacts/android/123.json']['release_notes']
        self.play.calls.clear()
        with self.assertRaises(ProviderError):
            self.publish()
        self.assertFalse(self.play.calls)
