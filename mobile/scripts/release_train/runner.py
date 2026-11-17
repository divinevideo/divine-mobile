"""Main-only coordinator IO and durable mutation journal."""

from __future__ import annotations

import base64
import json
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
from release_train.coordinator import (
    ACTIVE,
    affects_app,
    consume_version_acknowledgements,
    current_acknowledgements,
    observe,
    plan_tick,
    version_ack_key,
)
from release_train.ledger import GhLedgerStore, claim_path
from release_train.providers import (
    APP_ID,
    Apple,
    ArtifactRedirect,
    DeferredReview,
    NotFound,
    Play,
    ProviderError,
    apple_token,
    play_token,
    request_json,
    verify_bundle,
)
from release_train.versions import parse_version

STATE_PATH = "coordinator/state-v1.json"
DEFAULT_GROUPS = [
    "95678954-19fc-4e4d-aa56-f400d6a1b5d0",
    "20032be3-e9da-445b-a695-dbc9f6e1455b",
    "ddb77cbf-9fb9-4553-8363-b11572f2909c",
    "245e738b-b2d3-478e-9786-98511d085990",
]
WORKFLOWS = {"ios": "ios-scheduled-build", "android": "android-build"}


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
            kind == "app-store" and operation["status"] == "acknowledged"
        ):
            build = action.get("build", action)
            observed = False
            if kind in {"public-beta", "attach-beta-groups"}:
                matches = [
                    b
                    for b in snapshot.get("ios", {}).get("builds", [])
                    if b["id"] == build["id"]
                ]
                if matches:
                    current = matches[0]
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
                        if state.get("holds", {}).get(platform) == key:
                            state["holds"].pop(platform)
            elif kind == "app-store":
                matching = [
                    v
                    for v in snapshot.get("ios", {}).get("versions", [])
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
                    for v in snapshot.get("ios", {}).get("versions", [])
                )
                if superseded:
                    consume_version_acknowledgements(
                        state,
                        {
                            v["id"]
                            for v in snapshot.get("ios", {}).get("versions", [])
                            if v["state"] in accepted_states
                        },
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
                    for r in snapshot.get("ios", {}).get("review_submissions", [])
                )
            elif kind in {"play-production", "retry-android-upload"}:
                track = "production" if kind == "play-production" else "internal"
                observed = any(
                    b["number"] == build["number"]
                    for b in snapshot.get("android", {}).get(track, [])
                )
            if observed:
                if kind == "app-store":
                    consume_version_acknowledgements(state, {v["id"] for v in matching})
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
        if state.get("holds", {}).get(action["platform"]) is not None:
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
        state.setdefault("operations", {})[key] = {
            "action": action,
            "status": "started",
            "started_at": snapshot.get("now", int(time.time())),
        }
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
            state["operations"][key]["status"] = "done"
            state["operations"][key]["result"] = result
        except DeferredReview:
            state["operations"][key]["status"] = "deferred"
            state.setdefault("messages", []).append(
                action["platform"] + ": waiting on previous Play review"
            )
        except ProviderError as error:
            state["operations"][key]["error"] = str(error)
            state["operations"][key]["status"] = "ambiguous"
            state.setdefault("holds", {})[action["platform"]] = key
        store.save(state)


