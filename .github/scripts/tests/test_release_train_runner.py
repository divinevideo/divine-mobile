import copy
import json
import unittest

import release_train_fakes  # adds repository scripts to sys.path
from release_train.providers import ProviderError
from release_train.runner import execute_plan, reconcile_operations


class Store:
    def __init__(self):
        self.saves = []

    def save(self, state):
        self.saves.append(copy.deepcopy(state))


class Provider:
    def __init__(self, store):
        self.store = store
        self.calls = []

    def execute(self, action, state, snapshot):
        self.calls.append(action)
        assert self.store.saves[-1]["operations"][action["key"]]["status"] == "started"
        raise ProviderError("ambiguous")


class RunnerTest(unittest.TestCase):
    def test_credential_refresh_failure_does_not_consume_attempt_or_hold_queue(self):
        class PreparationFailure(Provider):
            def prepare_build(self, action, snapshot):
                raise ProviderError('credential storage unavailable')
        store = Store()
        provider = PreparationFailure(store)
        state = {}
        plan = {'actions': [{'kind': 'build', 'platform': 'ios', 'sha': 'a' * 40, 'attempt': 1}]}
        execute_plan(plan, state, {}, store, provider)
        self.assertFalse(state.get('operations'))
        self.assertFalse(state.get('attempts'))
        self.assertFalse(state.get('holds'))
        self.assertFalse(state.get('last_build_started'))
        self.assertFalse(provider.calls)
        self.assertIn('credential storage unavailable', plan['errors'][0])

    def test_intent_is_durable_before_call_and_ambiguous_is_not_retried(self):
        store = Store()
        provider = Provider(store)
        state = {}
        action = {"kind": "build", "platform": "ios", "sha": "a" * 40, "attempt": 1}
        execute_plan({"actions": [action]}, state, {}, store, provider)
        self.assertEqual(len(provider.calls), 1)
        execute_plan({"actions": [action]}, state, {}, store, provider)
        self.assertEqual(len(provider.calls), 1)
        self.assertTrue(state["holds"]["ios"])

    def test_build_start_reconciles_by_durable_label(self):
        state = {
            "operations": {
                "build:ios:" + ("a" * 40) + ":1": {
                    "status": "started",
                    "action": {
                        "kind": "build",
                        "platform": "ios",
                        "sha": "a" * 40,
                        "attempt": 1,
                    },
                }
            }
        }
        snapshot = {
            "cm": [
                {
                    "platform": "ios",
                    "sha": "a" * 40,
                    "attempt": 1,
                    "status": "finished",
                    "id": "123",
                }
            ]
        }
        reconcile_operations(state, snapshot)
        self.assertEqual(next(iter(state["operations"].values()))["status"], "done")
        self.assertEqual(state["attempts"]["ios"]["a" * 40]["status"], "finished")


