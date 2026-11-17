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

    def test_source_batches_cover_final_files_without_generated_schema_noise(self):
        def git(*args):
            if args[0] == "diff" and "--name-only" in args:
                return "mobile/lib/a.dart\nmobile/lib/b.dart\nmobile/lib/router/routes.g.dart\nmobile/packages/db/drift_schemas/schema.json\n"
            return "+ source change\n"

        with patch.object(self.notes, "_git", side_effect=git):
            batches = self.notes.source_batches("a" * 40, "b" * 40)
        paths = [p for batch in batches for p in batch["paths"]]
        self.assertEqual(paths, ["mobile/lib/a.dart", "mobile/lib/b.dart"])
        self.assertTrue(all("patch" in batch for batch in batches))

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
                "source_batches",
                side_effect=AssertionError("do not inventory without credential"),
            ),
            self.assertRaisesRegex(ValueError, "RELEASE_NOTES_LUNAROUTE_API_KEY"),
        ):
            self.notes._generate("android", "b" * 40, self.bundle["baseline"], [], {})

    def test_complete_source_facts_are_reviewed_before_bundle_is_accepted(self):
        fact = {
            "path": "mobile/lib/a.dart",
            "include": True,
            "summary": "Find people while videos load.",
            "test": "Search for a friend and play a video.",
            "reason": "Visible search behavior",
        }
        copy = {"google_play": self.bundle["google_play"]}
        with (
            patch.object(
                self.notes,
                "source_batches",
                return_value=[{"paths": [fact["path"]], "patch": "+ final source"}],
            ),
            patch.object(
                self.notes,
                "model_json",
                side_effect=[
                    {"facts": [fact]},
                    {"approved": True, "reason": ""},
                    copy,
                    {"approved": True, "reason": ""},
                ],
            ) as model,
        ):
            generated = self.notes._generate(
                "android",
                "b" * 40,
                self.bundle["baseline"],
                [],
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "not-a-key"},
            )
        self.assertEqual(generated["changes"], [fact])
        self.assertEqual(generated["google_play"], copy["google_play"])
        self.assertEqual(model.call_count, 4)

    def test_missing_source_fact_or_rejected_editorial_stops_publication(self):
        cases = [
            ([{"facts": []}], "inventory"),
            (
                [
                    {"facts": [{"path": "mobile/lib/a.dart", "include": True}]},
                    {"approved": False, "reason": "Invented behavior"},
                ]
                * 3,
                "verification",
            ),
        ]
        for responses, message in cases:
            with (
                self.subTest(message=message),
                patch.object(
                    self.notes,
                    "source_batches",
                    return_value=[
                        {"paths": ["mobile/lib/a.dart"], "patch": "+ source"}
                    ],
                ),
                patch.object(self.notes, "model_json", side_effect=responses),
                self.assertRaisesRegex(ValueError, message),
            ):
                self.notes._generate(
                    "android",
                    "b" * 40,
                    self.bundle["baseline"],
                    [],
                    {"RELEASE_NOTES_LUNAROUTE_API_KEY": "not-a-key"},
                )

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

    def test_source_fact_feedback_is_corrected_and_independently_rechecked(self):
        bad = {
            "path": "mobile/lib/a.dart",
            "include": True,
            "summary": "Thirteen effects.",
            "test": "Try an effect.",
            "reason": "UI",
        }
        good = dict(bad, summary="Try new video effects.")
        responses = [
            {"facts": [bad]},
            {"approved": False, "reason": "Count not proven; drop the count."},
            {"facts": [good]},
            {"approved": True, "reason": ""},
            {"google_play": self.bundle["google_play"]},
            {"approved": True, "reason": ""},
        ]
        with (
            patch.object(
                self.notes,
                "source_batches",
                return_value=[{"paths": [bad["path"]], "patch": "+ final source"}],
            ),
            patch.object(self.notes, "model_json", side_effect=responses),
        ):
            result = self.notes._generate(
                "android",
                "b" * 40,
                self.bundle["baseline"],
                [],
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
            )
        self.assertEqual(result["changes"], [good])

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

    def test_unproven_claim_is_omitted_only_after_independent_reverification(self):
        fact = {
            "path": "mobile/lib/a.dart",
            "include": True,
            "summary": "Newest copy always wins.",
            "test": "Sync a list.",
            "reason": "Unproven recency",
        }
        rejection = {
            "approved": False,
            "reason": "This is an internal tie-break, not a recency comparison.",
            "rejected_paths": [fact["path"]],
        }
        responses = [{"facts": [fact]}, rejection] * 3 + [
            {
                "approved": True,
                "reason": "Unsupported claim is now excluded.",
                "rejected_paths": [],
            },
            {"google_play": self.bundle["google_play"]},
            {"approved": True, "reason": ""},
        ]
        with (
            patch.object(
                self.notes,
                "source_batches",
                return_value=[
                    {"paths": [fact["path"]], "patch": "+ deterministic tie break"}
                ],
            ),
            patch.object(self.notes, "model_json", side_effect=responses),
        ):
            result = self.notes._generate(
                "android",
                "b" * 40,
                self.bundle["baseline"],
                [],
                {"RELEASE_NOTES_LUNAROUTE_API_KEY": "lr_synthetic"},
            )
        self.assertEqual(len(result["changes"]), 1)
        self.assertFalse(result["changes"][0]["include"])
        self.assertEqual(result["changes"][0]["summary"], "")
        self.assertIn("Unverified", result["changes"][0]["reason"])

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
