import copy
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train.ledger import LedgerError


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


def release_notes_bundle(platform='ios', source='a' * 40):
    languages = ('en-US', 'es-419', 'pt-BR', 'fr-FR', 'de-DE', 'it-IT', 'nl-NL', 'pl-PL', 'sv-SE', 'ro', 'bg', 'tr-TR', 'ar', 'ur', 'ja-JP', 'ko-KR', 'zh-CN', 'vi', 'id', 'ms', 'fil', 'am', 'te-IN')
    return {
        'schema': 1, 'platform': platform, 'source_sha': source,
        'baseline': {'version': '1.0.30', 'sha': 'b' * 40},
        'locales': ['en-US'] if platform == 'ios' else [],
        'testflight': [{'language': 'en-US', 'text': 'Try recording a loop.'}] if platform == 'ios' else [],
        'app_store': [{'language': 'en-US', 'text': 'Videos load more smoothly.'}] if platform == 'ios' else [],
        'google_play': [{'language': language, 'text': 'Videos load more smoothly.'} for language in languages] if platform == 'android' else [],
        'changes': [], 'policy_sha256': 'c' * 64,
    }
