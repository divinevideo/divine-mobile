"""Screen the source of a production candidate before either store is changed."""

from __future__ import annotations

import hashlib
import json
import plistlib
import subprocess
from xml.parsers.expat import ExpatError

from release_train.providers import ProviderError
from release_train.release_notes import ROOT, SHA, production_build

APPLE = 'https://developer.apple.com/app-store/review/guidelines/'
PLAY = 'https://support.google.com/googleplay/android-developer/answer/9859455'
PLAY_UGC = 'https://support.google.com/googleplay/android-developer/answer/9876937'
IOS_PLIST = 'mobile/ios/Runner/Info.plist'
IOS_PROJECT = 'mobile/ios/Runner.xcodeproj/project.pbxproj'
# Release builds take their Flutter version, and with it Android's targetSdk, from here.
CODEMAGIC = 'codemagic.yaml'
STORE_ACTIONS = {'app-store', 'play-production'}
# Screens and the blocs, services, providers and packages that carry out the flow.
MODERATION_PATHS = (
    'mobile/lib/features/chat/', 'mobile/lib/screens/inbox/',
    'mobile/lib/blocs/safety_settings/', 'mobile/lib/screens/safety_settings',
    'mobile/lib/services/content_reporting', 'mobile/lib/services/blocklist',
    'mobile/lib/widgets/report_',
    'mobile/lib/services/content_moderation', 'mobile/packages/content_blocklist_repository/lib/',
    'mobile/lib/blocs/report/', 'mobile/lib/widgets/video_feed_item/actions/report_',
    'mobile/lib/blocs/other_profile/', 'mobile/lib/widgets/profile/unavailable_profile_actions',
    'mobile/lib/widgets/profile/blocked_user_screen', 'mobile/lib/widgets/profile/more_sheet/',
    'mobile/lib/services/report_retry_service',
    'mobile/lib/providers/moderation_providers', 'mobile/lib/blocs/dm/conversation_actions/',
    'mobile/lib/screens/other_profile_screen', 'mobile/lib/widgets/video_feed_item/video_feed_item.dart',
    'mobile/lib/blocs/comments/comment_reactions/comment_reactions_bloc',
    'mobile/lib/screens/comments/widgets/comment_options_modal',
    'mobile/packages/comments_repository/lib/src/comment_moderation_repository',
    'mobile/lib/providers/social_providers', 'mobile/lib/providers/repository_providers',
    'mobile/lib/config/official_accounts',
    'mobile/packages/db_client/lib/src/database/daos/pending_reports_dao',
    'mobile/lib/services/nsfw_content_filter', 'mobile/lib/services/moderation_label_service',
    'mobile/lib/services/video_block_policy', 'mobile/packages/content_policy/lib/',
    'mobile/lib/widgets/content_warning', 'mobile/lib/widgets/video_feed_item/content_warning_',
    'mobile/lib/widgets/video_feed_item/moderated_content_overlay',
    'mobile/lib/blocs/dm/message_requests/', 'mobile/lib/blocs/dm/minor_dm_approval',
    'mobile/lib/blocs/dm/conversation_list/protected_minor_inbox_gate',
)
ACCESS_PATHS = (
    'mobile/lib/screens/auth/', 'mobile/lib/features/oauth/',
    'mobile/lib/widgets/delete_account_', 'mobile/lib/screens/settings/legal_',
    'mobile/lib/screens/settings/support_center', 'mobile/lib/screens/minor_account',
    'mobile/lib/blocs/minor_consent_', 'mobile/lib/blocs/analytics_consent/',
    'mobile/lib/services/account_deletion_', 'mobile/lib/blocs/account_deletion_',
    'mobile/lib/constants/terms_acceptance_', 'mobile/lib/services/auth_service',
    'mobile/lib/services/auth/',
    'mobile/lib/router/routes/auth_routes', 'mobile/lib/blocs/divine_auth/',
    'mobile/packages/keycast_flutter/lib/', 'mobile/lib/providers/auth_providers',
    'mobile/lib/router/app_router_redirect', 'mobile/lib/blocs/welcome/',
    'mobile/lib/widgets/geo_blocking_gate',
    'mobile/lib/blocs/email_verification/', 'mobile/lib/services/email_verification_listener',
    'mobile/lib/services/age_verification_service', 'mobile/lib/widgets/age_verification_dialog',
    'mobile/lib/screens/account_deletion_recovery_screen',
    'mobile/lib/router/routes/account_deletion_recovery_routes',
    'mobile/lib/repositories/account_deletion_recovery_repository',
    'mobile/lib/screens/settings/nostr_settings_screen',
    'mobile/lib/services/user_data_cleanup_service',
    'mobile/lib/screens/settings/privacy_settings_screen', 'mobile/lib/services/analytics_service',
    'mobile/lib/providers/analytics_providers',
    'mobile/packages/analytics/lib/src/firebase_analytics_event_sink',
    'mobile/lib/repositories/minor_account_review_repository',
    'mobile/lib/blocs/support_contact/', 'mobile/lib/services/zendesk_support_service',
    'mobile/lib/services/support_email_composer',
)


