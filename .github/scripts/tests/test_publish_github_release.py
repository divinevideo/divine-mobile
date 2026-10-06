"""Release publication must not overwrite a different build or stable assets."""
import contextlib
import io
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[3] / 'mobile/scripts/publish_github_release.py'
spec = importlib.util.spec_from_file_location('release', SCRIPT)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
SHA = 'a' * 40


class FakeGitHub:
    def __init__(self):
        self.commit = None
        self.record = None
        self.calls = []

    def tag_commit(self, tag):
        return self.commit

    def get_release(self, tag):
        return self.record

    def create(self, tag, sha, body, beta):
        self.calls.append(('create', tag, sha, beta))
        self.commit = sha
        self.record = dict(draft=True, prerelease=beta, body=body, assets=[], target_commitish=sha)

    def upload(self, tag, paths):
        self.calls.append(('upload', tag))
        self.record['assets'] += [dict(name=p.name, digest=release.digest(p)) for p in paths]

    def edit(self, tag, body, beta):
        self.calls.append(('edit', tag, beta))
        self.record.update(draft=False, prerelease=beta, body=body)
        if self.commit is None:
            self.commit = self.record['target_commitish']

    def latest_tag(self):
        return '1.2.3'


class PublicationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.notes = self.root / 'notes.md'
        self.notes.write_text('## Make it yours\n\n- Add your own sounds.\n')
        self.asset = self.root / 'app.apk'
        self.asset.write_bytes(b'release bytes')
        self.gh = FakeGitHub()

    def publish(self, channel='PRODUCTION'):
        return release.publish(self.gh, '1.2.3', SHA, channel, 'PRODUCTION', self.notes, [self.asset])

    def test_production_creates_draft_then_uploads_then_promotes(self):
        self.assertEqual(self.publish(), '1.2.3')
        self.assertEqual([c[0] for c in self.gh.calls], ['create', 'upload', 'edit'])
        self.assertFalse(self.gh.record['prerelease'])
        self.assertFalse(self.gh.record['draft'])
        self.assertIn('Add your own sounds', self.gh.record['body'])

    def test_beta_uses_separate_source_tag(self):
        self.assertEqual(self.publish('BETA'), '1.2.3-beta.production.' + SHA)
        self.assertTrue(self.gh.record['prerelease'])

    def test_beta_can_publish_without_finished_notes(self):
        self.notes.unlink()
        self.publish('BETA')
        self.assertIn('beta', self.gh.record['body'])

    def test_production_requires_notes_before_mutation(self):
        self.notes.unlink()
        with self.assertRaisesRegex(ValueError, 'notes'):
            self.publish()
        self.assertEqual(self.gh.calls, [])

    def test_tag_mismatch_blocks_upload(self):
        self.gh.commit = 'b' * 40
        with self.assertRaisesRegex(ValueError, 'different commit'):
            self.publish()
        self.assertEqual(self.gh.calls, [])

    def test_identical_repeated_upload_is_skipped(self):
        self.publish()
        self.gh.calls.clear()
        self.publish()
        self.assertEqual([c[0] for c in self.gh.calls], ['edit'])

    def test_changed_asset_is_never_clobbered(self):
        self.publish()
        self.gh.calls.clear()
        self.asset.write_bytes(b'different rebuild')
        with self.assertRaisesRegex(ValueError, 'different bytes'):
            self.publish()
        self.assertEqual(self.gh.calls, [])

    def test_existing_prerelease_is_promoted_and_notes_refreshed(self):
        self.gh.commit = SHA
        self.gh.record = dict(draft=False, prerelease=True, body='old', assets=[])
        self.publish()
        self.assertFalse(self.gh.record['prerelease'])
        self.assertNotEqual(self.gh.record['body'], 'old')

    def test_production_rejects_staging_backend(self):
        with self.assertRaisesRegex(ValueError, 'backend'):
            release.publish(self.gh, '1.2.3', SHA, 'PRODUCTION', 'STAGING', self.notes, [self.asset])
        self.assertEqual(self.gh.calls, [])

    def test_draft_notes_are_never_published(self):
        self.notes.write_text('<!-- DRAFT -->\nInternal inventory')
        with self.assertRaisesRegex(ValueError, 'notes'):
            self.publish()
        self.publish('BETA')
        self.assertNotIn('Internal inventory', self.gh.record['body'])

    def test_draft_heading_without_marker_is_rejected(self):
        self.notes.write_text('# Release notes working draft\nInternal inventory')
        with self.assertRaisesRegex(ValueError, 'notes'):
            self.publish()
        self.assertEqual(self.gh.calls, [])

    def test_draft_with_different_target_cannot_be_published(self):
        self.gh.record = dict(draft=True, prerelease=True, body='', assets=[],
                              target_commitish='b' * 40)
        with self.assertRaisesRegex(ValueError, 'different commit'):
            self.publish()
        self.assertEqual(self.gh.calls, [])

    def test_stable_release_cannot_be_downgraded(self):
        self.publish()
        self.gh.calls.clear()
        with self.assertRaisesRegex(ValueError, 'stable'):
            self.publish('BETA')
        self.assertEqual(self.gh.calls, [])

    def test_older_release_cannot_replace_latest(self):
        self.gh.latest_tag = lambda: '2.0.0'
        with self.assertRaisesRegex(ValueError, 'newer'):
            self.publish()
        self.assertEqual(self.gh.calls, [])

    def test_newer_release_during_upload_prevents_late_promotion(self):
        upload = self.gh.upload
        def newer_release(tag, paths):
            upload(tag, paths)
            self.gh.latest_tag = lambda: '1.2.4'
        self.gh.upload = newer_release
        with self.assertRaisesRegex(ValueError, 'newer'):
            self.publish()
        self.assertTrue(self.gh.record['draft'])
        self.assertNotIn('edit', [c[0] for c in self.gh.calls])

    def test_newer_latest_during_publication_is_preserved(self):
        edit = self.gh.edit
        def concurrent_release(tag, body, beta):
            edit(tag, body, beta)
            self.gh.latest_tag = lambda: '1.2.4'
        self.gh.edit = concurrent_release
        self.assertEqual(self.publish(), '1.2.3')
        self.assertEqual(self.gh.latest_tag(), '1.2.4')

    def test_invalid_channel_and_version_fail_closed(self):
        for version, channel in [('1.2.3', ''), ('1.2.3-rc', 'PRODUCTION')]:
            with self.assertRaises(ValueError):
                release.publish(self.gh, version, SHA, channel, 'PRODUCTION', self.notes, [self.asset])
        self.assertEqual(self.gh.calls, [])

    def test_no_assets_does_not_create_release(self):
        with self.assertRaisesRegex(ValueError, 'artifacts'):
            release.publish(self.gh, '1.2.3', SHA, 'PRODUCTION', 'PRODUCTION', self.notes, [])
        self.assertEqual(self.gh.calls, [])

    def test_promotion_reuses_verified_beta_artifacts(self):
        beta_tag = '1.2.3-beta.production.' + SHA
        beta = dict(draft=False, prerelease=True,
                    assets=[dict(name='app.apk', digest=release.digest(self.asset))])
        original_get = self.gh.get_release
        self.gh.get_release = lambda tag: beta if tag == beta_tag else original_get(tag)
        original_commit = self.gh.tag_commit
        self.gh.tag_commit = lambda tag: SHA if tag == beta_tag else original_commit(tag)
        self.gh.download = lambda tag, directory: (directory / 'app.apk').write_bytes(b'release bytes')
        self.assertEqual(release.promote(self.gh, beta_tag, self.notes), '1.2.3')
        self.assertEqual(self.gh.calls[0], ('create', '1.2.3', SHA, False))

    def test_promotion_rejects_wrong_backend_or_download_bytes(self):
        with self.assertRaisesRegex(ValueError, 'production-backend'):
            release.promote(self.gh, '1.2.3-beta.staging.' + SHA, self.notes)
        self.gh.commit = SHA
        self.gh.record = dict(draft=False, prerelease=True,
                             assets=[dict(name='app.apk', digest=release.digest(self.asset))])
        self.gh.download = lambda tag, directory: (directory / 'app.apk').write_bytes(b'wrong')
        with self.assertRaisesRegex(ValueError, 'digest'):
            release.promote(self.gh, '1.2.3-beta.production.' + SHA, self.notes)
        self.assertEqual(self.gh.calls, [])

    def test_interrupted_draft_can_resume_at_same_source(self):
        self.gh.record = dict(draft=True, prerelease=True, body='', assets=[],
                              target_commitish=SHA)
        self.publish()
        self.assertEqual([c[0] for c in self.gh.calls], ['upload', 'edit'])
        self.assertFalse(self.gh.record['draft'])

    def test_corrupt_upload_is_not_promoted(self):
        upload = self.gh.upload
        def corrupt(tag, paths):
            upload(tag, paths)
            self.gh.record['assets'][0]['digest'] = 'sha256:' + '0' * 64
        self.gh.upload = corrupt
        with self.assertRaisesRegex(RuntimeError, 'Uploaded artifact verification'):
            self.publish()
        self.assertTrue(self.gh.record['draft'])
        self.assertNotIn('edit', [c[0] for c in self.gh.calls])

    def test_upload_failure_leaves_new_release_draft(self):
        def fail(*args):
            raise RuntimeError('upload failed')
        self.gh.upload = fail
        with self.assertRaises(RuntimeError):
            self.publish()
        self.assertTrue(self.gh.record['draft'])


