#!/usr/bin/env python3
"""Publish reviewed notes and source-pinned artifacts without clobbering releases."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return 'sha256:' + value.hexdigest()


class GitHub:
    def __init__(self, repo):
        self.repo = repo

    def api(self, endpoint, optional=False):
        result = subprocess.run(
            ['gh', 'api', f'repos/{self.repo}/{endpoint}'],
            capture_output=True, text=True,
        )
        if result.returncode:
            if optional and '(HTTP 404)' in result.stderr:
                return None
            raise RuntimeError(result.stderr.strip())
        return json.loads(result.stdout)

    def tag_commit(self, tag):
        ref = self.api(f'git/ref/tags/{tag}', optional=True)
        if ref is None:
            return None
        obj = ref['object']
        while obj['type'] == 'tag':
            obj = self.api(f"git/tags/{obj['sha']}")['object']
        if obj['type'] != 'commit':
            raise ValueError('Release tag does not point to a commit')
        return obj['sha']

    def get_release(self, tag):
        record = self.api(f'releases/tags/{tag}', optional=True)
        if record is None:
            # The tag endpoint only guarantees published releases. Recover an
            # interrupted draft upload through the authenticated release list.
            pages = json.loads(run('gh', 'api', '--paginate', '--slurp',
                                   f'repos/{self.repo}/releases'))
            record = next((r for page in pages for r in page
                           if r['tag_name'] == tag), None)
        if record is not None:
            # The embedded assets list can be truncated by GitHub.
            pages = json.loads(run('gh', 'api', '--paginate', '--slurp',
                                  f"repos/{self.repo}/releases/{record['id']}/assets"))
            record['assets'] = [asset for page in pages for asset in page]
        return record

    def with_notes(self, arguments, body):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'notes.md'
            path.write_text(body)
            run('gh', 'release', *arguments, '--repo', self.repo, '--notes-file', str(path))

    def create(self, tag, sha, body, beta):
        self.with_notes(['create', tag, '--target', sha, '--draft',
                         f'--prerelease={str(beta).lower()}', '--latest=false',
                         '--title', f'Divine {tag}'], body)

    def upload(self, tag, paths):
        # No --clobber: concurrent platform builds must never replace bytes.
        run('gh', 'release', 'upload', tag, '--repo', self.repo, *map(str, paths))

    def edit(self, tag, body, beta):
        record = self.get_release(tag)
        # GitHub selects Latest by date/semantic version. Forcing latest=true
        # here could undo a newer release completed during our artifact upload.
        payload = dict(name=f'Divine {tag}', body=body, draft=False,
                       prerelease=beta, make_latest='false' if beta else 'legacy')
        result = subprocess.run(
            ['gh', 'api', '--method', 'PATCH',
             f"repos/{self.repo}/releases/{record['id']}", '--input', '-'],
            input=json.dumps(payload), text=True, capture_output=True,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or 'GitHub release update failed')

    def download(self, tag, directory):
        run('gh', 'release', 'download', tag, '--repo', self.repo,
            '--pattern', '*', '--dir', str(directory))

    def latest_tag(self):
        release = self.api('releases/latest', optional=True)
        return release['tag_name'] if release else None


def version_number(tag):
    if tag and re.fullmatch(r'\d+\.\d+\.\d+', tag):
        return tuple(map(int, tag.split('.')))
    return None


def check_newer_release(gh, version):
    latest = version_number(gh.latest_tag())
    if latest and latest > version_number(version):
        raise ValueError('Cannot replace a newer Latest release with an older version')


def unfinished_notes(body):
    return '<!-- DRAFT -->' in body or '# Release notes working draft' in body


def publish(gh, version, sha, channel, backend, notes, artifacts):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected a three-part marketing version')
    if not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('Expected the full build commit SHA')
    if channel not in ('BETA', 'PRODUCTION'):
        raise ValueError('Release channel must be BETA or PRODUCTION')
    if backend not in ('PRODUCTION', 'STAGING', 'POC'):
        raise ValueError('Unknown backend')
    beta = channel == 'BETA'
    if not beta and backend != 'PRODUCTION':
        raise ValueError('Production releases require the PRODUCTION backend')
    if not artifacts or any(not p.is_file() for p in artifacts):
        raise ValueError('No release artifacts, or an artifact is missing')
    if len({p.name for p in artifacts}) != len(artifacts):
        raise ValueError('Artifact filenames must be unique')
    body = notes.read_text().strip() if notes.is_file() else ''
    if not beta and (not body or unfinished_notes(body)):
        raise ValueError(f'Production requires finished release notes: {notes}')
    tag = f'{version}-beta.{backend.lower()}.{sha}' if beta else version
    if beta:
        if unfinished_notes(body):
            body = ''
        body = ('## Divine beta\n\n'
                'An early build for testing. Things may break. '
                f'Thanks for helping us make Divine better. Backend: {backend.lower()}.\n\n' + body)
    body = body.rstrip() + f'\n\nBuild source: `{sha}`.\n'
    commit = gh.tag_commit(tag)
    if commit is not None and commit != sha:
        raise ValueError(f'Tag {tag} points to a different commit; do not move a published tag')
    current = gh.get_release(tag)
    if current and commit is None and current.get('target_commitish') != sha:
        raise ValueError('Existing draft targets a different commit; refusing publication')
    if current and beta and not current['prerelease']:
        raise ValueError('Cannot turn an existing stable release into a beta')
    if not beta:
        check_newer_release(gh, version)
    existing = {a['name']: a for a in current['assets']} if current else {}
    missing = []
    for path in artifacts:
        if path.name not in existing:
            missing.append(path)
        elif existing[path.name].get('digest') != digest(path):
            raise ValueError(f'{path.name} already exists with different bytes or no digest; refusing replacement')
    if current is None:
        gh.create(tag, sha, body, beta)
    if missing:
        gh.upload(tag, missing)
    uploaded = gh.get_release(tag)
    uploaded_assets = {a['name']: a.get('digest') for a in uploaded['assets']}
    if any(uploaded_assets.get(p.name) != digest(p) for p in artifacts):
        raise RuntimeError('Uploaded artifact verification failed; release not promoted')
    if not beta:
        check_newer_release(gh, version)
    gh.edit(tag, body, beta)
    saved = gh.get_release(tag)
    if (saved['draft'] or saved['prerelease'] != beta
            or saved['body'].replace('\r\n', '\n').strip() != body.strip()
            or gh.tag_commit(tag) != sha):
        raise RuntimeError('Published release metadata verification failed')
    saved_assets = {a['name']: a.get('digest') for a in saved['assets']}
    if any(saved_assets.get(p.name) != digest(p) for p in artifacts):
        raise RuntimeError('Published artifact verification failed')
    if not beta:
        latest = version_number(gh.latest_tag())
        if latest is None or latest < version_number(version):
            raise RuntimeError('Latest release verification failed')
    return tag


def promote(gh, beta_tag, notes):
    match = re.fullmatch(r'(\d+\.\d+\.\d+)-beta\.production\.([0-9a-f]{40})', beta_tag)
    if not match:
        raise ValueError('Promotion requires a production-backend beta tag from this publisher')
    version, sha = match.groups()
    beta = gh.get_release(beta_tag)
    if not beta or beta['draft'] or not beta['prerelease'] or gh.tag_commit(beta_tag) != sha:
        raise ValueError('Expected a published beta with a matching source tag')
    if not beta['assets']:
        raise ValueError('Beta has no release artifacts')
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        for asset in beta['assets']:
            name = asset['name']
            if Path(name).name != name or name in ('.', '..'):
                raise ValueError('Invalid release asset filename')
        gh.download(beta_tag, root)
        paths = [root / a['name'] for a in beta['assets']]
        for asset, path in zip(beta['assets'], paths):
            if not path.is_file() or digest(path) != asset.get('digest'):
                raise ValueError('Downloaded beta artifact digest does not match')
        return publish(gh, version, sha, 'PRODUCTION', 'PRODUCTION', notes, paths)


def marketing_version(pubspec):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$', pubspec, re.MULTILINE)
    if not match:
        raise ValueError('Expected pubspec version: major.minor.patch with optional +build')
    return match.group(1)


def recovery_artifacts(directory):
    if not directory.is_dir():
        raise ValueError('Original artifacts directory does not exist')
    patterns = ('*arm64*.apk', '*armeabi*.apk', '*.ipa', '*.dmg')
    return sorted(p for p in directory.rglob('*')
                  if p.is_file() and any(p.match(pattern) for pattern in patterns))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--channel', default=None, choices=['BETA', 'PRODUCTION'])
    parser.add_argument('--backend', default='PRODUCTION')
    parser.add_argument('--promote-from', help='Publish an existing beta’s exact artifacts as stable')
    parser.add_argument('--artifacts-dir', type=Path,
                        help='Retry with original downloaded artifacts; checkout their source commit first')
    args = parser.parse_args()
    if args.promote_from and (args.channel == 'BETA' or args.backend != 'PRODUCTION' or args.artifacts_dir):
        parser.error('--promote-from requires production channel/backend and cannot use --artifacts-dir')
    mobile = Path(__file__).resolve().parents[1]
    if args.promote_from:
        version = args.promote_from.split('-beta.', 1)[0]
        if not re.fullmatch(r'\d+\.\d+\.\d+', version):
            parser.error('Invalid beta version')
        tag = promote(GitHub(args.repo), args.promote_from,
                      mobile.parent / 'release-notes' / f'{version}.md')
        print(f'Promoted and verified https://github.com/{args.repo}/releases/tag/{tag}')
        return
    try:
        version = marketing_version((mobile / 'pubspec.yaml').read_text())
    except ValueError as error:
        parser.error(str(error))
    sha = run('git', '-C', str(mobile), 'rev-parse', 'HEAD')
    patterns = ['build/app/outputs/apk/release/*arm64*.apk',
                'build/app/outputs/apk/release/*armeabi*.apk',
                'build/ios/ipa/*.ipa', 'build/macos/Build/Products/Release/*.dmg']
    artifacts = (recovery_artifacts(args.artifacts_dir) if args.artifacts_dir
                 else sorted({p for pattern in patterns for p in mobile.glob(pattern)}))
    tag = publish(GitHub(args.repo), version, sha, args.channel or 'BETA', args.backend,
                  mobile.parent / 'release-notes' / f'{version}.md', artifacts)
    print(f'Published and verified https://github.com/{args.repo}/releases/tag/{tag}')


if __name__ == '__main__':
    main()
