"""Main-only coordinator IO and durable mutation journal."""

from __future__ import annotations

import base64
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

from start_ios_release import APP_ID as CM_APP_ID
from start_ios_release import TEAM_ID as CM_TEAM_ID

from release_train.allocator import reconcile
from release_train.campaign_drafts import publish_release_drafts
from release_train.coordinator import (
    ACTIVE,
    APPLE_PLATFORMS,
    affects_app,
    consume_version_acknowledgements,
    current_acknowledgements,
    is_public_beta_release,
    observe,
    plan_tick,
    version_ack_key,
)
from release_train.ledger import (
    GhLedgerStore,
    LedgerError,
    claim_path,
    validate_macos_provenance,
)
from release_train.providers import (
    APP_ID,
    Apple,
    ArtifactRedirect,
    BeforeStoreMutationError,
    DeferredReview,
    NotFound,
    Play,
    ProviderError,
    apple_token,
    play_token,
    request_json,
    verify_bundle,
)
from release_train.store_review import STORE_ACTIONS, screen as screen_store_review
from release_train.versions import parse_version

STATE_PATH = "coordinator/state-v1.json"
DEFAULT_GROUPS = [
    "95678954-19fc-4e4d-aa56-f400d6a1b5d0",
    "20032be3-e9da-445b-a695-dbc9f6e1455b",
    "ddb77cbf-9fb9-4553-8363-b11572f2909c",
    "245e738b-b2d3-478e-9786-98511d085990",
]
WORKFLOWS = {
    "ios": "ios-scheduled-build",
    "macos": "macos-scheduled-build",
    "android": "android-build",
}


def beta_attributes(attributes, detail, legacy):
    if detail is not None:
        return detail["attributes"]
    if attributes.get("expired") or legacy:
        return {"externalBuildState": "EXPIRED"}
    processing = attributes.get("processingState")
    if processing == "PROCESSING":
        return {"externalBuildState": "PROCESSING"}
    if processing in {"FAILED", "INVALID"}:
        return {"externalBuildState": "PROCESSING_EXCEPTION"}
    raise ProviderError("Processed Apple build has no verifiable beta state")


def operation_key(action):
    identity = (
        action["sha"]
        if action["kind"] == "build"
        else str(action.get("build", {}).get("number") or action.get("number"))
    )
    return ":".join(
        [action["kind"], action["platform"], identity]
        + ([str(action["attempt"])] if action["kind"] == "build" else [])
    )


def reconcile_operations(state, snapshot):
    for key, operation in state.get("operations", {}).items():
        action = operation["action"]
        platform = action["platform"]
        kind = action["kind"]
        if kind == "android-distribution":
            from release_train.android_distribution import reconcile_distribution
            reconcile_distribution(key, operation, state, snapshot)
            continue
        if kind == "build":
            matches = [
                b
                for b in snapshot.get("cm", [])
                if b.get("platform") == platform
                and b.get("sha") == action["sha"]
                and b.get("attempt") == action["attempt"]
            ]
            if len(matches) > 1:
                state.setdefault("holds", {})[platform] = key
                continue
            if matches:
                build = matches[0]
                status = build["status"]
                operation["status"] = "done"
                operation["build_id"] = build["id"]
                state.setdefault("attempts", {}).setdefault(platform, {})[
                    action["sha"]
                ] = {
                    "count": action["attempt"],
                    "status": "active" if status in ACTIVE else status,
                    "build_id": build["id"],
                }
                if state.get("holds", {}).get(platform) == key:
                    state["holds"].pop(platform)
                if status == "finished":
                    started = operation.get("started_at", 0)
                    if started >= state.setdefault("last_built_source_started", {}).get(
                        platform, -1
                    ):
                        state["last_built_source_started"][platform] = started
                        state.setdefault("last_built_source", {})[platform] = action[
                            "sha"
                        ]
            elif operation["status"] in {"started", "ambiguous"}:
                state.setdefault("holds", {})[platform] = key
        elif operation["status"] in {"started", "ambiguous", "deferred"} or (
            (kind == "app-store" or is_public_beta_release(action))
            and operation["status"] == "acknowledged"
        ) or (
            is_public_beta_release(action)
            and operation["status"] == "done"
            and "cadence_at" not in operation
        ):
            build = action.get("build", action)
            observed = False
            if kind in {"public-beta", "attach-beta-groups"}:
                matches = [
                    b
                    for b in snapshot.get(platform, {}).get("builds", [])
                    if b["id"] == build["id"]
                ]
                if matches:
                    current = matches[0]
                    if is_public_beta_release(action) and current.get("public"):
                        confirmed_at = operation.setdefault(
                            "public_observed_at",
                            snapshot.get(platform, {}).get("observed_at", snapshot["now"]),
                        )
                        operation["cadence_at"] = max(
                            operation.get("cadence_at", 0), confirmed_at
                        )
                    observed = current.get("public_complete", current.get("public"))
                    if not observed and (
                        current.get("groups")
                        or current.get("external")
                        in {
                            "WAITING_FOR_BETA_REVIEW",
                            "IN_BETA_REVIEW",
                            "BETA_APPROVED",
                            "IN_BETA_TESTING",
                        }
                    ):
                        operation["status"] = "deferred"
                        if is_public_beta_release(action):
                            operation.setdefault(
                                "cadence_at",
                                snapshot.get(platform, {}).get("observed_at", snapshot["now"]),
                            )
                        if state.get("holds", {}).get(platform) == key:
                            state["holds"].pop(platform)
            elif kind == "app-store":
                matching = [
                    v
                    for v in snapshot.get(platform, {}).get("versions", [])
                    if v.get("build_id") == build["id"]
                ]
                accepted_states = {
                    "WAITING_FOR_REVIEW",
                    "IN_REVIEW",
                    "ACCEPTED",
                    "PENDING_DEVELOPER_RELEASE",
                    "PENDING_APPLE_RELEASE",
                    "PROCESSING_FOR_DISTRIBUTION",
                    "WAITING_FOR_EXPORT_COMPLIANCE",
                    "READY_FOR_SALE",
                    "READY_FOR_DISTRIBUTION",
                }
                superseded = any(
                    v["state"] in accepted_states
                    and v.get("build_id")
                    and v["build_id"] != build["id"]
                    and parse_version(v["version"]) >= parse_version(build["version"])
                    for v in snapshot.get(platform, {}).get("versions", [])
                )
                if superseded:
                    consume_version_acknowledgements(
                        state,
                        {
                            v["id"]
                            for v in snapshot.get(platform, {}).get("versions", [])
                            if v["state"] in accepted_states
                        },
                        platform,
                    )
                    operation["status"] = "superseded"
                    if state.get("holds", {}).get(platform) == key:
                        state["holds"].pop(platform)
                    continue
                observed = any(v["state"] in accepted_states for v in matching)
                ids = {v["id"] for v in matching}
                observed = observed or any(
                    (r["attributes"].get("submittedDate") or 0)
                    >= operation.get("started_at", snapshot.get("now", 0))
                    and any(i.get("version_id") in ids for i in r.get("items", []))
                    for r in snapshot.get(platform, {}).get("review_submissions", [])
                )
            elif kind in {"play-production", "retry-android-upload"}:
                track = "production" if kind == "play-production" else "internal"
                observed = any(
                    b["number"] == build["number"]
                    for b in snapshot.get("android", {}).get(track, [])
                )
            if observed:
                if is_public_beta_release(action):
                    operation.setdefault(
                        "cadence_at",
                        snapshot.get(platform, {}).get("observed_at", snapshot["now"]),
                    )
                if kind == "app-store":
                    consume_version_acknowledgements(
                        state, {v["id"] for v in matching}, platform
                    )
                operation["status"] = "done"
                if kind == "retry-android-upload":
                    state.pop("deferred_android", None)
                if state.get("holds", {}).get(platform) == key:
                    state["holds"].pop(platform)
            elif operation["status"] in {"started", "ambiguous"}:
                state.setdefault("holds", {})[platform] = key