class RuntimeBoundaryTest(unittest.TestCase):
    def test_missing_tag_token_fails_closed(self):
        from release_train.runner import Runtime

        with self.assertRaisesRegex(ProviderError, "candidate tag"):
            Runtime(
                {
                    "GITHUB_REPOSITORY": "owner/repo",
                    "GH_TOKEN": "public-token",
                    "PROVENANCE_TOKEN": "private-token",
                }
            )

    def test_candidate_tag_creation_uses_only_mobile_scoped_app_token(self):
        from release_train.providers import NotFound
        from release_train.runner import Runtime

        class GH:
            def __init__(self):
                self.calls = []

            def call(self, method, path, payload=None):
                self.calls.append((method, path, payload))
                if method == "GET":
                    raise NotFound("missing")
                return {}

        runtime = Runtime.__new__(Runtime)
        runtime.tags = GH()
        runtime.gh = GH()
        runtime.env = {"PROVENANCE_TOKEN": "private-ledger-token", "CANDIDATE_TAG_TOKEN": "mobile-release-token", "PUBLIC_PEOPLE_LIST_POLICY": "[]"}
        cm_calls = []

        def cm(method, path, payload=None):
            cm_calls.append((method, path, payload))
            if '/apps/' in path and '/variable-groups' in path:
                return {"data": [{"id": "g", "name": "store_release_credentials"}]}
            if '/variable-groups/' in path:
                return {"data": [{"id": 'id-' + name, "name": name, "secure": True, "value": None}
                                  for name in ['PROVENANCE_TOKEN', 'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS']]} if method == 'GET' else {}
            return {"data": {"id": "123"}}

        runtime.cm = cm
        from unittest.mock import patch

        from release_train_fakes import MemoryLedgerStore, release_notes_bundle
        runtime.ledger = MemoryLedgerStore()
        runtime.env['OPENAI_API_KEY'] = 'model-secret-must-stay-in-github'
        action = {"kind": "build", "platform": "ios", "sha": "a" * 40, "attempt": 1}
        with patch('release_train.release_notes.ensure_bundle', return_value=release_notes_bundle()):
            runtime.prepare_build(action, {})
        runtime.execute(action, {}, {})
        self.assertEqual(len(runtime.tags.calls), 2)
        self.assertFalse(runtime.gh.calls)
        patches = [c for c in cm_calls if c[0] == 'PATCH']
        self.assertEqual({c[1].rsplit('/', 1)[-1].removeprefix('id-'): c[2] for c in patches}, {
            'PROVENANCE_TOKEN': {'value': 'private-ledger-token', 'secure': True},
            'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS': {'value': '[]', 'secure': True},
        })
        build_call = next(c for c in cm_calls if c[0] == 'POST')
        self.assertLess(cm_calls.index(patches[-1]), cm_calls.index(build_call))
        self.assertNotIn('private-ledger-token', str(build_call))
        self.assertNotIn('mobile-release-token', str(cm_calls))
        self.assertNotIn('model-secret-must-stay-in-github', str(cm_calls))
        variables = build_call[2]['environment']['variables']
        forwarded = json.loads(variables['RELEASE_NOTES_BUNDLE'])
        self.assertEqual(forwarded['source_sha'], 'a' * 40)
        self.assertEqual(forwarded['testflight'], [{'language': 'en-US', 'text': 'Try recording a loop.'}])


class AuditTest(unittest.TestCase):
    def test_incomplete_android_observations_do_not_publish_null_deployment_refs(self):
        from release_train.runner import Runtime

        class GH:
            def __init__(self):
                self.calls = []
            def pages(self, path):
                return []
            def call(self, method, path, payload=None):
                self.calls.append((method, path, payload))
                if path == '/deployments':
                    if not payload.get('ref'):
                        raise ProviderError('invalid null deployment ref')
                    return {'id': len(self.calls)}
                return {}

        runtime = Runtime.__new__(Runtime)
        runtime.gh = GH()
        complete = {'number': 10, 'version': '1.0.31', 'sha': 'a' * 40}
        incomplete = complete | {'number': 11, 'sha': None, 'provenance_incomplete': True}
        runtime.audit_observations({'android': {
            'internal': [incomplete, complete], 'production': [incomplete, complete],
        }}, {})
        writes = [payload for _, path, payload in runtime.gh.calls if path == '/deployments']
        self.assertEqual(len(writes), 2)
        self.assertTrue(all(payload['ref'] == 'a' * 40 for payload in writes))

    def test_public_deployment_payload_is_allowlisted_and_existing_reused(self):
        from release_train.runner import Runtime

        class GH:
            def __init__(self):
                self.calls = []

            def pages(self, path):
                return []

            def call(self, method, path, payload=None):
                self.calls.append((method, path, payload))
                return {"id": 42}

        runtime = Runtime.__new__(Runtime)
        runtime.gh = GH()
        state = {}
        build = {
            "number": 10,
            "version": "1.0.31",
            "sha": "a" * 40,
            "id": "store",
            "digest": "a" * 64,
            "url": "private",
            "build_id": "private",
        }
        runtime.deploy("ios-testflight-public", build, "success", state)
        runtime.deploy("ios-testflight-public", build, "success", state)
        created = [c for c in runtime.gh.calls if c[1] == "/deployments"]
        self.assertEqual(len(created), 1)
        self.assertEqual(
            set(created[0][2]["payload"]), {"number", "version", "sha", "id"}
        )


