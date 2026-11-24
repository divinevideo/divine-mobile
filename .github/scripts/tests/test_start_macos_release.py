import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = ROOT / 'mobile/scripts'
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

SCRIPT = SCRIPTS_DIR / 'start_macos_release.py'
SHA = 'a' * 40
BUILD_ID = 'b' * 24
OTHER_ID = 'c' * 24


def load_driver():
    spec = importlib.util.spec_from_file_location('start_macos_release', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class StartMacosReleaseTest(unittest.TestCase):
    def setUp(self):
        self.driver = load_driver()
        self.env = {
            'CODEMAGIC_API_TOKEN': 'private-codemagic-token',
            'GH_TOKEN': 'private-gh-token',
            'PROVENANCE_TOKEN': 'private-provenance-token',
            'PUBLIC_PEOPLE_LIST_POLICY': '["example-excluded-list"]',
            'GITHUB_REPOSITORY': 'example/repo',
            'GITHUB_RUN_ID': '12345',
            'GITHUB_RUN_ATTEMPT': '1',
            'GITHUB_REF': 'refs/heads/main',
            'GITHUB_SHA': SHA,
            'GITHUB_WORKFLOW_SHA': SHA,
            'GITHUB_WORKFLOW_REF': 'example/repo/.github/workflows/macos_testflight_release.yml@refs/heads/main',
        }
        self.ci_ok = True
        self.existing_builds = []
        self.build_states = [
            {'status': 'building', 'app_store_connect_status': None, 'commit': {'hash': SHA}},
            {'status': 'finished', 'app_store_connect_status': 'processing', 'commit': {'hash': SHA}},
            {'status': 'finished', 'app_store_connect_status': 'finished', 'commit': {'hash': SHA}},
        ]
        self.group_vars = []
        self.posted_payloads = []
        self.clock = 0.0

    def _monotonic(self):
        self.clock += 5.0
        return self.clock

    def api(self, method, url, token, payload=None):
        if url.endswith('/git/ref/heads/main'):
            return {'object': {'sha': SHA}}
        if '/actions/workflows/mobile_ci.yaml/runs?' in url:
            if not self.ci_ok:
                return {'workflow_runs': []}
            return {
                'workflow_runs': [
                    {
                        'id': 99,
                        'head_sha': SHA,
                        'event': 'push',
                        'head_branch': 'main',
                        'status': 'completed',
                        'conclusion': 'success',
                    }
                ]
            }
        if '/check-runs?' in url:
            if not self.ci_ok:
                return {'check_runs': []}
            return {
                'check_runs': [
                    {
                        'name': 'Mobile CI',
                        'head_sha': SHA,
                        'status': 'completed',
                        'conclusion': 'success',
                        'app': {'slug': 'github-actions', 'id': 15368},
                        'details_url': 'https://github.com/example/repo/actions/runs/99/job/1',
                    }
                ]
            }
        if '/teams/' in url and '/builds?' in url:
            return {'data': self.existing_builds, 'cursor': None}
        if '/variable-groups' in url and url.endswith('/variable-groups?page_size=100&page=1'):
            return {'data': [{'id': 'grp1', 'name': 'store_release_credentials'}]}
        if '/variable-groups/grp1/variables' in url:
            if method == 'GET':
                return {'data': list(self.group_vars)}
            if method == 'POST':
                for v in payload['variables']:
                    self.group_vars.append({'id': f'v-{v["name"]}', 'name': v['name'], 'secure': payload['secure']})
                return {}
            if method == 'PATCH':
                return {}
        if method == 'POST' and url.endswith('/builds'):
            self.posted_payloads.append(payload)
            return {'data': {'id': BUILD_ID}}
        if method == 'GET' and url.endswith('/builds/' + BUILD_ID):
            state = self.build_states.pop(0) if len(self.build_states) > 1 else self.build_states[0]
            return {
                'data': {
                    'id': BUILD_ID,
                    'app_id': self.driver.APP_ID,
                    'workflow': {'id': 'macos-build'},
                    'branch': 'main',
                    'build_inputs': {'DEFAULT_ENV': self.env.get('NATIVE_DEFAULT_ENV', 'PRODUCTION')},
                    **state,
                }
            }
        raise AssertionError(f'Unexpected request: {method} {url}')

    def test_happy_path_refreshes_store_credentials_and_monitors_to_upload(self):
        selected = self.driver.run_release(
            self.env,
            request=self.api,
            checked_out_sha=SHA,
            sleep=lambda _: None,
            monotonic=self._monotonic,
        )
        self.assertEqual(selected, BUILD_ID)
        self.assertEqual(len(self.posted_payloads), 1)
        self.assertEqual(self.posted_payloads[0]['workflow_id'], 'macos-build')
        self.assertEqual(self.posted_payloads[0]['branch'], 'main')
        self.assertEqual(self.posted_payloads[0]['inputs'], {'DEFAULT_ENV': 'PRODUCTION'})
        stored_names = {v['name'] for v in self.group_vars}
        self.assertEqual(stored_names, {'PROVENANCE_TOKEN', 'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS'})

    def test_rejects_non_main_workflow_ref(self):
        self.env['GITHUB_WORKFLOW_REF'] = 'example/repo/.github/workflows/macos_testflight_release.yml@refs/heads/feature'
        with self.assertRaisesRegex(self.driver.ReleaseError, 'trusted main'):
            self.driver.run_release(self.env, request=self.api, checked_out_sha=SHA, sleep=lambda _: None)

    def test_rejects_missing_mobile_ci_pass(self):
        self.ci_ok = False
        with self.assertRaisesRegex(self.driver.ReleaseError, 'Mobile CI'):
            self.driver.run_release(self.env, request=self.api, checked_out_sha=SHA, sleep=lambda _: None)

    def test_rejects_invalid_default_env(self):
        self.env['NATIVE_DEFAULT_ENV'] = 'INVALID'
        with self.assertRaisesRegex(self.driver.ReleaseError, 'DEFAULT_ENV'):
            self.driver.run_release(self.env, request=self.api, checked_out_sha=SHA, sleep=lambda _: None)

    def test_blocks_when_another_macos_build_is_active(self):
        self.existing_builds = [
            {
                'id': OTHER_ID,
                'app_id': self.driver.APP_ID,
                'workflow': {'id': 'macos-build'},
                'branch': 'main',
                'status': 'building',
                'app_store_connect_status': None,
                'commit': {'hash': SHA},
                'labels': [],
            }
        ]
        with self.assertRaisesRegex(self.driver.ReleaseError, OTHER_ID):
            self.driver.run_release(self.env, request=self.api, checked_out_sha=SHA, sleep=lambda _: None)

    def test_fails_when_app_store_connect_upload_fails(self):
        self.build_states = [
            {'status': 'finished', 'app_store_connect_status': 'failed', 'commit': {'hash': SHA}},
        ]
        with self.assertRaisesRegex(self.driver.ReleaseError, 'failed'):
            self.driver.run_release(
                self.env,
                request=self.api,
                checked_out_sha=SHA,
                sleep=lambda _: None,
                monotonic=self._monotonic,
            )

    def test_parsed_workflow_matches_store_release_security_contract(self):
        path = ROOT / '.github/workflows/macos_testflight_release.yml'
        data = json.loads(
            subprocess.check_output(
                ['ruby', '-ryaml', '-rjson', '-e', 'print JSON.generate(YAML.load_file(ARGV[0]))', str(path)],
                text=True,
            )
        )
        trigger = data.get('on', data.get('true'))
        self.assertEqual(['workflow_dispatch'], list(trigger))
        self.assertEqual('store-release-train', data['concurrency']['group'])
        self.assertEqual(False, data['concurrency']['cancel-in-progress'])
        self.assertEqual({'contents': 'read', 'checks': 'read', 'actions': 'read'}, data['permissions'])
        job = data['jobs']['release']
        self.assertEqual('store-release', job['environment'])
        self.assertIn('refs/heads/main', job['if'])
        tokens = [s for s in job['steps'] if s.get('uses', '').startswith('actions/create-github-app-token@')]
        self.assertEqual(len(tokens), 1)
        self.assertEqual('divine-release-provenance', tokens[0]['with']['repositories'])
        self.assertTrue(tokens[0]['with']['skip-token-revoke'])
        step = job['steps'][-1]
        self.assertEqual('python3 mobile/scripts/start_macos_release.py', step['run'])
        self.assertEqual('${{ steps.provenance.outputs.token }}', step['env']['PROVENANCE_TOKEN'])
        self.assertEqual('${{ secrets.CODEMAGIC_API_TOKEN }}', step['env']['CODEMAGIC_API_TOKEN'])
        self.assertEqual(
            '${{ vars.DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS }}',
            step['env']['PUBLIC_PEOPLE_LIST_POLICY'],
        )


if __name__ == '__main__':
    unittest.main()
