import hashlib
import io
import json
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

import release_train_fakes  # adds repository scripts to sys.path
from release_train.providers import (
    Apple,
    BeforeStoreMutationError,
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
        play.promote(123, notes=play_notes())
        payload = next(c[3] for c in http.calls if c[0] == "PUT")
        self.assertEqual(payload["releases"][0]["versionCodes"], ["123"])
        self.assertEqual(payload["releases"][0]["status"], "completed")
        self.assertFalse(any(c[0] == "DELETE" for c in http.calls))
        self.assertEqual([call[0] for call in http.calls], ["POST", "PUT", "POST", "POST"])
        self.assertTrue(http.calls[2][1].endswith("/edits/edit:validate"))
        self.assertIn(":commit?", http.calls[3][1])

    def test_play_validation_failure_discards_edit_without_committing(self):
        for cleanup in [{}, ProviderError("cleanup failed")]:
            with self.subTest(cleanup=cleanup):
                http = FakeHTTP()
                http.responses = [{"id": "edit"}, {}, ProviderError("invalid"), cleanup]
                with self.assertRaisesRegex(BeforeStoreMutationError, "validate edit"):
                    Play("token", request=http).promote(123, notes=play_notes())
                self.assertEqual([call[0] for call in http.calls], ["POST", "PUT", "POST", "DELETE"])
                self.assertNotIn(":commit", " ".join(call[1] for call in http.calls))

    def test_play_commit_failure_is_not_reclassified_as_a_preflight_failure(self):
        http = FakeHTTP()
        http.responses = [{"id": "edit"}, {}, {}, DeferredReview("in review")]
        with self.assertRaises(DeferredReview):
            Play("token", request=http).promote(123, notes=play_notes())
        self.assertEqual([call[0] for call in http.calls], ["POST", "PUT", "POST", "POST"])

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
        apple.submit_beta({"id": "10"}, [{"language": "en-US", "text": "Changes"}])
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


PLAY_LANGUAGES = ('en-US', 'es-419', 'pt-BR', 'fr-FR', 'de-DE', 'it-IT', 'nl-NL', 'pl-PL', 'sv-SE', 'ro', 'bg', 'tr-TR', 'ar', 'ur', 'ja-JP', 'ko-KR', 'zh-CN', 'vi', 'id', 'ms', 'fil', 'am', 'te-IN')


def play_notes():
    return [{'language': language, 'text': release_train_fakes.TRANSLATED_SEARCH_NOTES[language]} for language in PLAY_LANGUAGES]


class LocalizedNotesTest(unittest.TestCase):
    def test_play_promotion_preserves_all_localized_text(self):
        http = FakeHTTP()
        notes = play_notes()
        notes[3]['text'] = 'Retrouvez vos vidéos.'
        Play('token', request=http).promote(123, notes=notes)
        payload = next(c[3] for c in http.calls if c[0] == 'PUT')
        self.assertEqual(payload['releases'][0]['releaseNotes'], notes)

    def test_play_missing_or_oversized_notes_fail_before_edit_creation(self):
        for notes in [[], play_notes()[:-1], play_notes() + [play_notes()[0]],
                      [n | {'text': 'x' * 501} for n in play_notes()]]:
            with self.subTest(notes=notes):
                http = FakeHTTP()
                with self.assertRaises(ProviderError):
                    Play('token', request=http).promote(123, notes=notes)
                self.assertEqual(http.calls, [])

    def test_beta_note_update_matches_locale_and_never_changes_review_or_groups(self):
        http = FakeHTTP()
        http.responses = [{'data': [
            {'id': 'english', 'attributes': {'locale': 'en-US'}},
            {'id': 'french', 'attributes': {'locale': 'fr-FR'}},
        ]}]
        Apple('token', 'group', request=http).set_beta_notes({'id': '10'}, [
            {'language': 'en-US', 'text': 'Try recording a loop.'},
            {'language': 'fr-FR', 'text': 'Essayez une nouvelle vidéo.'},
        ])
        writes = [c for c in http.calls if c[0] != 'GET']
        self.assertEqual([(c[0], c[1].rsplit('/', 1)[-1], c[3]['data']['attributes']) for c in writes], [
            ('PATCH', 'english', {'whatsNew': 'Try recording a loop.'}),
            ('PATCH', 'french', {'whatsNew': 'Essayez une nouvelle vidéo.'}),
        ])

    def test_beta_missing_locale_fails_before_auto_notify_or_other_mutation(self):
        http = FakeHTTP()
        http.responses = [{'data': [{'id': 'french', 'attributes': {'locale': 'fr-FR'}}]}]
        with self.assertRaises(ProviderError):
            Apple('token', 'group', request=http).submit_beta(
                {'id': '10', 'beta_detail_id': 'detail'},
                [{'language': 'en-US', 'text': 'Try a loop.'}],
            )
        self.assertTrue(all(c[0] == 'GET' for c in http.calls))

    def test_store_missing_locale_fails_before_build_or_release_changes(self):
        http = FakeHTTP()
        http.responses = [{'data': [{'id': 'french', 'attributes': {'locale': 'fr-FR'}}]}]
        with self.assertRaises(ProviderError):
            Apple('token', 'group', request=http).submit_store(
                {'id': '10', 'version': '1.0.31'},
                [{'id': 'v', 'version': '1.0.31', 'state': 'PREPARE_FOR_SUBMISSION'}], [],
                notes=[{'language': 'en-US', 'text': 'Videos load more smoothly.'}],
            )
        self.assertTrue(all(c[0] == 'GET' for c in http.calls))

    def test_store_localizations_preserve_each_translation(self):
        calls = []
        def http(method, url, headers=None, body=None):
            calls.append((method, url, body))
            if url.endswith('/appStoreVersionLocalizations'):
                return {'data': [{'id': 'english', 'attributes': {'locale': 'en-US'}},
                                 {'id': 'french', 'attributes': {'locale': 'fr-FR'}}]}
            return {'data': None if method == 'GET' else {'id': 'review'}}
        Apple('token', 'group', request=http).submit_store(
            {'id': '10', 'version': '1.0.31'},
            [{'id': 'v', 'version': '1.0.31', 'state': 'PREPARE_FOR_SUBMISSION'}], [],
            notes=[{'language': 'en-US', 'text': 'Videos load more smoothly.'},
                   {'language': 'fr-FR', 'text': 'Les vidéos se chargent mieux.'}],
        )
        self.assertEqual({url.rsplit('/', 1)[-1]: body['data']['attributes']['whatsNew']
                          for method, url, body in calls if method == 'PATCH' and '/appStoreVersionLocalizations/' in url},
                         {'english': 'Videos load more smoothly.', 'french': 'Les vidéos se chargent mieux.'})

    def test_new_store_version_missing_configured_locale_never_creates_version(self):
        http = FakeHTTP()
        http.responses = [{'data': [{'id': 'info'}]},
                          {'data': [{'id': 'french', 'attributes': {'locale': 'fr-FR'}}]}]
        with self.assertRaises(ProviderError):
            Apple('token', 'group', request=http).submit_store(
                {'id': '10', 'version': '1.0.31'}, [], [],
                notes=[{'language': 'en-US', 'text': 'Videos load more smoothly.'}],
            )
        self.assertTrue(all(c[0] == 'GET' for c in http.calls))

    def test_held_916_cannot_be_submitted_to_app_store(self):
        http = FakeHTTP()
        with self.assertRaises(ProviderError):
            Apple('token', 'group', request=http).submit_store(
                {'id': '916', 'number': 916, 'version': '1.0.30'}, [], [],
                notes=[{'language': 'en-US', 'text': 'Videos load more smoothly.'}],
            )
        self.assertEqual(http.calls, [])

    def test_play_upload_validates_notes_before_edit_or_artifact_access(self):
        http = FakeHTTP()
        with self.assertRaises(ProviderError):
            Play('token', request=http).upload('not-an-artifact', 10, 'a' * 64, notes=[])
        self.assertEqual(http.calls, [])

    def test_empty_store_locale_inventory_stops_before_existing_version_mutation(self):
        http = FakeHTTP()
        http.responses = [{'data': []}]
        with self.assertRaises(ProviderError):
            Apple('token', 'group', request=http).submit_store(
                {'id': '10', 'version': '1.0.31'},
                [{'id': 'v', 'version': '1.0.31', 'state': 'PREPARE_FOR_SUBMISSION'}], [],
                notes=[{'language': 'en-US', 'text': 'Videos load more smoothly.'}],
            )
        self.assertTrue(all(c[0] == 'GET' for c in http.calls))


class PlayUploadTransportTest(unittest.TestCase):
    def test_slow_bundle_upload_can_finish_after_one_minute(self):
        calls = []

        class GoogleTransport:
            def open(self, request, timeout):
                url = request.full_url
                calls.append((request.method, url, timeout, request.data))
                if '/bundles?' in url:
                    # Simulate a successful upload taking 90 seconds. No real wait.
                    if timeout < 90:
                        raise TimeoutError('upload response exceeded socket timeout')
                    response = {'versionCode': 123}
                else:
                    response = {'id': 'edit'}
                return io.BytesIO(json.dumps(response).encode())

        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / 'signed.aab'
            artifact.write_bytes(b'original signed artifact')
            digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
            with patch('release_train.providers.urllib.request.build_opener',
                       return_value=GoogleTransport()):
                Play('token').upload(artifact, 123, digest, notes=play_notes())
        self.assertEqual([c[0] for c in calls], ['POST', 'POST', 'PUT', 'POST'])
        self.assertTrue(calls[-1][1].endswith(
            ':commit?changesInReviewBehavior=ERROR_IF_IN_REVIEW'))
        self.assertTrue(all(c[2] == 60 for c in calls if '/bundles?' not in c[1]))

    def test_upload_timeout_keeps_mutation_ambiguous_and_does_not_commit(self):
        # urllib wraps a timeout while sending the bundle in URLError; a timeout
        # while waiting for Google to process the uploaded bundle is not wrapped.
        for failure in (
            urllib.error.URLError(TimeoutError('secret transport details must not be logged')),
            TimeoutError('secret transport details must not be logged'),
        ):
            with self.subTest(failure=type(failure).__name__):
                calls = []

                class UnavailableGoogleTransport:
                    def open(self, request, timeout):
                        calls.append(request.full_url)
                        if '/bundles?' in request.full_url:
                            raise failure
                        return io.BytesIO(b'{"id":"edit"}')

                with tempfile.TemporaryDirectory() as directory:
                    artifact = Path(directory) / 'signed.aab'
                    artifact.write_bytes(b'original signed artifact')
                    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
                    with (
                        patch('release_train.providers.urllib.request.build_opener',
                              return_value=UnavailableGoogleTransport()),
                        self.assertRaisesRegex(ProviderError, 'Google Play bundle upload.*timed out') as error,
                    ):
                        Play('token').upload(artifact, 123, digest, notes=play_notes())
                self.assertNotIn('secret transport details', str(error.exception))
                self.assertEqual(len(calls), 2)
