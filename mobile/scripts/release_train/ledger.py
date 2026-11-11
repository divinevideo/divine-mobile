from __future__ import annotations

import base64
import json
import subprocess
from typing import Protocol

BOOTSTRAP_PATH = "allocations/bootstrap.json"
_MAX_CONFLICT_RETRIES = 5


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
    def __init__(self, repository, branch="main", run=subprocess.run):
        self._repository = repository
        self._branch = branch
        self._run = run
        self._paths = None

    def _gh(self, *args):
        return self._run(
            ["gh", "api", *args], capture_output=True, text=True, check=False
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
        for attempt in range(_MAX_CONFLICT_RETRIES + 1):
            result = self._gh(
                "--method", "PUT",
                f"repos/{self._repository}/contents/{path}",
                "-f", f"message={message}",
                "-f", f"content={encoded}",
                "-f", f"branch={self._branch}",
            )
            if result.returncode == 0:
                self._paths = None
                return True
            stderr = result.stderr.strip()
            if "(HTTP 409)" in stderr and attempt < _MAX_CONFLICT_RETRIES:
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
