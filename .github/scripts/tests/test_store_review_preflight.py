import copy
import io
import os
import plistlib
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import Mock, patch

import release_train_fakes  # adds repository scripts to sys.path
from release_train import release_notes, runner, store_review
from release_train.providers import BeforeStoreMutationError, DeferredReview


class StoreReviewTest(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.repo = Path(scratch.name)
        self.git('-c', 'init.defaultBranch=main', 'init', '-q')
        self.enterContext(patch.object(store_review, 'ROOT', self.repo))
        self.plist({'UIBackgroundModes': ['fetch']})
        self.write('mobile/android/app/src/main/AndroidManifest.xml', '<manifest/>')
        self.base = self.commit()

    def git(self, *args):
        # A developer's global signing or hook settings must not change the fixture.
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        return subprocess.check_output(
            ['git', '-C', str(self.repo), *args], text=True, env=env
        ).strip()

    def write(self, name, contents):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        return path

    def plist(self, data):
        path = self.repo / 'mobile/ios/Runner/Info.plist'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(data))

    def commit(self):
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                 'commit', '-qm', 'Fixture')
        return self.git('rev-parse', 'HEAD')

    def action(self, platform, candidate, number=2):
        kind = 'app-store' if platform == 'ios' else 'play-production'
        return {'kind': kind, 'platform': platform,
                'build': {'number': number, 'version': '1.0.2', 'sha': candidate}}

    def snapshot(self, base):
        return {
            'ios': {'versions': [{'state': 'READY_FOR_DISTRIBUTION', 'version': '1.0.1', 'build_id': 'live'}],
                    'builds': [{'id': 'live', 'number': 1, 'version': '1.0.1', 'sha': base}]},
            'android': {'production': [{'number': 1, 'version': '1.0.1', 'sha': base}]},
        }

    def screen(self, actions=(), *, proposed=(), approval='', dry=False, baseline=None):
        plan = {'actions': list(actions), 'proposed': list(proposed), 'errors': [], 'reasons': []}
        store_review.screen(plan, self.snapshot(baseline or self.base), approval, dry=dry)
        return plan

    def token_for(self, action):
        report = self.screen([action])
        return report['errors'][0].split('approve_store_review=')[1].split('`')[0]

    def ticks(self, steps):
        """Run the coordinator once per (event, approval, action, outcome), keeping its state."""
        saved = [{}]
        env = {
            'GITHUB_REPOSITORY': 'owner/repo',
            'GITHUB_REF': 'refs/heads/main',
            'GITHUB_SHA': self.base,
            'GITHUB_WORKFLOW_SHA': self.base,
            'GITHUB_WORKFLOW_REF': 'owner/repo/.github/workflows/release_train.yml@refs/heads/main',
            'RELEASE_TRAIN_ANDROID': 'production',
            'RELEASE_DRY_RUN': 'false',
        }
        results = []
        for event, approval, action, outcome in steps:
            runtime = Mock()
            runtime.snapshot.return_value = self.snapshot(self.base)
            runtime.store.load.side_effect = lambda: copy.deepcopy(saved[-1])
            runtime.store.save.side_effect = lambda state: saved.append(copy.deepcopy(state))
            runtime.ledger.paths.return_value = []
            runtime.execute.side_effect = outcome
            with (
                patch.object(runner, 'Runtime', return_value=runtime),
                patch.object(runner.subprocess, 'check_output', return_value=self.base),
                patch.object(runner, 'observe', side_effect=lambda snapshot, state: state),
                patch.object(runner, 'reconcile'),
                patch.object(runner, 'plan_tick', side_effect=lambda *_: {
                    'actions': [copy.deepcopy(action)], 'errors': [], 'reasons': []}),
                redirect_stdout(io.StringIO()),
            ):
                status = runner.main(env | {
                    'GITHUB_EVENT_NAME': event, 'RELEASE_APPROVE_STORE_REVIEW': approval})
            results.append((status, runtime.execute.called, copy.deepcopy(saved[-1])))
        return results

    def test_detects_an_exact_candidate_regression_even_if_head_was_fixed(self):
        self.plist({'UIBackgroundModes': ['fetch', 'audio', 'bluetooth-central']})
        build = self.action('ios', self.commit())
        self.plist({'UIBackgroundModes': ['fetch']})
        self.commit()
        plan = self.screen([build], approval='any')
        self.assertFalse(plan['actions'])
        self.assertRegex(plan['errors'][0], r'2\.5\.4.*audio.*bluetooth-central')
        self.assertNotIn('approve_store_review', plan['errors'][0])

    def test_shared_flow_change_requires_approval_bound_to_store_build_and_baseline(self):
        self.write('mobile/lib/main.dart', 'new baseline')
        newer_baseline = self.commit()
        self.write('mobile/lib/widgets/delete_account_dialog.dart', 'account deletion')
        candidate = self.commit()
        ios = self.action('ios', candidate)
        android = self.action('android', candidate)
        report = self.screen([ios, android])
        self.assertFalse(report['actions'])
        self.assertIn('account deletion', report['errors'][0])
        self.assertIn('account deletion', report['errors'][1])
        approval = report['errors'][0].split('approve_store_review=')[1].split('`')[0]
        self.assertEqual(self.screen([ios, android], approval=approval)['actions'], [ios])
        self.assertFalse(self.screen([self.action('ios', candidate, 3)], approval=approval)['actions'])
        self.assertFalse(self.screen([ios], approval=approval, baseline=newer_baseline)['actions'])
        self.write('mobile/lib/main.dart', 'new candidate')
        new_candidate = self.action('ios', self.commit())
        self.assertFalse(self.screen([new_candidate], approval=approval)['actions'])

    def test_replacement_production_build_at_the_same_sha_invalidates_confirmation(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'changed report UI')
        action = self.action('android', self.commit())
        report = self.screen([action])
        approval = report['errors'][0].split('approve_store_review=')[1].split('`')[0]
        snapshot = self.snapshot(self.base)
        snapshot['android']['production'][0]['number'] = 3
        plan = {'actions': [action], 'errors': [], 'reasons': []}
        store_review.screen(plan, snapshot, approval, dry=False)
        self.assertFalse(plan['actions'])
        self.assertIn('production 1.0.1+3', plan['errors'][0])

    def test_unaffected_production_and_beta_remain_eligible(self):
        self.write('mobile/android/app/src/main/AndroidManifest.xml', '<manifest><uses-permission/></manifest>')
        candidate = self.commit()
        ios = self.action('ios', candidate)
        android = self.action('android', candidate)
        beta = {'kind': 'public-beta', 'platform': 'ios', 'build': ios['build']}
        plan = self.screen([ios, android, beta])
        self.assertEqual(plan['actions'], [ios, beta])
        self.assertIn('permissions', plan['errors'][0])

    def test_dry_run_reports_blockers_without_showing_blocked_submissions_as_eligible(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'new report UI')
        candidate = self.commit()
        plan = self.screen([self.action('ios', candidate)],
                           proposed=[self.action('android', candidate)], dry=True)
        self.assertEqual(plan['actions'], [])
        self.assertEqual(plan['proposed'], [])
        self.assertEqual(plan['errors'], [])
        self.assertEqual(sum('report' in reason for reason in plan['reasons']), 2)

    def test_missing_provenance_never_allows_a_submission_or_creates_an_intent(self):
        self.write('mobile/lib/main.dart', 'example')
        candidate = self.commit()
        snapshot = self.snapshot(self.base)
        snapshot['ios']['builds'].clear()
        plan = {'actions': [self.action('ios', candidate)], 'errors': [], 'reasons': []}
        store_review.screen(plan, snapshot, 'any', dry=False)
        store, provider, state = Mock(), Mock(), {}
        runner.execute_plan(plan, state, snapshot, store, provider)
        store.save.assert_not_called()
        provider.execute.assert_not_called()
        self.assertEqual(state, {})
        self.assertIn('missing verified source provenance', plan['errors'][0])

    def test_deleted_policy_surface_and_ipad_project_changes_are_flagged(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'existing report UI')
        project = 'mobile/ios/Runner.xcodeproj/project.pbxproj'
        self.write(project, 'TARGETED_DEVICE_FAMILY = 1;')
        base = self.commit()
        (self.repo / 'mobile/lib/widgets/report_content_dialog.dart').unlink()
        self.write(project, 'TARGETED_DEVICE_FAMILY = "1,2";')
        plan = self.screen([self.action('ios', self.commit())], baseline=base)
        self.assertIn('report', plan['errors'][0])
        self.assertIn('iPad screenshots', plan['errors'][0])

    def test_device_coverage_change_is_flagged_when_configuration_values_trade_places(self):
        project = 'mobile/ios/Runner.xcodeproj/project.pbxproj'
        self.write(project, 'Runner Release {\n    TARGETED_DEVICE_FAMILY = 1;\n}\n'
                   'Widget Release {\n    TARGETED_DEVICE_FAMILY = "1,2";\n}\n')
        base = self.commit()
        self.write(project, 'Runner Release {\n    TARGETED_DEVICE_FAMILY = "1,2";\n}\n'
                   'Widget Release {\n    TARGETED_DEVICE_FAMILY = 1;\n}\n')
        plan = self.screen([self.action('ios', self.commit())], baseline=base)
        self.assertFalse(plan['actions'])
        self.assertIn('iPad screenshots', plan['errors'][0])

    def test_account_deletion_backend_changes_prompt_both_stores(self):
        self.write('mobile/lib/services/account_deletion_service.dart', 'changed request')
        candidate = self.commit()
        actions = [self.action('ios', candidate), self.action('android', candidate)]
        plan = self.screen(actions)
        self.assertFalse(plan['actions'])
        self.assertTrue(all('account deletion' in error for error in plan['errors']))

    def test_primary_reporting_blocking_and_reviewer_access_changes_are_flagged(self):
        cases = {
            'mobile/lib/blocs/report/report_submission_cubit.dart': 'moderation flows',
            'mobile/lib/widgets/video_feed_item/actions/report_action_button.dart': 'moderation flows',
            'mobile/lib/widgets/profile/unavailable_profile_actions.dart': 'moderation flows',
            'mobile/lib/widgets/profile/more_sheet/block_confirmation_view.dart': 'moderation flows',
            'mobile/lib/services/auth_service.dart': 'reviewer access',
            'mobile/lib/services/auth/oauth_session_coordinator.dart': 'reviewer access',
            'mobile/lib/router/routes/auth_routes.dart': 'reviewer access',
        }
        baseline = self.base
        for path, finding in cases.items():
            with self.subTest(path=path):
                self.write(path, 'changed policy-sensitive behavior')
                source = self.commit()
                actions = [self.action('ios', source), self.action('android', source)]
                plan = self.screen(actions, baseline=baseline)
                baseline = source
                self.assertFalse(plan['actions'])
                self.assertEqual(len(plan['errors']), 2)
                self.assertTrue(all(finding in error for error in plan['errors']))

    def test_code_that_carries_out_review_critical_flows_is_flagged_on_both_stores(self):
        cases = {
            'mobile/lib/blocs/comments/comment_reactions/comment_reactions_bloc.dart': 'moderation flows',
            'mobile/lib/screens/comments/widgets/comment_options_modal.dart': 'moderation flows',
            'mobile/packages/comments_repository/lib/src/comment_moderation_repository.dart': 'moderation flows',
            'mobile/lib/screens/other_profile_screen.dart': 'moderation flows',
            'mobile/lib/providers/social_providers.dart': 'moderation flows',
            'mobile/lib/services/nsfw_content_filter.dart': 'filtering objectionable content',
            'mobile/lib/widgets/content_warning.dart': 'moderation flows',
            'mobile/lib/widgets/video_feed_item/moderated_content_overlay.dart': 'moderation flows',
            'mobile/lib/services/moderation_label_service.dart': 'moderation flows',
            'mobile/packages/content_policy/lib/src/policy_rule.dart': 'moderation flows',
            'mobile/lib/blocs/dm/message_requests/message_request_actions_cubit.dart': 'moderation flows',
            'mobile/lib/blocs/dm/minor_dm_approval.dart': 'moderation flows',
            'mobile/lib/blocs/dm/conversation_list/protected_minor_inbox_gate_impl.dart': 'moderation flows',
            'mobile/packages/keycast_flutter/lib/src/oauth/oauth_client.dart': 'reviewer access',
            'mobile/lib/providers/auth_providers.dart': 'reviewer access',
            'mobile/lib/router/app_router_redirect.dart': 'reviewer access',
            'mobile/lib/screens/account_deletion_recovery_screen.dart': 'reviewer access',
            'mobile/lib/repositories/account_deletion_recovery_repository.dart': 'reviewer access',
            'mobile/lib/screens/settings/privacy_settings_screen.dart': 'reviewer access',
            'mobile/lib/services/analytics_service.dart': 'reviewer access',
            'mobile/lib/blocs/support_contact/support_contact_cubit.dart': 'reviewer access',
            'mobile/lib/services/age_verification_service.dart': 'reviewer access',
            'mobile/lib/blocs/email_verification/email_verification_cubit.dart': 'reviewer access',
        }
        baseline = self.base
        for path, finding in cases.items():
            with self.subTest(path=path):
                self.write(path, 'changed policy-sensitive behavior')
                source = self.commit()
                actions = [self.action('ios', source), self.action('android', source)]
                plan = self.screen(actions, baseline=baseline)
                baseline = source
                self.assertFalse(plan['actions'])
                self.assertEqual(len(plan['errors']), 2)
                self.assertTrue(all(finding in error for error in plan['errors']))

    def test_documented_file_triggers_and_exclusions(self):
        cases = [
            ('ios', 'mobile/ios/Runner/en.lproj/InfoPlist.strings', 'changed', 'localized iOS permission prompts'),
            ('ios', 'mobile/ios/Runner/PrivacyInfo.xcprivacy', 'changed', 'privacy manifests'),
            ('ios', 'mobile/ios/Runner/Runner.entitlements', 'changed', 'privacy manifests'),
            ('ios', 'mobile/ios/fastlane/metadata/en-US/description.txt', 'changed', 'iPad screenshots'),
            ('ios', 'mobile/ios/Flutter/Release.xcconfig', 'TARGETED_DEVICE_FAMILY = 1,2', 'iPad screenshots'),
            ('android', 'mobile/android/app/build.gradle.kts', 'changed', 'merged permissions'),
            ('android', 'mobile/android/gradle.properties', 'changed', 'merged permissions'),
            ('android', 'mobile/android/fastlane/metadata/android/en-US/title.txt', 'changed', 'merged permissions'),
            ('android', 'mobile/android/app/src/debug/AndroidManifest.xml', 'changed', None),
            ('android', 'mobile/packages/cam/example/android/app/src/main/AndroidManifest.xml', 'changed', None),
            ('android', 'mobile/packages/cam/android/src/test/AndroidManifest.xml', 'changed', None),
        ]
        baseline = self.base
        for platform, path, contents, finding in cases:
            with self.subTest(path=path):
                self.write(path, contents)
                action = self.action(platform, self.commit())
                plan = self.screen([action], baseline=baseline)
                baseline = action['build']['sha']
                if finding:
                    self.assertFalse(plan['actions'])
                    self.assertIn(finding, plan['errors'][0])
                else:
                    self.assertEqual((plan['actions'], plan['errors']), ([action], []))

    def test_info_plist_policy_keys_and_purpose_strings_are_flagged(self):
        for extra, finding in [({'NSCameraUsageDescription': 'Record loops'}, 'permission prompts'),
                               ({'ITSAppUsesNonExemptEncryption': False}, 'export declarations'),
                               ({'NSAppTransportSecurity': {'NSAllowsLocalNetworking': True}},
                                'App Transport Security'),
                               ({'CFBundleDisplayName': 'Divine'}, None)]:
            with self.subTest(extra=extra):
                self.plist({'UIBackgroundModes': ['fetch'], **extra})
                action = self.action('ios', self.commit())
                plan = self.screen([action])
                self.assertEqual(plan['actions'], [] if finding else [action])
                if finding:
                    self.assertIn(finding, plan['errors'][0])

    def test_each_unsupported_background_mode_is_blocked(self):
        for mode in ('audio', 'bluetooth-central', 'bluetooth-peripheral'):
            with self.subTest(mode=mode):
                self.plist({'UIBackgroundModes': ['fetch', mode]})
                plan = self.screen([self.action('ios', self.commit())], approval='any')
                self.assertFalse(plan['actions'])
                self.assertIn(f'regression ({mode})', plan['errors'][0])

    def test_background_modes_written_as_a_string_are_rejected(self):
        self.plist({'UIBackgroundModes': 'audio'})
        plan = self.screen([self.action('ios', self.commit())], approval='any')
        self.assertFalse(plan['actions'])
        self.assertIn('invalid UIBackgroundModes', plan['errors'][0])

    def test_confirmation_is_bound_to_the_reported_findings(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'changed report UI')
        action = self.action('android', self.commit())
        approval = self.token_for(action)
        original = store_review.findings_for
        with patch.object(store_review, 'findings_for', side_effect=lambda *a: original(*a) + ['New rule.']):
            plan = self.screen([action], approval=approval)
        self.assertFalse(plan['actions'])
        self.assertIn('New rule.', plan['errors'][0])

    def test_proposed_submission_in_a_live_tick_is_reported_not_failed(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'changed report UI')
        plan = self.screen(proposed=[self.action('android', self.commit())], dry=False)
        self.assertEqual((plan['proposed'], plan['errors']), ([], []))
        self.assertIn('review required', plan['reasons'][0])

    def test_candidate_without_verified_source_never_reaches_git(self):
        for sha in (None, 'HEAD'):
            with self.subTest(sha=sha):
                plan = self.screen([self.action('android', sha)], approval='any')
                self.assertFalse(plan['actions'])
                self.assertIn('candidate source provenance is missing', plan['errors'][0])

    def test_production_outside_the_candidate_history_is_named_and_blocks_both_stores(self):
        self.git('checkout', '-q', '-b', 'hotfix')
        self.write('mobile/lib/main.dart', 'hotfix only on a side branch')
        production = self.commit()
        self.git('checkout', '-q', '-')
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'changed report UI')
        candidate = self.commit()
        actions = [self.action('ios', candidate), self.action('android', candidate)]
        plan = self.screen(actions, approval='any', baseline=production)
        self.assertFalse(plan['actions'])
        for error in plan['errors']:
            self.assertIn(f'against production 1.0.1+1 ({production})', error)
            self.assertIn('not an ancestor of the candidate', error)
            self.assertNotIn('approve_store_review', error)

    def test_unreadable_candidate_info_plist_names_the_file_and_commit(self):
        (self.repo / 'mobile/ios/Runner/Info.plist').unlink()
        candidate = self.commit()
        plan = self.screen([self.action('ios', candidate)])
        self.assertFalse(plan['actions'])
        self.assertIn(f'cannot read mobile/ios/Runner/Info.plist at {candidate}', plan['errors'][0])

    def test_dependency_and_flutter_upgrades_prompt_permission_and_privacy_checks(self):
        pin = 'environment:\n  flutter: {0}\n  vars:\n    FLUTTER_VERSION: {0}\n    OTHER: {1}\n'
        self.write('codemagic.yaml', pin.format('3.47.9', 'x'))
        baseline = self.commit()
        cases = [
            ('mobile/pubspec.lock', 'packages: {}\n', True, True),
            ('codemagic.yaml', pin.format('3.47.9', 'y'), False, False),
            ('codemagic.yaml', pin.format('3.48.0', 'y'), True, True),
            ('mobile/ios/Podfile', "platform :ios, '16.0'\n", True, False),
        ]
        for path, contents, ios_flagged, android_flagged in cases:
            with self.subTest(path=path, contents=contents):
                self.write(path, contents)
                source = self.commit()
                ios, android = self.action('ios', source), self.action('android', source)
                plan = self.screen([ios, android], baseline=baseline)
                baseline = source
                self.assertEqual(ios in plan['actions'], not ios_flagged)
                self.assertEqual(android in plan['actions'], not android_flagged)
                errors = ' '.join(plan['errors'])
                self.assertEqual('privacy manifests' in errors, ios_flagged)
                self.assertEqual('merged permissions' in errors, android_flagged)

    def test_main_releases_only_when_live_dispatch_confirms_the_exact_build(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'changed report UI')
        candidate = self.commit()
        action = self.action('android', candidate)
        report = self.screen([action])
        approval = report['errors'][0].split('approve_store_review=')[1].split('`')[0]
        snapshot = self.snapshot(self.base)
        runtime = Mock()
        runtime.snapshot.return_value = snapshot
        runtime.store.load.return_value = {}
        runtime.ledger.paths.return_value = []
        env = {
            'GITHUB_REPOSITORY': 'owner/repo',
            'GITHUB_REF': 'refs/heads/main',
            'GITHUB_SHA': candidate,
            'GITHUB_WORKFLOW_SHA': candidate,
            'GITHUB_WORKFLOW_REF': 'owner/repo/.github/workflows/release_train.yml@refs/heads/main',
            'RELEASE_TRAIN_ANDROID': 'production',
            'RELEASE_APPROVE_STORE_REVIEW': approval,
        }
        for event, dry, status, executed in [
            ('schedule', False, 1, False),
            ('workflow_dispatch', True, 0, False),
            ('workflow_dispatch', False, 0, True),
        ]:
            with self.subTest(event=event, dry=dry):
                runtime.reset_mock()
                plan = {'actions': [action], 'errors': [], 'reasons': []}
                output = io.StringIO()
                with (
                    patch.object(runner, 'Runtime', return_value=runtime),
                    patch.object(runner.subprocess, 'check_output', return_value=candidate),
                    patch.object(runner, 'observe', side_effect=lambda snapshot, state: state),
                    patch.object(runner, 'reconcile'),
                    patch.object(runner, 'plan_tick', return_value=plan),
                    redirect_stdout(output),
                ):
                    self.assertEqual(runner.main(env | {
                        'GITHUB_EVENT_NAME': event, 'RELEASE_DRY_RUN': str(dry).lower(),
                    }), status)
                self.assertEqual(runtime.execute.called, executed)
                self.assertIn('confirmed the flagged checks' if executed else 'review required',
                              output.getvalue())
                if dry:
                    runtime.store.save.assert_not_called()

    def test_confirmed_submission_retries_on_schedule_after_a_deferral_or_refusal(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'changed report UI')
        action = self.action('android', self.commit())
        token = self.token_for(action)
        for setback in [DeferredReview('CHANGES_ALREADY_IN_REVIEW'),
                        BeforeStoreMutationError('Google Play validate edit failed')]:
            with self.subTest(setback=type(setback).__name__):
                first, retry = self.ticks([
                    ('workflow_dispatch', token, action, setback),
                    ('schedule', '', action, None),
                ])
                self.assertTrue(first[1])
                self.assertEqual(first[2]['store_review_confirmations'], {'android': token})
                self.assertEqual(retry[0], 0)
                self.assertTrue(retry[1])
                self.assertEqual(retry[2]['store_review_confirmations'], {})

    def test_kept_confirmation_does_not_cover_another_build(self):
        self.write('mobile/lib/widgets/report_content_dialog.dart', 'changed report UI')
        candidate = self.commit()
        action = self.action('android', candidate)
        replacement = self.action('android', candidate, number=3)
        _, other_build = self.ticks([
            ('workflow_dispatch', self.token_for(action), action,
             DeferredReview('CHANGES_ALREADY_IN_REVIEW')),
            ('schedule', '', replacement, None),
        ])
        self.assertEqual(other_build[0], 1)
        self.assertFalse(other_build[1])


class StoreReviewPathListTest(unittest.TestCase):
    def test_every_watched_prefix_matches_a_tracked_file(self):
        tracked = subprocess.check_output(
            ['git', '-C', str(release_notes.ROOT), 'ls-files', 'mobile'], text=True
        ).splitlines()
        for prefix in store_review.MODERATION_PATHS + store_review.ACCESS_PATHS:
            with self.subTest(prefix=prefix):
                self.assertTrue(any(path.startswith(prefix) for path in tracked))