class CommandInputTest(unittest.TestCase):
    def test_version_accepts_optional_build_and_rejects_invalid_input(self):
        self.assertEqual(release.marketing_version('version: 1.2.3+820\n'), '1.2.3')
        self.assertEqual(release.marketing_version('version: 1.2.3\n'), '1.2.3')
        with self.assertRaisesRegex(ValueError, 'version'):
            release.marketing_version('version: wrong\n')

    def test_recovery_collects_original_downloads_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'android').mkdir()
            asset = root / 'android' / 'app-arm64-v8a-release.apk'
            asset.write_bytes(b'original')
            (root / 'android' / 'app-x86_64-release.apk').write_bytes(b'emulator')
            (root / 'android' / 'app-release.apk').write_bytes(b'universal')
            (root / 'notes.txt').write_text('not an artifact')
            self.assertEqual(release.recovery_artifacts(root), [asset])

    def test_explicit_beta_promotion_is_rejected_before_github(self):
        with patch('sys.argv', ['publisher', '--repo', 'owner/repo', '--channel',
                                'BETA', '--promote-from', '1.2.3-beta.production.' + SHA]), \
             patch.object(release, 'promote') as promote:
            output = io.StringIO()
            with contextlib.redirect_stderr(output), self.assertRaises(SystemExit) as error:
                release.main()
            self.assertEqual(error.exception.code, 2)
            self.assertIn('requires production', output.getvalue())
            promote.assert_not_called()


