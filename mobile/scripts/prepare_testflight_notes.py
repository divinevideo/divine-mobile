#!/usr/bin/env python3
"""Write localized TestFlight notes bound to the native build's exact source."""

import json
import os
import subprocess
import sys
from pathlib import Path

from publish_github_release import effective_version
from release_train.providers import ProviderError
from release_train.release_notes import bundle_from_env, notes_for


def prepare_notes(env=os.environ, *, source_sha=None,
                  release_env='build/shorebird/ios_release.env',
                  output='release_notes.json'):
    source = source_sha or subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], text=True).strip()
    effective_version(release_env, source)
    bundle = bundle_from_env(env, source, 'ios')
    notes = notes_for(bundle, 'testflight')
    Path(output).write_text(json.dumps(notes, ensure_ascii=False) + '\n', encoding='utf-8')
    return notes


def main():
    try:
        prepare_notes()
    except (ProviderError, ValueError, KeyError, OSError) as error:
        print('TestFlight notes stopped: ' + str(error))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
