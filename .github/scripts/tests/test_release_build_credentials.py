"""Private provenance commands must not inherit the public publishing token."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


class ProvenanceCredentialsTest(unittest.TestCase):
    def test_coordinator_keeps_tag_token_out_of_native_environment(self):
        workflow = json.loads(subprocess.check_output([
            'ruby', '-ryaml', '-rjson', '-e', 'print JSON.generate(YAML.load_file(ARGV[0]))',
            str(ROOT / '.github/workflows/release_train.yml'),
        ], text=True))
        steps = workflow['jobs']['tick']['steps']
        tokens = {step['id']: step['with'] for step in steps
                  if step.get('uses', '').startswith('actions/create-github-app-token@')}
        self.assertEqual(tokens['provenance']['repositories'], 'divine-release-provenance')
        self.assertTrue(tokens['provenance']['skip-token-revoke'])
        self.assertEqual(tokens['candidate']['repositories'], 'divine-mobile')
        self.assertFalse(tokens['candidate']['skip-token-revoke'])
        env = steps[-1]['env']
        self.assertEqual(env['PROVENANCE_TOKEN'], '${{ steps.provenance.outputs.token }}')
        self.assertEqual(env['CANDIDATE_TAG_TOKEN'], '${{ steps.candidate.outputs.token }}')
        self.assertEqual(env['PUBLIC_PEOPLE_LIST_POLICY'], '${{ vars.DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS }}')

    def test_expiring_group_is_last_and_only_imported_by_store_and_distribution_workflows(self):
        groups = json.loads(subprocess.check_output([
            'ruby', '-ryaml', '-rjson', '-e',
            ('data=YAML.safe_load_file(ARGV[0], aliases: true); '
             'print JSON.generate(data.fetch("workflows").transform_values { |w| w.fetch("environment", {}).fetch("groups", []) })'),
            str(ROOT / 'codemagic.yaml'),
        ], text=True))
        selected = {name: values[-1] for name, values in groups.items()
                    if 'store_release_credentials' in values}
        self.assertEqual(selected, {'ios-build': 'store_release_credentials',
                                    'ios-scheduled-build': 'store_release_credentials',
                                    'android-build': 'store_release_credentials',
                                    'macos-build': 'store_release_credentials',
                                    'zapstore-publish': 'store_release_credentials'})

    def test_forwarded_policy_does_not_require_actions_variables_permission(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gh = root / 'gh'
            gh.write_text('#!/bin/sh\necho "Variables API forbidden" >&2\nexit 1\n')
            gh.chmod(0o755)
            output = root / 'defines.json'
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                       GH_TOKEN='contents-only-mobile-token',
                       DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS='["synthetic-list"]')
            result = subprocess.run([
                'python3', str(ROOT / 'mobile/scripts/write_public_people_list_defines.py'),
                '--output', str(output), '--github-repository', 'owner/repo',
            ], env=env, capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(output.read_text())['DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS'],
                             '["synthetic-list"]')

    def test_fetch_uses_private_token_instead_of_public_token(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gh = root / "gh"
            gh.write_text("""#!/usr/bin/env python3
import base64, json, os, sys
if os.environ.get('GH_TOKEN') != 'private-ledger-token':
    print('Bad credentials (HTTP 401)', file=sys.stderr)
    sys.exit(1)
if any(arg.endswith('/commits') for arg in sys.argv):
    print('1')
else:
    print(base64.b64encode(json.dumps({'schema': 1}).encode()).decode())
""")
            gh.chmod(0o755)
            output = root / "record.json"
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                       GH_TOKEN="public-release-token", GITHUB_TOKEN="public-release-token",
                       PROVENANCE_TOKEN="private-ledger-token")
            result = subprocess.run([
                "bash", str(ROOT / "mobile/scripts/shorebird_provenance_store.sh"),
                "fetch", "ios", "1.2.3+456", str(output),
            ], env=env, capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(output.read_text()), {"schema": 1})
            self.assertNotIn("private-ledger-token", result.stdout + result.stderr)
