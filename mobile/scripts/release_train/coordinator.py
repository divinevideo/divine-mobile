"""Deterministic release policy. Provider reads and writes live in runner.py.

Timestamps are UTC epoch seconds. Absence of evidence never grants eligibility.
"""

from __future__ import annotations

import copy

from release_train.versions import parse_version

HOUR = 3600
DAY = 24 * HOUR
TESTFLIGHT_INTERVAL = 12 * HOUR
TESTFLIGHT_DAILY_LIMIT = 2
PRODUCTION_INTERVAL = 2 * DAY
PLAY_PUBLICATION_VERSION = 1
ACTIVE = {
    "initializing",
    "queued",
    "waiting",
    "preparing",
    "fetching",
    "testing",
    "building",
    "publishing",
    "finishing",
}
BETA_WAITING = {"WAITING_FOR_BETA_REVIEW", "IN_BETA_REVIEW"}
BETA_REJECTED = {"BETA_REJECTED", "REJECTED"}
BETA_STATES = (
    BETA_WAITING
    | BETA_REJECTED
    | {
        "PROCESSING",
        "READY_FOR_BETA_TESTING",
        "READY_FOR_BETA_SUBMISSION",
        "IN_BETA_TESTING",
        "EXPIRED",
        "MISSING_EXPORT_COMPLIANCE",
        "INVALID_BINARY",
        "NOT_APPLICABLE",
        "BETA_APPROVED",
        "IN_EXPORT_COMPLIANCE_REVIEW",
        "PROCESSING_EXCEPTION",
    }
)
STORE_WAITING = {
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "ACCEPTED",
    "PENDING_DEVELOPER_RELEASE",
    "PENDING_APPLE_RELEASE",
    "PROCESSING_FOR_DISTRIBUTION",
    "WAITING_FOR_EXPORT_COMPLIANCE",
}
STORE_REJECTED = {
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
    "DEVELOPER_REJECTED",
}
STORE_STATES = (
    STORE_WAITING
    | STORE_REJECTED
    | {
        "PREPARE_FOR_SUBMISSION",
        "READY_FOR_REVIEW",
        "READY_FOR_SALE",
        "READY_FOR_DISTRIBUTION",
        "REMOVED_FROM_SALE",
        "DEVELOPER_REMOVED_FROM_SALE",
        "REPLACED_WITH_NEW_VERSION",
    }
)
LEVELS = {
    "ios": ["off", "dry-run", "build", "testflight", "app-store"],
    "android": ["off", "dry-run", "build", "production"],
}


def version_ack_key(version):
    return "ios-version:" + version["id"] + ":" + version["version"]


def unresolved_review_is_acknowledged(review, versions, acknowledged):
    items = review.get("items", [])
    if len(items) != 1:
        return False
    item = items[0]
    if item.get("state") not in {"REJECTED", "READY_FOR_REVIEW"}:
        return False
    matching = [v for v in versions if v["id"] == item.get("version_id")]
    return len(matching) == 1 and (
        version_ack_key(matching[0]) in acknowledged
        or (
            item.get("state") == "READY_FOR_REVIEW"
            and matching[0]["state"] in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}
        )
    )


def current_acknowledgements(snapshot, state):
    acknowledged = set(state.get("acknowledged", []))
    latest = {}
    for event in state.get("acknowledgement_events", []):
        latest[event["item"]] = max(latest.get(event["item"], 0), event["observed_at"])
    versions = {v["id"]: v for v in snapshot.get("ios", {}).get("versions", [])}
    for review in snapshot.get("ios", {}).get("review_submissions", []):
        submitted = review["attributes"].get("submittedDate") or 0
        for item in review.get("items", []):
            version = versions.get(item.get("version_id"))
            if version is not None:
                key = version_ack_key(version)
                if submitted >= latest.get(key, 0):
                    acknowledged.discard(key)
    return acknowledged


def consume_version_acknowledgements(state, version_ids):
    prefixes = tuple("ios-version:" + identifier + ":" for identifier in version_ids)
    if prefixes:
        state["acknowledged"] = [
            key for key in state.get("acknowledged", []) if not key.startswith(prefixes)
        ]


