import io
import plistlib
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import Mock, patch

import release_train_fakes  # adds repository scripts to sys.path
from release_train import runner, store_review


class StoreReviewTest(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.repo = Path(scratch.name)
        self.git('init', '-q')
        self.enterContext(patch.object(store_review, 'ROOT', self.repo))
        self.plist({'UIBackgroundModes': ['fetch']})
        self.write('mobile/android/app/src/main/AndroidManifest.xml', '<manifest/>')
        self.base = self.commit()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True).strip()

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
