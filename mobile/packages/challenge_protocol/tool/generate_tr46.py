#!/usr/bin/env python3
"""Regenerate the attributed Unicode 17 tables without network access."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'third_party/tr46'
HASHES = {
    'lib/mappingTable.json': 'c45bd284e01f0845bc3c3b1d7594cd7b9ee8b955ddc850882b8e1dc5d0cba95d',
    'lib/regexes.js': '3f43551d5109e5a300b29d5a9c261adf2bfd1621ffc086909f8ebf40835fc70f',
}


def generate():
    for name, expected in HASHES.items():
        actual = hashlib.sha256((SOURCE / name).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f'{name}: expected {expected}, got {actual}')
    lines = [
        '// Generated from tr46 6.0.0 / Unicode 17.0.0. See third_party/tr46/SOURCE.md.',
        '// Copyright tr46 contributors. MIT license in third_party/tr46/LICENSE.md.',
        '',
        '/// Inclusive Unicode ranges, UTS46 status and mapping.',
        'const tr46Mapping = <(int, int, int, String)>[',
    ]
    for row in json.loads((SOURCE / 'lib/mappingTable.json').read_text()):
        span = row[0] if isinstance(row[0], list) else [row[0], row[0]]
        # JSON escapes also work in Dart, except Dart's interpolation marker.
        mapping = json.dumps(row[2] if len(row) > 2 else '', ensure_ascii=True)
        mapping = mapping.replace('$', r'\$')
        lines.append(f'  ({span[0]}, {span[1]}, {row[1]}, {mapping}),')
    lines.append('];')
    regexes = re.findall(r'^const (\w+) = /(.*)/u;$',
                        (SOURCE / 'lib/regexes.js').read_text(), re.MULTILINE)
    if len(regexes) != 12:
        raise ValueError(f'Unexpected regex inventory: {len(regexes)}')
    for name, pattern in regexes:
        if '"""' in pattern:
            raise ValueError('Unsafe Dart raw string delimiter')
        lines.extend(['', f'final {name} = RegExp('])
        chunks = [pattern[i:i + 66] for i in range(0, len(pattern), 66)]
        lines.extend('  r"""' + chunk + '"""' + (',' if i == len(chunks) - 1 else '')
                     for i, chunk in enumerate(chunks))
        lines.extend(['  unicode: true,', ');'])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--dart', default='dart')
    args = parser.parse_args()
    # Format in the package so the same language version and analysis options apply.
    (ROOT / '.dart_tool').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=ROOT / '.dart_tool') as directory:
        candidate = Path(directory) / 'tr46_data.g.dart'
        candidate.write_text(generate())
        subprocess.run([args.dart, 'format', str(candidate)], check=True,
                       stdout=subprocess.DEVNULL)
        output = candidate.read_bytes()
    target = ROOT / 'lib/src/tr46_data.g.dart'
    if args.check:
        if target.read_bytes() != output:
            raise SystemExit('Unicode 17 tables are stale; run tool/generate_tr46.py')
        print('Unicode 17 source hashes and generated tables match')
    else:
        target.write_bytes(output)
        print(f'Generated {target.relative_to(ROOT)} ({len(output)} bytes)')


if __name__ == '__main__':
    main()
