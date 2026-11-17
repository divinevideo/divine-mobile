import base64
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train import ledger
from release_train.versions import Version
from release_train_fakes import MemoryLedgerStore

REPO = "divinevideo/divine-release-provenance"


def done(returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


class FakeRun:
    def __init__(self, *responses):
        self.responses = list(responses)
        self.calls = []

    def __call__(self, args, **kwargs):
        self.calls.append(list(args))
        return self.responses.pop(0)


def b64(text):
    return base64.b64encode(text.encode()).decode()


class PathHelperTests(unittest.TestCase):
    def test_paths(self):
        self.assertEqual(
            ledger.reservation_path("ios", 7), "allocations/builds/ios/7.json"
        )
        self.assertEqual(
            ledger.key_path("ios", "refs/tags/a", 7),
            "allocations/keys/ios/refs--tags--a/7.json",
        )
        self.assertEqual(
            ledger.claim_path(Version(1, 2, 3), "beta"),
            "allocations/claims/1.2.3/beta.json",
        )
        self.assertEqual(
            ledger.provenance_path("ios", "1.2.3", 9), "releases/ios/1.2.3+9.json"
        )
        self.assertEqual(ledger.BOOTSTRAP_PATH, "allocations/bootstrap.json")


class GhLedgerStoreTests(unittest.TestCase):
    def test_private_ledger_token_overrides_stale_cli_token_without_changing_parent(self):
        calls = []

        def run(args, **kwargs):
            calls.append((args, kwargs))
            return done(stdout=json.dumps({"truncated": False, "tree": []}))

        with patch.dict(os.environ, {"GH_TOKEN": "stale-mobile-token", "PROVENANCE_TOKEN": "private-ledger-token"}):
            store = ledger.GhLedgerStore(REPO, run=run)
            self.assertEqual(store.paths(), frozenset())
            self.assertEqual(calls[0][1].get("env", {}).get("GH_TOKEN"), "private-ledger-token")
            self.assertEqual(os.environ["GH_TOKEN"], "stale-mobile-token")
            self.assertNotIn("private-ledger-token", calls[0][0])

    def store(self, *responses):
        run = FakeRun(*responses)
        return ledger.GhLedgerStore(REPO, run=run), run

    def test_paths_lists_the_recursive_tree(self):
        tree = {"truncated": False, "tree": [{"path": "a.json"}, {"path": "b/c.json"}]}
        store, run = self.store(done(stdout=json.dumps(tree)))
        self.assertEqual(store.paths(), frozenset({"a.json", "b/c.json"}))
        self.assertEqual(
            run.calls,
            [["gh", "api", f"repos/{REPO}/git/trees/main?recursive=1"]],
        )
        store.paths()
        self.assertEqual(len(run.calls), 1)

    def test_truncated_tree_fails_closed(self):
        store, _ = self.store(
            done(stdout=json.dumps({"truncated": True, "tree": []}))
        )
        with self.assertRaises(ledger.LedgerError):
            store.paths()

    def test_create_returns_true_on_success(self):
        store, run = self.store(done())
        self.assertTrue(store.create_json("p/x.json", {"b": 1, "a": 2}, "msg"))
        self.assertEqual(
            run.calls,
            [[
                "gh", "api", "--method", "PUT",
                f"repos/{REPO}/contents/p/x.json",
                "--input", "-",
            ]],
        )

    def test_large_release_note_bundle_uses_stdin_not_an_argument(self):
        record = {'changes': [{'sha': 'a' * 40, 'subject': 'change ' * 50}] * 1000}
        calls = []

        def run(args, **kwargs):
            calls.append((args, kwargs))
            self.assertLess(max(map(len, args)), 131072)
            payload = json.loads(kwargs['input'])
            self.assertEqual(json.loads(base64.b64decode(payload['content'])), record)
            self.assertEqual(payload['message'], 'Record notes')
            self.assertEqual(payload['branch'], 'main')
            return done()

        self.assertTrue(ledger.GhLedgerStore(REPO, run=run).create_json(
            'release-notes/ios/notes.json', record, 'Record notes'))
        self.assertEqual(calls[0][0][-2:], ['--input', '-'])

    def test_create_invalidates_paths_cache(self):
        tree = json.dumps({"truncated": False, "tree": []})
        store, run = self.store(done(stdout=tree), done(), done(stdout=tree))
        store.paths()
        store.create_json("p.json", {}, "m")
        store.paths()
        self.assertEqual(len(run.calls), 3)

    def test_lost_create_race_invalidates_paths_cache(self):
        tree = json.dumps({"truncated": False, "tree": []})
        store, run = self.store(
            done(stdout=tree),
            done(1, stderr="gh: Unprocessable Entity (HTTP 422)"),
            done(stdout=json.dumps({"content": b64("{}")})),
            done(stdout=tree),
        )
        store.paths()
        self.assertFalse(store.create_json("p.json", {}, "m"))
        store.paths()
        tree_call = ["gh", "api", f"repos/{REPO}/git/trees/main?recursive=1"]
        self.assertEqual(run.calls.count(tree_call), 2)

    def test_create_returns_false_when_path_exists(self):
        body = json.dumps({"content": b64("{}")})
        store, run = self.store(
            done(1, stderr="gh: Unprocessable Entity (HTTP 422)"),
            done(stdout=body),
        )
        self.assertFalse(store.create_json("p.json", {}, "m"))
        self.assertEqual(
            run.calls[1], ["gh", "api", f"repos/{REPO}/contents/p.json?ref=main"]
        )

    def test_422_without_existing_path_raises(self):
        store, _ = self.store(
            done(1, stderr="gh: Unprocessable Entity (HTTP 422)"),
            done(1, stderr="gh: Not Found (HTTP 404)"),
        )
        with self.assertRaises(ledger.LedgerError):
            store.create_json("p.json", {}, "m")

    def test_create_retries_branch_conflict(self):
        conflict = done(1, stderr="gh: Conflict (HTTP 409)")
        store, run = self.store(conflict, conflict, done())
        self.assertTrue(store.create_json("p.json", {}, "m"))
        self.assertEqual(len(run.calls), 3)
        self.assertEqual(run.calls[0][:4], ["gh", "api", "--method", "PUT"])
        self.assertEqual(run.calls[0], run.calls[1])
        self.assertEqual(run.calls[1], run.calls[2])

    def test_create_gives_up_after_five_conflicts(self):
        conflict = done(1, stderr="gh: Conflict (HTTP 409)")
        store, run = self.store(*[conflict] * 6)
        with self.assertRaises(ledger.LedgerError):
            store.create_json("p.json", {}, "m")
        self.assertEqual(len(run.calls), 6)
        self.assertTrue(all("PUT" in call for call in run.calls))

    def test_create_raises_on_other_errors(self):
        store, _ = self.store(done(1, stderr="gh: Forbidden (HTTP 403)"))
        with self.assertRaisesRegex(ledger.LedgerError, "403"):
            store.create_json("p.json", {}, "m")

    def test_read_json_decodes_base64_content(self):
        body = json.dumps({"content": b64('{"a": 1}') })
        store, run = self.store(done(stdout=body))
        self.assertEqual(store.read_json("p.json"), {"a": 1})
        self.assertEqual(
            run.calls, [["gh", "api", f"repos/{REPO}/contents/p.json?ref=main"]]
        )

    def test_read_json_accepts_github_line_wrapped_base64(self):
        record = {"key": "v" * 200, "n": 7}
        raw = base64.b64encode(json.dumps(record).encode()).decode()
        wrapped = "\n".join(raw[i : i + 60] for i in range(0, len(raw), 60)) + "\n"
        self.assertIn("\n", wrapped[:-1])
        store, _ = self.store(done(stdout=json.dumps({"content": wrapped})))
        self.assertEqual(store.read_json("p.json"), record)

    def test_read_json_unreadable_bodies_raise_ledger_error(self):
        for body in (
            json.dumps([{"name": "a.json"}]),
            json.dumps({"content": ""}),
            json.dumps({"content": None}),
            json.dumps({"content": "!!!notbase64"}),
            "not json at all",
        ):
            store, _ = self.store(done(stdout=body))
            with self.assertRaisesRegex(ledger.LedgerError, "p.json"):
                store.read_json("p.json")

    def test_paths_garbled_body_raises_ledger_error(self):
        for body in ("garbled", json.dumps([]), json.dumps({"truncated": False})):
            store, _ = self.store(done(stdout=body))
            with self.assertRaises(ledger.LedgerError):
                store.paths()

    def test_read_json_missing_raises(self):
        store, _ = self.store(done(1, stderr="gh: Not Found (HTTP 404)"))
        with self.assertRaises(ledger.LedgerError):
            store.read_json("p.json")


class MemoryLedgerStoreTests(unittest.TestCase):
    def test_create_once_and_record_order(self):
        store = MemoryLedgerStore({"a.json": {"x": 1}})
        self.assertFalse(store.create_json("a.json", {}, "m"))
        self.assertTrue(store.create_json("b.json", {"y": 2}, "m"))
        self.assertEqual(store.creates, ["b.json"])
        self.assertEqual(store.paths(), frozenset({"a.json", "b.json"}))
        self.assertEqual(store.read_json("b.json"), {"y": 2})
        with self.assertRaises(ledger.LedgerError):
            store.read_json("zzz.json")


if __name__ == "__main__":
    unittest.main()
