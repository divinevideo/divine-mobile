#!/usr/bin/env python3
"""Dispatch and monitor a main-only Codemagic TestFlight build from GitHub Actions.

Provider contract: https://codemagic.io/api/v3/schema/openapi.json
This driver does not verify Apple Beta App Review or external tester availability.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

APP_ID = '69370e59eac15e6c367b661b'
TEAM_ID = '692de5e382bd4a97332896df'
INPUTS = {'DEFAULT_ENV': 'PRODUCTION', 'RELEASE_CHANNEL': 'BETA', 'PUBLISH_TO_GITHUB': 'NO'}
ACTIVE = {'initializing', 'queued', 'waiting', 'preparing', 'fetching', 'testing',
          'building', 'publishing', 'finishing'}
TERMINAL = {'finished', 'failed', 'canceled', 'timeout', 'skipped'}
ASC_PENDING = {'initiated', 'pending', 'processing'}
ASC_TERMINAL = {'finished', 'timeout', 'failed'}
SHA_PATTERN = re.compile(r'[0-9a-f]{40}')
ID_PATTERN = re.compile(r'[0-9a-f]{24}')


class ReleaseError(Exception):
    """Safe operator-facing error, without response bodies or credentials."""


class APIError(ReleaseError):
    def __init__(self, status):
        self.status = status
        super().__init__('API request failed' + (f' (HTTP {status})' if status else ' (transport or response error)'))


def request_json(method, url, token, payload=None):
    headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
    if url.startswith('https://api.github.com/'):
        headers.update({'Authorization': 'Bearer ' + token, 'X-GitHub-Api-Version': '2022-11-28'})
    elif url.startswith('https://codemagic.io/api/v3/'):
        headers['x-auth-token'] = token
    else:
        raise ReleaseError('Refusing an unexpected API origin.')
    request = urllib.request.Request(url, headers=headers, method=method,
                                     data=None if payload is None else json.dumps(payload).encode())
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if response.status != (202 if method == 'POST' else 200):
                raise APIError(response.status)
            result = json.load(response)
            if not isinstance(result, dict):
                raise APIError(None)
            return result
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
        raise APIError(status) from None
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        raise APIError(None) from None


def sha(value):
    return isinstance(value, str) and SHA_PATTERN.fullmatch(value) is not None


def build_id(value):
    if not isinstance(value, str) or ID_PATTERN.fullmatch(value) is None:
        raise ReleaseError('Provider returned an invalid build id; reconcile in Codemagic before dispatching again.')
    return value


def record(env, message, outputs=None):
    print(message, flush=True)
    if env.get('GITHUB_STEP_SUMMARY'):
        with open(env['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
            stream.write(message + '\n\n')
    if outputs and env.get('GITHUB_OUTPUT'):
        with open(env['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
            for key, value in outputs.items():
                stream.write(f'{key}={value}\n')


def validate_build(build, expected_sha, *, require_main=True):
    if (not isinstance(build, dict) or build.get('app_id') != APP_ID
            or (build.get('workflow') or {}).get('id') != 'ios-build'
            or (require_main and (build.get('branch') != 'main' or build.get('tag')))):
        raise ReleaseError('Codemagic build identity does not match the requested main iOS release.')
    build_id(build.get('id'))
    status = build.get('status')
    asc = build.get('app_store_connect_status')
    if status not in ACTIVE | TERMINAL or (asc is not None and asc not in ASC_PENDING | ASC_TERMINAL):
        raise ReleaseError('Unrecognized Codemagic status; inspect the build before continuing.')
    commit = (build.get('commit') or {}).get('hash')
    if commit is not None and commit != expected_sha:
        raise ReleaseError('Codemagic fetched a different source commit; release refused. Inspect the build immediately.')
    return status, asc, commit


def run_release(env, *, request=request_json, checked_out_sha=None, sleep=time.sleep,
                monotonic=time.monotonic, timeout=4800):
    for name in ['CODEMAGIC_API_TOKEN', 'GH_TOKEN', 'GITHUB_REPOSITORY', 'GITHUB_RUN_ID']:
        if not env.get(name):
            raise ReleaseError(f'Missing {name}; configure the GitHub Actions secret/environment before dispatching. No build started.')
    repo = env['GITHUB_REPOSITORY']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo) or not env['GITHUB_RUN_ID'].isdigit():
        raise ReleaseError('Invalid GitHub run identity.')
    workflow_ref = repo + '/.github/workflows/ios_testflight_release.yml@refs/heads/main'
    if env.get('GITHUB_REF') != 'refs/heads/main' or env.get('GITHUB_WORKFLOW_REF') != workflow_ref:
        raise ReleaseError('Release workflow must run from trusted main.')
    checked_out_sha = checked_out_sha or subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], text=True).strip()
    if (not sha(checked_out_sha) or checked_out_sha != env.get('GITHUB_SHA')
            or checked_out_sha != env.get('GITHUB_WORKFLOW_SHA')):
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
        raise ReleaseError('Release source must equal current main and the dispatched workflow commit; dispatch again from current main.')

    query = urllib.parse.urlencode({'head_sha': source, 'status': 'completed', 'per_page': 100})
    runs = gh('/actions/workflows/mobile_ci.yaml/runs?' + query).get('workflow_runs', [])
    passed = {str(run.get('id')) for run in runs
              if run.get('head_sha') == source
              and (run.get('event') == 'merge_group' or
                   (run.get('event') == 'push' and run.get('head_branch') == 'main'))
              and run.get('status') == 'completed'
              and run.get('conclusion') == 'success'}
    query = urllib.parse.urlencode({'check_name': 'Mobile CI', 'filter': 'latest', 'per_page': 100})
    checks = gh('/commits/' + source + '/check-runs?' + query).get('check_runs', [])
    ci_ok = any(check.get('name') == 'Mobile CI' and check.get('head_sha') == source
                and check.get('status') == 'completed' and check.get('conclusion') == 'success'
                and (check.get('app') or {}).get('slug') == 'github-actions'
                and (check.get('app') or {}).get('id') == 15368
                and any(check.get('details_url', '').startswith(
                    f'https://github.com/{repo}/actions/runs/{run_id}/') for run_id in passed)
                for check in checks)
    if not ci_ok:
        raise ReleaseError('Current main source needs its own successful main push or merge queue Mobile CI workflow and Mobile CI check. No build started.')

    def cm(method, path, payload=None):
        return request(method, 'https://codemagic.io/api/v3' + path, env['CODEMAGIC_API_TOKEN'], payload)
    label = f'github:{repo}:{env["GITHUB_RUN_ID"]}:ios-testflight:{source}'
    # Scan all statuses: the API's status filter omits some active states.
    cursor = None
    seen_cursors = set()
    matches = []
    blockers = []
    while True:
        query = {'app_id': APP_ID, 'workflow_id': 'ios-build', 'page_size': 100}
        if cursor is not None:
            query['cursor'] = cursor
        page = cm('GET', '/teams/' + TEAM_ID + '/builds?' + urllib.parse.urlencode(query))
        for item in page['data']:
            # Historical releases may target older commits; validate source only for reuse.
            expected = source if label in item.get('labels', []) else (item.get('commit') or {}).get('hash')
            status, asc, _ = validate_build(item, expected, require_main=label in item.get('labels', []))
            if label in item.get('labels', []):
                matches.append(item)
            elif status in ACTIVE or (status == 'finished' and asc in ASC_PENDING):
                blockers.append(build_id(item['id']))
        cursor = page.get('cursor')
        if cursor is None:
            break
        serialized = json.dumps(cursor, sort_keys=True)
        if serialized in seen_cursors or len(seen_cursors) >= 1000:
            raise ReleaseError('Could not finish Codemagic build pagination; refusing a new submission.')
        seen_cursors.add(serialized)
    if blockers:
        raise ReleaseError('Another iOS build or its App Store Connect processing is active: ' + ', '.join(blockers))
    if len(matches) > 1:
        raise ReleaseError('Multiple builds match this GitHub run; reconcile in Codemagic before continuing.')
    if matches:
        selected = build_id(matches[0]['id'])
    else:
        if env.get('GITHUB_RUN_ATTEMPT', '1') != '1':
            raise ReleaseError('Retry has no discoverable matching build; reconcile the previous request in Codemagic before a new dispatch.')
        payload = {'workflow_id': 'ios-build', 'branch': 'main', 'inputs': INPUTS,
                   'environment': {'variables': {'RELEASE_EXPECTED_SHA': source}}, 'labels': [label]}
        try:
            accepted = cm('POST', '/apps/' + APP_ID + '/builds', payload)
            selected = build_id(accepted.get('data', {}).get('id'))
        except ReleaseError:
            raise ReleaseError('Codemagic submission was not confirmed. Do not retry blindly: reconcile builds with label '
                               + label + ' before dispatching again. The driver did not retry POST.') from None
    url = f'https://codemagic.io/app/{APP_ID}/build/{selected}'
    record(env, f'Codemagic build `{selected}`: {url}\n\nSource: `{source}`',
           {'build_id': selected, 'build_url': url, 'source_sha': source})
    started = monotonic()
    last_state = None
    while monotonic() - started < timeout:
        try:
            build = cm('GET', '/builds/' + selected)['data']
        except APIError as error:
            # Accepted builds can briefly be invisible while Codemagic initializes them.
            if error.status != 404 or monotonic() - started >= 120:
                raise
            sleep(15)
            continue
        status, asc, commit = validate_build(build, source)
        if build['id'] != selected:
            raise ReleaseError('Provider returned a different build id.')
        inputs = build.get('build_inputs')
        if inputs is not None and any(inputs.get(key) != value for key, value in INPUTS.items()):
            raise ReleaseError('Codemagic release inputs differ from the requested beta release.')
        state = (status, asc, commit)
        if state != last_state:
            record(env, f'Build `{selected}`: {status}; App Store Connect: {asc or "not reported"}; '
                       f'commit: {commit or "not fetched yet"}.')
            last_state = state
        if status in TERMINAL - {'finished'} or asc in {'failed', 'timeout'}:
            raise ReleaseError('Codemagic build or App Store Connect publishing failed; inspect the recorded build URL.')
        if status == 'finished':
            if commit != source:
                raise ReleaseError('Finished build has no verified source commit.')
            if asc == 'finished':
                record(env, 'App Store Connect processing finished. Upload/submission completed in Codemagic; '
                           'verify Beta App Review and group availability in App Store Connect separately.', {'result': 'uploaded'})
                return selected
        sleep(15)
    raise ReleaseError('Timed out monitoring Codemagic; the build may still be running. Use the recorded build URL; do not start a duplicate.')


def main():
    try:
        run_release(os.environ)
        return 0
    except ReleaseError as error:
        record(os.environ, 'Release stopped: ' + str(error))
        return 1
    except (KeyError, TypeError, AttributeError, ValueError):
        record(os.environ, 'Release stopped: unexpected API response; inspect the known build/run before retrying.')
        return 1


if __name__ == '__main__':
    sys.exit(main())
