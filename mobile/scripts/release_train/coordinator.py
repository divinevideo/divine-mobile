"""Deterministic release policy. Provider reads and writes live in runner.py.

Timestamps are UTC epoch seconds. Absence of evidence never grants eligibility.
"""

from __future__ import annotations

import copy

from release_train.versions import parse_version

HOUR = 3600
DAY = 24 * HOUR
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
    now = snapshot["now"]
    for b in snapshot.get("ios", {}).get("builds", []):
        if (
            b.get("public")
            and b.get("valid")
            and b.get("external") in {"READY_FOR_BETA_TESTING", "IN_BETA_TESTING"}
        ):
            state.setdefault("public_available", {}).setdefault(b["id"], now)
    internal = snapshot.get("android", {}).get("internal", [])
    offered = {str(b["number"]) for b in internal}
    periods = state.setdefault("internal_periods", {})
    for number, period in periods.items():
        if number not in offered and not period.get("completed"):
            period["interrupted"] = True
    for b in internal:
        number = str(b["number"])
        if number not in periods or periods[number].get("interrupted"):
            periods[number] = {"since": now, "completed": False, "build": b}
        period = periods[number]
        if now - period["since"] >= 6 * HOUR:
            period["completed"] = True
    production = snapshot.get("android", {}).get("production", [])
    seen = state.setdefault("play_production_seen", {})
    for b in production:
        if str(b["number"]) not in seen:
            seen[str(b["number"])] = now
            state["last_play_promotion"] = now
    return state


def plan_tick(snapshot, state, levels):
    actions = []
    reasons = []
    errors = []
    proposed = []
    dry_platforms = {p for p, level in levels.items() if level == "dry-run"}
    now = snapshot["now"]
    ack = set(state.get("acknowledged", []))

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
            if hold not in ack:
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
        interval = HOUR if platform == "ios" else 4 * HOUR
        can_replace = True
        if platform == "android":
            for b in data.get("internal", []):
                period = state.get("internal_periods", {}).get(str(b["number"]), {})
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
            rejected = any(
                b.get("external") in BETA_REJECTED and "ios-build:" + b["id"] not in ack
                for b in builds
            )
            waiting = any(b.get("external") in BETA_WAITING for b in builds)
            budget = (
                len([d for d in dates if now - d < DAY]) < 6
                and now - max(dates, default=0) >= 4 * HOUR
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
                    or (
                        v["state"] in STORE_REJECTED
                        and "ios-version:" + v["id"] not in ack
                    )
                    for v in versions
                )
                reviews = data.get("review_submissions", [])
                blocked = blocked or any(
                    r["attributes"]["state"]
                    in {
                        "WAITING_FOR_REVIEW",
                        "IN_REVIEW",
                        "UNRESOLVED_ISSUES",
                        "CANCELING",
                        "COMPLETING",
                    }
                    for r in reviews
                )
                submitted = [
                    r["attributes"]["submittedDate"]
                    for r in reviews
                    if r["attributes"].get("submittedDate")
                ]
                submitted += [
                    v["submitted_at"] for v in versions if v.get("submitted_at")
                ]
                submitted += state.get("app_store_submissions", [])
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
                    if b.get("public")
                    and b.get("valid")
                    and b.get("ci_verified")
                    and b.get("public_complete", b.get("public"))
                    and b.get("external")
                    in {"READY_FOR_BETA_TESTING", "IN_BETA_TESTING"}
                    and b["id"] in state.get("public_available", {})
                    and now - state["public_available"][b["id"]] >= 6 * HOUR
                    and parse_version(b["version"]) > highest
                ]
                if not blocked and eligible and now - max(submitted, default=0) >= DAY:
                    action(
                        "app-store",
                        platform,
                        build=max(eligible, key=lambda b: b["number"]),
                    )
        if platform == "android" and level == "production":
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
                and state.get("internal_periods", {})
                .get(str(b["number"]), {})
                .get("completed")
                and parse_version(b["version"]) > highest
            ]
            if eligible and now - state.get("last_play_promotion", 0) >= DAY:
                action(
                    "play-production",
                    platform,
                    build=max(eligible, key=lambda b: b["number"]),
                )
    return {
        "actions": actions,
        "proposed": proposed,
        "reasons": reasons,
        "errors": errors,
    }
