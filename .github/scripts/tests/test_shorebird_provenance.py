import hashlib
import hmac
import json
import os
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "mobile" / "scripts" / "shorebird_provenance.rb"
POLICY_NAME = "DIVINE_PUBLIC_PEOPLE_LIST_EXCLUDED_D_TAGS"

# Throwaway P-256 public keys, generated for this test. Public halves only,
# and they sign nothing — they exist so the digest comparison has two
# genuinely different PEMs to tell apart.
RELEASE_PUBLIC_KEY = (
    "-----BEGIN PUBLIC KEY-----\\n"
    "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEU95v7B64q1r8ca3MXNw/0ytj1mA/\\n"
    "O5i37b9eVSOyf71BApflNYsMsj2wZDn8z32QJog17hEyHuQe9W3D0fGZvw==\\n"
    "-----END PUBLIC KEY-----"
)
ROTATED_PUBLIC_KEY = (
    "-----BEGIN PUBLIC KEY-----\\n"
    "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEaj+mmjSlZGv1yBNP/MjRw9wkTRHV\\n"
    "4uP7OqE7SPaokof38YYvsZFC1wGShILX89OM5d/O9DFwDCgbpV7x1BNZag==\\n"
    "-----END PUBLIC KEY-----"
)


class ShorebirdProvenanceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.defines = self.root / "defines.json"
        self.record = self.root / "record.json"
        self.env_output = self.root / "patch.env"
        self.defines.write_text(
            json.dumps({"DEFAULT_ENV": "PRODUCTION", "SECRET_TOKEN": "release-secret"})
        )
        self.head = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=REPO_ROOT,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()
        self.environment = {
            **os.environ,
            "SHOREBIRD_PROVENANCE_HMAC_KEY": "test-only-hmac-key-with-32-bytes-minimum",
            "SHOREBIRD_PROVENANCE_HMAC_KEY_ID": "test-key-v1",
            "SHOREBIRD_PATCH_PUBLIC_KEY": RELEASE_PUBLIC_KEY,
        }

    def emit(
        self,
        output: Path | None = None,
        environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "ruby",
                str(SCRIPT),
                "emit",
                "--platform",
                "ios",
                "--release-version",
                "1.2.3+456",
                "--source-commit",
                self.head,
                "--patch-baseline-commit",
                self.head,
                "--flutter-version",
                "3.44.9",
                "--shorebird-cli-version",
                "Shorebird 1.6.117",
                "--shorebird-cli-revision",
                "45facdd4e4b3c39e0d260107977584f0b7c66bec",
                "--defines",
                str(self.defines),
                "--output",
                str(output or self.record),
            ],
            cwd=REPO_ROOT,
            env=environment or self.environment,
            check=False,
            text=True,
            capture_output=True,
        )

    def verify(
        self,
        environment: dict[str, str] | None = None,
        **overrides: str,
    ) -> subprocess.CompletedProcess[str]:
        arguments = [
            "ruby",
            str(SCRIPT),
            "verify",
            "--platform",
            overrides.get("platform", "ios"),
            "--release-version",
            overrides.get("release_version", "1.2.3+456"),
            "--flutter-version",
            overrides.get("flutter_version", "3.44.9"),
            "--shorebird-cli-version",
            overrides.get("shorebird_cli_version", "Shorebird 1.6.117"),
            "--shorebird-cli-revision",
            overrides.get(
                "shorebird_cli_revision",
                "45facdd4e4b3c39e0d260107977584f0b7c66bec",
            ),
            "--defines",
            str(self.defines),
            "--record",
            str(self.record),
            "--env-output",
            str(self.env_output),
        ]
        if "release_commit" in overrides:
            arguments.extend(["--release-commit", overrides["release_commit"]])
        return subprocess.run(
            arguments,
            cwd=REPO_ROOT,
            env=environment or self.environment,
            check=False,
            text=True,
            capture_output=True,
        )

    def prepare_patch_policy(self, policy: str = "[]") -> subprocess.CompletedProcess[str]:
        # Execute the actual Codemagic gate with the real Ruby authenticator and
        # policy writer. Only the already-fetched record and temporary output
        # paths replace remote/build inputs; no network operation is needed.
        contents = (REPO_ROOT / "codemagic.yaml").read_text()
        step = contents.split("    - &fetch_and_verify_shorebird_provenance\n", 1)[1]
        gate = step.split("        PUBLIC_PEOPLE_LIST_POLICY_REQUIRED=", 1)[1]
        gate = "PUBLIC_PEOPLE_LIST_POLICY_REQUIRED=" + gate.split(
            "        ruby scripts/shorebird_provenance.rb verify", 1
        )[0]
        gate = gate.replace("${{ inputs.RELEASE_VERSION }}", "1.2.3+456")
        gate = gate.replace("build/shorebird/dart_defines.json", shlex.quote(str(self.defines)))
        return subprocess.run(
            ["bash", "-c", "set -euo pipefail\n" + gate],
            cwd=REPO_ROOT / "mobile",
            env={
                **self.environment,
                "PROVENANCE_PATH": str(self.record),
                "SHOREBIRD_PLATFORM": "ios",
                "CM_REPO_SLUG": "divinevideo/divine-mobile",
                POLICY_NAME: policy,
            },
            check=False,
            text=True,
            capture_output=True,
        )

    def test_legacy_release_keeps_policy_absent_from_actual_patch_defines(self) -> None:
        baseline = self.defines.read_bytes()
        self.assertEqual(0, self.emit().returncode)
        old_insertion = subprocess.run(
            ["python3", str(REPO_ROOT / "mobile/scripts/write_public_people_list_defines.py"),
             "--output", str(self.defines), "--merge"],
            env={**self.environment, POLICY_NAME: "[]"},
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, old_insertion.returncode, old_insertion.stderr)
        self.assertEqual("[]", json.loads(self.defines.read_text())[POLICY_NAME])

        # The original unconditional insertion really fails strict verification,
        # even for an empty policy; the fix must change compilation, not forgive it.
        drift = self.verify()
        self.assertNotEqual(0, drift.returncode)
        self.assertIn(POLICY_NAME, drift.stderr)
        self.defines.write_bytes(baseline)

        result = self.prepare_patch_policy('["new-policy"]')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(baseline, self.defines.read_bytes())
        self.assertNotIn(POLICY_NAME, json.loads(self.defines.read_text()))
        verified = self.verify()
        self.assertEqual(0, verified.returncode, verified.stderr)

    def test_current_release_inserts_and_verifies_the_recorded_policy(self) -> None:
        defines = json.loads(self.defines.read_text())
        defines[POLICY_NAME] = '["first","second"]'
        self.defines.write_text(json.dumps(defines))
        self.assertEqual(0, self.emit().returncode)
        defines.pop(POLICY_NAME)
        self.defines.write_text(json.dumps(defines))

        result = self.prepare_patch_policy('["second","first","first"]')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual('["first","second"]', json.loads(self.defines.read_text())[POLICY_NAME])
        verified = self.verify()
        self.assertEqual(0, verified.returncode, verified.stderr)

    def test_patch_policy_drift_remains_strict_and_does_not_log_values(self) -> None:
        defines = json.loads(self.defines.read_text())
        defines[POLICY_NAME] = "[]"
        self.defines.write_text(json.dumps(defines))
        self.assertEqual(0, self.emit().returncode)

        prepared = self.prepare_patch_policy('["private-policy-tag"]')
        self.assertEqual(0, prepared.returncode, prepared.stderr)
        drift = self.verify()
        self.assertNotEqual(0, drift.returncode)
        self.assertIn(POLICY_NAME, drift.stderr)
        self.assertNotIn("private-policy-tag", drift.stdout + drift.stderr)
        self.assertFalse(self.env_output.exists())

    def test_patch_policy_shape_cannot_hide_unknown_or_missing_other_keys(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        baseline = json.loads(self.defines.read_text())
        for altered in ({**baseline, "UNRECORDED_KEY": "value"}, {"SECRET_TOKEN": "release-secret"}):
            with self.subTest(keys=sorted(altered)):
                self.defines.write_text(json.dumps(altered))
                prepared = self.prepare_patch_policy()
                self.assertEqual(0, prepared.returncode, prepared.stderr)
                self.assertEqual(altered, json.loads(self.defines.read_text()))
                drift = self.verify()
                self.assertNotEqual(0, drift.returncode)
                self.assertIn("release configuration drifted", drift.stderr)
                self.assertFalse(self.env_output.exists())

    def test_forged_policy_presence_is_rejected_before_changing_defines(self) -> None:
        defines = json.loads(self.defines.read_text())
        defines[POLICY_NAME] = "[]"
        self.defines.write_text(json.dumps(defines))
        self.assertEqual(0, self.emit().returncode)
        record = json.loads(self.record.read_text())
        record["config_fingerprints"].pop(POLICY_NAME)
        self.record.write_text(json.dumps(record))
        baseline = self.defines.read_bytes()

        result = self.prepare_patch_policy()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("provenance authentication failed", result.stderr)
        self.assertEqual(baseline, self.defines.read_bytes())
        self.assertEqual("", result.stdout)
        self.assertFalse(self.env_output.exists())

    def test_policy_shape_requires_matching_authenticated_release_context(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        original = json.loads(self.record.read_text())
        baseline = self.defines.read_bytes()
        changes = (
            ("schema_version", 99, "unsupported release provenance schema"),
            ("platform", "android", "platform does not match"),
            ("release_version", "9.9.9+999", "version does not match"),
            ("patchable", False, "verified release configuration is unavailable"),
            ("config_fingerprint_key_id", "other-key", "different configuration fingerprint key"),
            ("config_fingerprints", [], "config_fingerprints is invalid"),
        )
        for field, value, message in changes:
            with self.subTest(field=field):
                record = {**original, field: value}
                record["record_hmac"] = self._recompute_hmac(record)
                self.record.write_text(json.dumps(record))
                result = self.prepare_patch_policy()
                self.assertNotEqual(0, result.returncode)
                self.assertIn(message, result.stderr)
                self.assertEqual(baseline, self.defines.read_bytes())
                self.assertEqual("", result.stdout)

    def test_fingerprint_is_stable_and_contains_no_values(self) -> None:
        second_record = self.root / "second.json"
        self.assertEqual(0, self.emit().returncode)
        self.assertEqual(0, self.emit(second_record).returncode)
        first = json.loads(self.record.read_text())
        second = json.loads(second_record.read_text())

        self.assertEqual(first["config_fingerprints"], second["config_fingerprints"])
        serialized = self.record.read_text()
        self.assertNotIn("release-secret", serialized)
        self.assertNotIn("PRODUCTION", serialized)

    def test_verify_accepts_matching_record_and_writes_baseline(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        result = self.verify(release_commit=self.head)

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            f"SHOREBIRD_PATCH_BASELINE_COMMIT={self.head}\n",
            self.env_output.read_text(),
        )

    def test_verify_rejects_malformed_or_mismatched_provenance(self) -> None:
        missing = self.verify()
        self.assertNotEqual(0, missing.returncode)
        self.assertIn("release provenance is missing", missing.stderr)

        self.record.write_text("not json")
        malformed = self.verify()
        self.assertNotEqual(0, malformed.returncode)
        self.assertIn("release provenance is malformed", malformed.stderr)

        self.assertEqual(0, self.emit().returncode)
        mismatch = self.verify(release_version="9.9.9+999")
        self.assertNotEqual(0, mismatch.returncode)
        self.assertIn("version does not match", mismatch.stderr)

    def test_verify_rejects_source_override_with_a_different_tree(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        history = subprocess.run(
            ["git", "log", "-64", "--format=%H%x09%T", self.head],
            cwd=REPO_ROOT,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.splitlines()
        # Replayed contributor commits can legitimately be empty. Pin an
        # actually different tree so this case never tests an allowed override.
        current_tree = history[0].split("\t")[1]
        different_commit = next(
            (commit for commit, tree in (line.split("\t") for line in history)
             if tree != current_tree),
            None,
        )
        self.assertIsNotNone(different_commit, "source-override fixture needs a different tree")

        mismatch = self.verify(release_commit=different_commit)
        self.assertNotEqual(0, mismatch.returncode)
        self.assertIn("does not match the recorded release source", mismatch.stderr)

    def test_verify_rejects_an_authenticated_record_that_was_modified(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        record = json.loads(self.record.read_text())
        record["patch_baseline_commit"] = "0000000000000000000000000000000000000000"
        self.record.write_text(json.dumps(record))

        result = self.verify()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("provenance authentication failed", result.stderr)

    def test_verify_rejects_toolchain_drift(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        flutter_mismatch = self.verify(flutter_version="9.9.9")
        self.assertNotEqual(0, flutter_mismatch.returncode)
        self.assertIn("Flutter version does not match", flutter_mismatch.stderr)

        cli_mismatch = self.verify(
            shorebird_cli_revision="0000000000000000000000000000000000000000"
        )
        self.assertNotEqual(0, cli_mismatch.returncode)
        self.assertIn("CLI revision does not match", cli_mismatch.stderr)

        cli_version_mismatch = self.verify(shorebird_cli_version="Shorebird 9.9.9")
        self.assertNotEqual(0, cli_version_mismatch.returncode)
        self.assertIn("CLI version does not match", cli_version_mismatch.stderr)

    def test_verify_identifies_fingerprint_key_rotation(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        rotated_environment = {
            **self.environment,
            "SHOREBIRD_PROVENANCE_HMAC_KEY_ID": "test-key-v2",
        }
        result = self.verify(environment=rotated_environment)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("different configuration fingerprint key", result.stderr)

    def test_config_drift_reports_only_key_names(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        self.defines.write_text(
            json.dumps({"DEFAULT_ENV": "STAGING", "SECRET_TOKEN": "patch-secret"})
        )
        result = self.verify()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("DEFAULT_ENV", result.stderr)
        self.assertIn("SECRET_TOKEN", result.stderr)
        self.assertNotIn("PRODUCTION", result.stderr)
        self.assertNotIn("STAGING", result.stderr)
        self.assertNotIn("release-secret", result.stderr)
        self.assertNotIn("patch-secret", result.stderr)

    def test_verify_rejects_a_rotated_patch_signing_key(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        rotated = self.verify(
            environment={
                **self.environment,
                "SHOREBIRD_PATCH_PUBLIC_KEY": ROTATED_PUBLIC_KEY,
            }
        )

        self.assertNotEqual(0, rotated.returncode)
        self.assertIn("patch signing key does not match", rotated.stderr)

    def test_recorded_key_digest_is_the_plain_digest_of_the_pem(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        record = json.loads(self.record.read_text())

        self.assertEqual(
            hashlib.sha256(
                RELEASE_PUBLIC_KEY.replace("\\n", "\n").encode()
            ).hexdigest(),
            record["patch_public_key_sha256"],
        )

    def test_emit_rejects_a_public_key_that_is_not_a_pem(self) -> None:
        result = self.emit(
            environment={
                **self.environment,
                "SHOREBIRD_PATCH_PUBLIC_KEY": "-----BEGIN PRIVATE KEY-----\\nx\\n-----END PRIVATE KEY-----",
            }
        )

        self.assertNotEqual(0, result.returncode)
        self.assertIn("not a public-key PEM", result.stderr)

    def test_a_record_predating_key_binding_verifies_with_a_note(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        record = json.loads(self.record.read_text())
        record.pop("patch_public_key_sha256")
        # The HMAC covers every field but itself, so a record written before
        # the field existed still authenticates once the field is dropped.
        record["record_hmac"] = self._recompute_hmac(record)
        self.record.write_text(json.dumps(record))

        result = self.verify(
            environment={
                **self.environment,
                "SHOREBIRD_PATCH_PUBLIC_KEY": ROTATED_PUBLIC_KEY,
            }
        )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("predates patch-signing-key binding", result.stderr)

    def _recompute_hmac(self, record: dict) -> str:
        payload = subprocess.run(
            [
                "ruby",
                "-rjson",
                "-e",
                """
                def canonical(value)
                  case value
                  when Hash then '{' + value.keys.sort.map { |k|
                    "#{JSON.generate(k)}:#{canonical(value.fetch(k))}" }.join(',') + '}'
                  when Array then '[' + value.map { |i| canonical(i) }.join(',') + ']'
                  else JSON.generate(value)
                  end
                end
                record = JSON.parse($stdin.read)
                print canonical(record.reject { |name, _| name == 'record_hmac' })
                """,
            ],
            input=json.dumps(record),
            check=True,
            text=True,
            capture_output=True,
        ).stdout
        return hmac.new(
            self.environment["SHOREBIRD_PROVENANCE_HMAC_KEY"].encode(),
            payload.encode(),
            hashlib.sha256,
        ).hexdigest()

    def test_unpatchable_historical_record_fails_closed(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        record = json.loads(self.record.read_text())
        record["patchable"] = False
        record.pop("config_fingerprints")
        self.record.write_text(json.dumps(record))

        result = self.verify()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("verified release configuration is unavailable", result.stderr)


if __name__ == "__main__":
    unittest.main()
