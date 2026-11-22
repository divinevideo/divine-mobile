"""Source-bound evidence for publishing the original Android downloads."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from release_train.providers import ProviderError
from release_train.release_notes import bundle_from_env

APK_NAMES = ("app-arm64-v8a-release.apk", "app-armeabi-v7a-release.apk")
KIND = "android-distribution"


def receipt_matches(receipt, build):
    return (isinstance(receipt, dict) and receipt.get("schema") == 1
            and receipt.get("zapstore_cli_succeeded") is True
            and all(receipt.get(k) == build.get(k) for k in
                    ("number", "version", "sha", "manifest_sha256")))


def plan_distribution(snapshot, state, levels):
    from release_train.coordinator import ACTIVE
    from release_train.versions import parse_version

    result = {"actions": [], "proposed": [], "reasons": [], "errors": []}
    android = snapshot.get("android", {})
    data = snapshot.get("distribution", {})
    if (levels.get("android") not in {"production", "dry-run"}
            or android.get("error") or not android.get("lifecycle_complete")
            or state.get("holds", {}).get("android")):
        return result
    if data.get("error") or state.get("holds", {}).get(KIND):
        result["errors"].append("Android distribution held: " +
                                str(data.get("error") or state["holds"][KIND]))
        return result
    if not android.get("production"):
        return result
    newest = max(android["production"], key=lambda b: (parse_version(b["version"]), b["number"]))
    matches = [b for b in data.get("downloads", []) if all(
        b.get(k) == newest.get(k) for k in ("number", "version", "sha"))]
    if not newest.get("ci_verified") or len(matches) != 1:
        result["reasons"].append("Android distribution: waiting for verified original APK evidence")
        return result
    build = matches[0]
    if receipt_matches(data.get("receipts", {}).get(str(build["number"])), build):
        return result
    if any(b.get("platform") == KIND and b.get("status") in ACTIVE for b in snapshot.get("cm", [])):
        result["reasons"].append("Android distribution: signing job is active")
        return result
    operation = state.get("operations", {}).get(f"{KIND}:android:{build['number']}", {})
    if operation and not (operation.get("retryable") or operation.get("status") == "acknowledged"):
        return result
    attempt = operation.get("action", {}).get("attempt", 0) + 1
    action = {"kind": KIND, "platform": "android", "build": build, "attempt": attempt}
    result["proposed" if levels["android"] == "dry-run" else "actions"].append(action)
    return result


def reconcile_distribution(key, operation, state, snapshot):
    from release_train.coordinator import ACTIVE

    build = operation["action"]["build"]
    attempt = operation["action"].get("attempt", 1)
    jobs = [b for b in snapshot.get("cm", []) if b.get("platform") == KIND
            and b.get("sha") == build["sha"] and b.get("number") == build["number"]
            and b.get("attempt") == attempt]
    if len(jobs) == 1:
        job = jobs[0]
        operation["build_id"] = job["id"]
        receipt = snapshot.get("distribution", {}).get("receipts", {}).get(str(build["number"]))
        if job["status"] == "finished" and receipt_matches(receipt, build):
            operation["status"] = "done"
            operation.pop("retryable", None)
        elif job["status"] in ACTIVE:
            operation["status"] = "deferred"
            operation.pop("retryable", None)
        elif job["status"] in {"failed", "canceled", "timeout", "skipped"} and attempt < 3:
            operation["status"] = "deferred"
            operation["retryable"] = True
        else:
            state.setdefault("holds", {})[KIND] = key
            return
        if state.get("holds", {}).get(KIND) == key:
            state["holds"].pop(KIND)
    elif operation["status"] in {"started", "ambiguous"} or len(jobs) > 1:
        state.setdefault("holds", {})[KIND] = key


def manifest_digest(record):
    return hashlib.sha256(json.dumps(record, sort_keys=True,
                          separators=(",", ":")).encode()).hexdigest()


def validate_downloads(record, build):
    if (not isinstance(record, dict) or record.get("schema") != 1 or record.get("scheduled") is not True
            or type(record.get("number")) is not int
            or any(not isinstance(record.get(k), str) for k in ("version", "sha", "build_id"))
            or record["number"] <= 0 or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", record.get("version", ""))
            or not re.fullmatch(r"[0-9a-f]{40}", record.get("sha", ""))
            or not re.fullmatch(r"[A-Za-z0-9-]+", record.get("build_id", ""))
            or any(record.get(k) != build.get(k) for k in ("number", "version", "sha"))):
        raise ProviderError("Original Android download identity differs from approved build")
    apks = record.get("apks")
    if (not isinstance(apks, list) or len(apks) != 2
            or any(not isinstance(a, dict) or not isinstance(a.get("sha256"), str) for a in apks)
            or [a.get("name") for a in apks] != list(APK_NAMES)
            or any(not re.fullmatch(r"[0-9a-f]{64}", a.get("sha256", "")) for a in apks)):
        raise ProviderError("Original APK evidence is missing or malformed")
    return bundle_from_env({"RELEASE_NOTES_BUNDLE": json.dumps(record.get("release_notes"))},
                           record["sha"], "android")


def retain_downloads(env, ledger, source, version, number):
    root = Path("build/app/outputs/apk/release")
    files = [root / name for name in APK_NAMES]
    if env.get("RELEASE_TRAIN_SCHEDULED") != "true":
        return
    if any(not p.is_file() or p.is_symlink() or p.stat().st_size == 0 for p in files):
        raise ProviderError("Both original signed ARM APKs are required for distribution")
    record = {
        "schema": 1, "scheduled": True, "number": number, "version": version, "sha": source,
        "build_id": env["CM_BUILD_ID"],
        "apks": [{"name": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                 for p in files],
        "release_notes": bundle_from_env(env, source, "android"),
    }
    path = f"artifacts/android-downloads/{number}.json"
    if path not in ledger.paths() and ledger.create_json(
        path, record, f"Retain original Android downloads {number}"
    ):
        return
    prior = ledger.read_json(path)
    if any(prior.get(k) != record[k] for k in (
        "schema", "scheduled", "number", "version", "sha", "build_id", "apks"
    )):
        raise ProviderError("Retained original APK identity is immutable; refusing different bytes")
    # Production may have advanced since the build; its original notes remain bound.
    bundle_from_env({"RELEASE_NOTES_BUNDLE": json.dumps(prior.get("release_notes"))},
                    source, "android")
