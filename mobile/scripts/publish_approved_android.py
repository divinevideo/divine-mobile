#!/usr/bin/env python3
"""Publish original approved Android downloads before the existing Zapstore signer."""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

from publish_github_release import GitHub, publish, record_stable_claim
from release_train.android_distribution import manifest_digest, validate_downloads, receipt_matches
from release_train.ledger import GhLedgerStore, LedgerError
from release_train.providers import ArtifactRedirect, ProviderError, request_json

PROOF = Path("build/distribution/github.json")
SIGNED_PROOF = Path("build/distribution/zapstore-succeeded")


def approved_identity(env):
    number = env.get("APPROVED_BUILD_NUMBER", "")
    if not number:
        return None
    if (env.get("CM_BRANCH") != "main" or not re.fullmatch(r"[1-9][0-9]*", number)
            or not re.fullmatch(r"[1-9][0-9]*", env.get("DISTRIBUTION_ATTEMPT", ""))
            or not re.fullmatch(r"[1-9][0-9]*", env.get("APPROVAL_OBSERVED_AT", ""))
            or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", env.get("APPROVED_VERSION", ""))
            or not re.fullmatch(r"[0-9a-f]{40}", env.get("APPROVED_SOURCE_SHA", ""))):
        raise ProviderError("Approved Android publication requires an exact main-only identity")
    return {"number": int(number), "version": env["APPROVED_VERSION"],
            "sha": env["APPROVED_SOURCE_SHA"]}


def load_manifest(env, ledger):
    build = approved_identity(env)
    record = ledger.read_json(f"artifacts/android-downloads/{build['number']}.json")
    notes = validate_downloads(record, build)
    return build, record, notes


def artifact_url(artifact):
    url = artifact.get("short_lived_download_url", "")
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != "https" or parsed.hostname != "api.codemagic.io"
            or parsed.username or parsed.password or parsed.port not in {None, 443}):
        raise ProviderError("Unexpected original APK download origin")
    return url


def download_artifact(url, destination):
    # Short-lived signed URLs carry their own authorization; never attach the API key.
    opener = urllib.request.build_opener(ArtifactRedirect())
    try:
        with opener.open(urllib.request.Request(url), timeout=60) as response, destination.open("wb") as out:
            count = 0
            while chunk := response.read(1024 * 1024):
                count += len(chunk)
                if count > 512 * 1024 * 1024:
                    raise ProviderError("Original APK exceeds the download size limit")
                out.write(chunk)
    except (OSError, ValueError):
        raise ProviderError("Original APK download failed; reuse the retained candidate") from None


def github_notes(build, bundle):
    english = next(n["text"] for n in bundle["google_play"] if n["language"] == "en-US")
    return (f"# Divine {build['version']} for Android\n\n{english}\n\n"
            "Android downloads from the same candidate published on Google Play.\n\n"
            f"Changes since Android {bundle['baseline']['version']}.\n")


def verify_release(github, build, record, body):
    saved = github.get_release(build["version"])
    expected_body = body.rstrip() + f"\n\nBuild source: `{build['sha']}`.\n"
    if (not saved or saved.get("draft") or saved.get("prerelease")
            or github.tag_commit(build["version"]) != build["sha"]
            or saved.get("body", "").replace("\r\n", "\n").strip() != expected_body.strip()):
        raise ProviderError("Stable GitHub release identity or notes could not be verified")
    assets = {a["name"]: a.get("digest") for a in saved.get("assets", [])}
    if any(assets.get(a["name"]) != "sha256:" + a["sha256"] for a in record["apks"]):
        raise ProviderError("Stable GitHub APK hashes differ from original candidate")


