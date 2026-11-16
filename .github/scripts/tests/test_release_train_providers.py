import hashlib
import tempfile
import unittest
from pathlib import Path

import release_train_fakes  # noqa: F401 - adds repository scripts to sys.path
from release_train.providers import (
    Apple,
    DeferredReview,
    Play,
    ProviderError,
    verify_bundle,
)


class FakeHTTP:
    def __init__(self):
        self.calls = []
        self.responses = []

    def __call__(self, method, url, headers=None, body=None):
        self.calls.append((method, url, headers, body))
        result = self.responses.pop(0) if self.responses else {"id": "edit"}
        if isinstance(result, Exception):
            raise result
        return result


class ProviderTest(unittest.TestCase):
    def test_all_play_commits_guard_review_races(self):
        http = FakeHTTP()
        http.responses = [DeferredReview("CHANGES_ALREADY_IN_REVIEW")]
        play = Play("token", request=http)
        with self.assertRaises(DeferredReview):
            play.commit("edit")
        self.assertTrue(
            http.calls[0][1].endswith(
                ":commit?changesInReviewBehavior=ERROR_IF_IN_REVIEW"
            )
        )
        self.assertEqual(len(http.calls), 1)

    def test_production_promotes_exact_tested_code_full_rollout(self):
        http = FakeHTTP()
        play = Play("token", request=http)
        play.promote(123)
        payload = next(c[3] for c in http.calls if c[0] == "PUT")
        self.assertEqual(payload["releases"][0]["versionCodes"], ["123"])
        self.assertEqual(payload["releases"][0]["status"], "completed")
        self.assertFalse(any(c[0] == "DELETE" for c in http.calls))

    def test_digest_mismatch_and_missing_artifact_fail_closed(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "bundle.aab"
            p.write_bytes(b"signed bundle")
            verify_bundle(p, hashlib.sha256(p.read_bytes()).hexdigest())
            for digest in ["a" * 64, "invalid"]:
                with self.assertRaises(ProviderError):
                    verify_bundle(p, digest)
            with self.assertRaises(ProviderError):
                verify_bundle(Path(d) / "missing", "a" * 64)

    def test_public_beta_never_changes_group_audience(self):
        http = FakeHTTP()
        http.responses = [
            {"data": []},
            {"data": {"id": "loc"}},
            {"data": {"id": "review"}},
            {"data": {}},
        ]
        apple = Apple("token", "group", request=http)
        apple.submit_beta({"id": "10"}, "Changes")
        self.assertFalse(
            any("/betaGroups/group" in c[1] and c[0] == "PATCH" for c in http.calls)
        )
        self.assertTrue(any("/betaAppReviewSubmissions" in c[1] for c in http.calls))


class ArtifactRedirectTest(unittest.TestCase):
    def test_download_redirect_strips_provider_credentials(self):
        from urllib.request import Request

        from release_train.providers import ArtifactRedirect

        request = Request(
            "https://api.codemagic.io/artifacts/original",
            headers={"x-auth-token": "private", "Authorization": "private"},
        )
        redirected = ArtifactRedirect().redirect_request(
            request, None, 302, "", {}, "https://storage.googleapis.com/signed-artifact"
        )
        self.assertFalse(redirected.headers)
        with self.assertRaises(ProviderError):
            ArtifactRedirect().redirect_request(
                request,
                None,
                302,
                "",
                {},
                "http://storage.googleapis.com/signed-artifact",
            )


if __name__ == "__main__":
    unittest.main()
