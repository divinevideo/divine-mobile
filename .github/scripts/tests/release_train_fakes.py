import copy
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train.ledger import LedgerError  # noqa: E402


class MemoryLedgerStore:
    """In-memory LedgerStore that records creates in order."""

    def __init__(self, files=None):
        self.files = copy.deepcopy(files or {})
        self.creates = []

    def paths(self):
        return frozenset(self.files)

    def read_json(self, path):
        if path not in self.files:
            raise LedgerError(f"missing ledger path: {path}")
        return copy.deepcopy(self.files[path])

    def create_json(self, path, record, message):
        if path in self.files:
            return False
        self.files[path] = copy.deepcopy(record)
        self.creates.append(path)
        return True
