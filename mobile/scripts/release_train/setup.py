"""Explicit main-only setup tasks; no changes to signing or store settings."""

import subprocess
from datetime import UTC, datetime

from start_ios_release import APP_ID as CM_APP_ID
from start_ios_release import TEAM_ID

from release_train.allocator import bootstrap, map_play_version_codes
from release_train.ledger import claim_path
from release_train.providers import (
    APP_ID,
    Apple,
    Play,
    ProviderError,
    apple_token,
    play_token,
)
from release_train.store_state import (
    ios_submitted_versions,
    play_production_version_codes,
    stable_tag_versions,
)


def cm_pages(cm, path):
    entries = []
    for page in range(1, 1001):
        response = cm(
            "GET", path + ("&" if "?" in path else "?") + f"page_size=100&page={page}"
        )
        entries.extend(response["data"])
        if len(response["data"]) < 100:
            return entries
    raise ProviderError("Incomplete Codemagic configuration listing")


def configure_secure_variables(cm, values):
    if any(not value for value in values.values()):
        raise ProviderError("Missing scoped GitHub build credential")
    groups = cm_pages(cm, "/apps/" + CM_APP_ID + "/variable-groups")
    if not any(g["name"] == "github_credentials" for g in groups):
        groups += cm_pages(cm, "/teams/" + TEAM_ID + "/variable-groups")
    matches = {g["id"]: g for g in groups if g["name"] == "github_credentials"}
    if len(matches) != 1:
        raise ProviderError(
            "Expected one existing github_credentials Codemagic group; configure it before setup"
        )
    identifier = next(iter(matches))
    path = "/variable-groups/" + identifier + "/variables"
    variables = cm_pages(cm, path)
    for name, value in values.items():
        existing = [v for v in variables if v["name"] == name]
        if len(existing) > 1:
            raise ProviderError("Duplicate Codemagic variables require reconciliation")
        if existing:
            cm("PATCH", path + "/" + existing[0]["id"], {"value": value, "secure": True})
        else:
            cm("POST", path, {"secure": True, "variables": [{"name": name, "value": value}]})
    verified = cm_pages(cm, path)
    for name in values:
        matches = [v for v in verified if v["name"] == name]
        if len(matches) != 1 or matches[0].get("secure") is not True:
            raise ProviderError("Codemagic variable encryption could not be verified")


def configure_codemagic(cm, token):
    configure_secure_variables(cm, {"CODEMAGIC_API_TOKEN": token})
    return "Scheduled allocator credential configured and verified secure in existing github_credentials."


def configure_build_credentials(cm, private_token, mobile_token):
    # API build overrides are plain strings; use the provider's secure storage.
    configure_secure_variables(cm, {
        "PROVENANCE_TOKEN": private_token,
        "GH_TOKEN": mobile_token,
        "GITHUB_TOKEN": mobile_token,
    })


def bootstrap_live(runtime, dry_run):
    env = runtime.env
    apple = Apple(apple_token(env), env.get("TESTFLIGHT_PUBLIC_GROUP_ID", ""))
    play = Play(play_token(env["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"]))
    versions = apple.pages("/apps/" + APP_ID + "/appStoreVersions?filter[platform]=IOS")
    tracks = play.tracks()
    production = next((t for t in tracks if t["track"] == "production"), None)
    codes = []
    for track in tracks:
        for release in track.get("releases", []):
            if track["track"] == "production" and release.get("status") == "draft":
                continue
            if release.get("status") not in {
                "draft",
                "completed",
                "inProgress",
                "halted",
            }:
                raise ProviderError("Unknown Play bootstrap state")
            codes.extend(int(n) for n in release.get("versionCodes", []))
    map_play_version_codes(runtime.ledger, codes)
    claims = bootstrap(
        ledger=runtime.ledger,
        ios_store_versions=ios_submitted_versions(versions),
        android_version_codes=play_production_version_codes(production),
        now=datetime.now(UTC),
        dry_run=dry_run,
    )
    tags = subprocess.check_output(
        ["git", "ls-remote", "--tags", "origin"], text=True
    ).splitlines()
    for version in stable_tag_versions(line.split()[-1] for line in tags):
        path = claim_path(version, "github-stable")
        if path not in runtime.ledger.paths():
            claims.append(path)
            if not dry_run:
                runtime.ledger.create_json(
                    path,
                    {
                        "schema": 1,
                        "version": str(version),
                        "channel": "github-stable",
                        "source": "bootstrap",
                    },
                    "Bootstrap GitHub stable version " + str(version),
                )
    return (
        ("Would bootstrap " if dry_run else "Bootstrapped ")
        + str(len(claims))
        + " identity records; all observed Play track codes reconciled."
    )


def capacity_metadata(cm):
    # No billing changes, no payment details. Missing capability isn't invented.
    try:
        subscriptions = cm("GET", "/teams/" + TEAM_ID + "/subscriptions")["data"]
        safe = [
            {k: s[k] for k in ["pricing_model", "status", "category"] if k in s}
            for s in subscriptions
        ]
        return {
            "subscriptions": safe,
            "required_machines": ["mac_mini_m2", "mac_mini_m4"],
            "concurrency": "verify fixed plan includes three builds and M4 in Codemagic billing",
            "queue_policy": "no new workflow while a manual or scheduled build of that platform is active",
        }
    except ProviderError:
        return {
            "subscription": "not readable with release token",
            "concurrency": "operator must verify three fixed-plan slots and M4 coverage",
        }
