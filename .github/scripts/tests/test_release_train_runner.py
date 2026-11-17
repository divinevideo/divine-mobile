import copy
import unittest

import release_train_fakes  # noqa: F401 - adds repository scripts to sys.path
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
                return {"data": [{"id": name, "name": name, "secure": True, "value": None}
                                  for name in ['GH_TOKEN', 'GITHUB_TOKEN', 'PROVENANCE_TOKEN', 'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS']]} if method == 'GET' else {}
            return {"data": {"id": "123"}}

        runtime.cm = cm
        runtime.execute(
            {"kind": "build", "platform": "ios", "sha": "a" * 40, "attempt": 1}, {}, {}
        )
        self.assertEqual(len(runtime.tags.calls), 2)
        self.assertFalse(runtime.gh.calls)
        patches = [c for c in cm_calls if c[0] == 'PATCH']
        self.assertEqual({c[1].rsplit('/', 1)[-1]: c[2] for c in patches}, {
            'GH_TOKEN': {'value': 'mobile-release-token', 'secure': True},
            'GITHUB_TOKEN': {'value': 'mobile-release-token', 'secure': True},
            'PROVENANCE_TOKEN': {'value': 'private-ledger-token', 'secure': True},
            'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS': {'value': '[]', 'secure': True},
        })
        build_call = next(c for c in cm_calls if c[0] == 'POST')
        self.assertLess(cm_calls.index(patches[-1]), cm_calls.index(build_call))
        self.assertNotIn('private-ledger-token', str(build_call))


class AuditTest(unittest.TestCase):
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