def execute_plan(plan, state, snapshot, store, provider):
    for raw in list(plan["actions"]):
        action = dict(raw)
        key = operation_key(action)
        action["key"] = key
        old = state.get("operations", {}).get(key)
        if old and old["status"] not in {"deferred", "acknowledged"}:
            continue
        scope = "android-distribution" if action["kind"] == "android-distribution" else action["platform"]
        if (state.get("holds", {}).get(scope) is not None
                or (scope == "android-distribution" and state.get("holds", {}).get("android") is not None)):
            continue
        try:
            if hasattr(provider, "prepare_action"):
                provider.prepare_action(action, snapshot)
            elif action["kind"] == "build" and hasattr(provider, "prepare_build"):
                provider.prepare_build(action, snapshot)
        except ProviderError as error:
            plan.setdefault("errors", []).append(action["platform"] + ": " + str(error))
            plan["actions"].remove(raw)
            continue
        if scope == "android-distribution" and any(
            state.get("holds", {}).get(channel) is not None for channel in ("android", scope)
        ):
            continue
        public_beta_release = is_public_beta_release(action)
        operation = state.setdefault("operations", {})[key] = {
            # Notes already live in the immutable source/artifact ledger. Keep
            # only operation identity here, not another full copy on every save.
            "action": {name: value for name, value in action.items() if name != "release_notes"},
            "status": "started",
            "started_at": (
                int(time.time()) if public_beta_release or action["kind"] == "app-store"
                else snapshot.get("now", int(time.time()))
            ),
        }
        if old and "cadence_at" in old:
            # Retrying missing groups can replace the first attachment's entry.
            operation["cadence_at"] = old["cadence_at"]
        if action["kind"] == "build":
            state.setdefault("attempts", {}).setdefault(action["platform"], {})[
                action["sha"]
            ] = {"count": action["attempt"], "status": "starting"}
            state.setdefault("last_build_started", {})[action["platform"]] = (
                snapshot.get("now", int(time.time()))
            )
        store.save(state)
        try:
            result = provider.execute(action, state, snapshot)
            state["operations"][key]["status"] = (
                "deferred" if action["kind"] == "android-distribution" else "done")
            state["operations"][key]["result"] = result
            if action["kind"] in STORE_ACTIONS:
                # The store took this build, so its review confirmation is spent.
                state.get("store_review_confirmations", {}).pop(action["platform"], None)
        except BeforeStoreMutationError as error:
            # Nothing was submitted or published, so preserve the prior retryable
            # intent rather than manufacturing an ambiguous submission hold.
            if old is None:
                state["operations"].pop(key)
            else:
                state["operations"][key] = old
            plan.setdefault("errors", []).append(action["platform"] + ": " + str(error))
            plan["actions"].remove(raw)
        except DeferredReview:
            state["operations"][key]["status"] = "deferred"
            state.setdefault("messages", []).append(
                action["platform"] + ": waiting on previous Play review"
            )
        except ProviderError as error:
            state["operations"][key]["error"] = str(error)
            state["operations"][key]["status"] = "ambiguous"
            state.setdefault("holds", {})[scope] = key
        if public_beta_release and state.get("operations", {}).get(key) is operation:
            # A request's duration can vary; its return is the safe clock bound.
            operation["cadence_at"] = max(operation.get("cadence_at", 0), math.ceil(time.time()))
        store.save(state)


def acknowledge(state, item, snapshot):
    known = set(state.get("holds", {}).values())
    for platform in APPLE_PLATFORMS:
        known |= {
            f"{platform}-build:" + b["id"]
            for b in snapshot.get(platform, {}).get("builds", [])
            if b.get("external") in {"BETA_REJECTED", "REJECTED"}
        }
        known |= {
            f"{platform}-version:" + v["id"]
            for v in snapshot.get(platform, {}).get("versions", [])
            if v["state"]
            in {"REJECTED", "METADATA_REJECTED", "INVALID_BINARY", "DEVELOPER_REJECTED"}
        }
    if item not in known:
        raise ProviderError(
            "Acknowledgement must identify an observed rejection or current failure hold"
        )
    acknowledged_item = item
    for platform in APPLE_PLATFORMS:
        versions = snapshot.get(platform, {}).get("versions", [])
        matched = next(
            (
                version_ack_key(v, platform)
                for v in versions
                if item == f"{platform}-version:" + v["id"]
            ),
            None,
        )
        if matched is not None:
            acknowledged_item = matched
            break
    state.setdefault("acknowledged", []).append(acknowledged_item)
    state.setdefault("acknowledgement_events", []).append(
        {
            "item": acknowledged_item,
            "observed_at": snapshot.get("now", int(time.time())),
        }
    )
    state["holds"] = {
        p: key for p, key in state.get("holds", {}).items() if key != item
    }
    if item in state.get("operations", {}):
        operation = state["operations"][item]
        operation["status"] = "acknowledged"
        action = operation["action"]
        if action["kind"] == "build":
            attempt = (
                state.setdefault("attempts", {})
                .setdefault(action["platform"], {})
                .setdefault(action["sha"], {"count": action["attempt"]})
            )
            attempt["status"] = "failed"