class RetryIdentityTest(unittest.TestCase):
    def test_different_spent_android_identities_on_same_source_do_not_collide(self):
        from release_train.runner import operation_key

        one = {
            "kind": "retry-android-upload",
            "platform": "android",
            "sha": "a" * 40,
            "number": 10,
        }
        two = one | {"number": 11}
        self.assertNotEqual(operation_key(one), operation_key(two))

    def test_deferred_digest_is_checked_before_upload(self):
        from release_train.runner import Runtime

        class Ledger:
            def read_json(self, path):
                return record

        class Play:
            def upload(self, *args):
                raise AssertionError("mismatched bytes must not be uploaded")

        runtime = Runtime.__new__(Runtime)
        runtime.ledger = Ledger()
        runtime.play = Play()
        record = {
            "number": 10,
            "version": "1.0.31",
            "sha": "a" * 40,
            "digest": "a" * 64,
            "build_id": "123",
            "artifact_name": "app.aab",
            "release_notes": release_train_fakes.release_notes_bundle('android'),
        }
        runtime.cm = lambda *args: {
            "data": {
                "commit": {"hash": "a" * 40},
                "artifacts": [{"name": "app.aab", "url": "private"}],
            }
        }
        runtime.download = lambda url, path: path.write_bytes(b"tampered")
        with self.assertRaisesRegex(ProviderError, "digest"):
            runtime.execute(
                record | {"kind": "retry-android-upload", "platform": "android"}, {}, {}
            )


if __name__ == "__main__":
    unittest.main()


class HistoricalBuildTest(unittest.TestCase):
    def test_allocated_build_without_completed_provenance_is_not_promotable(self):
        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore

        runtime = Runtime.__new__(Runtime)
        runtime.ledger = MemoryLedgerStore({'allocations/builds/ios/999.json': {
            'version': '1.0.31', 'source_sha': 'a' * 40,
            'reservation_key': 'manual/first',
        }})
        incomplete = runtime.identity('ios', 999, '1.0.31')
        self.assertIsNone(incomplete['sha'])
        self.assertTrue(incomplete['legacy'])
        self.assertTrue(incomplete['provenance_incomplete'])
        runtime.ledger.files['releases/ios/1.0.31+999.json'] = {
            'platform': 'ios', 'release_version': '1.0.31+999',
            'build_source_commit': 'a' * 40, 'patchable': True,
        }
        self.assertEqual(runtime.identity('ios', 999, '1.0.31')['sha'], 'a' * 40)
        runtime.ledger.files['releases/ios/1.0.31+999.json']['build_source_commit'] = 'b' * 40
        with self.assertRaisesRegex(ProviderError, 'completed provenance'):
            runtime.identity('ios', 999, '1.0.31')

    def test_pre_provenance_ios_builds_are_observation_only(self):
        from release_train.runner import Runtime

        class Ledger:
            def paths(self):
                return frozenset({"releases/ios/1.0.30+900.json"})

        runtime = Runtime.__new__(Runtime)
        runtime.ledger = Ledger()
        old = runtime.identity("ios", 100, "1.0.1", allow_historical=True)
        self.assertTrue(old["legacy"])
        self.assertIsNone(old["sha"])
        with self.assertRaises(ProviderError):
            runtime.identity("ios", 901, "1.0.31", allow_historical=True)


class MissingRetainedArtifactTest(unittest.TestCase):
    def test_missing_retained_artifact_stops_queue_without_rebuild(self):
        from release_train.runner import Runtime

        record = {
            "number": 10,
            "version": "1.0.31",
            "sha": "a" * 40,
            "digest": "a" * 64,
            "build_id": "123",
            "artifact_name": "app.aab",
            "release_notes": release_train_fakes.release_notes_bundle('android'),
        }

        class Ledger:
            def read_json(self, path):
                return record

        runtime = Runtime.__new__(Runtime)
        runtime.ledger = Ledger()
        runtime.cm = lambda *args: {
            "data": {"commit": {"hash": "a" * 40}, "artifacts": []}
        }
        with self.assertRaisesRegex(ProviderError, "missing"):
            runtime.execute(
                record | {"kind": "retry-android-upload", "platform": "android"}, {}, {}
            )