def affects_app(path):
    if (
        path.endswith(".md")
        or "/test/" in path
        or "/tests/" in path
        or "/integration_test/" in path
    ):
        return False
    return path == "codemagic.yaml" or (
        path.startswith("mobile/") and not path.startswith("mobile/docs/")
    )


def observe(snapshot, previous):
    """Reconcile first observations, preserving completed continuous exposure only."""
    state = copy.deepcopy(previous)
    consume_version_acknowledgements(
        state,
        {
            v["id"]
            for v in snapshot.get("ios", {}).get("versions", [])
            if v["state"]
            in STORE_WAITING | {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}
        },
    )
    ios = snapshot.get("ios", {})
    published = [
        v["version"]
        for v in ios.get("versions", [])
        if v["state"] in {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}
    ]
    if published and not ios.get("error"):
        highest = max(published, key=parse_version)
        if parse_version(highest) > parse_version(
            state.get("highest_app_store_version", "0.0.0")
        ):
            state["highest_app_store_version"] = highest
            state["last_app_store_publication"] = max(
                snapshot["now"], state.get("last_app_store_publication", 0)
            )
    android = snapshot.get("android", {})
    if not android.get("lifecycle_complete"):
        return state
    now = android.get("observed_at", snapshot["now"])

    publication = state.get("play_publication", {})
    if publication.get("version") != PLAY_PUBLICATION_VERSION:
        publication = {
            "version": PLAY_PUBLICATION_VERSION,
            "internal_periods": {},
            "highest_production_build": 0,
        }
        state["play_publication"] = publication

    internal = android.get("internal", [])
    offered = {str(b["number"]) for b in internal}
    periods = publication["internal_periods"]
    for number, period in periods.items():
        if number not in offered and not period.get("completed"):
            period["interrupted"] = True
    for b in internal:
        number = str(b["number"])
        if number not in periods or periods[number].get("interrupted"):
            periods[number] = {"since": now, "completed": False}
        period = periods[number]
        if now - period["since"] >= 6 * HOUR:
            period["completed"] = True
    highest = max((b["number"] for b in android.get("production", [])), default=0)
    if highest > publication["highest_production_build"]:
        publication["highest_production_build"] = highest
        state["last_play_promotion"] = max(now, state.get("last_play_promotion", 0))
    return state


def last_operation_started(state, kind):
    """Accepted writes may precede provider visibility or a saved success clock."""
    return max(
        (
            o.get("started_at", 0)
            for o in state.get("operations", {}).values()
            if o["action"]["kind"] == kind
        ),
        default=0,
    )


