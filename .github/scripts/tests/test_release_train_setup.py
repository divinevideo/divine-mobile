import unittest

import release_train_fakes  # noqa: F401 - adds repository scripts to sys.path
from release_train.setup import configure_codemagic


class SetupTest(unittest.TestCase):
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
