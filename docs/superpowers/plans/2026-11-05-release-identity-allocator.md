# Release Identity Allocator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One allocator owns marketing versions and build numbers for iOS, Android, and direct-distribution builds. It is backed by a create-only ledger, so manual and scheduled builds never collide or go backwards.

**Architecture:**
- A standard-library Python package, `mobile/scripts/release_train/`, holds pure decision logic over normalized inputs and a `LedgerStore` interface.
- A thin CLI, `mobile/scripts/release_identity.py`, connects it to Codemagic's store CLIs and to `gh api`.
- The work ships as three pull requests, each safe to merge alone:
  - **PR A** adds the package and a manual bootstrap workflow. Builds are unchanged.
  - **PR B** makes the GitHub publisher read the build's effective version. This is a no-op until PR C.
  - **PR C** makes builds allocate.

This order splits design step 2 so the publisher is fixed before versions can diverge from pubspec.

**Tech Stack:** Python 3 standard library (`unittest`, `json`, `subprocess`, `base64`, `dataclasses`), bash in `codemagic.yaml`, `gh api`, and codemagic-cli-tools (`app-store-connect`, `google-play`). The existing Ruby preflights are unchanged.

**Spec:** [scheduled store releases, revision 6](https://github.com/divinevideo/divine-mobile/blob/417b9972e730ce5688f87ce40fe9ccbbd6be3228/docs/superpowers/specs/2026-11-03-scheduled-store-releases-design.md) in #10706: "Release identity allocator", "Direct distribution", and "Pull request sequence" steps 2–3. Tracking issue #10709.

## Global Constraints

- **Ledger:** repository `divinevideo/divine-release-provenance`, branch `main`, tree `allocations/`. Never touch `releases/`.
- **Writes:** every ledger write is a create-only contents-API `PUT` without `sha`. The allocator implements no update or delete; the credential itself is not restricted to create-only writes.
- **Version rule:** `version = max(pubspec, next patch after the highest claimed version)`. Versions only move forward.
- **Claim channels:** `app-store`, `play-production`, `github-stable`. GitHub stable tags (`refs/tags/X.Y.Z`) count as `github-stable` claims and are read live, never written.
- **Reservation keys:**
  - `manual/<codemagic-build-id>`.
  - `scheduled/<platform>/<40-hex-sha>`, where the SHA must equal the source SHA.
- **Reuse rule:** a key's latest reservation is reused only if the store's latest build number is below it, no Shorebird release `<version>+<n>` exists, and no `releases/<platform>/<version>+<n>.json` exists. Otherwise reserve a new number under the same key.
- **Identifiers:** App Store Connect app id `6747959501`. Play package `co.openvine.app`.
- **Fail closed:** every store lookup, ledger read, or unreconcilable production identity fails closed with `ERROR: ...` on stdout and exit 1.
- **Platform words:** `ios` and `android`, plus `macos` for the version-only allocation in PR C.
- **Tests:** `python3 -m unittest discover -s .github/scripts/tests` (CI's command). Test files must not use a dotted path with `-m unittest`.

## Review Focus

1. **Two allocations racing for the same build number.** The loser's create returns "exists" and it takes the next number. Pinned in Task 5.
2. **A contents-API `PUT` returns HTTP 409** because another write moved the branch. Retry the same path; never report "exists". Pinned in Task 2.
3. **The ledger tree listing comes back with `truncated: true`.** Fail closed rather than miss reservations. Pinned in Task 2.
4. **A pubspec `version:` without `+build`, or with two components.** `ValueError`, matching the existing preflight regex. Pinned in Task 1.
5. **A Play production `versionCode` with neither an allocation nor a provenance record.** Allocation fails, and the message names the code. Pinned in Task 4.

---

## PR A — allocator package and bootstrap workflow

Branch `feat/release-identity-allocator`. No change to existing workflows' steps.

### Task 1: Versions

**Files:**
- Create: `mobile/scripts/release_train/__init__.py` (empty)
- Create: `mobile/scripts/release_train/versions.py`
- Test: `.github/scripts/tests/test_release_train_versions.py`

**Interfaces:**
- Produces:
  - `Version(NamedTuple)` with `major: int`, `minor: int`, `patch: int`. `str(Version(1, 0, 28)) == "1.0.28"`.
  - `parse_version(text: str) -> Version`. Accepts `^\d+(\.\d+){0,2}$`, pads with zeros, and raises `ValueError` otherwise.
  - `bump_patch(version: Version) -> Version`.
  - `pubspec_version(pubspec_text: str) -> Version`. Uses the multiline regex `^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$` and raises `ValueError` when it is absent.

- [ ] **Step 1:** Write tests with these assertions:
  - `test_parse_pads_missing_components`: `parse_version("1.1") == Version(1, 1, 0)`.
  - `test_parse_rejects_non_numeric`: `"1.0.x"` raises `ValueError`.
  - `test_versions_order_numerically`: `parse_version("1.0.10") > parse_version("1.0.9")`.
  - `test_bump_patch`: `Version(1, 0, 28)` becomes `Version(1, 0, 29)`.
  - `test_pubspec_version_reads_marketing_version`: `"name: openvine\nversion: 1.0.28+820\n"` gives `Version(1, 0, 28)`.
  - `test_pubspec_version_requires_build_suffix`: `"version: 1.0.28\n"` and `"version: 1.0+820\n"` raise `ValueError`.
- [ ] **Step 2:** Run `python3 -m unittest discover -s .github/scripts/tests -p 'test_release_train_versions.py'`. Expect `ModuleNotFoundError: release_train`. Tests add `REPO_ROOT / "mobile" / "scripts"` to `sys.path` at the top.
- [ ] **Step 3:** Implement `versions.py`.
- [ ] **Step 4:** Rerun. Expect OK.
- [ ] **Step 5:** Commit `feat(release): add release-train version parsing`.

### Task 2: Ledger store

**Files:**
- Create: `mobile/scripts/release_train/ledger.py`
- Create: `.github/scripts/tests/release_train_fakes.py` (`MemoryLedgerStore`, test-only)
- Test: `.github/scripts/tests/test_release_train_ledger.py`

**Interfaces:**
- Produces:
  - `LedgerError(RuntimeError)`.
  - `LedgerStore` (a `Protocol`):
    - `paths() -> frozenset[str]` lists every file path on `main`.
    - `read_json(path: str) -> dict` raises `LedgerError` if the path is missing.
    - `create_json(path: str, record: dict, message: str) -> bool` returns `True` if created and `False` if the path already existed. It raises `LedgerError` on anything else.
  - Path helpers:
    - `reservation_path(platform, n) -> "allocations/builds/<platform>/<n>.json"`.
    - `key_path(platform, key, n) -> "allocations/keys/<platform>/<key with "/" replaced by "--">/<n>.json"`.
    - `claim_path(version, channel) -> "allocations/claims/<version>/<channel>.json"`.
    - `provenance_path(platform, version, n) -> "releases/<platform>/<version>+<n>.json"`.
    - `BOOTSTRAP_PATH = "allocations/bootstrap.json"`.
  - `GhLedgerStore(repository: str, branch: str = "main", run=subprocess.run)`. It calls `gh api` only through `run`:
    - `paths()` calls `gh api repos/{repo}/git/trees/{branch}?recursive=1` and raises `LedgerError` if `truncated` is true. The result is cached until the next successful create.
    - `read_json` calls `gh api repos/{repo}/contents/{path}?ref={branch}` and base64-decodes the content.
    - `create_json` calls `gh api --method PUT repos/{repo}/contents/{path} -f message=… -f content=<base64 JSON> -f branch={branch}`:
      - Exit 0 returns `True`.
      - Stderr containing `(HTTP 409)` retries up to 5 times.
      - Stderr containing `(HTTP 422)` re-reads the path: if it exists, return `False`; otherwise raise.
      - Anything else raises `LedgerError`, including stderr.
- `MemoryLedgerStore(files: dict[str, dict] | None)` implements the same protocol in memory and records each create in order (`creates: list[str]`).

- [ ] **Step 1:** Write tests against `GhLedgerStore` with a fake `run` that returns scripted `CompletedProcess` values and records argv:
  - `test_paths_lists_the_recursive_tree`.
  - `test_truncated_tree_fails_closed`: raises `LedgerError`.
  - `test_create_returns_true_on_success`: asserts the `PUT` argv contains `branch=main` and the base64 of the sorted-key JSON.
  - `test_create_returns_false_when_path_exists`: a 422 followed by a successful contents read gives `False`.
  - `test_create_retries_branch_conflict`: two 409 responses then exit 0 give `True`, with three `PUT` calls.
  - `test_create_raises_on_other_errors`: an HTTP 403 raises `LedgerError` naming 403.
  - `test_read_json_decodes_base64_content`.
- [ ] **Step 2:** Run. Expect import failure.
- [ ] **Step 3:** Implement `ledger.py` and `release_train_fakes.py`. Records serialize with `json.dumps(record, sort_keys=True, indent=2) + "\n"`.
- [ ] **Step 4:** Rerun. Expect OK.
- [ ] **Step 5:** Commit `feat(release): add the create-only release ledger store`.

### Task 3: Store-state normalizers

**Files:**
- Create: `mobile/scripts/release_train/store_state.py`
- Test: `.github/scripts/tests/test_release_train_store_state.py`

**Interfaces:**
- Produces:
  - `ios_submitted_versions(app_store_versions: list) -> list[Version]`. It takes the `app-store-connect apps app-store-versions … --json` array and reads `attributes.appVersionState`, falling back to `appStoreState`. It keeps every state except `PREPARE_FOR_SUBMISSION` and `READY_FOR_REVIEW`. An empty array, or an entry without `versionString` or a state, raises `ValueError`.
  - `play_production_version_codes(track: dict) -> list[int]`. It takes the `google-play tracks get --track production --json` Track resource, requires `track == "production"`, and returns the integers from non-draft `releases[].versionCodes[]`, which arrive as ASCII digit strings. Submitted statuses are `completed`, `inProgress`, and `halted`; draft codes are ignored. An unknown/missing status or an empty submitted code set raises `ValueError`.
  - `shorebird_release_versions(payload: dict, platform: str) -> frozenset[str]`. It requires `status == "success"` and returns `data.releases[].version` where `platform_statuses[platform]` is present.
  - `stable_tag_versions(refs: Iterable[str]) -> list[Version]`. It keeps only `refs/tags/<d>.<d>.<d>` exactly, so `-beta.N` and other tags are ignored.

- [ ] **Step 1:** Write tests, one per rule above:
  - `test_ios_keeps_submitted_and_released_states`: includes `WAITING_FOR_REVIEW`, `REJECTED`, `DEVELOPER_REJECTED`, and `READY_FOR_DISTRIBUTION`.
  - `test_ios_drops_unsubmitted_states`.
  - `test_ios_empty_lookup_fails_closed`.
  - `test_play_codes_are_integers_from_every_release`.
  - `test_play_requires_the_production_track`.
  - `test_shorebird_versions_for_platform_only`.
  - `test_shorebird_failure_payload_raises`.
  - `test_stable_tags_ignore_betas_and_other_refs`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Rerun. Expect OK.
- [ ] **Step 5:** Commit `feat(release): normalize store and Shorebird release state`.

### Task 4: Reconciliation and version derivation

**Files:**
- Create: `mobile/scripts/release_train/allocator.py` (first part)
- Test: `.github/scripts/tests/test_release_train_allocator.py`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `AllocationError(RuntimeError)`.
  - `CHANNEL = {"ios": "app-store", "android": "play-production"}`.
  - `claimed_versions(paths: frozenset[str]) -> list[Version]`, parsed from `allocations/claims/<v>/<channel>.json` paths.
  - `reconcile(platform: str, *, ledger: LedgerStore, store_versions: Iterable[Version] = (), store_version_codes: Iterable[int] = (), now: datetime, dry_run: bool = False) -> list[str]`. It returns the claim paths it created. Rules:
    - **iOS:** each version gets `claim_path(v, "app-store")`.
    - **Android:** each code maps to a version through `allocations/builds/android/<code>.json` (its `version` field) or through a `releases/android/<v>+<code>.json` path, then gets `claim_path(v, "play-production")`.
    - **Unmappable codes:** collect them all and raise one `AllocationError` that lists them.
    - **Claim record:** `{"schema": 1, "version", "channel", "platform", "source": "reconciled", "observed_at": now.isoformat()}`. A claim that already exists is left alone.
  - `derive_version(floor: Version, claimed: Iterable[Version]) -> Version`, implementing `max(floor, bump_patch(max(claimed)))` and returning the floor when `claimed` is empty.

- [ ] **Step 1:** Write tests using `MemoryLedgerStore`:
  - `test_ios_reconcile_writes_missing_app_store_claims`.
  - `test_reconcile_repairs_a_claim_missing_beside_an_existing_allocation`: the allocation for `1.0.29` exists but the claim doesn't, so the claim is created. This covers the design's interrupted-submission case.
  - `test_android_reconcile_maps_codes_through_allocations_then_provenance`.
  - `test_unmappable_play_code_fails_closed_naming_it`: code `999` raises an error whose message contains `999`.
  - `test_existing_claims_are_not_rewritten`: `creates` is empty.
  - `test_derive_version_uses_next_patch_after_highest_claim`: floor `1.0.28` with claims `[1.0.27, 1.0.29]` gives `1.0.30`.
  - `test_derive_version_respects_a_higher_pubspec_floor`: floor `1.1.0` with claim `1.0.40` gives `1.1.0`.
  - `test_derive_version_without_claims_is_the_floor`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Rerun. Expect OK.
- [ ] **Step 5:** Commit `feat(release): reconcile store releases into version claims`.

### Task 5: Build-number reservation

**Files:**
- Modify: `mobile/scripts/release_train/allocator.py`
- Test: `.github/scripts/tests/test_release_train_allocator.py`

**Interfaces:**
- Produces:
  - `validate_reservation_key(key: str, platform: str, source_sha: str) -> None`. It accepts `^manual/[A-Za-z0-9]+$` or `^scheduled/<platform>/<source_sha>$` and requires a full lowercase 40-hex source SHA for both forms, raising `AllocationError` otherwise.
  - `reserve_build_number(platform: str, version: Version, *, ledger: LedgerStore, source_sha: str, reservation_key: str, codemagic_build_id: str, store_latest: int, build_floor: int = 0, shorebird_versions: frozenset[str], now: datetime, attempts: int = 20) -> tuple[int, bool]`. It returns `(number, reused)`.

Algorithm. The rules are fixed by the spec; the order matters.

```text
mine = numbers under key_path(platform, key, *) in ledger.paths()
if mine:
    n = max(mine); rec = ledger.read_json(reservation_path(platform, n))
    spent = (store_latest >= n
             or f"{version}+{n}" in shorebird_versions
             or provenance_path(platform, version, n) in ledger.paths())
    require rec["source_sha"] == source_sha and rec["reservation_key"] == key
    if rec["version"] == str(version) and n >= build_floor and not spent:
        return n, True
n = max(store_latest, build_floor - 1, max(reserved numbers for platform, default 0)) + 1
repeat attempts times:
    skip any number already held by a Shorebird release or provenance record
    if ledger.create_json(reservation_path(platform, n), record, msg):
        require ledger.create_json(key_path(platform, key, n), {"schema": 1, "reservation_key": key, "build_number": n}, msg), else fail closed
        return n, False
    n += 1
raise AllocationError("no free build number after <attempts> attempts")
```

The reservation record is `{"schema": 1, "platform", "build_number", "version", "source_sha", "origin": "manual" | "scheduled", "reservation_key", "codemagic_build_id", "reserved_at"}`.

- [ ] **Step 1:** Write tests:
  - `test_first_reservation_is_above_store_and_ledger`: store latest 906 and a reservation at 908 gives 909.
  - `test_racing_reservation_takes_the_next_number`: a `MemoryLedgerStore` subclass creates `909` just before our create, so the result is 910 and the loser never overwrites.
  - `test_retry_reuses_an_unspent_reservation`: returns `(909, True)` with no new creates.
  - `test_retry_after_shorebird_release_reserves_a_new_number`: `1.0.28+909` is in `shorebird_versions`.
  - `test_retry_after_provenance_reserves_a_new_number`.
  - `test_retry_after_store_upload_reserves_a_new_number`: `store_latest` is 909.
  - `test_retry_after_the_train_moved_reserves_a_new_number`: the version differs.
  - `test_manual_builds_never_share_a_number_with_a_scheduled_build`: two keys give distinct numbers.
  - `test_scheduled_key_must_match_the_source_sha`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Rerun. Expect OK.
- [ ] **Step 5:** Commit `feat(release): reserve build numbers in the release ledger`.

### Task 6: Allocate and bootstrap

**Files:**
- Modify: `mobile/scripts/release_train/allocator.py`
- Test: `.github/scripts/tests/test_release_train_allocator.py`

**Interfaces:**
- Produces:
  - `Allocation` (a frozen dataclass) with `platform`, `version: Version`, `build_number: int`, `reservation_key: str`, and `reused: bool`. Its `release_version` property is `f"{version}+{build_number}"`.
  - `allocate(platform, *, ledger, pubspec: Version, source_sha, reservation_key, codemagic_build_id, store_latest: int, build_floor: int = 0, shorebird_versions, stable_tags: list[Version], store_versions=(), store_version_codes=(), now) -> Allocation`. Order:
    1. Require `BOOTSTRAP_PATH` in `ledger.paths()`. Otherwise raise `AllocationError` with the message `the release ledger is not bootstrapped; run the release-identity-bootstrap workflow in Codemagic`.
    2. Run `reconcile`.
    3. Run `derive_version(pubspec, claimed_versions(paths) + stable_tags)`.
    4. Require the version to be newer than the highest observed submitted App Store version (iOS), or at least the highest mapped Play production version (Android), even if a concurrent claim is absent from the listing. Pending/rejected iOS versions remain permanently claimed, although the later store preflight permits reuse of those states.
    5. Run `reserve_build_number`.
  - `bootstrap(*, ledger, ios_store_versions: list[Version], android_version_codes: list[int], now, dry_run: bool) -> list[str]`. It reconciles both platforms and collects every unmappable identity before raising. Unless this is a dry run, it then creates `BOOTSTRAP_PATH` with `{"schema": 1, "bootstrapped_at", "claims": [sorted claim paths]}`. It returns the paths it created or would create. A dry run writes nothing.

- [ ] **Step 1:** Write tests:
  - `test_allocate_refuses_an_unbootstrapped_ledger`.
  - `test_allocate_reconciles_before_deriving`: an unrecorded `1.0.29` in App Store state gives version `1.0.30` and a new claim.
  - `test_allocate_counts_stable_tags_as_claims`.
  - `test_manual_build_after_ios_ran_ahead_of_pubspec_gets_the_train_version`: pubspec `1.0.28` with claims up to `1.0.31` gives `1.0.32`.
  - `test_two_android_internal_builds_share_a_version_with_increasing_codes`.
  - `test_bootstrap_dry_run_writes_nothing`.
  - `test_bootstrap_reports_every_unmappable_identity`.
  - `test_bootstrap_writes_claims_then_the_marker`: `creates[-1] == BOOTSTRAP_PATH`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Rerun. Expect OK.
- [ ] **Step 5:** Commit `feat(release): allocate release identities and bootstrap the ledger`.

### Task 7: CLI

**Files:**
- Create: `mobile/scripts/release_identity.py`
- Test: `.github/scripts/tests/test_release_identity_cli.py`

**Interfaces:**
- Consumes: Tasks 1–6. `--ledger-repository` defaults to `$SHOREBIRD_PROVENANCE_REPOSITORY` or `divinevideo/divine-release-provenance`.
- Produces:
  - **`allocate`:** `python3 scripts/release_identity.py allocate --platform {ios,android} --pubspec PATH --source-sha SHA --reservation-key KEY --codemagic-build-id ID --store-latest-build N --shorebird-releases PATH --stable-tags PATH [--app-store-versions PATH | --play-production-track PATH] --output PATH`.
    - It writes `SHOREBIRD_BUILD_NAME`, `SHOREBIRD_BUILD_NUMBER`, `SHOREBIRD_RELEASE_VERSION`, `RELEASE_TRAIN_RESERVATION_KEY`, and `RELEASE_TRAIN_RESERVATION_REUSED` lines to `--output`.
    - `--stable-tags` is a file with one ref per line.
  - **`bootstrap`:** `python3 scripts/release_identity.py bootstrap --app-store-versions PATH --play-production-track PATH [--dry-run]` prints each created or would-create path.
  - Errors print `ERROR: <message>` to stdout and exit 1. No traceback for `AllocationError`, `LedgerError`, or `ValueError`.
  - `main(argv, *, ledger_factory=GhLedgerStore, now=datetime.now(timezone.utc)) -> int`, so tests inject `MemoryLedgerStore`.

- [ ] **Step 1:** Write tests calling `main([...], ledger_factory=lambda repo: store)` with temp input files:
  - `test_allocate_writes_the_release_env`: exact line set.
  - `test_allocate_fails_closed_with_a_clear_error`: unbootstrapped, exit 1, output starts `ERROR:`.
  - `test_bootstrap_dry_run_prints_paths_without_writing`.
  - `test_script_runs_as_a_file`: `subprocess.run(["python3", script, "--help"])` exits 0, proving the `sys.path` import works when run from `mobile/`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement with `argparse` subcommands.
- [ ] **Step 4:** Rerun. Expect OK.
- [ ] **Step 5:** Commit `feat(release): add the release identity CLI`.

### Task 8: Bootstrap workflow, docs, PR A

**Files:**
- Modify: `codemagic.yaml` (add workflow `release-identity-bootstrap`)
- Modify: `.github/scripts/tests/test_codemagic_shorebird_config.py`
- Modify: `mobile/docs/SHOREBIRD_CODE_PUSH.md` (new "Release identity ledger" subsection)

**Interfaces:**
- Produces the workflow `release-identity-bootstrap`:
  - `mac_mini_m2`, `max_build_duration: 15`, `working_directory: mobile`, and `triggering: events: []`.
  - `integrations: app_store_connect: API key for Codemagic`.
  - Groups `google_play_credentials` and `github_credentials`.
  - Input `DRY_RUN` (choice `YES`/`NO`, default `YES`).
  - One script with `set -euo pipefail` and these fail-closed fetches, each printing its lookup output on error, in the style of the iOS preflight:
    - `app-store-connect apps app-store-versions 6747959501 --platform IOS --json`.
    - `google-play tracks get --package-name co.openvine.app --track production --json`.
  - It then runs `release_identity.py bootstrap`, adding `--dry-run` when `DRY_RUN=YES`.

- [ ] **Step 1:** Write config tests:
  - `test_bootstrap_workflow_is_manual_and_defaults_to_dry_run`.
  - `test_bootstrap_fetches_both_stores_fail_closed`: no `|| true` and no `2>/dev/null` in its script.
  - `test_bootstrap_workflow_defines_every_variable_its_script_reads`: extend the existing variable-coverage test's workflow list.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Add the workflow and the doc subsection. The subsection explains `allocations/`, the create-only rule, and that the bootstrap must run, as a dry run first, before PR C merges.
- [ ] **Step 4:** Run the full suite (`python3 -m unittest discover -s .github/scripts/tests`) and `git diff --check`. Expect OK.
- [ ] **Step 5:** Commit `ci(release): add a manual release-identity bootstrap workflow`. Open PR A with `Relates to #10709`. In `divinevideo/divine-release-provenance`, open a companion README PR documenting `allocations/` (paths, record fields, create-only rule, owner `release_identity.py`).

## PR B — the publisher reads the effective version

Branch `fix/publisher-effective-version`, from `main` after PR A merges. Merging changes nothing, because the release env still carries the pubspec version.

### Task 9: Publisher and APK names

**Files:**
- Modify: `mobile/scripts/publish_github_release.py`
- Modify: `codemagic.yaml` (`publish_github_release`, `build_apk`, artifacts of `ios-build`/`android-build`)
- Test: `.github/scripts/tests/test_publish_github_release.py`, `.github/scripts/tests/test_codemagic_shorebird_config.py`

**Interfaces:**
- Produces:
  - **`--release-env PATH`:** the version comes from `SHOREBIRD_BUILD_NAME` in that file and must match `\d+\.\d+\.\d+`. Without `--release-env`, the publisher falls back to `marketing_version(pubspec)`, which only `macos-build` uses until PR C.
  - **`--promote-from`:** unchanged, because it already takes the version from the beta tag.
  - **`--artifacts-dir` retries:** these require `--release-env`, the original build's env file, which is now kept as an artifact (`build/shorebird/*_release.env`).
  - **`publish_github_release` step:** passes `--release-env "build/shorebird/${SHOREBIRD_PLATFORM}_release.env"` when `SHOREBIRD_PLATFORM` is set.
  - **`build_apk`:** sources `android_release.env` and passes `--build-name=$SHOREBIRD_BUILD_NAME`. Its `--build-number` stays `$PROJECT_BUILD_NUMBER`.

- [ ] **Step 1:** Write tests:
  - `test_release_env_sets_the_published_version_and_notes_file`: env `1.0.31` with pubspec `1.0.28` publishes tag `1.0.31` and selects notes `release-notes/1.0.31.md`.
  - `test_release_env_with_an_invalid_name_errors`.
  - `test_artifacts_dir_retry_requires_release_env`.
  - `test_promote_from_keeps_the_beta_tags_version`.
  - `test_publish_step_passes_the_platform_release_env`.
  - `test_apk_build_uses_the_release_name`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the full suite. Expect OK.
- [ ] **Step 5:** Commit `fix(release): publish GitHub releases under the build's effective version`, then open PR B.

## PR C — builds allocate

Branch `feat/builds-allocate-release-identity`, from `main` after PR B merges **and** after one successful non-dry bootstrap run. State that ordering in the PR description: merging before the bootstrap makes manual builds stop with the bootstrap message.

### Task 10: iOS and Android preflights allocate

**Files:**
- Modify: `codemagic.yaml` (`preflight_shorebird_ios_release`, `preflight_shorebird_android_release`)
- Test: `.github/scripts/tests/test_android_release_preflight.py`, a new `.github/scripts/tests/test_ios_release_preflight.py` (same harness: stub `app-store-connect`, `shorebird`, `gh`, `python3` real), and `test_codemagic_shorebird_config.py`

**Interfaces:**
- Consumes: the Task 7 CLI.
- Produces, in each preflight, in this order:
  1. Read the pubspec.
  2. Run the fail-closed store lookups. iOS keeps its two. Android keeps `get-latest-build-number` and adds `google-play tracks get … --track production --json`.
  3. Run `shorebird releases list --platform=<p> --json > build/shorebird/release_info.json`, moved before allocation.
  4. Run `gh api repos/divinevideo/divine-mobile/git/matching-refs/tags/ --paginate --jq '.[].ref' > build/shorebird/stable_tags.txt`, failing closed.
  5. Run `python3 scripts/release_identity.py allocate … --reservation-key "${RELEASE_TRAIN_RESERVATION_KEY:-manual/$CM_BUILD_ID}" --output build/shorebird/<p>_release.env`.
  6. iOS only: run `ios_store_version_preflight.rb` on `SHOREBIRD_BUILD_NAME`.
  7. Run `shorebird_release_preflight.rb` on `SHOREBIRD_RELEASE_VERSION`.

  This removes the old version and build-number arithmetic from both steps. Pass the observed Play latest build unchanged as `--store-latest-build`, and pass `PROJECT_BUILD_NUMBER` separately as `--build-number-floor`. The floor is a minimum candidate number, not evidence of a store upload; an unspent reservation at the floor remains reusable.

- [ ] **Step 1:** Update the Android harness from PR 1 to stub `gh` (bootstrap marker present, ledger tree) and assert the allocated env. Add the iOS harness. Write tests:
  - `test_allocator_output_feeds_the_shorebird_preflight`.
  - `test_unbootstrapped_ledger_stops_the_build`.
  - `test_production_track_lookup_failure_stops_the_build`.
  - `test_reservation_key_defaults_to_the_codemagic_build`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the full suite. Expect OK.
- [ ] **Step 5:** Commit `feat(release): allocate store build identities before signing`.

### Task 11: macOS version and release docs

**Files:**
- Modify: `mobile/scripts/release_identity.py` (`allocate --platform macos --version-only`: derive and write `SHOREBIRD_BUILD_NAME` only, with no reservation and no store lookup)
- Modify: `codemagic.yaml` (`macos-build` runs it before `build_macos`, and its publish passes `--release-env build/shorebird/macos_release.env`)
- Modify: `mobile/docs/SHOREBIRD_CODE_PUSH.md` ("Cutting a release": the version is allocated and pubspec is the floor; remove "ask a maintainer before changing it" per decision 2) and `docs/RELEASE_CHECKLIST.md`
- Test: `test_release_identity_cli.py`, `test_codemagic_shorebird_config.py`

- [ ] **Step 1:** Write tests:
  - `test_macos_version_only_allocation_writes_no_reservation`.
  - `test_macos_publish_uses_the_allocated_version`.
- [ ] **Step 2:** Run. Expect failures.
- [ ] **Step 3:** Implement, and update the docs.
- [ ] **Step 4:** Run the full suite and `git diff --check`. Expect OK.
- [ ] **Step 5:** Commit `feat(release): give direct macOS releases the train version`, then open PR C.

## Review corrections (2026-11-07)

- Bootstrap writes require `CM_BRANCH=main`; `DRY_RUN=YES` remains available on any branch. Validate both inputs before store lookups. Execute the actual YAML step with stub CLIs to test dry-run argument propagation and independent lookup failures.
- Refuse an empty submitted Play production view. Ignore draft release codes, while retaining completed, staged and halted releases. Claim iOS versions already submitted, including pending and rejected versions; claims never expire.
- Mapping repairs go only in `allocations/builds/android/<code>.json`, never in patch provenance under `releases/`.
- CLI tests must observe both stores affecting versions, the platform-specific Shorebird spent check, and the Codemagic build id. Bind reuse to the recorded source SHA and reservation key; require full lowercase 40-hex source SHAs for manual keys too.
- Keep observed store uploads separate from the minimum build-number floor. A spent reservation gets a new number; the existing identity is never rebuilt. Refuse an iOS version at or below the observed submitted version even if a concurrent claim is absent from the ledger listing. Android retains its strictly-below guard because Play accepts a higher code with the same version name.
- Report only claims and bootstrap markers actually created by this invocation. Fresh reservations skip identities already held by Shorebird or provenance.

Before builds allocate (PR C), complete these explicit prerequisites:

- [ ] Add bounded backoff to branch-conflict retries in `GhLedgerStore.create_json` (current retries are immediate).
- [ ] Write `--output` atomically, and test interrupted/rejected output writes.
- [ ] Enforce a single active build per scheduled platform/source key in the coordinator and all retry entry points. Reuse by the same key intentionally returns the same unspent number; create-only writes arbitrate different keys, not concurrent builders using one key.

Keep these requirements in PR C and coordinator implementation reviews; schedules and existing build callers remain unchanged in PR A.