def plan_tick(snapshot, state, levels):
    actions = []
    reasons = []
    errors = []
    proposed = []
    dry_platforms = {p for p, level in levels.items() if level == "dry-run"}
    now = snapshot["now"]
    ack = current_acknowledgements(snapshot, state)
    publication = state.get("play_publication", {})
    periods = (
        publication.get("internal_periods", {})
        if publication.get("version") == PLAY_PUBLICATION_VERSION
        else {}
    )

    def action(kind, platform, **values):
        (proposed if platform in dry_platforms else actions).append(
            dict(kind=kind, platform=platform, **values)
        )

    for platform in ["ios", "android"]:
        level = levels.get(platform, "off")
        if level not in LEVELS[platform]:
            errors.append(f"{platform}: unknown release level")
            continue
        if level == "dry-run":
            level = LEVELS[platform][-1]
        if level == "off":
            reasons.append(f"{platform}: {level}")
            continue
        data = snapshot.get(platform, {})
        if data.get("error"):
            errors.append(f"{platform}: " + data["error"])
            continue
        if state.get("holds", {}).get(platform):
            hold = state["holds"][platform]
            errors.append(
                f"{platform}: acknowledge {hold} after resolving the provider failure"
            )
            continue
        # Unknown provider states hold this platform, including its builds.
        if platform == "ios" and (
            any(b.get("external") not in BETA_STATES for b in data.get("builds", []))
            or any(v.get("state") not in STORE_STATES for v in data.get("versions", []))
        ):
            errors.append("ios: unknown Apple state; inspect App Store Connect")
            continue
        active = any(
            b.get("platform") == platform and b.get("status") in ACTIVE
            for b in snapshot.get("cm", [])
        )
        candidate = snapshot.get("candidate")
        attempt = state.get("attempts", {}).get(platform, {}).get(candidate, {})
        interval = TESTFLIGHT_INTERVAL if platform == "ios" else 4 * HOUR
        can_replace = not (platform == "android" and data.get("internal_pending"))
        if not can_replace:
            reasons.append(
                "android: preserve the pending Google Play internal release (draft or review)"
            )
        if platform == "android":
            for b in data.get("internal", []):
                period = periods.get(str(b["number"]), {})
                if not period.get("completed"):
                    can_replace = False
        if platform == "android" and state.get("deferred_android"):
            if can_replace and not active:
                action("retry-android-upload", platform, **state["deferred_android"])
            continue
        if (
            candidate
            and snapshot.get("ci_passed")
            and snapshot.get("changes", {}).get(platform)
            and not active
            and not any(
                b.get("sha") == candidate
                for b in data.get("builds" if platform == "ios" else "internal", [])
            )
            and can_replace
            and now - state.get("last_build_started", {}).get(platform, 0) >= interval
            and attempt.get("status") != "starting"
            and attempt.get("count", 0) < 2
            and attempt.get("status") not in {"finished", "active"}
        ):
            action(
                "build", platform, sha=candidate, attempt=attempt.get("count", 0) + 1
            )
        if not any(
            a["kind"] == "build" and a["platform"] == platform
            for a in actions + proposed
        ):
            reasons.append(
                f"{platform}: no new build (CI/change/retry/active-build/cadence/exposure checks)"
            )
        if platform == "ios" and level in {"testflight", "app-store"}:
            for b in data.get("builds", []):
                known_operation = any(
                    o["action"]["kind"] == "public-beta"
                    and o["action"].get("build", {}).get("id") == b["id"]
                    for o in state.get("operations", {}).values()
                )
                if (
                    b.get("ci_verified")
                    and not b.get("public_complete", b.get("public"))
                    and (b.get("groups") or known_operation)
                    and b.get("external")
                    in BETA_WAITING
                    | {"BETA_APPROVED", "READY_FOR_BETA_TESTING", "IN_BETA_TESTING"}
                ):
                    action("attach-beta-groups", "ios", build=b)
            builds = data.get("builds", [])
            dates = data.get("submissions", [])
            for b in builds:
                if (
                    b.get("external") in BETA_REJECTED
                    and "ios-build:" + b["id"] not in ack
                ):
                    reasons.append(
                        "ios public: rejection hold; resolve the issue then acknowledge ios-build:"
                        + b["id"]
                    )
            rejected = any(
                b.get("external") in BETA_REJECTED and "ios-build:" + b["id"] not in ack
                for b in builds
            )
            waiting = any(b.get("external") in BETA_WAITING for b in builds)
            budget = (
                len([d for d in dates if now - d < DAY]) < TESTFLIGHT_DAILY_LIMIT
                and now
                - max(max(dates, default=0), last_operation_started(state, "public-beta"))
                >= TESTFLIGHT_INTERVAL
            )
            if not budget:
                reasons.append(
                    "ios public: wait twelve hours; at most two releases per rolling day"
                )
            newest_public = max(
                (b["number"] for b in builds if b.get("public")), default=0
            )
            candidates = [
                b
                for b in builds
                if b.get("valid")
                and b.get("ci_verified")
                and not b.get("public")
                and b["number"] > newest_public
                and b.get("external")
                in {
                    "BETA_APPROVED",
                    "READY_FOR_BETA_SUBMISSION",
                    "READY_FOR_BETA_TESTING",
                    "IN_BETA_TESTING",
                }
            ]
            if not data.get("group_valid"):
                errors.append(
                    "ios: configured public group must remain external with its public link"
                )
            elif candidates and not waiting and not rejected and budget:
                action(
                    "public-beta",
                    platform,
                    build=max(candidates, key=lambda b: b["number"]),
                )
            if level == "app-store":
                versions = data.get("versions", [])
                blocked = any(
                    v["state"] in STORE_WAITING
                    or (v["state"] in STORE_REJECTED and version_ack_key(v) not in ack)
                    for v in versions
                )
                for version in versions:
                    if (
                        version["state"] in STORE_REJECTED
                        and version_ack_key(version) not in ack
                    ):
                        reasons.append(
                            "ios app-store: rejection hold for "
                            + version["version"]
                            + "; resolve the issue then acknowledge ios-version:"
                            + version["id"]
                        )
                reviews = data.get("review_submissions", [])
                blocked = blocked or any(
                    r["attributes"]["state"]
                    in {
                        "WAITING_FOR_REVIEW",
                        "IN_REVIEW",
                        "CANCELING",
                        "COMPLETING",
                    }
                    for r in reviews
                )
                blocked = blocked or any(
                    r["attributes"]["state"] == "UNRESOLVED_ISSUES"
                    and not unresolved_review_is_acknowledged(r, versions, ack)
                    for r in reviews
                )
                if rejected:
                    reasons.append(
                        "ios app-store: held by the unacknowledged beta rejection above"
                    )
                blocked = blocked or rejected
                resumable = {
                    o["action"]["build"]["number"]
                    for o in state.get("operations", {}).values()
                    if o.get("status") == "acknowledged"
                    and o["action"]["kind"] == "app-store"
                }
                submitted = [
                    r["attributes"]["submittedDate"]
                    for r in reviews
                    if r["attributes"].get("submittedDate")
                ]
                submitted += [
                    v["submitted_at"] for v in versions if v.get("submitted_at")
                ]
                submitted += state.get("app_store_submissions", [])
                submitted += [
                    state.get("last_app_store_publication", 0),
                    last_operation_started(state, "app-store"),
                ]
                highest = max(
                    (
                        parse_version(v["version"])
                        for v in versions
                        if v["state"]
                        not in {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}
                    ),
                    default=parse_version("0.0.0"),
                )
                eligible = [
                    b
                    for b in builds
                    if not (b.get("version") == "1.0.30" and str(b.get("number")) == "916")
                    and b.get("valid")
                    and b.get("ci_verified")
                    and b.get("external") not in BETA_REJECTED
                    and (
                        parse_version(b["version"]) > highest
                        or b["number"] in resumable
                    )
                ]
                if resumable:
                    eligible = [b for b in eligible if b["number"] in resumable]
                store_budget = now - max(submitted, default=0) >= PRODUCTION_INTERVAL
                if not store_budget:
                    reasons.append(
                        "ios app-store: wait 48 hours after the last submission or observed publication"
                    )
                if not blocked and eligible and store_budget:
                    action(
                        "app-store",
                        platform,
                        build=max(eligible, key=lambda b: b["number"]),
                    )
        if platform == "android" and level == "production":
            if data.get("production_pending"):
                reasons.append("android: preserve pending Google Play production review/publication")
                continue
            if data.get("managed_publishing") is not False:
                errors.append(
                    "android: managed publishing is enabled or unknown; publish approved changes in Play Console or verify the setting"
                )
                continue
            highest = max(
                (parse_version(b["version"]) for b in data.get("production", [])),
                default=parse_version("0.0.0"),
            )
            eligible = [
                b
                for b in data.get("internal", [])
                if b.get("ci_verified")
                and periods.get(str(b["number"]), {}).get("completed")
                and parse_version(b["version"]) > highest
            ]
            play_budget = (
                now
                - max(
                    state.get("last_play_promotion", 0),
                    last_operation_started(state, "play-production"),
                )
                >= PRODUCTION_INTERVAL
            )
            if not play_budget:
                reasons.append(
                    "android production: wait 48 hours after the last promotion or observed publication"
                )
            if eligible and play_budget:
                action(
                    "play-production",
                    platform,
                    build=max(eligible, key=lambda b: b["number"]),
                )
    from release_train.android_distribution import plan_distribution
    distribution = plan_distribution(snapshot, state, levels)
    actions.extend(distribution["actions"])
    proposed.extend(distribution["proposed"])
    reasons.extend(distribution["reasons"])
    errors.extend(distribution["errors"])
    return {
        "actions": actions,
        "proposed": proposed,
        "reasons": reasons,
        "errors": errors,
    }