class GitHubAdapterTest(unittest.TestCase):
    def test_edit_surfaces_github_failure_reason(self):
        gh = release.GitHub('owner/repo')
        with patch.object(gh, 'get_release', return_value={'id': 42}), patch.object(
            release.subprocess, 'run',
            return_value=subprocess.CompletedProcess([], 1, '', 'HTTP 422: invalid release'),
        ):
            with self.assertRaisesRegex(RuntimeError, 'HTTP 422: invalid release'):
                gh.edit('1.2.3', 'Finished notes', False)

    def test_only_404_is_treated_as_missing(self):
        gh = release.GitHub('owner/repo')
        for status, missing in [(404, True), (403, False), (500, False)]:
            result = subprocess.CompletedProcess([], 1, '', f'gh: error (HTTP {status})')
            with patch.object(release.subprocess, 'run', return_value=result):
                if missing:
                    self.assertIsNone(gh.api('releases/tags/1.2.3', optional=True))
                else:
                    with self.assertRaises(RuntimeError):
                        gh.api('releases/tags/1.2.3', optional=True)

    def test_annotated_tags_are_peeled_to_commits(self):
        gh = release.GitHub('owner/repo')
        with patch.object(gh, 'api', side_effect=[
            {'object': {'type': 'tag', 'sha': 'b' * 40}},
            {'object': {'type': 'commit', 'sha': SHA}},
        ]):
            self.assertEqual(gh.tag_commit('1.2.3'), SHA)

    def test_draft_release_is_found_when_tag_endpoint_returns_404(self):
        gh = release.GitHub('owner/repo')
        draft = dict(id=42, tag_name='1.2.3', draft=True, assets=[])
        with patch.object(gh, 'api', return_value=None), patch.object(
            release, 'run', side_effect=[json.dumps([[draft]]), '[[]]']
        ):
            self.assertEqual(gh.get_release('1.2.3'), draft)

    def test_notes_and_release_flags_use_structured_cli_arguments(self):
        gh = release.GitHub('owner/repo')
        calls = []
        def capture(*args):
            body = Path(args[args.index('--notes-file') + 1]).read_text()
            calls.append((args, body))
            return ''
        with patch.object(release, 'run', side_effect=capture):
            gh.create('1.2.3', SHA, 'Literal `text` and $values', False)
        self.assertIn('--draft', calls[0][0])
        self.assertIn(SHA, calls[0][0])
        self.assertEqual(calls[0][1], 'Literal `text` and $values')
        with patch.object(gh, 'get_release', return_value={'id': 42}), patch.object(
            release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')
        ) as execute:
            gh.edit('1.2.3', 'Finished notes', False)
            command = execute.call_args.args[0]
            payload = json.loads(execute.call_args.kwargs['input'])
            self.assertIn('PATCH', command)
            self.assertIn('repos/owner/repo/releases/42', command)
            self.assertFalse(payload['prerelease'])
            self.assertFalse(payload['draft'])
            self.assertEqual(payload['make_latest'], 'legacy')
            self.assertEqual(payload['body'], 'Finished notes')
            gh.edit('1.2.3-beta.production.' + SHA, 'Beta notes', True)
            payload = json.loads(execute.call_args.kwargs['input'])
            self.assertTrue(payload['prerelease'])
            self.assertEqual(payload['make_latest'], 'false')



if __name__ == '__main__':
    unittest.main()
