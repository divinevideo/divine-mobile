from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import time
from typing import Protocol

BOOTSTRAP_PATH = "allocations/bootstrap.json"
_MAX_CONFLICT_RETRIES = 5
ALLOWED_MACOS_DEFAULT_ENVS = frozenset({"PRODUCTION", "STAGING", "POC"})
_SHA40_RE = re.compile(r"[0-9a-f]{40}")
_SHA64_RE = re.compile(r"[0-9a-f]{64}")


def validate_macos_provenance(
    record: dict,
    *,
    expected_version: str | None,
    expected_number: int,
    expected_source: str | None = None,
    require_production: bool = False,
) -> str:
    """Validate a macOS provenance record and return its verified DEFAULT_ENV."""
    if not isinstance(record, dict):
        raise ValueError("macOS provenance record must be a JSON object")
    if not expected_version:
        raise ValueError("macOS provenance expected_version missing")
    if record.get("platform") != "macos":
        raise ValueError("macOS provenance platform mismatch")
    if record.get("release_version") != f"{expected_version}+{expected_number}":
        raise ValueError("macOS provenance release_version mismatch")
    source = record.get("build_source_commit")
    if not _SHA40_RE.fullmatch(source or ""):
        raise ValueError("macOS provenance has invalid build_source_commit")
    if expected_source is not None and source != expected_source:
        raise ValueError("macOS provenance build_source_commit mismatch")
    if record.get("patchable") is not False:
        raise ValueError("macOS provenance requires patchable=false")
    if not _SHA64_RE.fullmatch(record.get("pkg_sha256") or ""):
        raise ValueError("macOS provenance requires a 64-hex pkg_sha256")
    default_env = record.get("default_env")
    if default_env not in ALLOWED_MACOS_DEFAULT_ENVS:
        raise ValueError(f"macOS provenance has invalid default_env: {default_env!r}")
    if require_production and default_env != "PRODUCTION":
        raise ValueError(f"macOS provenance default_env must be PRODUCTION, got {default_env!r}")
    return default_env


class LedgerError(RuntimeError):
    pass


class LedgerStore(Protocol):
    def paths(self) -> frozenset[str]: ...

    def read_json(self, path: str) -> dict: ...

    def create_json(self, path: str, record: dict, message: str) -> bool: ...


def reservation_path(platform, n) -> str:
    return f"allocations/builds/{platform}/{n}.json"


def key_path(platform, key, n) -> str:
    return f"allocations/keys/{platform}/{key.replace('/', '--')}/{n}.json"


def claim_path(version, channel) -> str:
    return f"allocations/claims/{version}/{channel}.json"


def provenance_path(platform, version, n) -> str:
    return f"releases/{platform}/{version}+{n}.json"


class GhLedgerStore:
    def __init__(self, repository, branch="main", run=subprocess.run, sleep=time.sleep, token=None):
        self._repository = repository
        self._branch = branch
        self._run = run
        self._paths = None
        self._sleep = sleep
        self._token = token or os.environ.get("PROVENANCE_TOKEN")

    def refresh(self):
        self._paths = None
        return self.paths()

    def _gh(self, *args, input=None):
        kwargs = {}
        if input is not None:
            kwargs['input'] = input
        if self._token:
            kwargs["env"] = dict(os.environ, GH_TOKEN=self._token)
        return self._run(
            ["gh", "api", *args], capture_output=True, text=True, check=False, **kwargs
        )

    def paths(self) -> frozenset[str]:
        if self._paths is None:
            result = self._gh(
                f"repos/{self._repository}/git/trees/{self._branch}?recursive=1"
            )
            if result.returncode != 0:
                raise LedgerError(f"gh tree listing failed: {result.stderr.strip()}")
            try:
                tree = json.loads(result.stdout)
                truncated = tree.get("truncated")
                found = frozenset(entry["path"] for entry in tree["tree"])
            except (ValueError, KeyError, TypeError, AttributeError) as error:
                raise LedgerError(
                    f"unreadable tree listing from gh: {error!r}"
                ) from error
            if truncated:
                raise LedgerError("ledger tree listing was truncated")
            self._paths = found
        return self._paths

    def read_json(self, path: str) -> dict:
        result = self._gh(
            f"repos/{self._repository}/contents/{path}?ref={self._branch}"
        )
        if result.returncode != 0:
            raise LedgerError(f"cannot read {path}: {result.stderr.strip()}")
        try:
            content = json.loads(result.stdout)["content"]
            raw = base64.b64decode("".join(content.split()), validate=True)
            record = json.loads(raw.decode("utf-8"))
        except (ValueError, KeyError, TypeError, AttributeError) as error:
            raise LedgerError(f"unreadable content for {path}: {error!r}") from error
        if not isinstance(record, dict):
            raise LedgerError(f"content of {path} is not a JSON object")
        return record

    def create_json(self, path: str, record: dict, message: str) -> bool:
        body = json.dumps(record, sort_keys=True, indent=2) + "\n"
        encoded = base64.b64encode(body.encode("utf-8")).decode("ascii")
        payload = json.dumps({'message': message, 'content': encoded, 'branch': self._branch})
        for attempt in range(_MAX_CONFLICT_RETRIES + 1):
            result = self._gh(
                "--method", "PUT",
                f"repos/{self._repository}/contents/{path}",
                "--input", "-", input=payload,
            )
            if result.returncode == 0:
                self._paths = None
                return True
            stderr = result.stderr.strip()
            if "(HTTP 409)" in stderr and attempt < _MAX_CONFLICT_RETRIES:
                self._paths = None
                self._sleep(min(0.05 * 2 ** attempt, 0.5))
                continue
            if "(HTTP 422)" in stderr:
                try:
                    self.read_json(path)
                except LedgerError as error:
                    raise LedgerError(
                        f"create of {path} failed with 422 but path is unreadable: "
                        f"{stderr}; {error}"
                    ) from error
                self._paths = None
                return False
            raise LedgerError(f"create of {path} failed: {stderr}")
        raise LedgerError(f"create of {path} failed")  # pragma: no cover