class ReleaseNotesConsumerTest(unittest.TestCase):
    def test_note_generation_failure_does_not_spend_build_attempt(self):
        from unittest.mock import patch

        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore

        runtime = Runtime.__new__(Runtime)
        runtime.env = {'PROVENANCE_TOKEN': 'private', 'PUBLIC_PEOPLE_LIST_POLICY': '[]'}
        runtime.ledger = MemoryLedgerStore()
        runtime.cm = lambda *args: (_ for _ in ()).throw(AssertionError('No Codemagic call before notes'))
        state = {}
        plan = {'actions': [{'kind': 'build', 'platform': 'ios', 'sha': 'a' * 40, 'attempt': 1}]}
        with patch('release_train.release_notes.ensure_bundle', side_effect=ProviderError('Notes unavailable')):
            execute_plan(plan, state, {}, Store(), runtime)
        self.assertFalse(state.get('operations'))
        self.assertFalse(state.get('attempts'))
        self.assertFalse(state.get('holds'))
        self.assertIn('Notes unavailable', plan['errors'][0])

    def test_public_beta_uses_source_bundle_without_git_log_copy(self):
        from unittest.mock import patch

        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle

        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.ledger = MemoryLedgerStore()
        submitted = []
        class Apple:
            def submit_beta(self, build, notes):
                submitted.append((build, notes))
        runtime.apple = Apple()
        runtime.deploy = lambda *args: None
        build = {'id': '10', 'sha': 'a' * 40, 'number': 10}
        bundle = release_notes_bundle()
        with patch('release_train.release_notes.ensure_bundle', return_value=bundle) as ensure, patch('release_train.runner.subprocess.check_output', side_effect=AssertionError('Raw git titles must not become release copy')):
            action = {'kind': 'public-beta', 'platform': 'ios', 'build': build}
            snapshot = {'ios': {'builds': []}}
            runtime.prepare_action(action, snapshot)
            runtime.execute(action, {}, snapshot)
        self.assertEqual(submitted[0][1], [{'language': 'en-US', 'text': 'Try recording a loop.'}])
        self.assertEqual(ensure.call_args.args[:2], ('ios', 'a' * 40))

    def test_android_retry_keeps_retained_bundle_when_production_changes(self):
        import hashlib
        from unittest.mock import patch

        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle

        bundle = release_notes_bundle('android')
        record = {'number': 10, 'version': '1.0.31', 'sha': 'a' * 40,
                  'digest': hashlib.sha256(b'original signed aab').hexdigest(),
                  'build_id': '123', 'artifact_name': 'app.aab', 'release_notes': bundle}
        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.ledger = MemoryLedgerStore({'artifacts/android/10.json': record})
        runtime.cm = lambda *args: {'data': {'commit': {'hash': 'a' * 40}, 'artifacts': [{'name': 'app.aab', 'url': 'private'}]}}
        runtime.download = lambda url, path: path.write_bytes(b'original signed aab')
        uploaded = []
        class Play:
            def upload(self, path, number, digest, *, notes):
                uploaded.append((number, notes))
        runtime.play = Play()
        with patch('release_train.release_notes.ensure_bundle', side_effect=AssertionError('Retained notes must not regenerate')):
            runtime.execute(record | {'kind': 'retry-android-upload', 'platform': 'android'}, {}, {'android': {'production': [{'number': 11, 'sha': 'd' * 40}]}})
        self.assertEqual(uploaded, [(10, bundle['google_play'])])

    def test_android_retry_rejects_notes_from_other_source_before_upload(self):
        import hashlib

        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle

        record = {'number': 10, 'version': '1.0.31', 'sha': 'a' * 40,
                  'digest': hashlib.sha256(b'original signed aab').hexdigest(),
                  'build_id': '123', 'artifact_name': 'app.aab',
                  'release_notes': release_notes_bundle('android', 'd' * 40)}
        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.ledger = MemoryLedgerStore({'artifacts/android/10.json': record})
        runtime.cm = lambda *args: {'data': {'commit': {'hash': 'a' * 40}, 'artifacts': [{'name': 'app.aab', 'url': 'private'}]}}
        runtime.download = lambda url, path: (_ for _ in ()).throw(AssertionError('Wrong-source notes must fail first'))
        with self.assertRaises(ProviderError):
            runtime.execute(record | {'kind': 'retry-android-upload', 'platform': 'android'}, {}, {})

    def test_promotion_reuses_source_notes_after_live_baseline_advances(self):
        from unittest.mock import patch

        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle
        bundle = release_notes_bundle('android')
        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        from release_train.release_notes import policy_digest
        bundle['policy_sha256'] = policy_digest()
        runtime.ledger = MemoryLedgerStore({'release-notes/android/' + 'a' * 40 + '/' + 'b' * 40 + '-' + policy_digest() + '.json': bundle})
        promoted = []
        class Play:
            def promote(self, number, *, notes):
                promoted.append((number, notes))
        runtime.play = Play()
        runtime.claim = lambda *args: None
        runtime.deploy = lambda *args: None
        with patch('release_train.release_notes.production_baseline', side_effect=AssertionError('Original bundle must survive newer production')):
            action = {'kind': 'play-production', 'platform': 'android', 'build': {'number': 10, 'sha': 'a' * 40}}
            snapshot = {'now': 123, 'android': {'production': [{'number': 11, 'sha': 'd' * 40}]}}
            runtime.prepare_action(action, snapshot)
            runtime.execute(action, {}, snapshot)
        self.assertEqual(promoted, [(10, bundle['google_play'])])