def acknowledge(state, item, snapshot):
    known = (
        set(state.get("holds", {}).values())
        | {
            "ios-build:" + b["id"]
            for b in snapshot.get("ios", {}).get("builds", [])
            if b.get("external") in {"BETA_REJECTED", "REJECTED"}
        }
        | {
            "ios-version:" + v["id"]
            for v in snapshot.get("ios", {}).get("versions", [])
            if v["state"]
            in {"REJECTED", "METADATA_REJECTED", "INVALID_BINARY", "DEVELOPER_REJECTED"}
        }
    )
    if item not in known:
        raise ProviderError(
            "Acknowledgement must identify an observed rejection or current failure hold"
        )
    versions = snapshot.get("ios", {}).get("versions", [])
    acknowledged_item = next(
        (version_ack_key(v) for v in versions if item == "ios-version:" + v["id"]), item
    )
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

    def list_builds(self):
        entries = []
        for workflow in ["ios-build", "ios-scheduled-build", "android-build"]:
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
                    platform = "android" if workflow == "android-build" else "ios"
                    labels = item.get("labels", [])
                    match = next(
                        (
                            re.fullmatch(
                                r"release-train:(ios|android):([0-9a-f]{40}):([12])",
                                label,
                            )
                            for label in labels
                            if label.startswith("release-train:")
                        ),
                        None,
                    )
                    sha = (item.get("commit") or {}).get("hash")
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
            if not matches and allow_historical and platform == "ios":
                recorded = [
                    int(m.group(1))
                    for path in self.ledger.paths()
                    if (
                        m := re.fullmatch(
                            r"releases/ios/[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)\.json", path
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
                raise ProviderError(
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
            # Shorebird registration and the provenance write both completed.
            completed = f"releases/{platform}/{name or version}+{number}.json"
            if completed not in self.ledger.paths():
                return {"number": int(number), "version": name or version,
                        "sha": None, "legacy": True, "provenance_incomplete": True}
            provenance = self.ledger.read_json(completed)
            if (provenance.get("platform") != platform
                    or provenance.get("release_version") != f"{name or version}+{number}"
                    or provenance.get("build_source_commit") != source
                    or provenance.get("patchable") is not True):
                raise ProviderError(f"{platform} build {number} has no matching completed provenance; reconcile the partial native release before promotion")
        return {"number": int(number), "version": name or version, "sha": source}

    def apple_snapshot(self):
        apple = self.apple
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
            identity = self.identity("ios", number, version, allow_historical=True)
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
        reviews = apple.pages("/apps/" + APP_ID + "/reviewSubmissions")
        versions = []
        for v in apple.pages(
            "/apps/" + APP_ID + "/appStoreVersions?filter[platform]=IOS"
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
        tracks = self.play.tracks()
        found = {}
        for track in tracks:
            if track["track"] not in {"internal", "production"}:
                continue
            numbers = []
            for release in track.get("releases", []):
                if release.get("status") == "draft":
                    continue
                if release.get("status") not in {"completed", "inProgress", "halted"}:
                    raise ProviderError("Unknown Play track state")
                numbers.extend(int(n) for n in release["versionCodes"])
            found[track["track"]] = [
                self.identity("android", n) for n in sorted(set(numbers))
            ]
        if not found.get("production"):
            raise ProviderError("Play production state is empty")
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
            "cm": self.list_builds(),
        }
        snapshot["candidate"] = self.candidate()
        snapshot["ci_passed"] = bool(snapshot["candidate"])
        for platform in ["ios", "android"]:
            baseline = state.get("last_built_source", {}).get(platform)
            if baseline and snapshot["candidate"]:
                paths = subprocess.check_output(
                    ["git", "diff", "--name-only", baseline, snapshot["candidate"]],
                    text=True,
                ).splitlines()
                snapshot["changes"][platform] = any(affects_app(p) for p in paths)
            else:
                snapshot["changes"][platform] = True
            if levels[platform] == "off":
                snapshot[platform] = {}
                continue
            try:
                if platform == "ios":
                    group = (
                        self.env.get("TESTFLIGHT_PUBLIC_GROUP_ID") or DEFAULT_GROUPS[0]
                    )
                    self.apple = Apple(apple_token(self.env), group)
                    self.apple.groups = json.loads(
                        self.env.get("TESTFLIGHT_GROUP_IDS")
                        or json.dumps(DEFAULT_GROUPS)
                    )
                    if (
                        not isinstance(self.apple.groups, list)
                        or len(self.apple.groups) != 4
                        or set(self.apple.groups) != set(DEFAULT_GROUPS)
                        or group not in self.apple.groups
                    ):
                        raise ProviderError(
                            "TestFlight groups must preserve the four existing external audiences"
                        )
                    snapshot["ios"] = self.apple_snapshot()
                else:
                    self.play = Play(
                        play_token(self.env["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"])
                    )
                    snapshot["android"] = self.play_snapshot()
            except (ProviderError, KeyError, ValueError) as error:
                snapshot[platform] = {
                    "error": str(error)
                    if isinstance(error, ProviderError)
                    else "Missing credential, configuration, or malformed provider response"
                }
        for platform in ["ios", "android"]:
            data = snapshot.get(platform, {})
            if data.get("error"):
                continue
            try:
                for b in data.get("builds" if platform == "ios" else "internal", []):
                    b["ci_verified"] = bool(b.get("sha")) and self.source_ci(b["sha"])
            except ProviderError as error:
                snapshot[platform] = {"error": str(error)}
        return snapshot

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
                        in {"ios-app-store", "android-play-production"},
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
        ios = snapshot.get("ios", {})
        for build in ios.get("builds", []):
            if not build.get("sha"):
                continue
            if build.get("valid") and build.get("internal_available"):
                self.deploy(
                    "ios-testflight-internal", build, "success", state, "available"
                )
            if build.get("public") and build.get("external") in {
                "READY_FOR_BETA_TESTING",
                "IN_BETA_TESTING",
            }:
                self.deploy(
                    "ios-testflight-public", build, "success", state, "available"
                )
            elif build.get("external") in {"BETA_REJECTED", "REJECTED"}:
                acknowledged = "ios-build:" + build["id"] in acknowledged_items
                self.deploy(
                    "ios-testflight-public",
                    build,
                    "inactive" if acknowledged else "failure",
                    state,
                    "acknowledged" if acknowledged else "rejected",
                )
        for version in ios.get("versions", []):
            matches = [
                b for b in ios.get("builds", []) if b["id"] == version.get("build_id")
            ]
            if not matches or not matches[0].get("sha"):
                continue
            status = version["state"]
            acknowledged = version_ack_key(version) in acknowledged_items
            if acknowledged and status in {
                "REJECTED",
                "METADATA_REJECTED",
                "INVALID_BINARY",
                "DEVELOPER_REJECTED",
            }:
                self.deploy(
                    "ios-app-store", matches[0], "inactive", state, "acknowledged"
                )
            elif status in {
                "REJECTED",
                "METADATA_REJECTED",
                "INVALID_BINARY",
                "DEVELOPER_REJECTED",
            }:
                self.deploy("ios-app-store", matches[0], "failure", state, "rejected")
            elif status in {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}:
                self.deploy("ios-app-store", matches[0], "success", state, "available")
            elif status not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}:
                self.deploy(
                    "ios-app-store",
                    matches[0],
                    "in_progress",
                    state,
                    "in review or pending availability",
                )
        for build in snapshot.get("android", {}).get("internal", []):
            if build.get("sha"):
                self.deploy("android-play-internal", build, "success", state, "available")
        for build in snapshot.get("android", {}).get("production", []):
            if not build.get("sha"):
                continue
            self.deploy(
                "android-play-production",
                build,
                "in_progress",
                state,
                "production track observed; review outcome via console/email",
            )
        for key in state.get("acknowledged", []):
            operation = state.get("operations", {}).get(key)
            if (
                operation
                and operation.get("status") == "acknowledged"
                and operation["action"].get("build")
            ):
                action = operation["action"]
                environment = {
                    "public-beta": "ios-testflight-public",
                    "app-store": "ios-app-store",
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
        if platform == "ios" and isinstance(self.apple, Apple):
            self.apple.headers["Authorization"] = "Bearer " + apple_token(self.env)
        elif platform == "android" and isinstance(self.play, Play):
            self.play.headers["Authorization"] = "Bearer " + play_token(
                self.env["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"]
            )

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
            result = self.cm(
                "POST",
                "/apps/" + CM_APP_ID + "/builds",
                {
                    "workflow_id": WORKFLOWS[platform],
                    "tag": tag,
                    "inputs": {
                        "DEFAULT_ENV": "PRODUCTION",
                        "RELEASE_CHANNEL": "BETA",
                        "PUBLISH_TO_GITHUB": "NO",
                    },
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
            self.deploy("ios-testflight-public", build, "in_progress", state)
            return {}
        if kind == "app-store":
            from release_train.release_notes import notes_for

            bundle = self.prepared_bundle(action)
            notes = notes_for(bundle, "app_store")
            self.refresh_store_authorization(platform)
            identifier = self.apple.submit_store(
                build,
                snapshot["ios"]["versions"],
                state.get("acknowledged", []),
                reviews=snapshot["ios"].get("review_submissions", []),
                notes=notes,
            )
            consume_version_acknowledgements(state, {identifier})
            self.claim(build, "app-store")
            state.setdefault("app_store_submissions", []).append(snapshot["now"])
            self.deploy("ios-app-store", build, "in_progress", state)
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
        "android": env.get("RELEASE_TRAIN_ANDROID") or "off",
    }
    runtime = Runtime(env)
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
        for platform in ["ios", "android"]:
            data = snapshot.get(platform, {})
            if levels[platform] in {"off", "dry-run"} or data.get("error"):
                continue
            if platform == "ios":
                from release_train.versions import parse_version

                versions = [
                    parse_version(v["version"])
                    for v in data.get("versions", [])
                    if v["state"] not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}
                ]
                reconcile(
                    "ios",
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
                    state["deferred_android"] = record
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
    if not dry:
        runtime.store.save(state)
        audit_snapshot = dict(snapshot)
        for platform in ["ios", "android"]:
            if levels[platform] in {"off", "dry-run"}:
                audit_snapshot[platform] = {}
        runtime.audit_observations(audit_snapshot, state)
        runtime.store.save(state)
        execute_plan(plan, state, snapshot, runtime.store, runtime)
    summary = [
        "Release train " + ("dry run" if dry else "tick"),
        *plan["reasons"],
        *plan["errors"],
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
        levels.get(p) not in {"off", "dry-run"} for p in state.get("holds", {})
    )
    return 1 if plan["errors"] or active_holds else 0
