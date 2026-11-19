import copy
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "mobile/scripts"))


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        from release_train import release_notes as notes
        from release_train_fakes import release_notes_bundle

        self.notes = notes
        self.bundle = {
            "schema": 1,
            "platform": "android",
            "source_sha": "b" * 40,
            "baseline": {"version": "1.0.29", "sha": "a" * 40},
            "locales": [],
            "testflight": [],
            "app_store": [],
            "google_play": release_notes_bundle("android")["google_play"],
            "changes": [],
            "policy_sha256": notes.policy_digest(),
        }

    def test_native_rejects_wrong_source_before_upload(self):
        with self.assertRaisesRegex(ValueError, "source"):
            self.notes.bundle_from_env(
                {"RELEASE_NOTES_BUNDLE": json.dumps(self.bundle)}, "c" * 40, "android"
            )

    def test_all_play_locales_required(self):
        self.bundle["google_play"].pop()
        with self.assertRaisesRegex(ValueError, "language|locale"):
            self.notes.notes_for(self.bundle, "google_play")

    def test_character_limit_counts_unicode_not_utf8_bytes(self):
        self.bundle["google_play"][0]["text"] = "界" * 500
        self.assertEqual(
            len(self.notes.notes_for(self.bundle, "google_play")[0]["text"]), 500
        )
        self.bundle["google_play"][0]["text"] += "界"
        with self.assertRaisesRegex(ValueError, "500"):
            self.notes.notes_for(self.bundle, "google_play")

    def test_blank_duplicate_and_developer_titles_rejected(self):
        for text in ["", "fix(startup): use partial SQLite index", "a" * 40]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.notes.validate_localizations(
                    [{"language": "en-US", "text": text}], limit=4000
                )
        with self.assertRaises(ValueError):
            self.notes.validate_localizations(
                [{"language": "en-US", "text": "Try search."}] * 2, limit=4000
            )

    def test_apple_requires_each_requested_language(self):
        bundle = copy.deepcopy(self.bundle)
        bundle.update(
            platform="ios",
            locales=["en-US", "fr-FR"],
            google_play=[],
            testflight=[
                {"language": "en-US", "text": "Search for a friend. Open their videos."}
            ],
            app_store=[{"language": "en-US", "text": "Find your people more easily."}],
        )
        with self.assertRaisesRegex(ValueError, "language|locale"):
            self.notes.notes_for(bundle, "testflight")

    def test_baseline_comes_from_live_store_not_newest_beta(self):
        data = {
            "versions": [
                {"version": "1.0.29", "state": "READY_FOR_SALE", "build_id": "live"},
                {
                    "version": "1.0.30",
                    "state": "PREPARE_FOR_SUBMISSION",
                    "build_id": "beta",
                },
            ],
            "builds": [
                {"id": "live", "version": "1.0.29", "sha": "a" * 40},
                {"id": "beta", "version": "1.0.30", "sha": "c" * 40},
            ],
        }
        self.assertEqual(
            self.notes.production_baseline("ios", data), self.bundle["baseline"]
        )

    def test_missing_production_provenance_cannot_guess_a_git_tag(self):
        with self.assertRaisesRegex(ValueError, "provenance|source"):
            self.notes.production_baseline(
                "android",
                {"production": [{"version": "1.0.29", "number": 855, "sha": None}]},
            )

    def test_immutable_cache_reuse_does_not_require_model_key(self):
        class Ledger:
            def paths(inner):
                return {self.notes.bundle_path("android", "b" * 40, "a" * 40)}

            def read_json(inner, path):
                return self.bundle

        with (
            patch.object(self.notes, "_check_ancestry"),
            patch.object(
                self.notes, "_generate", side_effect=AssertionError("must reuse")
            ),
        ):
            result = self.notes.ensure_bundle(
                "android",
                "b" * 40,
                {"production": [{"number": 855, **self.bundle["baseline"]}]},
                env={},
                ledger=Ledger(),
            )
        self.assertEqual(result, self.bundle)

    def test_ledger_failures_are_typed_preparation_errors(self):
        from release_train.ledger import LedgerError
        from release_train_fakes import MemoryLedgerStore

        for operation in ['paths', 'read_json', 'create_json']:
            with self.subTest(operation=operation):
                path = self.notes.bundle_path('android', 'b' * 40, 'a' * 40)
                ledger = MemoryLedgerStore({path: self.bundle} if operation == 'read_json' else {})
                with (
                    patch.object(ledger, operation, side_effect=LedgerError('Ledger unavailable')),
                    patch.object(self.notes, '_check_ancestry'),
                    patch.object(self.notes, '_generate', return_value=self.bundle),
                    self.assertRaisesRegex(self.notes.ReleaseNotesError, 'ledger'),
                ):
                    self.notes.ensure_bundle('android', 'b' * 40,
                        {'production': [{'number': 855, **self.bundle['baseline']}]},
                        env={}, ledger=ledger)

    def test_source_cache_remains_bound_after_production_advances(self):
        class Ledger:
            def paths(inner):
                return {self.notes.bundle_path("android", "b" * 40, "a" * 40)}

            def read_json(inner, path):
                return self.bundle

        with patch.object(
            self.notes,
            "_production_data",
            side_effect=AssertionError("must retain original baseline"),
        ):
            self.assertEqual(
                self.notes.ensure_bundle("android", "b" * 40, env={}, ledger=Ledger()),
                self.bundle,
            )

    def test_native_bundle_omits_internal_fact_inventory(self):
        self.bundle["changes"] = [
            {"path": "mobile/lib/a.dart", "summary": "Private editorial inventory"}
        ]
        compact = self.notes.bundle_for_native(self.bundle)
        self.assertEqual(compact["changes"], [])
        self.assertEqual(compact["google_play"], self.bundle["google_play"])
        self.assertEqual(len(self.bundle["changes"]), 1)

    def test_generation_requires_funded_model_before_reading_source(self):
        with (
            patch.object(
                self.notes,
                "source_inventory",
                side_effect=AssertionError("do not inventory without credential"),
            ),
            self.assertRaisesRegex(ValueError, "RELEASE_NOTES_LUNAROUTE_API_KEY"),
        ):
            self.notes._generate("android", "b" * 40, self.bundle["baseline"], [], {})

    def test_generation_uses_lunaroute_gateway_and_managed_model(self):
        import io

        response = {
            "status": "completed",
            "output": [
                {
                    "type": "message",
                    "content": [
                        {
                            "type": "output_text",
                            "text": '{"text":"Search for a friend and open a video."}',
                        }
                    ],
                }
            ],
        }
        with patch(
            "urllib.request.OpenerDirector.open",
            return_value=io.StringIO(json.dumps(response)),
        ) as request:
            output = self.notes.model_json(
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
                "Write helpful notes.",
                {},
                {"type": "object"},
            )
        sent = request.call_args.args[0]
        self.assertEqual(sent.full_url, "https://gw.lunaroute.com/v1/responses")
        self.assertEqual(sent.get_header("Lunaroute-api-key"), "lr_synthetic")
        body = json.loads(sent.data)
        self.assertEqual(body["model"], "glm-5.3")
        self.assertFalse(body["store"])
        self.assertIn("JSON schema", body["instructions"])
        self.assertNotIn("lr_synthetic", sent.data.decode())
        self.assertEqual(output["text"], "Search for a friend and open a video.")

    def test_model_json_rejects_a_complete_but_wrong_schema(self):
        import io

        response = {
            "status": "completed",
            "output": [
                {
                    "type": "message",
                    "content": [{"type": "output_text", "text": '{"wrong":"field"}'}],
                }
            ],
        }
        schema = self.notes._object({"text": {"type": "string"}})
        with (
            patch(
                "urllib.request.OpenerDirector.open",
                return_value=io.StringIO(json.dumps(response)),
            ),
            self.assertRaisesRegex(ValueError, "schema"),
        ):
            self.notes.model_json(
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
                "Write notes.",
                {},
                schema,
            )

    def test_managed_concurrency_limit_is_retried_with_bounded_backoff(self):
        import io
        import urllib.error

        busy = urllib.error.HTTPError(
            "https://gw.lunaroute.com/v1/responses",
            429,
            "busy",
            {"Retry-After": "1"},
            io.BytesIO(),
        )
        reply = io.StringIO(
            json.dumps(
                {
                    "status": "completed",
                    "output": [
                        {
                            "type": "message",
                            "content": [{"type": "output_text", "text": "{}"}],
                        }
                    ],
                }
            )
        )
        with (
            patch(
                "urllib.request.OpenerDirector.open", side_effect=[busy, reply]
            ) as request,
            patch("release_train.release_notes.time.sleep") as sleep,
        ):
            self.notes.model_json(
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
                "JSON only.",
                {},
                {"type": "object"},
            )
        self.assertEqual(request.call_count, 2)
        sleep.assert_called_once_with(1)

    def test_original_baseline_survives_brand_policy_updates(self):
        bundle = self.bundle

        class Ledger:
            def paths(inner):
                return {
                    "release-notes/android/"
                    + "b" * 40
                    + "/"
                    + "a" * 40
                    + "-"
                    + "c" * 64
                    + ".json"
                }

            def read_json(inner, path):
                return bundle

        with (
            patch.object(self.notes, "policy_digest", return_value="d" * 64),
            patch.object(
                self.notes,
                "_production_data",
                side_effect=AssertionError("original baseline must survive"),
            ),
        ):
            self.assertEqual(
                self.notes.ensure_bundle("android", "b" * 40, env={}, ledger=Ledger()),
                bundle,
            )

    def test_apple_rejects_extra_model_locale_before_any_store_mutation(self):
        bundle = copy.deepcopy(self.bundle)
        bundle.update(
            platform="ios",
            locales=["en-US"],
            google_play=[],
            testflight=[
                {"language": "en-US", "text": "Search for a friend."},
                {"language": "zz-ZZ", "text": "Invented locale."},
            ],
            app_store=[{"language": "en-US", "text": "Find your people."}],
        )
        with self.assertRaisesRegex(ValueError, "locale"):
            self.notes.notes_for(bundle, "testflight")

    def test_play_languages_cover_every_shipped_app_language(self):
        app_languages = {
            path.stem.removeprefix("app_")
            for path in (self.notes.ROOT / "mobile/lib/l10n").glob("app_*.arb")
        }
        self.assertEqual(
            {locale.split("-")[0] for locale in self.notes.PLAY_LOCALES}, app_languages
        )

    def test_translated_notes_cannot_repeat_english_copy(self):
        self.bundle["google_play"][1]["text"] = self.bundle["google_play"][0]["text"]
        with self.assertRaisesRegex(ValueError, "English"):
            self.notes.notes_for(self.bundle, "google_play")

    def test_generate_uses_one_model_call_for_the_complete_release_changelog(self):
        inventory = [
            {"sha": "c" * 40, "subject": "fix(search): load people and videos together"}
        ]
        with (
            patch.object(self.notes, "source_inventory", return_value=inventory),
            patch.object(
                self.notes,
                "model_json",
                return_value={"google_play": self.bundle["google_play"]},
            ) as model,
        ):
            result = self.notes._generate(
                "android",
                "b" * 40,
                self.bundle["baseline"],
                [],
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
            )
        self.assertEqual(model.call_count, 1)
        self.assertEqual(model.call_args.args[2]["changes"], inventory)
        self.assertEqual(result["changes"], inventory)
        self.assertEqual(result["google_play"], self.bundle["google_play"])

    def test_testflight_covers_both_betas_since_the_shipped_version(self):
        shipped_sha, first_beta_sha, candidate_sha = "a" * 40, "b" * 40, "c" * 40
        data = {
            "versions": [
                {
                    "version": "1.0.30",
                    "state": "READY_FOR_DISTRIBUTION",
                    "build_id": "shipped",
                },
                {
                    "version": "1.0.31",
                    "state": "IN_REVIEW",
                    "build_id": "first-beta",
                },
            ],
            "builds": [
                {"id": "shipped", "version": "1.0.30", "sha": shipped_sha},
                {"id": "first-beta", "version": "1.0.31", "sha": first_beta_sha},
                {"id": "second-beta", "version": "1.0.31", "sha": candidate_sha},
            ],
        }
        subjects = [
            {"sha": first_beta_sha, "subject": "feat(editor): add curtain effects"},
            {"sha": candidate_sha, "subject": "feat(camera): film with both cameras"},
        ]
        generated = {
            "testflight": [{"language": "en-US", "text": "Give your loop an entrance"}],
            "app_store": [{"language": "en-US", "text": "Open with a stage curtain."}],
        }
        baseline = self.notes.production_baseline("ios", data)
        with (
            patch.object(
                self.notes,
                "_git",
                side_effect=[
                    "mobile/lib/editor.dart\nmobile/lib/camera.dart\n",
                    "\n".join(f"{entry['sha']}\t{entry['subject']}" for entry in subjects),
                    "mobile/lib/editor.dart\n",
                    "mobile/lib/camera.dart\n",
                ],
            ) as git,
            patch.object(self.notes, "model_json", return_value=generated) as model,
        ):
            bundle = self.notes._generate(
                "ios", candidate_sha, baseline, ["en-US"],
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
            )
        git.assert_any_call(
            "log", "--first-parent", "--reverse", "--format=%H%x09%s",
            f"{shipped_sha}..{candidate_sha}",
        )
        _, instructions, context, _ = model.call_args.args
        self.assertEqual(context["baseline"], {"version": "1.0.30", "sha": shipped_sha})
        self.assertEqual(context["changes"], subjects)
        self.assertIn("upgrading from the previous public App Store release", instructions)
        self.assertIn("earlier betas of the same version", instructions)
        self.assertIn("1,100–1,800 characters", instructions)
        self.assertEqual(self.notes.notes_for(bundle, "testflight"), generated["testflight"])

    def test_changelog_excludes_build_only_prototype_and_other_platform_changes(self):
        subjects = {
            "c" * 40: "fix(search): show results together",
            "d" * 40: "feat(prototype): inbox experiment",
            "e" * 40: "fix(ios): share sheet",
            "f" * 40: "build: update release scripts",
        }
        paths = {
            "c" * 40: "mobile/lib/search.dart",
            "d" * 40: "mobile/lib/prototypes/inbox.dart",
            "e" * 40: "mobile/ios/Runner/Share.swift",
            "f" * 40: "mobile/scripts/release.py",
        }

        def git(*args):
            if args[0] == "log":
                return "\n".join(key + "\t" + value for key, value in subjects.items())
            if args[:2] == ("diff", "--name-only"):
                if args[2] == "a" * 40:
                    return "\n".join(paths.values())
                return paths[args[2].removesuffix("^")]
            raise AssertionError(args)

        with patch.object(self.notes, "_git", side_effect=git):
            changes = self.notes.source_inventory(
                "a" * 40, "b" * 40, platform="android"
            )
        self.assertEqual(changes, [{"sha": "c" * 40, "subject": subjects["c" * 40]}])

    def test_overlong_translation_gets_one_shortening_retry(self):
        bad = copy.deepcopy(self.bundle["google_play"])
        bad[1]["text"] = "x" * 501
        inventory = [{"sha": "c" * 40, "subject": "fix(search): load results together"}]
        with (
            patch.object(self.notes, "source_inventory", return_value=inventory),
            patch.object(
                self.notes,
                "model_json",
                side_effect=[
                    {"google_play": bad},
                    {"google_play": self.bundle["google_play"]},
                ],
            ) as model,
        ):
            result = self.notes._generate(
                "android",
                "b" * 40,
                self.bundle["baseline"],
                [],
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
            )
        self.assertEqual(model.call_count, 2)
        self.assertIn("es-419", model.call_args.args[2]["validation_error"])
        self.assertEqual(result["google_play"], self.bundle["google_play"])

    def test_transport_error_never_contains_key_or_response_body(self):
        import urllib.error

        error = urllib.error.HTTPError(
            "https://api.openai.com/v1/responses", 401, "secret response", {}, None
        )
        with (
            patch("urllib.request.OpenerDirector.open", side_effect=error),
            self.assertRaisesRegex(ValueError, "HTTP 401") as raised,
        ):
            self.notes.model_json(
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
                "instruction",
                {},
                {"type": "object"},
            )
        self.assertNotIn("lr_synthetic", str(raised.exception))
        self.assertNotIn("secret response", str(raised.exception))

    def test_completed_output_required_even_when_json_exists(self):
        with self.assertRaisesRegex(ValueError, "incomplete"):
            self.notes.response_json(
                {
                    "status": "incomplete",
                    "output": [
                        {
                            "type": "message",
                            "content": [{"type": "output_text", "text": "{}"}],
                        }
                    ],
                }
            )


if __name__ == "__main__":
    unittest.main()
