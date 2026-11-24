#!/usr/bin/env python3
"""Dispatch and monitor main-only macOS App Store / TestFlight builds from GitHub Actions.

Refreshes encrypted PROVENANCE_TOKEN and public people-list policy in Codemagic's
store_release_credentials group before triggering `macos-build` on `main`.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse

from release_train.providers import ProviderError
from release_train.setup import configure_build_credentials
from start_ios_release import (
    ACTIVE,
    APP_ID,
    ASC_PENDING,
    ASC_TERMINAL,
    SOURCE_PENDING,
    TEAM_ID,
    TERMINAL,
    APIError,
    ReleaseError,
    build_id,
    record,
    request_json,
    sha,
)

WORKFLOW_FILE = 'macos_testflight_release.yml'
WORKFLOW_ID = 'macos-build'
ALLOWED_ENVS = {'PRODUCTION', 'STAGING', 'POC'}


def validate_macos_build(build, expected_sha, *, require_main=True):
    source_pending = (
        isinstance(build, dict)
        and build.get('status') in SOURCE_PENDING
        and build.get('branch') is None
        and build.get('commit') is None
    )
    if (
        not isinstance(build, dict)
        or build.get('app_id') != APP_ID
        or (build.get('workflow') or {}).get('id') != WORKFLOW_ID
        or (require_main and ((build.get('branch') != 'main' and not source_pending) or build.get('tag')))
    ):
        raise ReleaseError('Codemagic build identity does not match the requested main macOS release.')
    build_id(build.get('id'))
    status = build.get('status')
    asc = build.get('app_store_connect_status')
    if status not in ACTIVE | TERMINAL or (asc is not None and asc not in ASC_PENDING | ASC_TERMINAL):
        raise ReleaseError('Unrecognized Codemagic status; inspect the build before continuing.')
    commit = (build.get('commit') or {}).get('hash')
    if commit is not None and commit != expected_sha:
        raise ReleaseError('Codemagic fetched a different source commit; release refused. Inspect the build immediately.')
    return status, asc, commit


def run_release(
    env,
    *,
    request=request_json,
    checked_out_sha=None,
    sleep=time.sleep,
    monotonic=time.monotonic,
    timeout=4800,
):
    default_env = env.get('NATIVE_DEFAULT_ENV') or 'PRODUCTION'
    if default_env not in ALLOWED_ENVS:
        raise ReleaseError('Invalid DEFAULT_ENV; no build started.')
    inputs = {'DEFAULT_ENV': default_env}

    for name in [
        'CODEMAGIC_API_TOKEN',
        'GH_TOKEN',
        'GITHUB_REPOSITORY',
        'GITHUB_RUN_ID',
        'PROVENANCE_TOKEN',
        'PUBLIC_PEOPLE_LIST_POLICY',
    ]:
        if not env.get(name):
            raise ReleaseError(
                f'Missing {name}; configure the GitHub Actions secret/environment before dispatching. No build started.'
            )

    repo = env['GITHUB_REPOSITORY']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo) or not env['GITHUB_RUN_ID'].isdigit():
        raise ReleaseError('Invalid GitHub run identity.')

    workflow_ref = f'{repo}/.github/workflows/{WORKFLOW_FILE}@refs/heads/main'
    if env.get('GITHUB_REF') != 'refs/heads/main' or env.get('GITHUB_WORKFLOW_REF') != workflow_ref:
        raise ReleaseError('Release workflow must run from trusted main.')

    checked_out_sha = checked_out_sha or subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], text=True
    ).strip()
    if (
        not sha(checked_out_sha)
        or checked_out_sha != env.get('GITHUB_SHA')
        or checked_out_sha != env.get('GITHUB_WORKFLOW_SHA')
    ):
        raise ReleaseError('Checked-out script and workflow must be the dispatched main commit.')

    requested = env.get('SOURCE_SHA', '')
    if requested and not sha(requested):
        raise ReleaseError('source_sha must be a full 40-character lowercase hexadecimal commit SHA.')

    gh_base = 'https://api.github.com/repos/' + repo

    def gh(path):
        return request('GET', gh_base + path, env['GH_TOKEN'])

    current = gh('/git/ref/heads/main').get('object', {}).get('sha')
    source = requested or current
    if not sha(source) or source != current or source != checked_out_sha:
        raise ReleaseError(
            'Release source must equal current main and the dispatched workflow commit; dispatch again from current main.'
        )

    query = urllib.parse.urlencode({'head_sha': source, 'status': 'completed', 'per_page': 100})
    runs = gh('/actions/workflows/mobile_ci.yaml/runs?' + query).get('workflow_runs', [])
    passed = {
        str(run.get('id'))
        for run in runs
        if run.get('head_sha') == source
        and (run.get('event') == 'merge_group' or (run.get('event') == 'push' and run.get('head_branch') == 'main'))
        and run.get('status') == 'completed'
        and run.get('conclusion') == 'success'
    }
    query = urllib.parse.urlencode({'check_name': 'Mobile CI', 'filter': 'latest', 'per_page': 100})
    checks = gh('/commits/' + source + '/check-runs?' + query).get('check_runs', [])
    ci_ok = any(
        check.get('name') == 'Mobile CI'
        and check.get('head_sha') == source
        and check.get('status') == 'completed'
        and check.get('conclusion') == 'success'
        and (check.get('app') or {}).get('slug') == 'github-actions'
        and (check.get('app') or {}).get('id') == 15368
        and any(
            check.get('details_url', '').startswith(f'https://github.com/{repo}/actions/runs/{run_id}/')
            for run_id in passed
        )
        for check in checks
    )
    if not ci_ok:
        raise ReleaseError(
            'Current main source needs its own successful main push or merge queue Mobile CI workflow and Mobile CI check. No build started.'
        )

    def cm(method, path, payload=None):
        return request(method, 'https://codemagic.io/api/v3' + path, env['CODEMAGIC_API_TOKEN'], payload)

    label = f'github:{repo}:{env["GITHUB_RUN_ID"]}:macos-testflight:{source}'
    cursor = None
    seen_cursors = set()
    matches = []
    blockers = []
    while True:
        query = {'app_id': APP_ID, 'page_size': 100}
        if cursor is not None:
            query['cursor'] = cursor
        page = cm('GET', '/teams/' + TEAM_ID + '/builds?' + urllib.parse.urlencode(query))
        for item in page['data']:
            if (item.get('workflow') or {}).get('id') != WORKFLOW_ID:
                if label in item.get('labels', []):
                    raise ReleaseError('Matching build label has an unexpected workflow.')
                continue
            expected = source if label in item.get('labels', []) else (item.get('commit') or {}).get('hash')
            status, asc, _ = validate_macos_build(
                item, expected, require_main=label in item.get('labels', [])
            )
            if label in item.get('labels', []):
                matches.append(item)
            elif status in ACTIVE or asc in ASC_PENDING:
                blockers.append(build_id(item['id']))
        cursor = page.get('cursor')
        if cursor is None:
            break
        serialized = json.dumps(cursor, sort_keys=True)
        if serialized in seen_cursors or len(seen_cursors) >= 1000:
            raise ReleaseError('Could not finish Codemagic build pagination; refusing a new submission.')
        seen_cursors.add(serialized)

    if blockers:
        raise ReleaseError('Another macOS build has active store processing: ' + ', '.join(blockers))
    if len(matches) > 1:
        raise ReleaseError('Multiple builds match this GitHub run; reconcile in Codemagic before continuing.')

    if matches:
        selected = build_id(matches[0]['id'])
    else:
        if env.get('GITHUB_RUN_ATTEMPT', '1') != '1':
            raise ReleaseError(
                'Retry has no discoverable matching build; reconcile the previous request in Codemagic before a new dispatch.'
            )
        try:
            configure_build_credentials(cm, env['PROVENANCE_TOKEN'], env['PUBLIC_PEOPLE_LIST_POLICY'])
        except (ProviderError, ReleaseError) as error:
            raise ReleaseError(f'Could not prepare secure build credentials: {error}. No build started.') from None
        payload = {
            'workflow_id': WORKFLOW_ID,
            'branch': 'main',
            'inputs': inputs,
            'environment': {'variables': {'RELEASE_EXPECTED_SHA': source}},
            'labels': [label],
        }
        try:
            accepted = cm('POST', '/apps/' + APP_ID + '/builds', payload)
            selected = build_id(accepted.get('data', {}).get('id'))
        except ReleaseError:
            raise ReleaseError(
                'Codemagic submission was not confirmed. Do not retry blindly: reconcile builds with label '
                + label
                + ' before dispatching again. The driver did not retry POST.'
            ) from None

    url = f'https://codemagic.io/app/{APP_ID}/build/{selected}'
    record(
        env,
        f'Codemagic macOS build `{selected}`: {url}\n\nSource: `{source}`',
        {'build_id': selected, 'build_url': url, 'source_sha': source},
    )

    started = monotonic()
    last_state = None
    while monotonic() - started < timeout:
        try:
            build = cm('GET', '/builds/' + selected)['data']
        except APIError as error:
            if error.status != 404 or monotonic() - started >= 120:
                raise
            sleep(15)
            continue
        status, asc, commit = validate_macos_build(build, source)
        if build['id'] != selected:
            raise ReleaseError('Provider returned a different build id.')
        actual_inputs = build.get('build_inputs')
        if actual_inputs is not None and any(actual_inputs.get(k) != v for k, v in inputs.items()):
            raise ReleaseError('Codemagic release inputs differ from the requested macOS release.')
        state = (status, asc, commit)
        if state != last_state:
            record(
                env,
                f'Build `{selected}`: {status}; App Store Connect: {asc or "not reported"}; '
                f'commit: {commit or "not fetched yet"}.',
            )
            last_state = state
        if status in TERMINAL - {'finished'} or asc in {'failed', 'timeout'}:
            raise ReleaseError(
                'Codemagic macOS build or App Store Connect publishing failed; inspect the recorded build URL.'
            )
        if status == 'finished':
            if commit != source:
                raise ReleaseError('Finished build has no verified source commit.')
            if asc == 'finished':
                record(
                    env,
                    'macOS App Store Connect upload finished. Verify TestFlight processing and group availability in App Store Connect.',
                    {'result': 'uploaded'},
                )
                return selected
        sleep(15)

    raise ReleaseError(
        'Timed out monitoring Codemagic; the build may still be running. Use the recorded build URL; do not start a duplicate.'
    )


def main():
    try:
        run_release(os.environ)
        return 0
    except ReleaseError as error:
        record(os.environ, 'Release stopped: ' + str(error))
        return 1
    except (KeyError, TypeError, AttributeError, ValueError):
        record(
            os.environ,
            'Release stopped: unexpected API response; inspect the known build/run before retrying.',
        )
        return 1


if __name__ == '__main__':
    sys.exit(main())