def publish_approved(env, ledger, cm, github, *, download=download_artifact, now=None):
    if approved_identity(env) is None:
        return None
    SIGNED_PROOF.unlink(missing_ok=True)
    build, record, bundle = load_manifest(env, ledger)
    approval = ledger.read_json(
        f"distributions/approvals/android/{build['number']}/"
        f"{env['DISTRIBUTION_ATTEMPT']}-{env['APPROVAL_OBSERVED_AT']}.json")
    now = time.time() if now is None else now
    observed = approval.get("observed_at")
    if (approval.get("schema") != 1 or approval.get("play_state") != "PUBLISHED"
            or approval.get("ci_verified") is not True
            or any(approval.get(k) != build[k] for k in build)
            or approval.get("manifest_sha256") != manifest_digest(record)
            or not isinstance(observed, (int, float))
            or observed != int(env["APPROVAL_OBSERVED_AT"])
            or not 0 <= now - observed <= 3600):
        raise ProviderError("Play approval is stale, incomplete or differs from original APK identity")
    provenance = ledger.read_json(f"releases/android/{build['version']}+{build['number']}.json")
    if (provenance.get("platform") != "android"
            or provenance.get("release_version") != f"{build['version']}+{build['number']}"
            or provenance.get("build_source_commit") != build["sha"]
            or provenance.get("patchable") is not True or not provenance.get("record_hmac")):
        raise ProviderError("Original Android source provenance is incomplete")
    body = github_notes(build, bundle)
    existing = github.get_release(build["version"])
    if existing and not existing.get("draft") and not existing.get("prerelease"):
        verify_release(github, build, record, body)
    else:
        provider = cm("GET", "/builds/" + record["build_id"])["data"]
        if (provider.get("id") != record["build_id"] or provider.get("status") != "finished"
                or (provider.get("commit") or {}).get("hash") != build["sha"]):
            raise ProviderError("Original Codemagic source or build identity differs")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = []
            for apk in record["apks"]:
                matches = [a for a in provider.get("artifacts", []) if a.get("name") == apk["name"]]
                if len(matches) != 1:
                    raise ProviderError("Original APK artifact is missing or ambiguous; do not rebuild")
                path = root / apk["name"]
                download(artifact_url(matches[0]), path)
                if hashlib.sha256(path.read_bytes()).hexdigest() != apk["sha256"]:
                    raise ProviderError("Downloaded APK hash differs from retained original")
                files.append(path)
            notes = root / "notes.md"
            notes.write_text(body)
            publish(github, build["version"], build["sha"], "PRODUCTION", "PRODUCTION", notes, files)
    verify_release(github, build, record, body)
    record_stable_claim(ledger, build["version"], build["sha"])
    proof = build | {"manifest_sha256": manifest_digest(record), "publication_build_id": env["CM_BUILD_ID"]}
    PROOF.parent.mkdir(parents=True, exist_ok=True)
    PROOF.write_text(json.dumps(proof) + "\n")
    complete = f"distributions/android/{build['number']}.json" in ledger.paths()
    if complete:
        prior = ledger.read_json(f"distributions/android/{build['number']}.json")
        if not receipt_matches(prior, proof) or prior.get("apks") != record["apks"]:
            raise ProviderError("Existing Zapstore publication receipt has another identity")
    with Path(env["CM_ENV"]).open("a") as out:
        out.write(f"ANDROID_DISTRIBUTION_VERSION={build['version']}\n")
        out.write(f"ANDROID_DISTRIBUTION_COMPLETE={'true' if complete else 'false'}\n")
    return proof


def record_published(env, ledger, github):
    if approved_identity(env) is None:
        return None
    build, record, bundle = load_manifest(env, ledger)
    if (not SIGNED_PROOF.is_file() or SIGNED_PROOF.read_text().splitlines()
            != [build["version"], env["CM_BUILD_ID"]]):
        raise ProviderError("Zapstore signing did not record successful publication for this job")
    proof = json.loads(PROOF.read_text())
    if (any(proof.get(k) != v for k, v in build.items())
            or proof.get("manifest_sha256") != manifest_digest(record)
            or proof.get("publication_build_id") != env["CM_BUILD_ID"]):
        raise ProviderError("GitHub verification proof differs from the signing job")
    verify_release(github, build, record, github_notes(build, bundle))
    receipt = proof | {"schema": 1, "apks": record["apks"], "zapstore_cli_succeeded": True}
    path = f"distributions/android/{build['number']}.json"
    if not ledger.create_json(path, receipt, f"Record Android distribution {build['number']}"):
        prior = ledger.read_json(path)
        if any(prior.get(k) != v for k, v in receipt.items() if k != "publication_build_id"):
            raise ProviderError("Existing distribution receipt differs from original candidate")
    return receipt


def main():
    if not os.environ.get("APPROVED_BUILD_NUMBER"):
        return
    ledger = GhLedgerStore(os.environ.get("SHOREBIRD_PROVENANCE_REPOSITORY")
                           or "divinevideo/divine-release-provenance")
    github = GitHub(os.environ["CM_REPO_SLUG"])
    if sys.argv[1:] == ["record"]:
        record_published(os.environ, ledger, github)
    elif not sys.argv[1:]:
        def cm(method, path):
            return request_json(method, "https://codemagic.io/api/v3" + path,
                                {"x-auth-token": os.environ["CODEMAGIC_API_TOKEN"]})
        publish_approved(os.environ, ledger, cm, github)
    else:
        raise ProviderError("Unknown Android distribution command")


if __name__ == "__main__":
    try:
        main()
    except (ProviderError, LedgerError, OSError, ValueError, KeyError):
        # Raw provider errors may contain signed URLs or credential-bearing details.
        sys.exit("Approved Android distribution stopped; inspect the retained identity before retrying")