class SnapshotChangesTest(unittest.TestCase):
    def test_existing_build_baselines_still_detect_app_changes(self):
        from unittest.mock import patch

        from release_train.runner import Runtime

        runtime = Runtime.__new__(Runtime)
        runtime.list_builds = list
        runtime.candidate = lambda: 'b' * 40
        state = {'last_built_source': {'ios': 'a' * 40, 'android': 'a' * 40}}
        with patch('release_train.runner.subprocess.check_output', return_value='mobile/lib/main.dart\n'):
            snapshot = runtime.snapshot(state, {'ios': 'off', 'android': 'off'})
        self.assertEqual(snapshot['changes'], {'ios': True, 'android': True})


class StoreAuthorizationRefreshTest(unittest.TestCase):
    def test_apple_mutations_refresh_authorization_after_note_generation(self):
        from unittest.mock import patch

        from release_train.providers import Apple
        from release_train.runner import Runtime
        from release_train_fakes import release_notes_bundle

        for kind in ['public-beta', 'app-store']:
            with self.subTest(kind=kind):
                clock = {'now': 0}
                requests = []

                def http(method, url, headers=None, body=None, *, clock=clock, requests=requests):
                    # The snapshot token was minted at t=0 and expires at t=1190.
                    if clock['now'] > 1190 and headers['Authorization'] != 'Bearer fresh-apple':
                        raise ProviderError('Apple authorization expired before store mutation')
                    requests.append((method, url, body))
                    if url.endswith(('/betaBuildLocalizations', '/appStoreVersionLocalizations')):
                        return {'data': [{'id': 'english', 'attributes': {'locale': 'en-US'}}]}
                    return {'data': None if method == 'GET' else {'id': 'review'}}

                runtime = Runtime.__new__(Runtime)
                runtime.env = {}
                runtime.apple = Apple('snapshot-apple', 'primary-group', request=http)
                runtime.apple.groups = ['primary-group', 'secondary-group']
                original_client = runtime.apple
                runtime.claim = lambda *args: None
                runtime.deploy = lambda *args: None
                bundle = release_notes_bundle()

                def generate(*args, clock=clock, bundle=bundle):
                    clock['now'] = 1200
                    return bundle

                def fresh_token(env, clock=clock):
                    self.assertEqual(clock['now'], 1200)
                    return 'fresh-apple'

                runtime.release_bundle = generate
                build = {'id': '10', 'number': 10, 'version': '1.0.31', 'sha': 'a' * 40,
                         'external': 'BETA_APPROVED', 'groups': ['primary-group']}
                snapshot = {'now': 1200, 'ios': {'versions': [
                    {'id': 'v', 'version': '1.0.31', 'state': 'PREPARE_FOR_SUBMISSION'}]}}
                with patch('release_train.runner.apple_token', side_effect=fresh_token):
                    action = {'kind': kind, 'platform': 'ios', 'build': build}
                    runtime.prepare_action(action, snapshot)
                    runtime.execute(action, {}, snapshot)
                self.assertIs(runtime.apple, original_client)
                self.assertIs(runtime.apple.request, http)
                self.assertEqual(runtime.apple.groups, ['primary-group', 'secondary-group'])
                self.assertTrue(any(method != 'GET' for method, _, _ in requests))
                if kind == 'public-beta':
                    self.assertTrue(any('/betaGroups/secondary-group/' in url for _, url, _ in requests))

    def test_play_promotion_refreshes_authorization_after_note_generation(self):
        from unittest.mock import patch

        from release_train.providers import Play
        from release_train.runner import Runtime
        from release_train_fakes import release_notes_bundle

        clock = {'now': 0}
        requests = []

        def http(method, url, headers=None, body=None):
            if clock['now'] > 3500 and headers['Authorization'] != 'Bearer fresh-play':
                raise ProviderError('Play authorization expired before store mutation')
            requests.append((method, url, body))
            return {'id': 'edit'}

        runtime = Runtime.__new__(Runtime)
        runtime.env = {'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': 'protected-credentials'}
        runtime.play = Play('snapshot-play', request=http)
        original_client = runtime.play
        runtime.claim = lambda *args: None
        runtime.deploy = lambda *args: None
        bundle = release_notes_bundle('android')

        def generate(*args):
            clock['now'] = 3600
            return bundle

        def fresh_token(credentials):
            self.assertEqual(credentials, 'protected-credentials')
            self.assertEqual(clock['now'], 3600)
            return 'fresh-play'

        runtime.release_bundle = generate
        with patch('release_train.runner.play_token', side_effect=fresh_token):
            action = {'kind': 'play-production', 'platform': 'android',
                      'build': {'number': 10, 'sha': 'a' * 40}}
            runtime.prepare_action(action, {'now': 3600})
            runtime.execute(action, {}, {'now': 3600})
        self.assertIs(runtime.play, original_client)
        self.assertIs(runtime.play.request, http)
        self.assertEqual(next(body for method, _, body in requests if method == 'PUT')['releases'][0]['releaseNotes'], bundle['google_play'])

    def test_android_retry_refreshes_authorization_after_slow_artifact_download(self):
        import hashlib
        from unittest.mock import patch

        from release_train.providers import Play
        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle

        clock = {'now': 0}
        requests = []

        def http(method, url, headers=None, body=None):
            if clock['now'] > 3500 and headers['Authorization'] != 'Bearer fresh-play':
                raise ProviderError('Play authorization expired during artifact download')
            requests.append((method, url, body))
            return {'versionCode': 10} if '/bundles?' in url else {'id': 'edit'}

        bundle = release_notes_bundle('android')
        record = {'number': 10, 'version': '1.0.31', 'sha': 'a' * 40,
                  'digest': hashlib.sha256(b'signed original bytes').hexdigest(),
                  'build_id': '123', 'artifact_name': 'app.aab', 'release_notes': bundle}
        runtime = Runtime.__new__(Runtime)
        runtime.env = {'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': 'protected-credentials'}
        runtime.ledger = MemoryLedgerStore({'artifacts/android/10.json': record})
        runtime.play = Play('snapshot-play', request=http)
        runtime.cm = lambda *args: {'data': {'commit': {'hash': 'a' * 40}, 'artifacts': [{'name': 'app.aab', 'url': 'private'}]}}

        def download(url, path):
            path.write_bytes(b'signed original bytes')
            clock['now'] = 3600

        def fresh_token(credentials):
            self.assertEqual(clock['now'], 3600)
            return 'fresh-play'

        runtime.download = download
        state = {}
        with patch('release_train.runner.play_token', side_effect=fresh_token):
            runtime.execute(record | {'kind': 'retry-android-upload', 'platform': 'android'}, state, {})
        self.assertEqual(state['resolved_android_uploads'], [10])
        self.assertTrue(any('/bundles?' in url for _, url, _ in requests))