class GitHub:
    def __init__(self, repository, token, request=request_json):
        self.base = "https://api.github.com/repos/" + repository
        self.token = token
        self.request = request

    def call(self, method, path, body=None):
        return self.request(
            method,
            self.base + path,
            {
                "Authorization": "Bearer " + self.token,
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
            body,
        )

    def pages(self, path, field=None):
        found = []
        page = 1
        while True:
            result = self.call(
                "GET",
                path + ("&" if "?" in path else "?") + f"per_page=100&page={page}",
            )
            entries = result[field] if field else result
            if not isinstance(entries, list):
                raise ProviderError("Incomplete GitHub listing")
            found.extend(entries)
            if len(entries) < 100:
                return found
            page += 1
            if page > 1000:
                raise ProviderError("GitHub listing exceeded safe pagination bound")


class UnmappedBuild(ProviderError):
    """The provider build has no allocation or release provenance record."""


class StateStore:
    def __init__(self, github):
        self.github = github
        self.sha = None

    def load(self):
        try:
            result = self.github.call("GET", "/contents/" + STATE_PATH + "?ref=main")
        except NotFound:
            return {}
        self.sha = result["sha"]
        if result.get("encoding") == "none":
            result = self.github.call("GET", "/git/blobs/" + self.sha)
        if result.get("encoding", "base64") != "base64":
            raise ProviderError("Private coordinator state encoding is unsupported")
        state = json.loads(base64.b64decode(result["content"]))
        if not isinstance(state, dict):
            raise ProviderError("Private coordinator state is invalid")
        return state

    def save(self, state):
        content = base64.b64encode(
            (json.dumps(state, sort_keys=True, indent=2) + "\n").encode()
        ).decode()
        payload = {
            "message": "Update release coordinator state",
            "content": content,
            "branch": "main",
        }
        if self.sha:
            payload["sha"] = self.sha
        result = self.github.call("PUT", "/contents/" + STATE_PATH, payload)
        self.sha = result["content"]["sha"]


class Runtime:
    def __init__(self, env):
        self.env = env
        self.gh = GitHub(env["GITHUB_REPOSITORY"], env["GH_TOKEN"])
        if not env.get("CANDIDATE_TAG_TOKEN"):
            raise ProviderError("Missing repository-scoped candidate tag App token")
        if not env.get("PUBLIC_PEOPLE_LIST_POLICY"):
            raise ProviderError("Missing PUBLIC_PEOPLE_LIST_POLICY repository configuration")
        self.tags = GitHub(env["GITHUB_REPOSITORY"], env["CANDIDATE_TAG_TOKEN"])
        private_token = env["PROVENANCE_TOKEN"]
        repository = env.get(
            "SHOREBIRD_PROVENANCE_REPOSITORY", "divinevideo/divine-release-provenance"
        )
        self.private = GitHub(repository, private_token)
        self.ledger = GhLedgerStore(
            repository,
            token=private_token,
        )
        self.store = StateStore(self.private)
        self.apple = None
        self.play = None

    def cm(self, method, path, body=None):
        return request_json(
            method,
            "https://codemagic.io/api/v3" + path,
            {"x-auth-token": self.env["CODEMAGIC_API_TOKEN"]},
            body,
        )

    def list_workflow_builds(self, workflows):
        entries = []
        for workflow in workflows:
            cursor = None
            seen = set()
            while True:
                query = {"app_id": CM_APP_ID, "workflow_id": workflow, "page_size": 100}
                if cursor is not None:
                    query["cursor"] = cursor
                page = self.cm(
                    "GET",
                    "/teams/" + CM_TEAM_ID + "/builds?" + urllib.parse.urlencode(query),
                )
                for item in page["data"]:
                    if (
                        item.get("app_id") != CM_APP_ID
                        or item.get("workflow", {}).get("id") != workflow
                    ):
                        raise ProviderError(
                            "Codemagic returned another app or workflow"
                        )
                    status = item["status"]
                    if status not in ACTIVE | {
                        "finished",
                        "failed",
                        "canceled",
                        "timeout",
                        "skipped",
                    }:
                        raise ProviderError("Unknown Codemagic build state")
                    if workflow == "android-build":
                        platform = "android"
                    elif workflow in {"macos-build", "macos-scheduled-build"}:
                        platform = "macos"
                    else:
                        platform = "ios"
                    labels = item.get("labels", [])
                    match = next(
                        (
                            re.fullmatch(
                                r"release-train:(ios|macos|android):([0-9a-f]{40}):([12])",
                                label,
                            )
                            for label in labels
                            if label.startswith("release-train:")
                        ),
                        None,
                    )
                    sha = (item.get("commit") or {}).get("hash")
                    if workflow == "zapstore-publish":
                        matches = [re.fullmatch(
                            r"release-distribution:android:([1-9][0-9]*):([0-9a-f]{40}):([1-9][0-9]*)", label)
                            for label in labels if label.startswith("release-distribution:")]
                        if len(matches) > 1 or (matches and matches[0] is None):
                            raise ProviderError("Ambiguous Android distribution job label")
                        distribution = matches[0] if matches else None
                        entries.append({"id": item["id"], "platform": "android-distribution",
                            "status": status, "sha": distribution.group(2) if distribution else sha,
                            "number": int(distribution.group(1)) if distribution else None,
                            "attempt": int(distribution.group(3)) if distribution else None})
                        continue
                    if match and sha and sha != match.group(2):
                        raise ProviderError(
                            "Scheduled Codemagic build fetched a different candidate"
                        )
                    entries.append(
                        {
                            "id": item["id"],
                            "platform": platform,
                            "status": status,
                            "sha": sha or (match.group(2) if match else None),
                            "attempt": int(match.group(3)) if match else None,
                        }
                    )
                cursor = page.get("cursor")
                if cursor is None:
                    break
                text = json.dumps(cursor, sort_keys=True)
                if text in seen or len(seen) > 1000:
                    raise ProviderError("Codemagic pagination did not finish")
                seen.add(text)
        return entries

    def list_builds(self):
        return self.list_workflow_builds(
            ["ios-build", "ios-scheduled-build", "android-build", "zapstore-publish"]
        )

    def list_macos_builds(self):
        return self.list_workflow_builds(["macos-build", "macos-scheduled-build"])

    def candidate(self):
        shas = subprocess.check_output(
            ["git", "rev-list", "--first-parent", "origin/main", "--max-count=100"],
            text=True,
        ).splitlines()
        for sha in shas:
            if self.source_ci(sha):
                return sha
        return None

    def source_ci(self, sha):
        if not hasattr(self, "_ci_cache"):
            self._ci_cache = {}
        if sha in self._ci_cache:
            return self._ci_cache[sha]
        if (
            not re.fullmatch("[0-9a-f]{40}", sha or "")
            or subprocess.run(
                ["git", "merge-base", "--is-ancestor", sha, "origin/main"],
                capture_output=True,
                check=False,
            ).returncode
        ):
            self._ci_cache[sha] = False
            return False
        query = urllib.parse.urlencode({"head_sha": sha, "status": "completed"})
        runs = self.gh.pages(
            "/actions/workflows/mobile_ci.yaml/runs?" + query, "workflow_runs"
        )
        passed = {
            str(r["id"])
            for r in runs
            if r["head_sha"] == sha
            and r["conclusion"] == "success"
            and r["status"] == "completed"
            and (
                r["event"] == "merge_group"
                or (r["event"] == "push" and r["head_branch"] == "main")
            )
        }
        if not passed:
            self._ci_cache[sha] = False
            return False
        checks = self.gh.pages(
            "/commits/" + sha + "/check-runs?check_name=Mobile%20CI", "check_runs"
        )
        result = any(
            c["name"] == "Mobile CI"
            and c["head_sha"] == sha
            and c["status"] == "completed"
            and c["conclusion"] == "success"
            and c.get("app", {}).get("id") == 15368
            and any(
                c.get("details_url", "").startswith(
                    "https://github.com/"
                    + self.env["GITHUB_REPOSITORY"]
                    + "/actions/runs/"
                    + run
                    + "/"
                )
                for run in passed
            )
            for c in checks
        )
        self._ci_cache[sha] = result
        return result

    def identity(self, platform, number, version=None, *, allow_historical=False):
        path = f"allocations/builds/{platform}/{number}.json"
        if path not in self.ledger.paths():
            matches = [
                p
                for p in self.ledger.paths()
                if re.fullmatch(
                    r"releases/"
                    + platform
                    + r"/[0-9]+\.[0-9]+\.[0-9]+\+"
                    + str(number)
                    + r"\.json",
                    p,
                )
            ]
            if not matches and allow_historical and platform in APPLE_PLATFORMS:
                if platform == "macos":
                    allocated = [
                        int(m.group(1))
                        for p in self.ledger.paths()
                        if (
                            m := re.fullmatch(
                                r"allocations/builds/macos/([0-9]+)\.json",
                                p,
                            )
                        )
                    ]
                    if not allocated or int(number) < min(allocated):
                        return {
                            "number": int(number),
                            "version": version,
                            "sha": None,
                            "legacy": True,
                        }
                else:
                    recorded = [
                        int(m.group(1))
                        for p in self.ledger.paths()
                        if (
                            m := re.fullmatch(
                                r"releases/" + platform + r"/[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)\.json",
                                p,
                            )
                        )
                    ]
                    if recorded and int(number) < min(recorded):
                        return {
                            "number": int(number),
                            "version": version,
                            "sha": None,
                            "legacy": True,
                        }
            if len(matches) != 1:
                error_type = ProviderError if matches else UnmappedBuild
                raise error_type(
                    f"Unreconciled {platform} build {number}; repair private provenance mapping"
                )
            path = matches[0]
        record = self.ledger.read_json(path)
        source = (
            record.get("source_sha")
            or record.get("build_source_commit")
            or record.get("source_commit")
            or record.get("git_commit")
        )
        name = (
            record.get("version")
            or record.get("build_name")
            or record.get("release_version", "").split("+")[0]
        )
        if version and name and name != version:
            raise ProviderError(
                "Provider marketing version conflicts with private build identity"
            )
        if not re.fullmatch("[0-9a-f]{40}", source or ""):
            raise ProviderError(f"{platform} build {number} has no verified source")
        if record.get("reservation_key"):
            # Allocation precedes the native build. It is not evidence that
            # native packaging and the provenance write both completed.
            completed = f"releases/{platform}/{name or version}+{number}.json"
            if completed not in self.ledger.paths():
                return {"number": int(number), "version": name or version,
                        "sha": None, "legacy": True, "provenance_incomplete": True}
            provenance = self.ledger.read_json(completed)
            if platform == "macos":
                try:
                    default_env = validate_macos_provenance(
                        provenance,
                        expected_version=name or version,
                        expected_number=int(number),
                        expected_source=source,
                    )
                except ValueError:
                    raise ProviderError(
                        f"{platform} build {number} has no matching completed provenance; "
                        "reconcile the partial native release before promotion"
                    ) from None
                return {
                    "number": int(number),
                    "version": name or version,
                    "sha": source,
                    "default_env": default_env,
                }
            if (provenance.get("platform") != platform
                    or provenance.get("release_version") != f"{name or version}+{number}"
                    or provenance.get("build_source_commit") != source
                    or provenance.get("patchable") is not True):
                raise ProviderError(f"{platform} build {number} has no matching completed provenance; reconcile the partial native release before promotion")
        elif platform == "macos":
            try:
                default_env = validate_macos_provenance(
                    record,
                    expected_version=name or version,
                    expected_number=int(number),
                    expected_source=source,
                )
            except ValueError:
                raise ProviderError(
                    f"{platform} build {number} has invalid macOS provenance; "
                    "repair private provenance mapping"
                ) from None
            return {
                "number": int(number),
                "version": name or version,
                "sha": source,
                "default_env": default_env,
            }
        return {"number": int(number), "version": name or version, "sha": source}

    def apple_snapshot(self, platform="ios"):
        apple = self.apple
        asc_platform = "MAC_OS" if platform == "macos" else "IOS"
        memberships = {}
        for identifier in apple.groups:
            group = apple.call("GET", "/betaGroups/" + identifier)["data"]["attributes"]
            if group.get("isInternalGroup") is not False:
                raise ProviderError(
                    "Configured TestFlight distribution group is no longer external"
                )
            if identifier == apple.group and not (
                group.get("publicLinkEnabled") is True and group.get("publicLink")
            ):
                raise ProviderError(
                    "Designated public TestFlight group no longer has its public link"
                )
            memberships[identifier] = {
                b["id"] for b in apple.pages("/betaGroups/" + identifier + "/builds")
            }
        builds, included = apple.pages_including(
            "/builds?"
            + urllib.parse.urlencode(
                {
                    "filter[app]": APP_ID,
                    "filter[preReleaseVersion.platform]": asc_platform,
                    "include": "preReleaseVersion,buildBetaDetail,betaAppReviewSubmission",
                    "limit": 200,
                }
            )
        )
        # Preserve included resources across every page; incomplete relations fail closed.
        normalized = []
        submitted = []
        for b in builds:
            attrs = b["attributes"]
            number = int(attrs["version"])

            def related(name, optional=False, build=b):
                relationship = build.get("relationships", {}).get(name, {}).get("data")
                if relationship is None:
                    if optional:
                        return None
                    raise ProviderError(
                        "Apple build is missing required included " + name
                    )
                value = included.get((relationship["type"], relationship["id"]))
                if value is None:
                    raise ProviderError("Apple pagination omitted related " + name)
                return value

            version = related("preReleaseVersion")["attributes"]["version"]
            identity = self.identity(platform, number, version, allow_historical=True)
            beta_detail = related("buildBetaDetail", optional=True)
            if (
                beta_detail is None
                and not identity.get("legacy")
                and attrs.get("processingState") == "VALID"
                and not attrs.get("expired")
            ):
                beta_detail = apple.beta_detail(b["id"], beta_detail)
            detail = beta_attributes(attrs, beta_detail, identity.get("legacy", False))
            review = related("betaAppReviewSubmission", optional=True)
            if review and review["attributes"].get("submittedDate"):
                submitted.append(epoch(review["attributes"]["submittedDate"]))
            external = detail.get("externalBuildState")
            normalized.append(
                identity
                | {
                    "id": b["id"],
                    "beta_detail_id": beta_detail["id"] if beta_detail else None,
                    "valid": not identity.get("legacy")
                    and attrs["processingState"] == "VALID"
                    and not attrs.get("expired", False),
                    "internal_available": detail.get("internalBuildState")
                    == "IN_BETA_TESTING",
                    "external": external,
                    "public": b["id"] in memberships[apple.group],
                    "groups": [
                        group for group in apple.groups if b["id"] in memberships[group]
                    ],
                    "public_complete": all(
                        b["id"] in memberships[group] for group in apple.groups
                    ),
                }
            )
        reviews = apple.pages(
            "/apps/" + APP_ID + "/reviewSubmissions?filter[platform]=" + asc_platform
        )
        versions = []
        for v in apple.pages(
            "/apps/" + APP_ID + "/appStoreVersions?filter[platform]=" + asc_platform
        ):
            attrs = v["attributes"]
            build = apple.call("GET", "/appStoreVersions/" + v["id"] + "/build").get(
                "data"
            )
            versions.append(
                {
                    "id": v["id"],
                    "version": attrs["versionString"],
                    "state": attrs.get("appVersionState") or attrs.get("appStoreState"),
                    "build_id": build["id"] if build else None,
                }
            )
        states = {
            "READY_FOR_REVIEW",
            "WAITING_FOR_REVIEW",
            "IN_REVIEW",
            "UNRESOLVED_ISSUES",
            "CANCELING",
            "COMPLETING",
            "COMPLETE",
        }
        for r in reviews:
            attrs = r["attributes"]
            if attrs["state"] not in states:
                raise ProviderError("Unknown Apple review submission state")
            if attrs.get("submittedDate"):
                attrs["submittedDate"] = epoch(attrs["submittedDate"])
            if attrs["state"] in {"UNRESOLVED_ISSUES", "READY_FOR_REVIEW"}:
                r["items"] = []
                for item in apple.pages(
                    "/reviewSubmissions/" + r["id"] + "/items?include=appStoreVersion"
                ):
                    version = (
                        item.get("relationships", {})
                        .get("appStoreVersion", {})
                        .get("data")
                    )
                    r["items"].append(
                        {
                            "id": item["id"],
                            "state": item["attributes"]["state"],
                            "version_id": version["id"] if version else None,
                        }
                    )
        return {
            "builds": normalized,
            "versions": versions,
            "submissions": submitted,
            "group_valid": True,
            "review_submissions": reviews,
        }

    def play_snapshot(self):
        tracks, errors = self.play.release_statuses()
        found = {"internal": [], "production": [], "releases": []}
        for track, releases in tracks.items():
            published = sorted({n for r in releases if r["state"] == "PUBLISHED"
                                for n in r["numbers"]})
            identities = {n: self.identity("android", n) for n in published}
            found[track] = list(identities.values())
            newest = max(published, default=0)
            for release in releases:
                current = not release["numbers"] or max(release["numbers"]) >= newest
                status = release["state"]
                builds = []
                for number in release["numbers"]:
                    try:
                        builds.append(identities.get(number) or self.identity("android", number))
                    except UnmappedBuild:
                        # An obsolete rejection without a recorded identity has no audit
                        # target. Current releases and inconsistent provenance fail closed.
                        if status != "NOT_APPROVED" or current:
                            raise
                found["releases"].append({"track": track, "state": status, "builds": builds})
                if current and status == "NOT_APPROVED":
                    found["error"] = "Google Play release rejected; resolve the provider rejection"
                elif status not in {"PUBLISHED", "NOT_APPROVED"}:
                    found[track + "_pending"] = True
        complete = not errors and {"internal", "production"} <= tracks.keys()
        if not complete:
            found["release_state_errors"] = errors
            found["error"] = "Google Play release lifecycle read incomplete; publication stopped"
        elif not found["production"]:
            found["error"] = "Play published production state is empty"
        found["lifecycle_complete"] = complete and bool(found["production"])
        setting = self.env.get("PLAY_MANAGED_PUBLISHING")
        found["managed_publishing"] = (
            False if setting == "off" else True if setting == "on" else None
        )
        return found

    def snapshot(self, state, levels):
        snapshot = {
            "now": int(time.time()),
            "ci_passed": False,
            "changes": {},
            "cm": list(self.list_builds()),
        }
        snapshot["candidate"] = self.candidate()
        snapshot["ci_passed"] = bool(snapshot["candidate"])
        for platform in ["ios", "macos", "android"]:
            baseline = state.get("last_built_source", {}).get(platform)
            if baseline and snapshot["candidate"]:
                paths = subprocess.check_output(
                    ["git", "diff", "--name-only", baseline, snapshot["candidate"]],
                    text=True,
                ).splitlines()
                snapshot["changes"][platform] = any(affects_app(p) for p in paths)
            else:
                snapshot["changes"][platform] = True
            if levels.get(platform, "off") == "off":
                snapshot[platform] = {}
                continue
            try:
                if platform in APPLE_PLATFORMS:
                    if getattr(self, "apple", None) is None:
                        # Assign only once the groups validate, so a failed
                        # iOS pass cannot leave macOS an unvalidated client.
                        group = (
                            self.env.get("TESTFLIGHT_PUBLIC_GROUP_ID") or DEFAULT_GROUPS[0]
                        )
                        apple = Apple(apple_token(self.env), group)
                        apple.groups = json.loads(
                            self.env.get("TESTFLIGHT_GROUP_IDS")
                            or json.dumps(DEFAULT_GROUPS)
                        )
                        if (
                            not isinstance(apple.groups, list)
                            or len(apple.groups) != 4
                            or set(apple.groups) != set(DEFAULT_GROUPS)
                            or group not in apple.groups
                        ):
                            raise ProviderError(
                                "TestFlight groups must preserve the four existing external audiences"
                            )
                        self.apple = apple
                    if platform == "macos":
                        snapshot["cm"].extend(self.list_macos_builds())
                    snapshot[platform] = self.apple_snapshot(platform)
                    snapshot[platform]["observed_at"] = math.ceil(time.time())
                else:
                    self.play = Play(
                        play_token(self.env["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"])
                    )
                    snapshot["android"] = self.play_snapshot()
                    snapshot["android"]["observed_at"] = int(time.time())
            except (ProviderError, KeyError, ValueError) as error:
                snapshot[platform] = {
                    "error": str(error)
                    if isinstance(error, ProviderError)
                    else "Missing credential, configuration, or malformed provider response"
                }
        for platform in ["ios", "macos", "android"]:
            data = snapshot.get(platform, {})
            if data.get("error"):
                continue
            try:
                builds = (data.get("builds", []) if platform in APPLE_PLATFORMS else
                          data.get("internal", []) + data.get("production", []))
                for b in builds:
                    b["ci_verified"] = bool(b.get("sha")) and self.source_ci(b["sha"])
            except ProviderError as error:
                snapshot[platform] = {"error": str(error)}
        if levels.get("android") in {"production", "dry-run"}:
            self.collect_distribution(snapshot, state)
        return snapshot

    def collect_distribution(self, snapshot, state):
        from release_train.android_distribution import manifest_digest, validate_downloads, receipt_matches

        data = snapshot["distribution"] = {"downloads": [], "receipts": {}}
        android = snapshot.get("android", {})
        if android.get("error") or not android.get("lifecycle_complete"):
            return
        builds = {b["number"]: b for b in android.get("production", []) if b.get("ci_verified")}
        for operation in state.get("operations", {}).values():
            if operation["action"]["kind"] == "android-distribution":
                b = operation["action"]["build"]
                builds.setdefault(b["number"], b)
        try:
            paths = self.ledger.paths()
            for number, build in builds.items():
                path = f"artifacts/android-downloads/{number}.json"
                if path not in paths:
                    continue
                record = self.ledger.read_json(path)
                validate_downloads(record, build)
                evidence = build | {"manifest_sha256": manifest_digest(record)}
                data["downloads"].append(evidence)
                receipt_path = f"distributions/android/{number}.json"
                if receipt_path in paths:
                    receipt = self.ledger.read_json(receipt_path)
                    if not receipt_matches(receipt, evidence) or receipt.get("apks") != record["apks"]:
                        raise ProviderError("Android distribution receipt identity differs")
                    data["receipts"][str(number)] = receipt
        except (ProviderError, LedgerError, KeyError, ValueError, TypeError):
            data["error"] = "Original Android download evidence could not be verified"

    def deploy(self, environment, build, status, state, stage=None):
        key = environment + ":" + str(build["number"])
        deployments = state.setdefault("deployments", {})
        if key not in deployments:
            # Public payload is an explicit allowlist. Artifact handles stay private.
            payload = {
                k: build[k] for k in ["version", "number", "sha", "id"] if k in build
            }
            existing = [
                d
                for d in self.gh.pages(
                    "/deployments?"
                    + urllib.parse.urlencode(
                        {"environment": environment, "sha": build["sha"]}
                    )
                )
                if isinstance(d.get("payload"), dict)
                and d["payload"].get("number") == build["number"]
            ]
            if len(existing) > 1:
                raise ProviderError(
                    "Duplicate build deployments require reconciliation"
                )
            result = (
                existing[0]
                if existing
                else self.gh.call(
                    "POST",
                    "/deployments",
                    {
                        "ref": build["sha"],
                        "environment": environment,
                        "auto_merge": False,
                        "required_contexts": [],
                        "payload": payload,
                        "transient_environment": False,
                        "production_environment": environment
                        in {"ios-app-store", "macos-app-store", "android-play-production"},
                    },
                )
            )
            deployments[key] = result["id"]
        marker = status + ":" + (stage or status)
        if state.setdefault("deployment_stages", {}).get(key) == marker:
            return
        self.gh.call(
            "POST",
            "/deployments/" + str(deployments[key]) + "/statuses",
            {
                "state": status,
                "description": (stage or status)[:140],
                "auto_inactive": False,
            },
        )

        state["deployment_stages"][key] = marker

    def audit_observations(self, snapshot, state):
        acknowledged_items = current_acknowledgements(snapshot, state)
        for platform in APPLE_PLATFORMS:
            apple_data = snapshot.get(platform, {})
            for build in apple_data.get("builds", []):
                if not build.get("sha"):
                    continue
                if build.get("valid") and build.get("internal_available"):
                    self.deploy(
                        f"{platform}-testflight-internal", build, "success", state, "available"
                    )
                if build.get("public") and build.get("external") in {
                    "READY_FOR_BETA_TESTING",
                    "IN_BETA_TESTING",
                }:
                    self.deploy(
                        f"{platform}-testflight-public", build, "success", state, "available"
                    )
                elif build.get("external") in {"BETA_REJECTED", "REJECTED"}:
                    acknowledged = f"{platform}-build:" + build["id"] in acknowledged_items
                    self.deploy(
                        f"{platform}-testflight-public",
                        build,
                        "inactive" if acknowledged else "failure",
                        state,
                        "acknowledged" if acknowledged else "rejected",
                    )
            for version in apple_data.get("versions", []):
                matches = [
                    b for b in apple_data.get("builds", []) if b["id"] == version.get("build_id")
                ]
                if not matches or not matches[0].get("sha"):
                    continue
                status = version["state"]
                acknowledged = version_ack_key(version, platform) in acknowledged_items
                if acknowledged and status in {
                    "REJECTED",
                    "METADATA_REJECTED",
                    "INVALID_BINARY",
                    "DEVELOPER_REJECTED",
                }:
                    self.deploy(
                        f"{platform}-app-store", matches[0], "inactive", state, "acknowledged"
                    )
                elif status in {
                    "REJECTED",
                    "METADATA_REJECTED",
                    "INVALID_BINARY",
                    "DEVELOPER_REJECTED",
                }:
                    self.deploy(f"{platform}-app-store", matches[0], "failure", state, "rejected")
                elif status in {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}:
                    self.deploy(f"{platform}-app-store", matches[0], "success", state, "available")
                elif status not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}:
                    self.deploy(
                        f"{platform}-app-store",
                        matches[0],
                        "in_progress",
                        state,
                        "in review or pending availability",
                    )
        for track in ["internal", "production"]:
            for build in snapshot.get("android", {}).get(track, []):
                if build.get("sha"):
                    self.deploy("android-play-" + track, build, "success", state, "available")
        for release in snapshot.get("android", {}).get("releases", []):
            status = release["state"]
            if status == "PUBLISHED":
                continue
            published = {b["number"] for b in snapshot["android"].get(release["track"], [])}
            for build in release["builds"]:
                # A metadata review does not remove an already published binary.
                if not build.get("sha") or build["number"] in published:
                    continue
                self.deploy(
                    "android-play-" + release["track"], build,
                    "failure" if status == "NOT_APPROVED" else "in_progress",
                    state,
                    "rejected" if status == "NOT_APPROVED" else status.lower().replace("_", " "),
                )
        for key in state.get("acknowledged", []):
            operation = state.get("operations", {}).get(key)
            if (
                operation
                and operation.get("status") == "acknowledged"
                and operation["action"].get("build")
            ):
                action = operation["action"]
                action_platform = action.get("platform", "ios")
                environment = {
                    "public-beta": f"{action_platform}-testflight-public",
                    "app-store": f"{action_platform}-app-store",
                    "play-production": "android-play-production",
                }.get(action["kind"])
                if environment:
                    self.deploy(
                        environment, action["build"], "inactive", state, "acknowledged"
                    )

    def release_bundle(self, platform, source, snapshot, retained=None):
        from release_train.release_notes import (
            bundle_for_native,
            bundle_from_env,
            ensure_bundle,
        )

        if retained is not None:
            return bundle_from_env(
                {"RELEASE_NOTES_BUNDLE": json.dumps(retained)}, source, platform
            )
        return bundle_for_native(ensure_bundle(
            platform, source, snapshot.get(platform), env=self.env, ledger=self.ledger
        ))

    def refresh_store_authorization(self, platform):
        """Renew snapshot credentials after slow generation or artifact downloads."""
        try:
            if platform in APPLE_PLATFORMS and isinstance(self.apple, Apple):
                self.apple.headers["Authorization"] = "Bearer " + apple_token(self.env)
            elif platform == "android" and isinstance(self.play, Play):
                self.play.headers["Authorization"] = "Bearer " + play_token(
                    self.env["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"]
                )
        except (ProviderError, KeyError, ValueError, OSError):
            # Only token creation/refresh belongs to this safe-to-retry boundary.
            # Provider calls below must keep their conservative ambiguity guard.
            raise BeforeStoreMutationError(
                "Store authorization unavailable before any store mutation; retry remains enabled"
            ) from None

    def retry_artifact_record(self, action):
        record = self.ledger.read_json(
            "artifacts/android/" + str(action["number"]) + ".json"
        )
        for field in ["number", "version", "sha", "digest", "build_id", "artifact_name"]:
            if record.get(field) != action.get(field):
                raise ProviderError(
                    "Deferred AAB identity conflicts with build-recorded signed artifact"
                )
        return record

    def prepared_bundle(self, action):
        from release_train.release_notes import bundle_from_env

        if action.get("release_notes") is None:
            raise ProviderError("Operation requires prepared source-bound release notes")
        source = action.get("build", action)["sha"]
        return bundle_from_env(
            {"RELEASE_NOTES_BUNDLE": json.dumps(action["release_notes"])},
            source, action["platform"],
        )

    def prepare_action(self, action, snapshot):
        """Finish fallible note preparation before journaling a store mutation."""
        from release_train.release_notes import bundle_for_native, notes_for

        if action["kind"] == "android-distribution":
            from release_train.android_distribution import manifest_digest, validate_downloads
            from release_train.setup import configure_build_credentials
            try:
                build = action["build"]
                android = snapshot.get("android", {})
                if (android.get("error") or not android.get("lifecycle_complete")
                        or not build.get("ci_verified") or not any(
                            all(b.get(k) == build.get(k) for k in ("number", "version", "sha"))
                            and b.get("ci_verified") for b in android.get("production", []))):
                    raise ProviderError("Exact Play production availability is not verified")
                record = self.ledger.read_json(f"artifacts/android-downloads/{build['number']}.json")
                validate_downloads(record, build)
                if manifest_digest(record) != build.get("manifest_sha256"):
                    raise ProviderError("Original APK evidence differs from the planned release")
                configure_build_credentials(self.cm, self.env["PROVENANCE_TOKEN"],
                                            self.env["PUBLIC_PEOPLE_LIST_POLICY"])
                action["approval_epoch"] = snapshot["now"]
                approval = {"schema": 1, "number": build["number"], "version": build["version"],
                            "sha": build["sha"], "manifest_sha256": build["manifest_sha256"],
                            "observed_at": snapshot["now"], "play_state": "PUBLISHED", "ci_verified": True}
                path = (f"distributions/approvals/android/{build['number']}/"
                        f"{action['attempt']}-{action['approval_epoch']}.json")
                if not self.ledger.create_json(path, approval, f"Observe approved Android {build['number']}"):
                    if self.ledger.read_json(path) != approval:
                        raise ProviderError("Existing Android approval evidence differs")
            except (ProviderError, LedgerError, KeyError, ValueError, TypeError):
                raise BeforeStoreMutationError("Approved Android distribution could not be prepared") from None
            return

        if action["kind"] == "build":
            self.prepare_build(action, snapshot)
            return
        channel = {
            "public-beta": "testflight",
            "app-store": "app_store",
            "play-production": "google_play",
            "retry-android-upload": "google_play",
        }.get(action["kind"])
        if channel is None:
            return
        retained = action.get("release_notes")
        if action["kind"] == "retry-android-upload":
            record = self.retry_artifact_record(action)
            retained = record.get("release_notes")
        source = action.get("build", action)["sha"]
        action["release_notes"] = self.release_bundle(
            action["platform"], source, snapshot, retained
        )
        bundle = self.prepared_bundle(action)
        notes_for(bundle, channel)
        action["release_notes"] = bundle_for_native(bundle)

    def prepare_build(self, action, snapshot):
        from release_train.setup import configure_build_credentials

        # Generation is fallible and must finish before recording a native attempt.
        action["release_notes"] = self.release_bundle(
            action["platform"], action["sha"], snapshot
        )
        self.prepared_bundle(action)
        configure_build_credentials(self.cm, self.env["PROVENANCE_TOKEN"],
                                    self.env["PUBLIC_PEOPLE_LIST_POLICY"])

    def execute(self, action, state, snapshot):
        kind = action["kind"]
        platform = action["platform"]
        build = action.get("build")
        if kind == "android-distribution":
            result = self.cm("POST", "/apps/" + CM_APP_ID + "/builds", {
                "workflow_id": "zapstore-publish", "branch": "main",
                "inputs": {"PUBLISH_TO_GITHUB": "YES", "RELEASE_CHANNEL": "PRODUCTION"},
                "environment": {"variables": {
                    "APPROVED_BUILD_NUMBER": str(build["number"]),
                    "APPROVED_VERSION": build["version"], "APPROVED_SOURCE_SHA": build["sha"],
                    "DISTRIBUTION_ATTEMPT": str(action["attempt"]),
                    "APPROVAL_OBSERVED_AT": str(action["approval_epoch"])}},
                "labels": [f"release-distribution:android:{build['number']}:{build['sha']}:{action['attempt']}"]})
            return {"build_id": result["data"]["id"]}
        if kind == "build":
            sha = action["sha"]
            bundle = self.prepared_bundle(action)
            tag = "release-candidate/" + sha
            try:
                existing = self.tags.call("GET", "/git/ref/tags/" + tag)
                if (
                    existing["object"]["type"] != "commit"
                    or existing["object"]["sha"] != sha
                ):
                    raise ProviderError(
                        "Candidate tag already targets different source"
                    )
            except NotFound:
                self.tags.call(
                    "POST", "/git/refs", {"ref": "refs/tags/" + tag, "sha": sha}
                )
            build_inputs = (
                {"DEFAULT_ENV": "PRODUCTION"}
                if platform == "macos"
                else {
                    "DEFAULT_ENV": "PRODUCTION",
                    "RELEASE_CHANNEL": "BETA",
                    "PUBLISH_TO_GITHUB": "NO",
                }
            )
            result = self.cm(
                "POST",
                "/apps/" + CM_APP_ID + "/builds",
                {
                    "workflow_id": WORKFLOWS[platform],
                    "tag": tag,
                    "inputs": build_inputs,
                    "environment": {
                        "variables": {
                            "RELEASE_EXPECTED_SHA": sha,
                            "RELEASE_NOTES_BUNDLE": json.dumps(bundle, separators=(",", ":"), ensure_ascii=False),
                            "RELEASE_TRAIN_SCHEDULED": "true",
                            "RELEASE_TRAIN_RESERVATION_KEY": f"scheduled/{platform}/{sha}",
                        }
                    },
                    "labels": [f"release-train:{platform}:{sha}:{action['attempt']}"],
                },
            )
            return {"build_id": result["data"]["id"]}
        if kind == "attach-beta-groups":
            self.refresh_store_authorization(platform)
            self.apple.attach_groups(build)
            return {}
        if kind == "public-beta":
            from release_train.release_notes import notes_for

            bundle = self.prepared_bundle(action)
            notes = notes_for(bundle, "testflight")
            self.refresh_store_authorization(platform)
            self.apple.submit_beta(build, notes)
            self.deploy(f"{platform}-testflight-public", build, "in_progress", state)
            return {}
        if kind == "app-store":
            from release_train.release_notes import notes_for

            bundle = self.prepared_bundle(action)
            notes = notes_for(bundle, "app_store")
            self.refresh_store_authorization(platform)
            submit_kwargs = {"platform": platform} if platform != "ios" else {}
            identifier = self.apple.submit_store(
                build,
                snapshot[platform]["versions"],
                state.get("acknowledged", []),
                reviews=snapshot[platform].get("review_submissions", []),
                notes=notes,
                **submit_kwargs,
            )
            submissions_key = (
                "app_store_submissions"
                if platform == "ios"
                else f"{platform}_app_store_submissions"
            )
            state.setdefault(submissions_key, []).append(math.ceil(time.time()))
            consume_version_acknowledgements(state, {identifier}, platform)
            self.claim(build, "app-store" if platform == "ios" else "mac-app-store")
            self.deploy(f"{platform}-app-store", build, "in_progress", state)
            return {"store_id": identifier}
        if kind == "play-production":
            from release_train.release_notes import notes_for

            bundle = self.prepared_bundle(action)
            notes = notes_for(bundle, "google_play")
            self.refresh_store_authorization(platform)
            self.play.promote(build["number"], notes=notes)
            self.claim(build, "play-production")
            state["last_play_promotion"] = snapshot["now"]
            self.deploy("android-play-production", build, "in_progress", state)
            return {}
        if kind == "retry-android-upload":
            record = self.retry_artifact_record(action)
            bundle = self.prepared_bundle(action)
            provider = self.cm("GET", "/builds/" + record["build_id"])["data"]
            if (provider.get("commit") or {}).get("hash") != record["sha"]:
                raise ProviderError("Deferred Codemagic source differs")
            matches = [
                a for a in provider["artifacts"] if a["name"] == record["artifact_name"]
            ]
            if len(matches) != 1:
                raise ProviderError(
                    "Retained signed AAB is missing or ambiguous; do not rebuild spent identity"
                )
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "original.aab"
                self.download(matches[0]["url"], path)
                verify_bundle(path, record["digest"])
                from release_train.release_notes import notes_for

                notes = notes_for(bundle, "google_play")
                self.refresh_store_authorization(platform)
                self.play.upload(
                    path, record["number"], record["digest"], notes=notes,
                )
            state.setdefault("resolved_android_uploads", []).append(record["number"])
            state.pop("deferred_android", None)
            return {}
        raise ProviderError("Unknown release operation")

    def claim(self, build, channel):
        self.ledger.create_json(
            claim_path(build["version"], channel),
            {
                "schema": 1,
                "version": build["version"],
                "channel": channel,
                "source_sha": build["sha"],
                "build_number": build["number"],
                "observed_at": datetime.now(UTC).isoformat(),
            },
            "Claim " + build["version"] + " " + channel,
        )

    def download(self, url, path):
        parsed = urllib.parse.urlsplit(url)
        if (
            parsed.scheme != "https"
            or parsed.hostname not in {"api.codemagic.io", "codemagic.io"}
            or not parsed.path.startswith("/artifacts/")
        ):
            raise ProviderError("Unexpected authenticated artifact origin")
        req = urllib.request.Request(
            url, headers={"x-auth-token": self.env["CODEMAGIC_API_TOKEN"]}
        )
        try:
            with (
                urllib.request.build_opener(ArtifactRedirect).open(
                    req, timeout=120
                ) as response,
                path.open("wb") as stream,
            ):
                shutil.copyfileobj(response, stream)
        except OSError:
            raise ProviderError(
                "Retained signed artifact unavailable; queue stopped, never rebuild this identity"
            ) from None


