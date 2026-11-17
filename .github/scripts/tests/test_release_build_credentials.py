"""Private provenance commands must not inherit the public publishing token."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


class ProvenanceCredentialsTest(unittest.TestCase):
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
            self.assertEqual(env["GH_TOKEN"], "public-release-token")
            self.assertNotIn("private-ledger-token", result.stdout + result.stderr)
