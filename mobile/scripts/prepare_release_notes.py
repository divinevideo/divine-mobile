#!/usr/bin/env python3
"""Generate a local change inventory for editing into Divine release notes."""
import argparse
from pathlib import Path
import re
import subprocess


def inventory(base, head):
    def git(*args):
        return subprocess.check_output(['git', *args], text=True).strip()
    # Resolve refs first: user input never becomes a git-log option or revision range.
    base_sha = git('rev-parse', '--verify', '--end-of-options', base + '^{commit}')
    head_sha = git('rev-parse', '--verify', '--end-of-options', head + '^{commit}')
    subprocess.run(['git', 'merge-base', '--is-ancestor', base_sha, head_sha], check=True)
    entries = git('log', '--first-parent', '--format=%H%x09%s', f'{base_sha}..{head_sha}')
    groups = {'New things to try': [], 'Fixes and improvements': [], 'Other changes to review': []}
    for line in entries.splitlines():
        sha, subject = line.split('\t', 1)
        kind = re.match(r'(\w+)(?:\([^)]*\))?!?:', subject)
        kind = kind.group(1) if kind else ''
        group = ('New things to try' if kind == 'feat' else
                 'Fixes and improvements' if kind in ('fix', 'perf') else
                 'Other changes to review')
        groups[group].append(f'- {subject} (`{sha}`)')
    sections = ['<!-- DRAFT -->', '# Release notes working draft',
                'Rewrite the inventory below as user benefits in Divine’s voice. '
                'Verify shipped behavior, remove reverted or disabled features and internal work, '
                'and review for sensitive details before publishing. '
                'Remove the DRAFT marker only after review.',
                f'Compared source commits: `{base_sha}` → `{head_sha}`.']
    for name, entries in groups.items():
        sections += ['## ' + name, '\n'.join(entries) or 'No changes in this group.']
    return '\n\n'.join(sections) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True, help='Verified source commit of the previous release')
    parser.add_argument('--head', default='HEAD', help='Candidate source commit')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    body = inventory(args.base, args.head)
    # Never overwrite reviewed copy by accident.
    with Path(args.output).open('x') as output:
        output.write(body)


if __name__ == '__main__':
    main()