def epoch(value):
    return int(datetime.fromisoformat(value).timestamp())


def diagnose_android_upload(runtime, number):
    """Store private Play validation evidence without changing release state."""
    if not re.fullmatch(r"[1-9][0-9]{0,9}", number) or int(number) > 2100000000:
        raise ProviderError("Diagnostic build number must be a positive Android version code")
    from release_train.release_notes import bundle_from_env, notes_for

    env = runtime.env
    record = runtime.ledger.read_json(f"uploads/android/{number}.json")
    if record.get("number") != int(number) or record.get("status") != "failed":
        raise ProviderError("Diagnostic requires the exact retained failed upload")
    if runtime.store.load().get("holds", {}).get("android") != f"android-upload:{number}":
        raise ProviderError("Diagnostic requires the exact Android upload hold")
    if any(build["platform"] == "android" and build["status"] in ACTIVE
           for build in runtime.list_builds()):
        raise ProviderError("Wait for active Android builds before opening a diagnostic edit")
    bundle = bundle_from_env({"RELEASE_NOTES_BUNDLE": json.dumps(record["release_notes"])},
                             record["sha"], "android")
    play = Play(play_token(env["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"]))
    report = play.diagnose_upload(notes=notes_for(bundle, "google_play"))
    path = f"diagnostics/android/{number}/{env['GITHUB_RUN_ID']}-{env['GITHUB_RUN_ATTEMPT']}.json"
    if not runtime.ledger.create_json(path, report | {"number": int(number), "sha": record["sha"]},
                                       f"Record Android upload diagnostic {number}"):
        raise ProviderError("Diagnostic report path already exists; inspect the retained report")
    # Provider messages may contain private metadata. Only the ledger gets them.
    print("Android upload diagnostic recorded privately at " + path)
    print("No binary upload, edit commit, release acknowledgement or build dispatch performed.")
    return 1 if any(report.get(key) for key in [
        "error", "cleanup_error", "release_state_errors"
    ]) else 0