class NotesPreparationJournalTest(unittest.TestCase):
    def test_generation_failure_for_every_store_action_does_not_create_operation_or_hold(self):
        import hashlib
        from unittest.mock import patch

        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore

        record = {'number': 10, 'version': '1.0.31', 'sha': 'a' * 40,
                  'digest': hashlib.sha256(b'original signed aab').hexdigest(),
                  'build_id': '123', 'artifact_name': 'app.aab'}
        for kind, platform in [('public-beta', 'ios'), ('app-store', 'ios'),
                               ('play-production', 'android'), ('retry-android-upload', 'android')]:
            with self.subTest(kind=kind):
                runtime = Runtime.__new__(Runtime)
                runtime.env = {}
                runtime.ledger = MemoryLedgerStore({'artifacts/android/10.json': record})
                runtime.cm = lambda *args: {'data': {'commit': {'hash': 'a' * 40}, 'artifacts': [{'name': 'app.aab', 'url': 'private'}]}}
                runtime.download = lambda url, path: path.write_bytes(b'original signed aab')
                state = {}
                action = {'kind': kind, 'platform': platform}
                if kind == 'retry-android-upload':
                    action.update(record)
                else:
                    action['build'] = {'id': '10', 'number': 10, 'version': '1.0.31', 'sha': 'a' * 40}
                plan = {'actions': [action]}
                with patch('release_train.release_notes.ensure_bundle', side_effect=ProviderError('Model timed out')):
                    execute_plan(plan, state, {}, Store(), runtime)
                self.assertFalse(state.get('operations'))
                self.assertFalse(state.get('holds'))
                self.assertFalse(state.get('attempts'))
                self.assertIn('Model timed out', plan['errors'][0])

    def test_wrong_source_notes_fail_before_store_journal(self):
        from unittest.mock import patch

        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle

        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.ledger = MemoryLedgerStore()
        state = {}
        action = {'kind': 'public-beta', 'platform': 'ios', 'build': {'id': '10', 'number': 10, 'sha': 'a' * 40}}
        with patch('release_train.release_notes.ensure_bundle', return_value=release_notes_bundle(source='d' * 40)):
            execute_plan({'actions': [action]}, state, {}, Store(), runtime)
        self.assertFalse(state.get('operations'))
        self.assertFalse(state.get('holds'))

    def test_retry_artifact_identity_conflict_fails_before_store_journal(self):
        from release_train.runner import Runtime
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle

        record = {'number': 10, 'version': '1.0.31', 'sha': 'a' * 40, 'digest': 'b' * 64,
                  'build_id': '123', 'artifact_name': 'app.aab', 'release_notes': release_notes_bundle('android')}
        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.ledger = MemoryLedgerStore({'artifacts/android/10.json': record})
        state = {}
        action = record | {'kind': 'retry-android-upload', 'platform': 'android', 'digest': 'c' * 64}
        plan = {'actions': [action]}
        execute_plan(plan, state, {}, Store(), runtime)
        self.assertFalse(state.get('operations'))
        self.assertFalse(state.get('holds'))
        self.assertIn('identity conflicts', plan['errors'][0])

    def test_store_failure_still_holds_after_notes_are_durable(self):
        from unittest.mock import patch

        from release_train.runner import Runtime, operation_key
        from release_train_fakes import MemoryLedgerStore, release_notes_bundle

        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.ledger = MemoryLedgerStore()
        state = {}
        store = Store()
        action = {'kind': 'public-beta', 'platform': 'ios',
                  'build': {'id': '10', 'number': 10, 'sha': 'a' * 40}}
        key = operation_key(action)

        class Apple:
            def submit_beta(self, build, notes):
                self_status = store.saves[-1]['operations'][key]
                if self_status['status'] != 'started' or not self_status['action'].get('release_notes'):
                    raise AssertionError('Store mutation must have durable intent and prepared notes')
                raise ProviderError('Store response unavailable')

        runtime.apple = Apple()

        def generate(*args, **kwargs):
            self.assertFalse(state.get('operations'))
            return release_notes_bundle()

        with patch('release_train.release_notes.ensure_bundle', side_effect=generate):
            execute_plan({'actions': [action]}, state, {}, store, runtime)
        self.assertEqual(state['operations'][key]['status'], 'ambiguous')
        self.assertEqual(state['holds'], {'ios': key})
        self.assertEqual(state['operations'][key]['action']['release_notes']['testflight'],
                         [{'language': 'en-US', 'text': 'Try recording a loop.'}])
