import unittest

import release_train_fakes  # noqa: F401 - adds repository scripts to sys.path
from release_train import setup
from release_train.setup import configure_codemagic


class SetupTest(unittest.TestCase):
    def test_native_group_is_created_at_app_scope_without_mutating_shared_credentials(self):
        groups = [{"id": "legacy", "name": "github_credentials"}]
        variables = {}
        calls = []

        def cm(method, path, payload=None):
            calls.append((method, path, payload))
            if '/apps/' in path:
                if method == 'POST':
                    groups.append({"id": "native", "name": payload["name"]})
                    return {}  # Codemagic returns an empty successful creation response.
                return {"data": groups}
            self.assertIn('/variable-groups/native/variables', path)
            if method == 'POST':
                for item in payload['variables']:
                    variables[item['name']] = dict(item, id=item['name'], secure=payload['secure'])
                return {}
            return {"data": list(variables.values())}

        setup.configure_build_credentials(cm, 'private-ledger-token', '[]')
        self.assertEqual(groups, [{"id": "legacy", "name": "github_credentials"},
                                  {"id": "native", "name": "store_release_credentials"}])
        self.assertFalse(any('/teams/' in path or '/legacy/' in path for _, path, _ in calls))
        self.assertEqual(set(variables), {'PROVENANCE_TOKEN',
                                         'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS'})

    def test_native_rotation_removes_candidate_tokens_and_uses_provider_variable_ids(self):
        variables = {
            'GH_TOKEN': {'id': 'mobile-one', 'name': 'GH_TOKEN', 'secure': True},
            'GITHUB_TOKEN': {'id': 'mobile-two', 'name': 'GITHUB_TOKEN', 'secure': True},
            'PROVENANCE_TOKEN': {'id': 'private-id', 'name': 'PROVENANCE_TOKEN', 'secure': True},
            'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS': {'id': 'policy-id', 'name': 'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS', 'secure': True},
        }
        mutations = []
        def cm(method, path, payload=None):
            if '/apps/' in path:
                return {'data': [{'id': 'g', 'name': 'store_release_credentials'}]}
            if method == 'GET':
                return {'data': list(variables.values())}
            mutations.append((method, path, payload))
            name = next(name for name, v in variables.items() if path.endswith('/' + v['id']))
            if method == 'DELETE':
                del variables[name]
            else:
                variables[name]['secure'] = payload['secure']
            return {}
        result = setup.configure_build_credentials(cm, 'private-ledger-token', '[]')
        self.assertIsNone(result)
        self.assertEqual(set(variables), {'PROVENANCE_TOKEN', 'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS'})
        self.assertEqual({path.rsplit('/', 1)[-1] for method, path, _ in mutations if method == 'DELETE'}, {'mobile-one', 'mobile-two'})
        self.assertEqual({path.rsplit('/', 1)[-1] for method, path, _ in mutations if method == 'PATCH'}, {'private-id', 'policy-id'})
        self.assertNotIn('mobile-release-token', str(mutations))

    def test_missing_value_names_the_key_without_network(self):
        def cm(*args):
            self.fail('missing configuration must fail before network')
        with self.assertRaisesRegex(setup.ProviderError, 'PUBLIC_PEOPLE_LIST_POLICY'):
            setup.configure_build_credentials(cm, 'private-token', '')
        with self.assertRaisesRegex(setup.ProviderError, 'PROVENANCE_TOKEN'):
            setup.configure_build_credentials(cm, '', '[]')

    def test_duplicate_variable_and_unencrypted_readback_fail_closed(self):
        from release_train.providers import ProviderError
        for failure in ['duplicate', 'unencrypted']:
            def cm(method, path, payload=None):
                if '/apps/' in path:
                    return {'data': [{'id': 'g', 'name': 'store_release_credentials'}]}
                if method != 'GET':
                    return {}
                variables = [{'id': 'one', 'name': 'PROVENANCE_TOKEN', 'secure': False}]
                if failure == 'duplicate':
                    variables.append(dict(variables[0], id='two'))
                return {'data': variables}
            expected = 'Duplicate' if failure == 'duplicate' else 'encryption'
            with self.subTest(failure=failure), self.assertRaisesRegex(ProviderError, expected):
                setup.configure_build_credentials(cm, 'private-token', '[]')

    def test_existing_token_is_updated_securely_and_response_not_printed(self):
        calls = []

        def cm(method, path, payload=None):
            calls.append((method, path, payload))
            if "/apps/" in path:
                return {"data": [{"id": "g", "name": "github_credentials"}]}
            if method == "GET":
                return {
                    "data": [
                        {
                            "id": "v",
                            "name": "CODEMAGIC_API_TOKEN",
                            "secure": True,
                            "value": None,
                        }
                    ]
                }
            return {}

        configure_codemagic(cm, "private-token")
        mutation = next(c for c in calls if c[0] == "PATCH")
        self.assertEqual(mutation[2], {"value": "private-token", "secure": True})
        self.assertFalse(any(c[0] == "DELETE" for c in calls))

    def test_missing_existing_group_fails_closed(self):
        from release_train.providers import ProviderError

        with self.assertRaises(ProviderError):
            configure_codemagic(lambda *args: {"data": []}, "private-token")



if __name__ == "__main__":
    unittest.main()