COMPARE_FAILED = (
    'could not compare the candidate with its live production source. '
    'Verify release provenance and Git history before submitting.'
)


def git(*args):
    try:
        return subprocess.run(
            ['git', *args], cwd=ROOT, capture_output=True, check=True
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        raise ProviderError(COMPARE_FAILED) from None


def require_ancestor(base, source):
    try:
        status = subprocess.run(
            ['git', 'merge-base', '--is-ancestor', base, source], cwd=ROOT, capture_output=True
        ).returncode
    except OSError:
        status = None
    if status == 1:
        raise ProviderError(
            'the live production source is not an ancestor of the candidate, so the candidate '
            'could drop changes already in production. Submit a build that contains it.'
        )
    if status != 0:
        raise ProviderError(COMPARE_FAILED)


def ios_plist(commit):
    try:
        data = plistlib.loads(git('show', f'{commit}:{IOS_PLIST}'))
    except (ProviderError, plistlib.InvalidFileException, ExpatError, ValueError, OverflowError):
        data = None
    if not isinstance(data, dict):
        raise ProviderError(f'cannot read {IOS_PLIST} at {commit}.')
    return data


def ios_findings(base, source, paths, *, dependencies_changed):
    plist = ios_plist(source)
    modes = plist.get('UIBackgroundModes', [])
    if not isinstance(modes, list) or any(not isinstance(mode, str) for mode in modes):
        raise ProviderError('invalid UIBackgroundModes in the candidate Info.plist.')
    unsupported = {'audio', 'bluetooth-central', 'bluetooth-peripheral'}
    regressions = sorted(unsupported.intersection(modes))
    if regressions:
        raise ProviderError(
            f'Apple 2.5.4 background-mode regression ({", ".join(regressions)}). '
            f'Remove the unsupported declarations from the candidate. {APPLE}'
        )

    findings = []
    if IOS_PLIST in paths:
        previous = ios_plist(base)
        relevant = {
            'UIBackgroundModes', 'BGTaskSchedulerPermittedIdentifiers',
            'ITSAppUsesNonExemptEncryption', 'NSAppTransportSecurity', 'CFBundleURLTypes',
        }
        purpose_strings = {
            key for key in plist.keys() | previous.keys()
            if isinstance(key, str) and key.endswith('UsageDescription')
        }
        if any(plist.get(key) != previous.get(key) for key in relevant | purpose_strings):
            findings.append(
                'Verify iOS permission prompts, background use, sign-in, App Transport '
                f'Security and export declarations as applicable. {APPLE}'
            )
    if any(path.endswith('/InfoPlist.strings') for path in paths):
        findings.append(f'Verify the localized iOS permission prompts explain the app’s actual use. {APPLE}')
    if (dependencies_changed or 'mobile/ios/Podfile' in paths
            or any(path.endswith(('.xcprivacy', '.entitlements')) for path in paths)):
        findings.append(
            'Check iOS privacy manifests and entitlements, including any a dependency or '
            f'Flutter upgrade adds, against the app and App Store Connect disclosures. {APPLE}'
        )

    device_settings_changed = git(
        'diff', '--name-only', '--no-renames', '-G', 'TARGETED_DEVICE_FAMILY',
        base, source, '--', IOS_PROJECT, ':(glob)mobile/ios/**/*.xcconfig',
    )
    if device_settings_changed or any(path.startswith('mobile/ios/fastlane/') for path in paths):
        findings.append(
            'Under Apple guideline 2.3.3, verify iPad screenshots are genuine captures for the '
            f'supported devices and match the current app. {APPLE}'
        )
    return findings


def findings_for(platform, base, source):
    require_ancestor(base, source)
    changed = git('diff', '--no-renames', '--name-only', '-z', base, source, '--', 'mobile')
    excluded = (
        'mobile/macos/', 'mobile/windows/', 'mobile/linux/', 'mobile/web/',
        'mobile/android/' if platform == 'ios' else 'mobile/ios/',
    )
    paths = {
        path for path in changed.decode('utf-8', errors='surrogateescape').split('\0')
        if path and not path.startswith(excluded)
        and '/example/' not in path and '/test/' not in path
    }
    # Plugins merge permissions and privacy manifests into the bundle, and the
    # pinned Flutter version sets Android's targetSdk.
    dependencies_changed = 'mobile/pubspec.lock' in paths or bool(git(
        'diff', '--name-only', '--no-renames', '-G', '(FLUTTER_VERSION|flutter):',
        base, source, '--', CODEMAGIC,
    ))
    findings = (
        ios_findings(base, source, paths, dependencies_changed=dependencies_changed)
        if platform == 'ios' else []
    )
    if platform == 'android' and (dependencies_changed or any(
        (path.endswith('/AndroidManifest.xml') and not any(
            f'/src/{source_set}/' in path for source_set in ('debug', 'profile', 'androidTest')
        ))
        or path in {
            'mobile/android/app/build.gradle', 'mobile/android/app/build.gradle.kts',
            'mobile/android/gradle.properties',
        }
        or path.startswith('mobile/android/fastlane/')
        for path in paths
    )):
        findings.append(
            'Check the release bundle’s merged permissions, target API, Play '
            f'listing and App content declarations. {PLAY}'
        )
    policy = APPLE if platform == 'ios' else PLAY_UGC
    if any(path.startswith(MODERATION_PATHS) for path in paths):
        findings.append(
            'Test the changed moderation flows on the candidate, including filtering '
            'objectionable content, reporting content and accounts and blocking '
            f'abusive users. {policy}'
        )
    if any(path.startswith(ACCESS_PATHS) for path in paths):
        policy = APPLE if platform == 'ios' else PLAY
        findings.append(
            'Verify reviewer access, sign-in, account deletion, consent and '
            f'legal/support links as affected by this change. {policy}'
        )
    return findings


def check_candidate(action, snapshot, approvals):
    platform = action['platform']
    build = action['build']
    source = build.get('sha')
    if not SHA.fullmatch(source or ''):
        raise ProviderError('candidate source provenance is missing. Verify the store build identity.')
    label = f"{build['version']}+{build['number']} ({source})"
    try:
        baseline = production_build(platform, snapshot.get(platform, {}))
        number = baseline.get('number')
        if type(number) is not int or number < 1:
            raise ProviderError('published build number is missing. Reconcile release provenance.')
        label += f" against production {baseline['version']}+{number} ({baseline['sha']})"
        findings = findings_for(platform, baseline['sha'], source)
    except ProviderError as error:
        raise ProviderError(f'{label}: {error}') from None
    if not findings:
        return None, f'{label}: none of the watched store review paths changed.'
    digest = hashlib.sha256(json.dumps([
        platform,
        [build['version'], build['number'], source, build.get('id')],
        [baseline['version'], number, baseline['sha'], baseline.get('id')],
        findings,
    ]).encode()).hexdigest()
    token = f'{platform}-{digest}'
    if token in approvals:
        return token, f'{label}: release operator confirmed the flagged checks. {" ".join(findings)}'
    raise ProviderError(
        f'{label}: review required. {" ".join(findings)} '
        f'After verifying the exact build and store listing, dispatch the release train with '
        f'`approve_store_review={token}` and `dry_run=false`.'
    )


def screen(plan, snapshot, approval, *, dry, confirmed=None):
    """Remove blocked submissions before journaling and describe them in the run summary.

    `confirmed` maps a platform to the confirmation a live dispatch already gave,
    so a deferred or retried submission keeps it while its build, baseline and
    findings are unchanged. Returns the confirmations this live run accepted.
    """
    confirmed = confirmed or {}
    accepted = {}
    for key in ('actions', 'proposed'):
        actions = plan.get(key, [])
        for action in list(actions):
            if action['kind'] not in STORE_ACTIONS:
                continue
            platform = action['platform']
            prefix = platform + ' store review preflight: '
            preview = dry or key == 'proposed'
            approvals = {confirmed.get(platform)} | (set() if preview else {approval})
            try:
                token, result = check_candidate(action, snapshot, approvals - {None, ''})
            except ProviderError as error:
                actions.remove(action)
                plan['reasons' if preview else 'errors'].append(prefix + str(error))
            else:
                if token and not preview:
                    accepted[platform] = token
                plan['reasons'].append(prefix + result)
    return accepted
