"""Native iOS publishing consumes only notes for the exact built source."""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import release_train_fakes  # noqa: F401

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / 'mobile/scripts/prepare_testflight_notes.py'


def ios_bundle(source):
    return {
        'schema': 1, 'platform': 'ios', 'source_sha': source,
        'baseline': {'version': '1.0.0', 'sha': 'b' * 40},
        'locales': ['en-US', 'fr-FR'],
        'testflight': [{'language': 'en-US', 'text': 'Try saving a draft.'},
                       {'language': 'fr-FR', 'text': 'Essayez de sauvegarder un brouillon.'}],
        'app_store': [{'language': 'en-US', 'text': 'Your drafts stay close.'},
                      {'language': 'fr-FR', 'text': 'Vos brouillons restent à portée de main.'}],
        'google_play': [], 'changes': [], 'policy_sha256': 'c' * 64,
    }


class PrepareNotesTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.mobile = self.root / 'mobile'
        (self.mobile / 'build/shorebird').mkdir(parents=True)
        subprocess.run(['git', 'init', '--quiet', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.invalid', 'commit', '--quiet',
                        '--allow-empty', '-m', 'fixture'], check=True)
        self.source = subprocess.check_output(['git', '-C', str(self.root),
                                               'rev-parse', 'HEAD'], text=True).strip()
        (self.mobile / 'build/shorebird/ios_release.env').write_text(
            'SHOREBIRD_BUILD_NAME=1.0.1\nSHOREBIRD_BUILD_NUMBER=123\n'
            'SHOREBIRD_RELEASE_VERSION=1.0.1+123\nRELEASE_SOURCE_SHA=' + self.source + '\n')

    def run_script(self, bundle=None):
        env = dict(os.environ)
        env.pop('RELEASE_NOTES_BUNDLE', None)
        if bundle is not None:
            env['RELEASE_NOTES_BUNDLE'] = json.dumps(bundle)
        return subprocess.run(['python3', str(SCRIPT)], check=False, cwd=self.mobile, env=env,
                              text=True, capture_output=True)

    def test_missing_bundle_refuses_generic_or_old_version_fallback(self):
        old = self.root / 'release-notes'
        old.mkdir()
        (old / '1.0.1-testflight.json').write_text(json.dumps([
            {'language': 'en-US', 'text': 'Outdated reviewed version notes'}]))
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.mobile / 'release_notes.json').exists())

    def test_different_source_bundle_is_rejected_before_writing_notes(self):
        result = self.run_script(ios_bundle('d' * 40))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.mobile / 'release_notes.json').exists())

    def test_all_configured_localizations_are_preserved(self):
        bundle = ios_bundle(self.source)
        result = self.run_script(bundle)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.mobile / 'release_notes.json').read_text()),
                         bundle['testflight'])

    def test_missing_configured_localization_is_rejected(self):
        bundle = ios_bundle(self.source)
        bundle['testflight'].pop()
        result = self.run_script(bundle)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.mobile / 'release_notes.json').exists())
