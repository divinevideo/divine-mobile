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
STORE_ACTIONS = {'app-store', 'play-production'}


def git(*args):
    try:
        return subprocess.run(
            ['git', *args], cwd=ROOT, capture_output=True, check=True
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        raise ProviderError(
            'could not compare the candidate with its live production source. '
            'Verify release provenance and Git history before submitting.'
        ) from None


def ios_plist(source):
    try:
        data = plistlib.loads(git('show', f'{source}:{IOS_PLIST}'))
    except (plistlib.InvalidFileException, ExpatError, ValueError, OverflowError):
        data = None
    if not isinstance(data, dict):
        raise ProviderError('cannot read the iOS Runner Info.plist at the selected commit.')
    return data


def ios_findings(base, source, paths):
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
                'Verify iOS permission prompts, background use, sign-in and '
                f'export declarations as applicable. {APPLE}'
            )
    if any(path.endswith('/InfoPlist.strings') for path in paths):
        findings.append(f'Verify the localized iOS permission prompts explain the app’s actual use. {APPLE}')
    if any(path.endswith(('.xcprivacy', '.entitlements')) for path in paths):
        findings.append(
            'Check iOS privacy manifests and entitlements against the app and '
            f'App Store Connect disclosures. {APPLE}'
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
    git('merge-base', '--is-ancestor', base, source)
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
    findings = ios_findings(base, source, paths) if platform == 'ios' else []
    if platform == 'android' and any(
        (path.endswith('/AndroidManifest.xml') and not any(
            f'/src/{source_set}/' in path for source_set in ('debug', 'profile', 'androidTest')
        ))
        or path in {
            'mobile/android/app/build.gradle', 'mobile/android/app/build.gradle.kts',
            'mobile/android/gradle.properties',
        }
        or path.startswith('mobile/android/fastlane/')
        for path in paths
    ):
        findings.append(
            'Check the release bundle’s merged permissions, target API, Play '
            f'listing and App content declarations. {PLAY}'
        )
    policy = APPLE if platform == 'ios' else PLAY_UGC
    if any(path.startswith((
        'mobile/lib/features/chat/', 'mobile/lib/screens/inbox/',
        'mobile/lib/blocs/safety_settings/', 'mobile/lib/screens/safety_settings',
        'mobile/lib/services/content_reporting', 'mobile/lib/services/blocklist',
        'mobile/lib/widgets/report_', 'mobile/lib/screens/settings/moderation',
        'mobile/lib/services/content_moderation', 'mobile/packages/content_blocklist_repository/lib/',
        'mobile/lib/blocs/report/', 'mobile/lib/widgets/video_feed_item/actions/report_',
        'mobile/lib/blocs/other_profile/', 'mobile/lib/widgets/profile/unavailable_profile_actions',
        'mobile/lib/widgets/profile/blocked_user_screen', 'mobile/lib/services/report_retry_service',
        'mobile/lib/providers/moderation_providers', 'mobile/lib/blocs/dm/conversation_actions/',
    )) for path in paths):
        findings.append(
            'Test the changed moderation flows on the candidate, including '
            f'reporting content and accounts and blocking abusive users. {policy}'
        )
    if any(path.startswith((
        'mobile/lib/screens/auth/', 'mobile/lib/features/oauth/',
        'mobile/lib/widgets/delete_account_', 'mobile/lib/screens/settings/legal_',
        'mobile/lib/screens/settings/support_center', 'mobile/lib/screens/minor_account',
        'mobile/lib/blocs/minor_consent_', 'mobile/lib/blocs/analytics_consent/',
        'mobile/lib/services/account_deletion_', 'mobile/lib/blocs/account_deletion_',
        'mobile/lib/constants/terms_acceptance_', 'mobile/lib/services/auth_service',
        'mobile/lib/router/routes/auth_routes', 'mobile/lib/blocs/divine_auth/',
    )) for path in paths):
        policy = APPLE if platform == 'ios' else PLAY
        findings.append(
            'Verify reviewer access, sign-in, account deletion, consent and '
            f'legal/support links as affected by this change. {policy}'
        )
    return findings


def check_candidate(action, snapshot, approval):
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
        findings = findings_for(platform, baseline['sha'], source)
    except ProviderError as error:
        raise ProviderError(f'{label}: {error}') from None
    label += f" against production {baseline['version']}+{number} ({baseline['sha']})"
    if not findings:
        return f'{label}: no issues detected by the source preflight.'
    digest = hashlib.sha256(json.dumps([
        platform,
        [build['version'], build['number'], source, build.get('id')],
        [baseline['version'], number, baseline['sha'], baseline.get('id')],
        findings,
    ]).encode()).hexdigest()
    token = f'{platform}-{digest}'
    if approval == token:
        return f'{label}: release operator confirmed the flagged checks. {" ".join(findings)}'
    raise ProviderError(
        f'{label}: review required. {" ".join(findings)} '
        f'After verifying the exact build and store listing, dispatch the release train with '
        f'`approve_store_review={token}` and `dry_run=false`.'
    )


def screen(plan, snapshot, approval, *, dry):
    """Remove blocked submissions before journaling and describe them in the run summary."""
    for key in ('actions', 'proposed'):
        actions = plan.get(key, [])
        for action in list(actions):
            if action['kind'] not in STORE_ACTIONS:
                continue
            prefix = action['platform'] + ' store review preflight: '
            preview = dry or key == 'proposed'
            try:
                result = check_candidate(action, snapshot, '' if preview else approval)
            except ProviderError as error:
                actions.remove(action)
                plan['reasons' if preview else 'errors'].append(prefix + str(error))
            else:
                plan['reasons'].append(prefix + result)