def main(env=os.environ):
    expected = (
        env.get("GITHUB_REPOSITORY", "")
        + "/.github/workflows/release_train.yml@refs/heads/main"
    )
    if (
        env.get("GITHUB_REF") != "refs/heads/main"
        or env.get("GITHUB_EVENT_NAME") not in {"schedule", "workflow_dispatch"}
        or env.get("GITHUB_WORKFLOW_REF") != expected
    ):
        raise ProviderError(
            "Release coordinator requires trusted main schedule or dispatch"
        )
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if source != env.get("GITHUB_SHA") or source != env.get("GITHUB_WORKFLOW_SHA"):
        raise ProviderError("Coordinator source differs from trusted main workflow")
    levels = {
        "ios": env.get("RELEASE_TRAIN_IOS") or "off",
        "macos": env.get("RELEASE_TRAIN_MACOS") or "off",
        "android": env.get("RELEASE_TRAIN_ANDROID") or "off",
    }
    runtime = Runtime(env)
    if env.get("RELEASE_DIAGNOSE_ANDROID_UPLOAD"):
        if env.get("GITHUB_EVENT_NAME") != "workflow_dispatch" or any(
            env.get(name) for name in ["RELEASE_ACKNOWLEDGE"]
        ) or any(env.get(name) == "true" for name in ["RELEASE_SETUP_CODEMAGIC", "RELEASE_BOOTSTRAP"]):
            raise ProviderError("Upload diagnostics require a standalone manual dispatch")
        return diagnose_android_upload(runtime, env["RELEASE_DIAGNOSE_ANDROID_UPLOAD"])
    dry = env.get("RELEASE_DRY_RUN") == "true" or all(
        level in {"off", "dry-run"} for level in levels.values()
    )
    if (
        env.get("RELEASE_SETUP_CODEMAGIC") == "true"
        or env.get("RELEASE_BOOTSTRAP") == "true"
    ):
        from release_train.setup import (
            bootstrap_live,
            capacity_metadata,
            configure_codemagic,
        )

        messages = []
        if env.get("RELEASE_SETUP_CODEMAGIC") == "true":
            messages.append(
                "Would configure encrypted Codemagic allocator credential."
                if env.get("RELEASE_DRY_RUN") == "true"
                else configure_codemagic(runtime.cm, env["CODEMAGIC_API_TOKEN"])
            )
        if env.get("RELEASE_BOOTSTRAP") == "true":
            messages.append(
                bootstrap_live(runtime, env.get("RELEASE_DRY_RUN") == "true")
            )
        messages.append(json.dumps(capacity_metadata(runtime.cm), sort_keys=True))
        report = "\n\n".join(messages) + "\n"
        print(report)
        if env.get("GITHUB_STEP_SUMMARY"):
            Path(env["GITHUB_STEP_SUMMARY"]).write_text(report)
        return 0
    state = runtime.store.load()
    snapshot = runtime.snapshot(state, levels)
    state = observe(snapshot, state)
    reconcile_operations(state, snapshot)
    acknowledgement = env.get("RELEASE_ACKNOWLEDGE", "")
    if acknowledgement:
        acknowledge(state, acknowledgement, snapshot)
    # Repair claims after an accepted store mutation, including manual releases.
    if not dry:
        for platform in ["ios", "macos", "android"]:
            data = snapshot.get(platform, {})
            if levels[platform] in {"off", "dry-run"} or data.get("error"):
                continue
            if platform in APPLE_PLATFORMS:
                from release_train.versions import parse_version

                versions = [
                    parse_version(v["version"])
                    for v in data.get("versions", [])
                    if v["state"] not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}
                ]
                reconcile(
                    platform,
                    ledger=runtime.ledger,
                    store_versions=versions,
                    now=datetime.now(UTC),
                )
            else:
                reconcile(
                    "android",
                    ledger=runtime.ledger,
                    store_version_codes=[
                        b["number"] for b in data.get("production", [])
                    ],
                    now=datetime.now(UTC),
                )
        # Discover manual as well as scheduled publishing deferrals, across restarts.
        uploaded = {
            b["number"] for b in snapshot.get("android", {}).get("internal", [])
        }
        for path in sorted(runtime.ledger.paths()):
            if path.startswith("uploads/android/"):
                record = runtime.ledger.read_json(path)
                if (
                    record["number"] not in uploaded
                    and record["number"]
                    not in state.get("resolved_android_uploads", [])
                    and record.get("status") == "deferred"
                ):
                    if (
                        state.get("deferred_android")
                        and state["deferred_android"]["number"] != record["number"]
                    ):
                        raise ProviderError(
                            "Multiple deferred Android artifacts require operator reconciliation"
                        )
                    state["deferred_android"] = {
                        name: value for name, value in record.items() if name != "release_notes"
                    }
                elif record["number"] in uploaded:
                    if record["number"] not in state.setdefault(
                        "resolved_android_uploads", []
                    ):
                        state["resolved_android_uploads"].append(record["number"])
                    if (
                        state.get("deferred_android", {}).get("number")
                        == record["number"]
                    ):
                        state.pop("deferred_android")
                elif record.get("status") == "failed" and "android-upload:" + str(
                    record["number"]
                ) not in state.get("acknowledged", []):
                    state.setdefault("holds", {})["android"] = "android-upload:" + str(
                        record["number"]
                    )
    plan = plan_tick(snapshot, state, levels)
    store_review_approval = (
        env.get("RELEASE_APPROVE_STORE_REVIEW", "")
        if env.get("GITHUB_EVENT_NAME") == "workflow_dispatch" else ""
    )
    confirmations = screen_store_review(
        plan, snapshot, store_review_approval, dry=dry,
        confirmed=state.get("store_review_confirmations", {}),
    )
    if not dry:
        if confirmations:
            state.setdefault("store_review_confirmations", {}).update(confirmations)
        runtime.store.save(state)
        audit_snapshot = dict(snapshot)
        for platform in ["ios", "macos", "android"]:
            if levels[platform] in {"off", "dry-run"}:
                audit_snapshot[platform] = {}
        runtime.audit_observations(audit_snapshot, state)
        runtime.store.save(state)
        execute_plan(plan, state, snapshot, runtime.store, runtime)
    draft_messages = publish_release_drafts(snapshot, env, levels, dry_run=dry)
    summary = [
        "Release train " + ("dry run" if dry else "tick"),
        *plan["reasons"],
        *plan["errors"],
        *draft_messages,
    ]
    summary += [a["platform"] + ": " + a["kind"] for a in plan["actions"]]
    summary += [
        "Would " + a["platform"] + ": " + a["kind"] for a in plan.get("proposed", [])
    ]
    summary += [
        operation["error"]
        for operation in state.get("operations", {}).values()
        if operation.get("status") == "ambiguous" and operation.get("error")
    ]
    summary += [
        "Queue held: " + p + " (" + key + ")"
        for p, key in state.get("holds", {}).items()
    ]
    summary += [
        "Lowering a level stops new submissions; accepted store reviews still need console action to stop release."
    ]
    text = "\n\n".join(summary) + "\n"
    print(text)
    if env.get("GITHUB_STEP_SUMMARY"):
        Path(env["GITHUB_STEP_SUMMARY"]).write_text(text)
    active_holds = any(
        levels.get("android" if p == "android-distribution" else p) not in {"off", "dry-run"}
        for p in state.get("holds", {})
    )
    return 1 if plan["errors"] or active_holds else 0
