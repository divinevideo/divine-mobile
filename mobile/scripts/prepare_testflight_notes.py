#!/usr/bin/env python3
"""Select reviewed effective-version notes, with a generic fallback for new trains."""

import json
import subprocess
from pathlib import Path

from publish_github_release import effective_version

version = effective_version(
    "build/shorebird/ios_release.env",
    subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
)
reviewed = Path("../release-notes") / (version + "-testflight.json")
Path("release_notes.json").write_text(
    reviewed.read_text()
    if reviewed.is_file()
    else json.dumps(
        [
            {
                "language": "en-US",
                "text": "This build includes the latest changes to Divine.",
            }
        ]
    )
    + "\n"
)
