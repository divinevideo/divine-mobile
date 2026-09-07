import json
import re
import subprocess
import unittest
from pathlib import Path


CODEMAGIC_PATH = Path(__file__).resolve().parents[3] / "codemagic.yaml"
MISE_PATH = Path(__file__).resolve().parents[3] / "mobile" / "mise.toml"
MOBILE_CI_PATH = (
    Path(__file__).resolve().parents[3] / ".github" / "workflows" / "mobile_ci.yaml"
)
WORKFLOWS_PATH = Path(__file__).resolve().parents[2] / "workflows"
COORDINATOR_PROBE_WORKFLOW_PATH = WORKFLOWS_PATH / "coordinator_route_probe.yml"
SHOREBIRD_DOC_PATH = (
    Path(__file__).resolve().parents[3] / "mobile" / "docs" / "SHOREBIRD_CODE_PUSH.md"
)
SHOREBIRD_CONFIG_PATH = (
    Path(__file__).resolve().parents[3] / "mobile" / "shorebird.yaml"
)
PROVENANCE_STORE_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "scripts"
    / "shorebird_provenance_store.sh"
)
PATCH_SOURCE_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "scripts"
    / "shorebird_patch_source.rb"
)
CAPTION_GENERATOR_GRADLE_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "packages"
    / "caption_generator"
    / "android"
    / "build.gradle.kts"
)


class CodemagicShorebirdConfigTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contents = CODEMAGIC_PATH.read_text()
        self.mobile_ci_contents = MOBILE_CI_PATH.read_text()
        self.coordinator_probe_workflow_contents = (
            COORDINATOR_PROBE_WORKFLOW_PATH.read_text()
        )
        self.mise_contents = MISE_PATH.read_text()
        self.shorebird_doc_contents = SHOREBIRD_DOC_PATH.read_text()
        self.shorebird_config_contents = SHOREBIRD_CONFIG_PATH.read_text()
        self.provenance_store_contents = PROVENANCE_STORE_PATH.read_text()
        self.patch_source_contents = PATCH_SOURCE_PATH.read_text()
        self.caption_generator_gradle_contents = CAPTION_GENERATOR_GRADLE_PATH.read_text()

    def test_codemagic_yaml_parses_with_aliases(self) -> None:
        result = subprocess.run(
            [
                "ruby",
                "-e",
                (
                    "require 'yaml'; "
                    "data = YAML.safe_load(File.read(ARGV[0]), aliases: true); "
                    "abort 'missing workflows' unless data.fetch('workflows').is_a?(Hash); "
                    "abort 'missing definitions' unless data.fetch('definitions').is_a?(Hash)"
                ),
                str(CODEMAGIC_PATH),
            ],
            check=False,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_ios_e2e_uses_one_simulator_for_boot_install_and_maestro(
        self,
    ) -> None:
        boot = self._definition_block("boot_ios_simulator")
        install = self._definition_block("install_app_ios_simulator")
        maestro = self._definition_block("run_maestro_smoke_tests")

        self.assertIn(
            'echo "MAESTRO_DEVICE_UDID=$DEVICE_UDID" >> "$CM_ENV"',
            boot,
        )
        self.assertIn(
            (
                ': "${MAESTRO_DEVICE_UDID:?The boot step did not export a '
                'simulator UDID}"'
            ),
            install,
        )
        self.assertNotIn("simctl list devices booted", install)
        self.assertIn(
            'simctl install "$MAESTRO_DEVICE_UDID" "$APP_PATH"',
            install,
        )
        self.assertIn(
            'simctl get_app_container "$MAESTRO_DEVICE_UDID" "$BUNDLE_ID"',
            install,
        )
        self.assertIn('if [ -n "${MAESTRO_DEVICE_UDID:-}" ]; then', maestro)
        self.assertIn('set -- --device "$MAESTRO_DEVICE_UDID"', maestro)
        self.assertIn('maestro "$@" test', maestro)

        workflow = self._resolved_config()["workflows"]["e2e-smoke-ios"]
        self.assertEqual(
            "co.openvine.app.staging",
            workflow["environment"]["vars"]["BUNDLE_ID"],
        )
        step_names = [step["name"] for step in workflow["scripts"]]
        self.assertLess(
            step_names.index("Boot iOS Simulator"),
            step_names.index("Install app on iOS Simulator"),
        )
        self.assertLess(
            step_names.index("Install app on iOS Simulator"),
            step_names.index("Run Maestro Smoke Tests"),
        )

    def test_feed_ttff_workflow_runs_the_budget_on_android(self) -> None:
        workflow = self._resolved_config()["workflows"]["perf-feed-ttff"]

        self.assertEqual("linux_x2", workflow["instance_type"])
        self.assertEqual("625k", workflow["environment"]["vars"]["THROTTLE_RATE"])
        self.assertEqual([], workflow["triggering"]["events"])
        self.assertIn("github_credentials", workflow["environment"]["groups"])
        step_names = [step["name"] for step in workflow["scripts"]]
        self.assertIn("Launch Android emulator", step_names)
        self.assertIn("Run feed TTFF budget twice on failure", step_names)

        runner = next(
            step["script"]
            for step in workflow["scripts"]
            if step["name"] == "Run feed TTFF budget twice on failure"
        )
        self.assertIn("GHCR_PULL_TOKEN", runner)
        self.assertIn("local_stack/up.sh --pull=missing", runner)
        self.assertEqual(2, runner.count("feed_ttff_test.dart"))
        self.assertIn("test_reports/*.jsonl", workflow["artifacts"])

    def test_pod_install_only_targets_the_app_workspace(self) -> None:
        pod_install = self._definition_block("pod_install")

        self.assertIn("cd ios && pod install", pod_install)
        self.assertNotIn("--project-directory", pod_install)
        self.assertNotIn("find ", pod_install)

    def test_android_e2e_excludes_unbounded_maestro_artifacts(self) -> None:
        workflow = self._resolved_config()["workflows"]["e2e-smoke-android"]

        self.assertEqual(
            "co.openvine.app.staging",
            workflow["environment"]["vars"]["BUNDLE_ID"],
        )
        self.assertEqual(
            [
                "build/app/outputs/flutter-apk/app-debug.apk",
                "~/.maestro/tests/**/screenshots/**",
                "~/.maestro/tests/**/screen-hierarchy/**",
                "~/.maestro/tests/**/logs/maestro.log",
                "~/.maestro/tests/**/commands.json",
            ],
            workflow["artifacts"],
        )

    def test_android_aab_build_uses_google_play_floor(self) -> None:
        self.assertIn(
            'google-play get-latest-build-number --package-name "co.openvine.app"',
            self.contents,
        )
        self.assertIn("BUILD_NUMBER=$PROJECT_BUILD_NUMBER", self.contents)
        self.assertIn(
            'NEXT_PLAY_BUILD_NUMBER=$((LATEST_GOOGLE_PLAY_BUILD_NUMBER + 1))',
            self.contents,
        )
        self.assertIn(
            'if [ "$NEXT_PLAY_BUILD_NUMBER" -gt "$BUILD_NUMBER" ]; then',
            self.contents,
        )
        self.assertNotIn("PROJECT_BUILD_NUMBER + 8", self.contents)

    def test_android_release_publishes_to_internal_track(self) -> None:
        block = self._workflow_block("android-build")
        self.assertRegex(block, r"(?m)^        track: internal$")
        self.assertNotIn("submit_as_draft", block)
        self.assertNotIn("track: production", block)

    def test_shorebird_supporters_defines_are_optional(self) -> None:
        self.assertIn("optional_names = %w[", self.contents)
        self.assertIn("SUPPORTERS_API_BASE_URL", self.contents)
        self.assertIn("FF_DIVINE_SUPPORTERS", self.contents)
        self.assertIn("defines[name] = ENV.fetch(name, '')", self.contents)

    def test_store_gate_probes_only_the_selected_environment(self) -> None:
        self.assertRegex(
            self.contents,
            r'(?s)&check_coordinator_route.*?DEFAULT_ENV="\$\{\{ inputs\.DEFAULT_ENV \}\}"'
            r"\s+\\\n\s+\./scripts/check_coordinator_route_serving\.sh",
        )
        for workflow in ("ios-build", "android-build"):
            self.assertIn(
                "- *check_coordinator_route",
                self._workflow_block(workflow),
            )

    def test_scheduled_probe_maintains_one_incident_issue(self) -> None:
        workflow = self.coordinator_probe_workflow_contents
        self.assertIn("issues: write", workflow)
        self.assertIn("group: coordinator-route-probe", workflow)
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertIn(
            "github.ref_name == github.event.repository.default_branch",
            workflow,
        )
        self.assertIn("coordinator-route-probe-incident", workflow)
        self.assertIn("state: 'all'", workflow)
        self.assertIn("state: 'open'", workflow)
        self.assertIn("state: 'closed'", workflow)
        self.assertEqual(1, workflow.count("github.rest.issues.create({"))

    def test_runtime_track_selection_disables_native_auto_update(self) -> None:
        self.assertRegex(
            self.shorebird_config_contents,
            r"(?m)^auto_update:\s*false\s*$",
        )

    def test_shorebird_required_defines_reject_empty_values(self) -> None:
        self.assertIn(
            "required_names.reject { |name| ENV.key?(name) && !ENV.fetch(name).empty? }",
            self.contents,
        )

    def test_shorebird_install_reuses_only_the_expected_cached_version(self) -> None:
        self.assertIn('EXPECTED_SHOREBIRD_VERSION="Shorebird 1.6.117"', self.contents)
        self.assertIn(
            'EXPECTED_SHOREBIRD_REVISION="45facdd4e4b3c39e0d260107977584f0b7c66bec"',
            self.contents,
        )
        self.assertIn('if [ -x "$SHOREBIRD_BIN" ]; then', self.contents)
        self.assertIn('git -C "$HOME/.shorebird" rev-parse HEAD', self.contents)
        self.assertRegex(
            self.contents,
            r"(?s)&shorebird_install.*?script: \|\n\s+set -euo pipefail\n",
        )

    def test_shorebird_cli_install_is_pinned_to_a_full_commit(self) -> None:
        self.assertRegex(
            self.contents,
            r'EXPECTED_SHOREBIRD_REVISION="[0-9a-f]{40}"',
        )
        self.assertIn('checkout --quiet --detach FETCH_HEAD', self.contents)
        self.assertNotIn("raw.githubusercontent.com/shorebirdtech/install", self.contents)
        self.assertNotRegex(self.contents, r"git clone .* (?:stable|v[0-9])")

    def test_shorebird_release_commands_are_signed_and_preflighted(self) -> None:
        self.assertIn("*preflight_shorebird_ios_release", self.contents)
        self.assertIn("*preflight_shorebird_android_release", self.contents)
        self.assertIn("shorebird releases list --platform=android --json", self.contents)
        self.assertIn("shorebird releases list --platform=ios --json", self.contents)
        self.assertEqual(2, self.contents.count("shorebird_release_preflight.rb"))
        self.assertNotIn("shorebird releases info", self.contents)
        self.assertIn("--build-name=$BUILD_NAME", self.contents)
        commands = self._shorebird_release_commands()
        self.assertEqual(2, len(commands))
        for command in commands:
            self.assertIn("--public-key-path=build/shorebird/patch_public_key.pem", command)

    def test_ios_release_rejects_closed_app_store_version_before_shorebird(self) -> None:
        workflow = self._workflow_block("ios-build")
        self.assertIn(
            "app-store-connect get-latest-app-store-build-number",
            self.contents,
        )
        self.assertIn("--include-version --json", self.contents)
        self.assertEqual(1, self.contents.count("ios_store_version_preflight.rb"))
        self.assertLess(
            workflow.index("- *preflight_shorebird_ios_release"),
            workflow.index("- *build_ios"),
        )

    def test_flutter_pins_match_current_shorebird_engine(self) -> None:
        mise_version = re.search(r'^flutter = "([^"]+)"$', self.mise_contents, re.MULTILINE)
        self.assertIsNotNone(mise_version)
        expected = mise_version.group(1)

        mobile_ci_versions = set(
            re.findall(r'flutter-version: "([^"]+)"', self.mobile_ci_contents)
        )
        codemagic_flutter_versions = set(
            re.findall(r"^\s+flutter: ([0-9]+\.[0-9]+\.[0-9]+)$", self.contents, re.MULTILINE)
        )
        shorebird_release_versions = set(
            re.findall(r"^\s+FLUTTER_VERSION: ([0-9]+\.[0-9]+\.[0-9]+)$", self.contents, re.MULTILINE)
        )

        self.assertEqual({expected}, mobile_ci_versions)
        self.assertEqual({expected}, codemagic_flutter_versions)
        self.assertEqual({expected}, shorebird_release_versions)
        stale_workflows = []
        for workflow in WORKFLOWS_PATH.glob("*.y*ml"):
            workflow_contents = workflow.read_text()
            uses_flutter = re.search(
                r"flutter_package\.yml|subosito/flutter-action|"
                r"\bflutter\s+(?:analyze|build|drive|pub|test)\b",
                workflow_contents,
            )
            if uses_flutter is None:
                continue
            versions = re.findall(
                r"flutter(?:-|_)version:\s*[\"']?([^\"'\s]+)",
                workflow_contents,
            )
            if set(versions) != {expected}:
                stale_workflows.append(workflow.name)
        self.assertEqual([], stale_workflows)

    def test_shorebird_patch_commands_publish_to_staging_and_are_signed(self) -> None:
        self.assertIn(
            "shorebird patch android --release-version=${{ inputs.RELEASE_VERSION }} --track=staging",
            self.contents,
        )
        self.assertIn(
            "shorebird patch ios --release-version=${{ inputs.RELEASE_VERSION }} --track=staging",
            self.contents,
        )
        self.assertNotIn("--track=stable", self.contents)
        # Per command, not whole-file: the release commands also carry these
        # flags, so a substring search over the file passes even when a patch
        # command is missing one. Shipping only --private-key-path is what
        # made every patch build die with "Both public and private keys must
        # be provided."
        commands = self._shorebird_patch_commands()
        self.assertEqual(2, len(commands))
        for command in commands:
            self.assertIn("--public-key-path=build/shorebird/patch_public_key.pem", command)
            self.assertIn("--private-key-path=build/shorebird/patch_private_key.pem", command)

    def test_patch_workflows_materialize_both_signing_keys(self) -> None:
        # A key path on the command line is inert unless some step wrote the
        # file it names.
        for workflow in ("ios-patch", "android-patch"):
            block = self._workflow_block(workflow)
            self.assertIn("*write_shorebird_public_key", block)
            self.assertIn("*write_shorebird_private_key", block)

    def test_shorebird_patch_workflows_use_private_provenance(self) -> None:
        self.assertIn('if [ "$CM_BRANCH" != "main" ]; then', self.contents)
        self.assertIn("PATCH_BRANCH:", self._workflow_block("ios-patch"))
        self.assertIn("PATCH_BRANCH:", self._workflow_block("android-patch"))
        self.assertIn("shorebird-patch/ios/<RELEASE_VERSION>", self.contents)
        self.assertIn("shorebird-patch/android/<RELEASE_VERSION>", self.contents)
        self.assertIn("RELEASE_COMMIT:", self.contents)
        self.assertIn("*fetch_and_verify_shorebird_provenance", self.contents)
        self.assertIn("shorebird_provenance_store.sh fetch", self.contents)
        self.assertIn("shorebird_provenance.rb verify", self.contents)
        self.assertIn("cp scripts/shorebird_patch_source.rb", self.contents)
        self.assertIn("--identity-only", self.contents)
        self.assertIn('git checkout --detach "refs/remotes/origin/${{ inputs.PATCH_BRANCH }}"', self.contents)
        self.assertIn("*prepare_patch_source", self.contents)

    def test_prepare_patch_source_fails_closed(self) -> None:
        # Codemagic does not abort a multi-line script when a command fails, so
        # the step must set -e: a rejected identity check or a failed
        # fetch/checkout must never leave the build validating and patching the
        # main checkout it started on.
        start = self.contents.index("- &prepare_patch_source")
        end = self.contents.index("- &", start + 1)
        step = self.contents[start:end]
        self.assertIn("script: |\n        set -euo pipefail\n", step)

    def test_prepare_patch_source_fetches_main_ref_deterministically(self) -> None:
        # The validator rejects patch sources that contain commits already on
        # main; that check needs refs/remotes/origin/main to exist at
        # validation time, so the step fetches it explicitly rather than
        # relying on the provenance step's opportunistic ref update.
        start = self.contents.index("- &prepare_patch_source")
        end = self.contents.index("- &", start + 1)
        step = self.contents[start:end]
        self.assertIn('"refs/heads/main:refs/remotes/origin/main"', step)

    def test_shorebird_workflows_define_every_variable_their_scripts_read(self) -> None:
        resolved = self._resolved_config()

        for name in ("ios-build", "android-build", "ios-patch", "android-patch"):
            workflow = resolved["workflows"][name]
            declared = set(workflow["environment"].get("vars") or {})
            scripts = "\n".join(
                step.get("script", "") for step in workflow["scripts"] if isinstance(step, dict)
            )
            # Every provenance step runs under `set -u`, so a workflow-local
            # variable its scripts read but never declare aborts the build.
            for variable in ("FLUTTER_VERSION", "SHOREBIRD_PLATFORM"):
                if re.search(rf"\${{?{variable}}}?\b", scripts):
                    self.assertIn(variable, declared, f"{name} reads ${variable} without declaring it")

    def test_store_release_workflows_require_main_and_emit_provenance(self) -> None:
        for workflow_name in ("ios-build", "android-build"):
            workflow = self._workflow_block(workflow_name)
            self.assertIn("- *verify_shorebird_release_source", workflow)
            self.assertIn("- *emit_shorebird_provenance", workflow)
        self.assertIn("shorebird_provenance_store.sh create", self.contents)
        self.assertIn("refusing to overwrite it", self.provenance_store_contents.lower())

    def test_existing_ios_release_has_verified_main_tree_equivalence(self) -> None:
        baseline_commit = "2504f4d871a9c1790e3e39f8398027bdc5105d04"
        expected_tree = "a17e0660a782e439c5d405c2d06dd49e5b7fbc81"
        repo_root = CODEMAGIC_PATH.parent

        result = subprocess.run(
            ["git", "rev-parse", f"{baseline_commit}^{{tree}}"],
            cwd=repo_root,
            check=True,
            text=True,
            capture_output=True,
        )
        self.assertEqual(expected_tree, result.stdout.strip())

    def test_ci_config_job_fetches_history_for_release_tree_verification(self) -> None:
        job_start = self.mobile_ci_contents.index("  ci-config-tests:")
        next_job = self.mobile_ci_contents.index("\n  generated-files:", job_start)
        job = self.mobile_ci_contents[job_start:next_job]

        self.assertIn("fetch-depth: 0", job)

    def test_caption_generator_names_missing_flutter_embedding_jar(self) -> None:
        self.assertIn("if (!flutterDebugEmbeddingJar.isFile)", self.caption_generator_gradle_contents)
        self.assertIn("Flutter debug embedding JAR not found at", self.caption_generator_gradle_contents)
        self.assertIn("flutterDebugEmbeddingJar.absolutePath", self.caption_generator_gradle_contents)

    def test_shorebird_patch_workflows_block_native_asset_and_dependency_changes(self) -> None:
        self.assertIn("BLOCKED_ROOTS = %w[android assets ios linux macos scripts shaders web windows]", self.patch_source_contents)
        self.assertIn("pubspec.yaml pubspec.lock shorebird.yaml", self.patch_source_contents)
        self.assertIn("android|assets|shaders|darwin|ios|linux|macos|windows", self.patch_source_contents)
        # overrides/ is a live dependency_overrides path root carrying Kotlin,
        # Swift and podspec sources, so it needs the same blocked surfaces
        # as packages/.
        self.assertIn("(?:packages|overrides)/", self.patch_source_contents)
        self.assertIn("BLOCKED_ROOT_SCRIPT", self.patch_source_contents)
        self.assertIn("cut a normal store release instead of a Shorebird patch", self.patch_source_contents)
        self.assertIn("no Dart changes found", self.patch_source_contents)
        self.assertIn("patch source contains merge commits", self.patch_source_contents)
        for command in self._shorebird_patch_commands():
            self.assertNotRegex(command, r"--allow-native-diffs|--allow-asset-diffs")

    def test_store_artifacts_are_built_by_shorebird_release(self) -> None:
        self.assertIn("*build_aab", self._workflow_block("android-build"))
        self.assertIn("*build_ios", self._workflow_block("ios-build"))
        self.assertRegex(self.contents, r"(?m)^\s+shorebird release android ")
        self.assertRegex(self.contents, r"(?m)^\s+shorebird release ios ")
        self.assertNotRegex(self.contents, r"(?m)^\s+flutter build appbundle ")
        self.assertNotRegex(self.contents, r"(?m)^\s+flutter build ipa ")

    def test_ios_release_uploads_without_automatic_review_submission(self) -> None:
        workflow = self._workflow_block("ios-build")

        self.assertIn("app_store_connect:", workflow)
        self.assertIn("submit_to_testflight: false", workflow)
        self.assertIn("submit_to_app_store: false", workflow)

        self.assertRegex(
            self.shorebird_doc_contents,
            r"automatic internal TestFlight\s+distribution",
        )
        self.assertRegex(
            self.shorebird_doc_contents,
            r"manual external TestFlight promotion",
        )
        self.assertRegex(
            self.shorebird_doc_contents,
            r"manual\s+App Store promotion",
        )

    def test_release_jobs_never_materialize_patch_private_key(self) -> None:
        self.assertIn("*write_shorebird_public_key", self._workflow_block("ios-build"))
        self.assertIn("*write_shorebird_public_key", self._workflow_block("android-build"))
        self.assertNotIn("*write_shorebird_private_key", self._workflow_block("ios-build"))
        self.assertNotIn("*write_shorebird_private_key", self._workflow_block("android-build"))

    def test_shorebird_cache_is_enabled_for_release_and_patch_workflows(self) -> None:
        for workflow in ("ios-build", "android-build", "ios-patch", "android-patch"):
            self.assertIn("- $HOME/.shorebird", self._workflow_block(workflow))

    def test_android_shorebird_builds_precache_android_engine_artifacts(self) -> None:
        # Shorebird's bundled Flutter precaches only host artifacts, and
        # shorebird_install rm -rf's ~/.shorebird on any pin change, so every
        # Shorebird Android build has to precache. Without it the Gradle build
        # dies on a missing flutter.jar (#7987).
        # Scoped to the definition, not the whole file: a whole-file search
        # passes on any occurrence anywhere, which is how the missing patch-key
        # wiring survived until #7936.
        definition = self._definition_block(
            "precache_shorebird_android_artifacts"
        )

        # The revision is parsed from the CLI rather than hardcoded, so it
        # cannot drift from EXPECTED_SHOREBIRD_REVISION.
        self.assertIn("FLUTTER_REVISION=$(shorebird --version", definition)
        self.assertNotRegex(
            definition,
            r"FLUTTER_REVISION=[\"']?[0-9a-f]{40}",
            "the Flutter revision must be derived, never a second hardcoded pin",
        )

        # The parsed revision has to reach a real executable path, and that
        # executable is what must run precache. Asserting the invocation is the
        # point: replacing this line with a no-op is the mutation that has to
        # turn this test red.
        self.assertIn(
            'SHOREBIRD_FLUTTER="$HOME/.shorebird/bin/cache/flutter/'
            '$FLUTTER_REVISION/bin/flutter"',
            definition,
        )
        self.assertIn('"$SHOREBIRD_FLUTTER" precache --android', definition)

        # A missing revision or binary must fail loudly, or Gradle reports the
        # original confusing "flutter.jar not found" instead.
        self.assertIn('if [ -z "$FLUTTER_REVISION" ]; then', definition)
        self.assertIn('if [ ! -x "$SHOREBIRD_FLUTTER" ]; then', definition)
        self.assertEqual(2, definition.count("exit 1"))

        # Ordering both ways: the CLI has to exist before its Flutter can be
        # precached, and the precache has to happen before the build that needs
        # the artifacts.
        for workflow_name, build_step in (
            ("android-build", "- *build_aab"),
            ("android-patch", "- *patch_android"),
        ):
            workflow = self._workflow_block(workflow_name)
            install_at = workflow.index("- *shorebird_install")
            precache_at = workflow.index(
                "- *precache_shorebird_android_artifacts"
            )
            self.assertLess(
                install_at,
                precache_at,
                f"{workflow_name} must install Shorebird before precaching it",
            )
            self.assertLess(
                precache_at,
                workflow.index(build_step),
                f"{workflow_name} must precache before {build_step}",
            )

        # The e2e workflow builds with Codemagic's own Flutter, not
        # Shorebird's, so it neither needs nor should pay for the download.
        self.assertNotIn(
            "- *precache_shorebird_android_artifacts",
            self._workflow_block("e2e-smoke-android"),
        )

    def test_shorebird_install_runs_before_ios_dependency_resolution(self) -> None:
        for workflow_name in ("ios-build", "ios-patch"):
            workflow = self._workflow_block(workflow_name)
            self.assertLess(
                workflow.index("- *shorebird_install"),
                workflow.index("- *prepare_ios_spm_packages"),
            )
        for workflow_name in ("android-build", "android-patch"):
            workflow = self._workflow_block(workflow_name)
            self.assertLess(
                workflow.index("- *shorebird_install"),
                workflow.index("- *setup_local_properties"),
            )

    def test_shorebird_release_preflight_runs_before_store_build(self) -> None:
        for workflow_name, preflight, build in (
            ("ios-build", "- *preflight_shorebird_ios_release", "- *build_ios"),
            ("android-build", "- *preflight_shorebird_android_release", "- *build_aab"),
        ):
            workflow = self._workflow_block(workflow_name)
            self.assertLess(workflow.index(preflight), workflow.index(build))

    def test_shorebird_release_builds_fail_on_missing_preflight_output(self) -> None:
        for anchor in ("build_aab", "build_ios"):
            self.assertRegex(
                self.contents,
                rf"(?s)&{anchor}.*?script: \|\n\s+set -euo pipefail\n",
            )

    def test_runbook_uses_current_patch_promotion_and_reporting(self) -> None:
        set_track = (
            "shorebird patches set-track --release <version> --patch <n> "
            "--track stable"
        )
        self.assertIn(set_track, self.shorebird_doc_contents)
        self.assertLess(
            self.shorebird_doc_contents.index(set_track),
            self.shorebird_doc_contents.index("shorebird patches promote"),
        )
        self.assertIn("`shorebird_code_push` is a runtime dependency", self.shorebird_doc_contents)
        self.assertIn("Crashlytics", self.shorebird_doc_contents)

    def _definition_block(self, anchor_name: str) -> str:
        start = self.contents.index(f"    - &{anchor_name}\n")
        next_definition = re.search(
            r"^    - &", self.contents[start + 1 :], re.MULTILINE
        )
        if next_definition is None:
            return self.contents[start:]
        return self.contents[start : start + 1 + next_definition.start()]

    def _resolved_config(self) -> dict[str, object]:
        return json.loads(
            subprocess.run(
                [
                    "ruby",
                    "-ryaml",
                    "-rjson",
                    "-e",
                    "print JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))",
                    str(CODEMAGIC_PATH),
                ],
                check=True,
                text=True,
                capture_output=True,
            ).stdout
        )

    def _workflow_block(self, workflow_name: str) -> str:
        start = self.contents.index(f"  {workflow_name}:")
        next_workflow = re.search(r"^  [a-z0-9-]+:", self.contents[start + 1 :], re.MULTILINE)
        if next_workflow is None:
            return self.contents[start:]
        return self.contents[start : start + 1 + next_workflow.start()]

    def _shorebird_commands(self, subcommand: str) -> list[str]:
        commands = []
        lines = self.contents.splitlines()
        command_pattern = re.compile(rf"^\s+shorebird {re.escape(subcommand)} ")
        for index, line in enumerate(lines):
            if command_pattern.match(line) is None:
                continue
            command_lines = [line]
            cursor = index
            while command_lines[-1].rstrip().endswith("\\"):
                cursor += 1
                command_lines.append(lines[cursor])
            commands.append("\n".join(command_lines))
        return commands

    def _shorebird_patch_commands(self) -> list[str]:
        return self._shorebird_commands("patch")

    def _shorebird_release_commands(self) -> list[str]:
        return self._shorebird_commands("release")


if __name__ == "__main__":
    unittest.main()
