import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / 'mobile/scripts/write_concord_release_defines.rb'
KEY = 'CONCORD_INVITE_URL'
RELAY = 'CONCORD_RELAY_URL'
INVITE = json.loads((ROOT / 'mobile/packages/concord_protocol/test/fixtures/community-interop.json').read_text())['inviteUrl']
VALID_RELAY = 'wss://synthetic.divine.video/relay'


class ConcordReleaseDefinesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name) / 'defines.json'
        self.original = '{"DEFAULT_ENV":"PRODUCTION","EXISTING_TOKEN":"synthetic-private-value"}\n'
        self.output.write_text(self.original)
        self.output.chmod(0o600)

    def write(self, invite=None, required=False, relay=None):
        return subprocess.run(
            ['ruby', str(SCRIPT), '--output', str(self.output)] +
            (['--required'] if required else []),
            env={'PATH': os.environ['PATH'], KEY: invite or '', RELAY: relay or ''},
            text=True, capture_output=True, check=False)

    def test_absent_or_empty_optional_invite_does_not_change_define_shape(self):
        for value in [None, '']:
            result = self.write(value)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(self.original, self.output.read_text())
            self.assertNotIn(KEY, json.loads(self.output.read_text()))

    def test_invite_merges_privately_without_logging_values(self):
        invite = INVITE
        self.output.chmod(0o644)
        result = self.write(invite, relay=VALID_RELAY)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual({**json.loads(self.original), KEY: invite, RELAY: VALID_RELAY},
                         json.loads(self.output.read_text()))
        self.assertEqual(0o600, self.output.stat().st_mode & 0o777)
        self.assertNotIn('synthetic', result.stdout + result.stderr)

    def test_invalid_or_missing_pair_is_rejected_without_changing_file(self):
        for invite, relay in [(INVITE, None), (INVITE, 'https://synthetic.divine.video'),
                              ('https://synthetic.divine.video/invite/bad#bad', VALID_RELAY),
                              (INVITE.split('#')[0] + '#bad', VALID_RELAY),
                              (INVITE.replace('/invite/', '/wrong/'), VALID_RELAY),
                              (INVITE.replace('https://', 'http://'), VALID_RELAY)]:
            with self.subTest(invite=invite, relay=relay):
                result = self.write(invite, relay=relay)
                self.assertNotEqual(0, result.returncode)
                self.assertEqual(self.original, self.output.read_text())

    def test_required_invite_cannot_silently_disappear(self):
        for value in [None, '']:
            result = self.write(value, required=True)
            self.assertNotEqual(0, result.returncode)
            self.assertIn(KEY, result.stderr)
            self.assertEqual(self.original, self.output.read_text())
            self.assertNotIn('synthetic', result.stdout + result.stderr)

    def test_invalid_existing_file_is_preserved_without_logging_contents(self):
        for invalid in ['["synthetic-private-value"]', '{"synthetic-private-value":']:
            self.output.write_text(invalid)
            result = self.write(INVITE, relay=VALID_RELAY)
            self.assertNotEqual(0, result.returncode)
            self.assertEqual(invalid, self.output.read_text())
            self.assertNotIn('synthetic', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
