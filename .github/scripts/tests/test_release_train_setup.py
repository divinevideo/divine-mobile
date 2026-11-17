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

        setup.configure_build_credentials(cm, 'private-ledger-token', 'mobile-release-token', '[]')
        self.assertEqual(groups, [{"id": "legacy", "name": "github_credentials"},
                                  {"id": "native", "name": "store_release_credentials"}])
        self.assertFalse(any('/teams/' in path or '/legacy/' in path for _, path, _ in calls))
        self.assertEqual(set(variables), {'GH_TOKEN', 'GITHUB_TOKEN', 'PROVENANCE_TOKEN',
                                         'DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS'})

    def test_build_credentials_rotate_secure_values_without_returning_secrets(self):
        variables = {"GITHUB_TOKEN": {"id": "old", "name": "GITHUB_TOKEN", "secure": False, "value": None}}
        mutations = []

        def cm(method, path, payload=None):
            if "/apps/" in path:
                return {"data": [{"id": "g", "name": "store_release_credentials"}]}
            if method == "GET":
                return {"data": list(variables.values())}
            mutations.append((method, path, payload))
            if method == "PATCH":
                variables["GITHUB_TOKEN"]["secure"] = payload["secure"]
            else:
                for item in payload["variables"]:
                    variables[item["name"]] = {"id": item["name"], "name": item["name"], "secure": payload["secure"], "value": None}
            return {}

        self.assertTrue(callable(getattr(setup, "configure_build_credentials", None)), "Builds must refresh their scoped credentials")
        result = setup.configure_build_credentials(cm, "private-ledger-token", "mobile-release-token", "[]")
        self.assertIsNone(result)
        self.assertEqual(set(variables), {"GITHUB_TOKEN", "GH_TOKEN", "PROVENANCE_TOKEN", "DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS"})
        self.assertTrue(all(item["secure"] for item in variables.values()))
        written = {}
        for method, path, payload in mutations:
            if method == "PATCH":
                written["GITHUB_TOKEN"] = payload["value"]
            else:
                written.update({item["name"]: item["value"] for item in payload["variables"]})
        self.assertEqual(written, {"GITHUB_TOKEN": "mobile-release-token", "GH_TOKEN": "mobile-release-token", "PROVENANCE_TOKEN": "private-ledger-token", "DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS": "[]"})

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
