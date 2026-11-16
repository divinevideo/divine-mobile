"""Release driver boundary tests; network calls are the only fake dependency."""
import base64
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / 'mobile/scripts/start_ios_release.py'
SHA = 'a' * 40
OTHER = 'b' * 40
BUILD_ID = '0123456789abcdef01234567'
APP_ID = '69370e59eac15e6c367b661b'
LABEL = 'github:example/repo:123:ios-testflight:' + SHA


def load_driver():
    spec = importlib.util.spec_from_file_location('start_ios_release', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def environment():
    return {'CODEMAGIC_API_TOKEN': 'private-codemagic-token', 'GH_TOKEN': 'private-gh-token',
            'GITHUB_REPOSITORY': 'example/repo', 'GITHUB_RUN_ID': '123',
            'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_REF': 'refs/heads/main',
            'GITHUB_SHA': SHA, 'GITHUB_WORKFLOW_SHA': SHA,
            'GITHUB_WORKFLOW_REF': 'example/repo/.github/workflows/ios_testflight_release.yml@refs/heads/main'}


def build(status='finished', asc='finished', commit=SHA, labels=None):
    return {'id': BUILD_ID, 'app_id': APP_ID, 'workflow': {'id': 'ios-build', 'source': 'yaml'},
            'status': status, 'index': 1, 'artifacts': [], 'labels': labels or [],
            'release_notes': [], 'created_at': '2026-11-16T00:00:00Z', 'priority': 0,
            'commit': {'hash': commit}, 'branch': 'main', 'tag': None,
            'app_store_connect_status': asc, 'instance_type': 'mac_mini_m2',
            'config': {}, 'remote_access_enabled': False,
            'build_inputs': {'DEFAULT_ENV': 'PRODUCTION', 'RELEASE_CHANNEL': 'BETA', 'PUBLISH_TO_GITHUB': 'NO'}}


class FakeAPI:
    def __init__(self, builds=None, polls=None, ci=True):
        self.builds = builds or []
        self.polls = list(polls or [build()])
        self.ci = ci
        self.calls = []
        self.pages = []
        self.source_config = (
            'workflows:\n  ios-build:\n    publishing:\n'
            '      app_store_connect:\n'
            '        submit_to_testflight: false\n'
            '        submit_to_app_store: false\n'
        )

    def __call__(self, method, url, token, payload=None):
        self.calls.append((method, url, token, payload))
        if '/git/ref/heads/main' in url:
            return {'object': {'sha': SHA}}
        if '/actions/workflows/mobile_ci.yaml/runs?' in url:
            return {'workflow_runs': [{'id': 1, 'head_sha': SHA, 'head_branch': 'main',
                                      'event': 'push', 'status': 'completed', 'conclusion': 'success'}] if self.ci else []}
        if '/check-runs?' in url:
            return {'check_runs': [{'name': 'Mobile CI', 'head_sha': SHA, 'status': 'completed',
                                   'conclusion': 'success', 'app': {'slug': 'github-actions', 'id': 15368},
                                   'details_url': 'https://github.com/example/repo/actions/runs/1/job/2'}]}
        if '/contents/codemagic.yaml?' in url:
            return {'encoding': 'base64', 'content': base64.b64encode(self.source_config.encode()).decode()}
        if '/teams/' in url:
            return self.pages.pop(0) if self.pages else {'data': self.builds, 'cursor': None, 'page_size': 100}
        if method == 'POST':
            return {'data': {'id': BUILD_ID}}
        if '/api/v3/builds/' in url:
            value = self.polls.pop(0) if len(self.polls) > 1 else self.polls[0]
            if isinstance(value, Exception):
                raise value
            return {'data': value}
        raise AssertionError('unexpected request: ' + url)

    @property
    def posts(self):
        return [c for c in self.calls if c[0] == 'POST']


class IOSReleaseTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.is_file(), "headless release driver is missing")
        self.driver = load_driver()
        self.env = environment()
        self.api = FakeAPI()
        self.output = io.StringIO()
        self.stdout = contextlib.redirect_stdout(self.output)
        self.stdout.__enter__()
        self.addCleanup(self.stdout.__exit__, None, None, None)

    def run_driver(self, **kwargs):
        return self.driver.run_release(self.env, request=self.api, checked_out_sha=SHA,
                                       sleep=lambda _: None, **kwargs)

    def test_missing_secret_rejects_before_network_or_mutation(self):
        del self.env['CODEMAGIC_API_TOKEN']
        with self.assertRaisesRegex(self.driver.ReleaseError, 'CODEMAGIC_API_TOKEN'):
            self.run_driver()
        self.assertEqual([], self.api.calls)

    def test_untrusted_workflow_or_checkout_never_submits(self):
        for field, value in [('GITHUB_REF', 'refs/heads/feature'),
                             ('GITHUB_WORKFLOW_REF', 'example/repo/.github/workflows/ios_testflight_release.yml@refs/heads/feature'),
                             ('GITHUB_WORKFLOW_SHA', OTHER), ('GITHUB_SHA', OTHER)]:
            with self.subTest(field=field):
                self.env = environment()
                self.env[field] = value
                with self.assertRaises(self.driver.ReleaseError):
                    self.run_driver()
                self.assertFalse(self.api.posts)

    def test_bad_or_stale_sha_never_submits(self):
        for value in ['abcd', 'A' * 40, OTHER, 'a' * 40 + '\n']:
            with self.subTest(value=value):
                self.env['SOURCE_SHA'] = value
                with self.assertRaises(self.driver.ReleaseError):
                    self.run_driver()
                self.assertFalse(self.api.posts)

    def test_missing_exact_main_ci_never_submits(self):
        self.api.ci = False
        with self.assertRaisesRegex(self.driver.ReleaseError, 'Mobile CI'):
            self.run_driver()
        self.assertFalse(self.api.posts)

    def test_wrong_or_skipped_check_never_submits(self):
        original = self.api
        for override in [{'head_sha': OTHER}, {'conclusion': 'skipped'},
                         {'app': {'slug': 'other-app'}},
                         {'details_url': 'https://github.com/example/repo/actions/runs/99/job/2'}]:
            def changed(method, url, token, payload=None):
                data = original(method, url, token, payload)
                if '/check-runs?' in url:
                    data['check_runs'][0].update(override)
                return data
            with self.subTest(override=override):
                with self.assertRaises(self.driver.ReleaseError):
                    self.driver.run_release(self.env, request=changed, checked_out_sha=SHA)
                self.assertFalse(original.posts)

    def test_exact_merge_queue_ci_is_accepted(self):
        original = self.api
        def queue_run(method, url, token, payload=None):
            data = original(method, url, token, payload)
            if '/actions/workflows/mobile_ci.yaml/runs?' in url:
                data['workflow_runs'][0].update(event='merge_group', head_branch='gh-readonly-queue/main/pr-123')
            return data
        self.driver.run_release(self.env, request=queue_run, checked_out_sha=SHA)
        self.assertEqual(1, len(self.api.posts))

    def test_feature_branch_push_or_wrong_check_app_id_is_rejected(self):
        original = self.api
        for target in ['workflow_runs', 'check_runs']:
            def bad_ci(method, url, token, payload=None):
                data = original(method, url, token, payload)
                if target == 'workflow_runs' and target in data:
                    data[target][0]['head_branch'] = 'feature'
                if target == 'check_runs' and target in data:
                    data[target][0]['app']['id'] = 999
                return data
            with self.subTest(target=target), self.assertRaises(self.driver.ReleaseError):
                self.driver.run_release(self.env, request=bad_ci, checked_out_sha=SHA)
            self.assertFalse(original.posts)

    def test_start_payload_and_real_outputs_identify_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.env['GITHUB_OUTPUT'] = str(Path(tmp) / 'output')
            self.env['GITHUB_STEP_SUMMARY'] = str(Path(tmp) / 'summary')
            self.run_driver()
            output = Path(self.env['GITHUB_OUTPUT']).read_text()
            summary = Path(self.env['GITHUB_STEP_SUMMARY']).read_text()
        self.assertIn('build_id=' + BUILD_ID, output)
        self.assertIn(SHA, summary)
        self.assertIn('App Store Connect processing finished', summary)
        self.assertNotIn('available to external testers', summary)
        method, url, token, payload = self.api.posts[0]
        self.assertEqual('https://codemagic.io/api/v3/apps/' + APP_ID + '/builds', url)
        self.assertEqual({'workflow_id': 'ios-build', 'branch': 'main',
                          'inputs': {'DEFAULT_ENV': 'PRODUCTION', 'RELEASE_CHANNEL': 'BETA', 'PUBLISH_TO_GITHUB': 'NO'},
                          'environment': {'variables': {'RELEASE_EXPECTED_SHA': SHA}},
                          'labels': [LABEL]}, payload)

    def test_active_manual_or_unknown_build_refuses_new_submission(self):
        for status in ['initializing', 'queued', 'waiting', 'preparing', 'fetching', 'testing',
                       'building', 'publishing', 'finishing', 'unexpected']:
            self.api = FakeAPI(builds=[build(status=status)])
            with self.subTest(status=status), self.assertRaises(self.driver.ReleaseError):
                self.run_driver()
            self.assertFalse(self.api.posts)

    def test_finished_build_still_processing_blocks_new_submission(self):
        self.api.builds = [build(asc='processing')]
        with self.assertRaises(self.driver.ReleaseError):
            self.run_driver()
        self.assertFalse(self.api.posts)

    def test_pending_store_processing_blocks_even_after_build_failure(self):
        for status in ['failed', 'canceled', 'timeout', 'skipped']:
            with self.subTest(status=status):
                self.api = FakeAPI(builds=[build(status=status, asc='processing')])
                with self.assertRaises(self.driver.ReleaseError):
                    self.run_driver()
                self.assertFalse(self.api.posts)

    def test_unreported_store_state_needs_verified_upload_only_source(self):
        for config in [
            self.api.source_config.replace('submit_to_testflight: false', 'submit_to_testflight: true'),
            self.api.source_config.replace('submit_to_app_store: false', 'submit_to_app_store: true'),
            self.api.source_config + '        beta_groups: [External]\n',
            'workflows: {}\n',
        ]:
            with self.subTest(config=config):
                self.api = FakeAPI(builds=[build(asc=None)])
                self.api.source_config = config
                with self.assertRaises(self.driver.ReleaseError):
                    self.run_driver()
                self.assertFalse(self.api.posts)

    def test_completed_historical_branch_or_nonpublished_build_does_not_block(self):
        historical = build(commit=OTHER, asc=None)
        historical['branch'] = 'old-feature'
        self.api.builds = [historical]
        self.api.source_config += '        beta_groups: []\n'
        self.run_driver()
        self.assertEqual(1, len(self.api.posts))

    def test_unreported_store_state_with_notes_or_missing_source_stays_blocked(self):
        for missing_source in [False, True]:
            with self.subTest(missing_source=missing_source):
                historical = build(asc=None)
                if missing_source:
                    historical['commit'] = None
                else:
                    historical['release_notes'] = [{'language': 'en-US', 'text': 'Try this build.'}]
                self.api = FakeAPI(builds=[historical])
                with self.assertRaises(self.driver.ReleaseError):
                    self.run_driver()
                self.assertFalse(self.api.posts)

    def test_same_run_reuses_build_without_post(self):
        self.api.builds = [build(labels=[LABEL])]
        self.run_driver()
        self.assertFalse(self.api.posts)

    def test_same_run_incompatible_commit_is_not_reused(self):
        self.api.builds = [build(commit=OTHER, labels=[LABEL])]
        with self.assertRaises(self.driver.ReleaseError):
            self.run_driver()
        self.assertFalse(self.api.posts)

    def test_retry_with_no_visible_build_fails_closed(self):
        self.env['GITHUB_RUN_ATTEMPT'] = '2'
        with self.assertRaisesRegex(self.driver.ReleaseError, 'reconcil'):
            self.run_driver()
        self.assertFalse(self.api.posts)

    def test_paginated_active_build_is_detected(self):
        self.api.pages = [{'data': [], 'cursor': 'opaque+cursor', 'page_size': 100},
                          {'data': [build(status='building')], 'cursor': None, 'page_size': 100}]
        with self.assertRaises(self.driver.ReleaseError):
            self.run_driver()
        self.assertTrue(any('cursor=opaque%2Bcursor' in c[1] for c in self.api.calls))
        self.assertFalse(self.api.posts)

    def test_eventual_404_and_commit_then_asc_processing_are_monitored(self):
        self.api.polls = [self.driver.APIError(404), build('fetching', None, None),
                          build(asc='processing'), build()]
        self.run_driver()
        self.assertEqual(1, len(self.api.posts))
        self.assertFalse(self.api.polls[:-1])

    def test_failed_unknown_wrong_identity_and_wrong_commit_fail(self):
        cases = [build(status=s) for s in ['failed', 'canceled', 'timeout', 'skipped', 'future-status']]
        cases += [build(asc=s) for s in ['failed', 'timeout', 'future-status']]
        cases += [build(commit=OTHER), build(commit=None)]
        for field, value in [('app_id', 'other'), ('workflow', {'id': 'other'}), ('branch', 'other')]:
            wrong = build()
            wrong[field] = value
            cases.append(wrong)
        for value in cases:
            self.api = FakeAPI(polls=[value])
            with self.subTest(value=value), self.assertRaises(self.driver.ReleaseError):
                self.run_driver()

    def test_monitor_timeout_is_failure_with_known_build_output(self):
        self.api.polls = [build(status='queued', asc=None, commit=None)]
        clock = iter([0, 0, 10])
        with self.assertRaisesRegex(self.driver.ReleaseError, 'Timed out'):
            self.run_driver(timeout=5, monotonic=lambda: next(clock))

    def test_ambiguous_post_is_never_retried_or_leaks_token(self):
        calls = []
        def failed(method, url, token, payload=None):
            calls.append(method)
            if method == 'POST':
                raise self.driver.APIError(None)
            return self.api(method, url, token, payload)
        with self.assertRaisesRegex(self.driver.ReleaseError, 'reconcil') as error:
            self.driver.run_release(self.env, request=failed, checked_out_sha=SHA)
        self.assertEqual(1, calls.count('POST'))
        self.assertNotIn(self.env['CODEMAGIC_API_TOKEN'], str(error.exception))

    def test_http_client_does_not_print_provider_body_or_credentials(self):
        for failure in [HTTPError('https://codemagic.io', 500, 'private-codemagic-token', {},
                                  io.BytesIO(b'private-codemagic-token')), URLError('private-codemagic-token')]:
            with patch('urllib.request.urlopen', side_effect=failure):
                with self.assertRaises(self.driver.APIError) as error:
                    self.driver.request_json('POST', 'https://codemagic.io/api/v3/apps/x/builds', 'secret', {})
            self.assertNotIn('private-codemagic-token', str(error.exception))
            if isinstance(failure, HTTPError):
                self.assertTrue(failure.fp.closed, 'HTTP error response must be closed')

    def test_parsed_workflow_is_manual_serial_and_checks_out_main_source(self):
        path = ROOT / '.github/workflows/ios_testflight_release.yml'
        data = json.loads(subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
            'print JSON.generate(YAML.load_file(ARGV[0]))', str(path)], text=True))
        trigger = data.get('on', data.get('true'))
        self.assertEqual(['workflow_dispatch'], list(trigger))
        self.assertEqual(False, data['concurrency']['cancel-in-progress'])
        self.assertEqual({'contents': 'read', 'checks': 'read', 'actions': 'read'}, data['permissions'])
        job = data['jobs']['release']
        self.assertGreaterEqual(job['timeout-minutes'], 90)
        checkout = next(step for step in job['steps'] if step.get('uses', '').startswith('actions/checkout@'))
        self.assertEqual('${{ github.sha }}', checkout['with']['ref'])
        self.assertEqual(False, checkout['with']['persist-credentials'])
        self.assertIn('refs/heads/main', job['if'])


if __name__ == '__main__':
    unittest.main()
