#!/usr/bin/env python3
"""Retain authenticated artifact identity before a guarded manual/scheduled upload."""

import hashlib
import json
import os
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

from publish_github_release import effective_version
from release_train.ledger import GhLedgerStore
from release_train.providers import DeferredReview, Play, ProviderError, play_token


def publish_bundle(env=os.environ, *, ledger=None, play=None):
    identity = dict(
        line.split("=", 1)
        for line in Path("build/shorebird/android_release.env").read_text().splitlines()
        if "=" in line
    )
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    version = effective_version("build/shorebird/android_release.env", source)
    artifacts = list(Path("build/app/outputs/bundle/release").glob("*.aab"))
    if len(artifacts) != 1:
        raise ProviderError("Expected exactly one signed AAB")
    path = artifacts[0]
    number = int(identity["SHOREBIRD_BUILD_NUMBER"])
    ledger = ledger or GhLedgerStore(
        env.get(
            "SHOREBIRD_PROVENANCE_REPOSITORY", "divinevideo/divine-release-provenance"
        )
    )
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    record = {
        "schema": 1,
        "number": number,
        "version": version,
        "sha": source,
        "digest": digest,
        "build_id": env["CM_BUILD_ID"],
        "artifact_name": path.name,
        "recorded_at": datetime.now(UTC).isoformat(),
    }
    remote = f"artifacts/android/{number}.json"
    if not ledger.create_json(
        remote, record, f"Record signed Android artifact {number}"
    ):
        prior = ledger.read_json(remote)
        if any(
            prior.get(k) != record[k]
            for k in ["number", "version", "sha", "digest", "build_id", "artifact_name"]
        ):
            raise ProviderError("Artifact identity is already spent; do not rebuild it")
        record = prior
    play = play or Play(play_token(env["GCLOUD_SERVICE_ACCOUNT_CREDENTIALS"]))
    try:
        play.upload(path, number, digest)
        result = "uploaded"
    except DeferredReview:
        result = "deferred"
    except ProviderError:
        ledger.create_json(
            f"uploads/android/{number}.json",
            record | {"status": "failed"},
            f"Record Android upload failure {number}",
        )
        raise
    ledger.create_json(
        f"uploads/android/{number}.json",
        record | {"status": result},
        f"Record Android upload {result} {number}",
    )
    Path("build/shorebird/android_upload.json").write_text(
        json.dumps(record | {"status": result}, sort_keys=True) + "\n"
    )
    print(
        "Android upload "
        + result
        + "; signed artifact identity retained in private ledger."
    )


if __name__ == "__main__":
    try:
        publish_bundle()
    except (ProviderError, ValueError, KeyError, OSError) as error:
        print("Android publishing stopped: " + str(error))
        sys.exit(1)
