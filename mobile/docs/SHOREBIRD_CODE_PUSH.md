# Shorebird Code Push

Shorebird ships Dart-only fixes to already-released builds over the air. A
patch reaches users on their next app launch without a store submission.

Read this before changing anything in `codemagic.yaml` that touches a store
artifact, and before shipping a patch.

## The one rule that matters

**A build is patchable only if it was produced by `shorebird release`.** That
command links the Shorebird updater into the engine; a plain `flutter build`
does not. If a store-bound artifact is ever built with `flutter build`, that
version is permanently unpatchable — there is no way to fix it after the fact
short of shipping a new store release.

This is why the Play AAB and App Store IPA steps in `codemagic.yaml` call
`shorebird release`. Do not "simplify" them back to `flutter build`.

## What can and cannot be patched

| Change | Patchable |
|---|---|
| Dart code — logic, UI, strings | Yes |
| Native code (Kotlin/Swift, plugins with native parts) | No |
| Assets bundled at build time | No |
| Adding or upgrading a dependency with native code | No |
| Flutter or engine version | No |

Shorebird detects native and asset diffs and **refuses** to build the patch.
That refusal is a correctness guard: a patch that disagrees with the binary it
lands on produces crashes that are extremely hard to diagnose in the field.

`--allow-native-diffs` and `--allow-asset-diffs` override the guard. Do not add
them. If a fix needs native changes, it needs a store release.

## How Divine is set up

The app is `mobile/shorebird.yaml` → `app_id`, owned by the **Divine**
organization in Shorebird (not an individual's account).

### Privacy disclosure

Shorebird checks for patches when the app launches. The request includes a
random identifier unique to that app installation, the app, release, and patch
versions, update channel, platform, and device architecture. Shorebird also
records patch download, installation, and failure status. This information is
used to deliver updates, diagnose update failures, and produce aggregated
update and active-install analytics. The installation identifier is not an
advertising identifier and is not used for advertising or cross-app tracking.

Keep the public privacy policy and store disclosures aligned with this
behavior. In App Store Connect, disclose Device ID, Product Interaction, and
Other Diagnostic Data for App Functionality and Analytics, without tracking.
Mark them as not linked only while neither Divine nor Shorebird joins the
installation identifier to Divine account data. In Google Play, disclose Device
or other IDs, App interactions, and Diagnostics as required collection for App
functionality and Analytics. Mark the Google Play data as not shared only while
Shorebird is contractually acting as Divine's service provider or processor.
Do not finalize that answer until the DPA is executed and the privacy review
confirms that its terms cover data relating to every intended user, including
minor users.

| Artifact | Built by | Patchable |
|---|---|---|
| Play AAB | `shorebird release android` (Shorebird Flutter fork) | Yes |
| App Store IPA | `shorebird release ios` (Shorebird Flutter fork) | Yes |
| Zapstore / GitHub per-ABI APKs | `flutter build apk --split-per-abi` (stock Flutter engine) | **No** — deliberate |
| macOS DMG | `flutter build macos` | No — not wired |

The Zapstore APKs are an intentional exception: Shorebird has no
`--split-per-abi`, and its universal APK would inflate the download for every
sideload user. Those installs cannot receive patches. Play and App Store
installs can.

Because the Play AAB and direct-download APKs use different Flutter engines,
engine-specific behavior can differ even when both artifacts come from the same
Codemagic run. Their build numbers can differ too: the APK uses
`PROJECT_BUILD_NUMBER`, while the AAB uses the higher of that value and the next
available Play build number.

Shorebird's native `auto_update` is disabled because it always checks `stable`
and would race the staged-patch validation relaunch. The app replaces it during
startup, before `runApp`, so a Dart-side failure mid-launch does not strand the
check: ordinary installations check `stable`, while a tester who has
downloaded a staged patch stays subscribed to `staging` until they explicitly
return to stable updates in Developer Options.
`shorebird_code_push` is a runtime dependency. Startup also records patch availability and the current
patch number in logs and Crashlytics custom keys. Use those values when
triaging crashes that may be patch-specific.

### Third-party attribution

`shorebird release` statically links Shorebird's Rust updater into the Flutter
engine. Flutter's license collector does not discover that native dependency:
it assembles `NOTICES` from Flutter, `sky_engine`, and packages in the Dart
package configuration. Divine therefore registers the updater's MIT and
Apache-2.0 license choices from `assets/licenses/` during app startup so both
appear under **Shorebird updater** in Settings → Legal → Open Source Licenses.
The updater is offered under either license at the recipient's option; showing
both documents records the available choices, rather than asserting that both
licenses must be satisfied simultaneously.

The bundled texts were copied from `shorebirdtech/updater` at commit
`1f85c4ab1ee5b540269b9859c75e1bffbb9050c7`, with one trailing newline added
to each local text asset (upstream license blob ids
`6802bc4b80c0f8df1413d55b16267c0969e352c9` and
`a7e77cb28d386ec6eddeaabf441f91473ddefa1e`). The store engine paired with the
current Flutter 3.44.9 pin is `27bc060323bfdfe2f5b6732174d4e499e74eca70`.

When Flutter or Shorebird changes, re-check attribution without producing a
store artifact:

1. Read `bin/internal/engine.version` from the Flutter SDK selected by
   Shorebird.
2. Compare the Shorebird fork's root `LICENSE` and cached
   `bin/cache/pkg/sky_engine/LICENSE` with the corresponding stock Flutter
   files.
3. Search those files for `shorebird` and `updater`, and inspect the fork's
   `flutter_tools` asset collector changes.
4. Compare the immutable upstream updater license blobs above with the current
   updater license files. Update the bundled assets and this provenance only
   when the canonical texts change.

### Flutter version

Shorebird ships its own Flutter, so `FLUTTER_VERSION` in `codemagic.yaml`
duplicates the workflow's `flutter:` setting and is passed to
`shorebird release --flutter-version`. **Keep the two in sync**, and when
bumping Flutter, confirm the target is in `shorebird flutter versions list`
first — Shorebird supports a subset.

The current 3.44.9 pin is deliberate. Shorebird's 3.44.0 engine crashed at
launch in the Dart async FFI path used by `cupertino_http`, so the repo and all
CI workflows moved together to the refreshed 3.44.9 Shorebird engine. Do not
move the pin back independently in one workflow.

Patch commands take no `--flutter-version`. A patch is compiled against
whatever version its release used, which Shorebird resolves from the release.

## Cutting a release

Run `ios-build` or `android-build` in Codemagic as usual. They now produce
Shorebird releases as a side effect of building the store artifact — no extra
step, no change to how you ship.

Before starting a store build, update `mobile/pubspec.yaml` to the intended
marketing version. The iOS preflight reads the latest approved App Store
version and refuses a candidate that is equal or lower before Shorebird builds
or records a release. Increasing only the build number cannot reopen a closed
App Store version train.

iOS publishing deliberately stops after uploading the Shorebird IPA to App
Store Connect (`submit_to_testflight: false`, `submit_to_app_store: false`).
App Store Connect, not Codemagic, provides automatic internal TestFlight
distribution. This depends on configuration outside this repository.

There is exactly one internal tester group: **Divine Internal**. It must have
**Automatic Distribution** enabled, and it must contain no external testers —
adding one turns every build into a Beta App Review submission. Codemagic no
longer names the group, because it stopped assigning beta groups when
publishing became upload-only, so nothing in this repository fails if that
toggle is turned off or the group is renamed. Manage membership in App Store
Connect; the group is recorded here only so the dependency stays reviewable.

Because it is a single group, it is also a single point of failure: if its
Automatic Distribution is off, no internal tester receives any build, and
every Codemagic run still reports success.

A green Codemagic build confirms the IPA upload, not successful App Store
Connect processing or tester distribution. After each iOS build, work through
this before treating internal delivery as complete:

1. Confirm the build finishes processing in App Store Connect and reaches
   **Ready to Test**. Codemagic reports success as soon as the upload lands,
   which is several minutes earlier.
2. Confirm the build was distributed to **Divine Internal**.
3. Confirm an internal tester actually sees it in TestFlight.

A build that uploaded but never reached testers looks identical to a healthy
one from Codemagic alone, which is why this is a checklist rather than a
closing remark.

After internal testing passes, perform a manual external TestFlight promotion
of the same build in App Store Connect: add it to the external groups and submit
it for Beta App Review. After the full external cohort passes, perform a manual
App Store promotion by selecting that exact build for the marketing version and
submitting it for App Store Review. Do not rebuild between those gates; the
binary reviewed for public release must be the Shorebird binary exercised by
both tester cohorts. Android uploads the same Shorebird-enabled release to
Play's internal testing track first. After internal testing passes, promote
that exact Play artifact to broader testing and then production manually; do
not rebuild between gates.

Release commands pass `--public-key-path`, so every new store binary only
accepts signed Shorebird patches. A release built without the public key cannot
be retrofitted later; cut a new store release instead.

After `shorebird release` succeeds, CI writes a create-only record to the
private `divinevideo/divine-release-provenance` repository. It binds the
platform and complete release version to the build commit, source tree, patch
baseline, Flutter version, exact Shorebird CLI revision, and keyed fingerprints
of every dart-define. The record contains no dart-define values. If recording
fails, treat the release build as incomplete and do not patch that release.

## Shipping a patch

Shorebird is an emergency repair path, not a second feature-delivery channel.
Do not freeze `main` after a store release and do not build a patch from the
current `main` tree. Build it from a release-specific patch line rooted at the
immutable provenance baseline instead. That keeps unrelated work merged after
the release out of the production payload.

### Patch eligibility

| Situation | Action |
|---|---|
| Small, understood Dart-only production regression | Shorebird candidate |
| Native, Flutter/engine, plugin-native, or bundled-asset change | Store release |
| Broad refactor, feature, or behavior expansion | Store release |
| Database or persistent-data migration | Store release unless mobile and platform owners explicitly establish backward compatibility |
| Fix needs substantial post-release architecture | Backport a smaller fix or cut a store release |
| Cannot reproduce against the released baseline | Do not patch |
| Cannot validate the exact release plus patch | Do not promote |
| Zapstore APK or macOS build | Not patchable in the current setup |

The preflight deliberately rejects every `pubspec.yaml` and `pubspec.lock`
change even though some pure-Dart dependency changes can be patchable. That is
a conservative operational boundary, not a claim about Shorebird's technical
capability. Cut a store release unless this policy is deliberately revised and
test-backed.

### Prepare the release patch line

1. Confirm the incident meets the eligibility policy and identify the exact
   live release with `shorebird releases list` or the Shorebird console.
1. Reproduce the failure against that release or explain why reproduction is
   impossible. Establish the failing layer before changing code.
1. Land the minimal fix and its regression test on `main` through the normal PR
   process. The release line is a backport destination, never the source of a
   product fix and never something merged back into `main`.
1. Read the private provenance and create the remote branch at its recorded
   `patch_baseline_commit`:

   ```text
   shorebird-patch/<platform>/<release-version>
   ```

   For example, iOS release `1.2.3+456` uses
   `shorebird-patch/ios/1.2.3+456`. Create this operational worktree from the
   recorded baseline, not `origin/main`; this is the sole exception to the
   normal task-worktree rule. The authenticated record lives at
   `releases/<platform>/<release-version>.json` in the private
   `divinevideo/divine-release-provenance` repository. After reading its full
   40-character baseline, create the line explicitly:

   ```bash
   git fetch origin
   git worktree add \
     .worktrees/shorebird-<platform>-<release-version> \
     -b shorebird-patch/<platform>/<release-version> \
     <patch-baseline-commit>
   ```
1. Cherry-pick the already-reviewed `main` fix onto the patch line. Do not add
   cleanup, refactors, features, merge commits, or unrelated generated output.
   If a backport needs adaptation, revise and review the portable fix on `main`
   first, then backport it. Use plain `git cherry-pick <sha>`, never
   `--ff` or a fast-forward merge: those put `main`'s own commit object on the
   line, and the patch-source validator correctly refuses any line containing
   a commit that is already on `main`.
1. If the release already has a patch, start from its existing patch line and
   add the next fix. A Shorebird patch replaces the release's Dart program and
   only one patch is active at a time, so every later patch must retain all
   fixes from the currently active patch. Never recreate a later patch directly
   from the bare release baseline.
1. Push the exact patch branch. Its contents were reviewed through the `main`
   PR; it is not a second product PR and must not be merged to `main`. Keep the
   branch until the release is no longer supported so cumulative patches remain
   reproducible. Repository rules prohibit deletion and non-fast-forward
   updates under `shorebird-patch/**`; never bypass that protection. Before
   pushing, compare the complete patch line and confirm every commit is an
   intentional backport:

   ```bash
   git log --oneline <patch-baseline-commit>..HEAD
   git diff --stat <patch-baseline-commit>..HEAD
   git push -u origin shorebird-patch/<platform>/<release-version>
   ```

   Config trust is shared across git worktrees, so a patch worktree is
   already trusted whenever the main checkout's `mobile/mise.toml` is — the
   normal case, and why this step is usually a no-op. It bites on a machine
   whose main checkout was never trusted (a clone cut fresh for the drill),
   under `paranoid` mode, or on mise older than `2026.7.5`, which predates
   that sharing. Then every `mise exec` step in the hook aborts, and because
   the analyze step sends stderr to `/dev/null` the trust error never reaches
   the terminal: the hook prints a bare `Analysis failed!` with nothing above
   it. Check with `mise trust --show` from the patch worktree's `mobile/`
   directory and run `mise trust` there if it reports `untrusted`. Then run
   `flutter pub get` explicitly and confirm `git status --short` is clean so
   no lockfile churn joins the patch payload — `flutter analyze` would
   resolve dependencies itself, but a `pubspec.lock` change is a blocked path
   and would fail the patch-source validator. The hook also warns that
   `shorebird` is not a semantic branch prefix; that warning is expected on a
   patch line, which never becomes a PR. Never reach for `--no-verify`.

### Build, validate, and promote

1. Start `ios-patch` or `android-patch` manually **from `main`** in Codemagic.
   `main` supplies the current trusted workflow; `PATCH_BRANCH` supplies the
   isolated app source. Use:
   - `CONFIRM_PATCH` = `YES` (defaults to `NO`; the build aborts otherwise)
   - `RELEASE_VERSION` = the exact release string, e.g. `1.0.9+247`
   - `PATCH_BRANCH` = `shorebird-patch/<platform>/<RELEASE_VERSION>`
   - `RELEASE_COMMIT` = optional source assertion; normally leave it empty
   - `DEFAULT_ENV` = **the same value the release was built with**
1. The workflow authenticates provenance and configuration before fetching the
   exact remote patch branch. It then verifies the branch name, release
   ancestry, linear history, that no patch commit is already on main, blocked
   paths, and non-empty Dart diff. It prints
   every included commit and Dart file. The incident owner and a mobile
   reviewer must read that complete output before proceeding; the relevant iOS
   or Android platform owner must approve promotion.
1. The workflow publishes to `staging`, never directly to `stable`. Validate
   the exact release plus staged patch on the affected platform using the
   **Shorebird Patches** section in Settings → Developer Options (see
   [Validating a staged patch](#validating-a-staged-patch) below). Verify the
   regression, adjacent behavior, startup, and the current patch number.
1. Record the incident owner, mobile reviewer, platform owner, release version,
   patch number, validation evidence, and rollback decision in the incident or
   patch issue. Then promote the exact approved patch:

   ```
   shorebird patches set-track --release <version> --patch <n> --track stable
   ```

   `shorebird patches promote --release-version <version> --patch-number <n>`
   is the deprecated legacy shorthand in the pinned CLI. Do not use it in new
   automation. After promotion, tap **Return to stable updates** in Settings →
   Developer Options → **Shorebird Patches**. Do not switch the validation
   device back before promotion: its next launch would check `stable` and could
   roll back the staged patch.
1. Monitor patch installation/failure diagnostics and the original production
   signal after promotion. If the patch regresses behavior, roll it back first
   and investigate second; rollback is emergency recovery, not validation.
1. iOS and Android have independent releases, provenance, patch branches,
   approvals, and patch runs. Never assume success on one proves the other.

The patch workflow fingerprints the regenerated dart-defines with the same
key used by the release and fails before compiling when any key differs. It
prints key names only, never values or mismatched fingerprints. Restore the
release configuration when the intended patch should preserve behavior; cut a
new store release when the configuration change is intentional.

Missing, malformed, overwritten, differently keyed, or explicitly unpatchable
provenance fails closed. Do not recreate a missing record from current values.
Recover it only from trustworthy release-build evidence; otherwise cut a new
store release.

The iOS `1.0.21+849` release predates automatic provenance. Its actual build
commit is `a46851e924b183fa0cb2ce6c6cfaae7ed02cc189`; the equivalent reachable
`main` baseline is `2504f4d871a9c1790e3e39f8398027bdc5105d04`. Both have tree
`a17e0660a782e439c5d405c2d06dd49e5b7fbc81`, which CI verifies. Its private
record is deliberately marked unpatchable because the historical dart-defines
cannot be established from source control.

### Validating a staged patch

An ordinary installed build polls `stable`. A patch published to `staging` is
invisible until a tester explicitly subscribes the installation through
Developer Options; promoting first would defeat the validation gate.

`shorebird preview` cannot close that gap on iOS. It downloads the release
artifact and tries to install it, but our IPA is signed for App Store
distribution: `get-task-allow` is false, `beta-reports-active` is true, and
the profile carries no `ProvisionedDevices`. `ideviceinstaller` rejects it
with `0xe800801f`. That is a property of the artifact we ship, not a
misconfiguration — an installable preview would need a development- or
ad-hoc-signed build, which is a different binary from the one under test.

So the affordance lives in the app. Settings → Developer Options →
**Shorebird Patches** shows the running patch number. Its check and apply
actions call `ShorebirdUpdater` with `UpdateTrack.staging` explicitly:

- **Check staging track** — reports whether a staged patch is waiting.
- **Apply staged patch** — downloads and installs it; relaunch to run it.
- **Return to stable updates** — selects `stable` for the next launch; it does
  not immediately remove the downloaded or running staging patch. Use it only
  after that exact patch is promoted to `stable`, then relaunch so the app can
  check the stable track and reconcile the installed patch.

Install the TestFlight build of the exact release under test, run the patch
workflow, then pull the patch through this section. The build number shown in
Settings must match the release version you patched. The section reports
"Not available in this build" on a plain `flutter run` — the updater
is only linked by `shorebird release`, so a debug build can never validate a
patch.

Promotion to `stable` happens only after this validation succeeds.

### A patch targets a release version, not a channel

TestFlight build `1.0.9+247` and App Store build `1.0.9+247` are the same
Shorebird release. There is no way to patch "just the TestFlight build". If
that version was promoted to the App Store, patching it reaches production
users too once the patch is promoted to `stable`, within about one app launch,
with no store review.

Treat every patch as a production deploy.

### Rollback is recovery, not validation

Shorebird supports patch rollback and on-device rollback from failed patches.
That reduces the worst-case blast radius, but it does not make patching casual:
users can still receive the bad patch before rollback, and rollback does not
replace review, staging validation, signing, or source-diff checks.

## Credentials

CI authenticates with `SHOREBIRD_TOKEN`, held in the `shorebird_credentials`
environment variable group in Codemagic and marked Secret. It is an API key
from the Shorebird console (**Account → API Keys**); `shorebird login:ci` no
longer exists.

The same group holds patch-signing key material:

- `SHOREBIRD_PATCH_PUBLIC_KEY` — public PEM passed to `shorebird release` and
  `shorebird patch`
- `SHOREBIRD_PATCH_PRIVATE_KEY` — secure private PEM passed to `shorebird patch`
- `SHOREBIRD_PROVENANCE_HMAC_KEY` — secure random key for dart-define
  fingerprints
- `SHOREBIRD_PROVENANCE_HMAC_KEY_ID` — non-secret key identifier

Store both patch-signing keys as single-line values with literal `\n` sequences
between PEM lines. CI decodes and validates that envelope before invoking
Shorebird. Release jobs materialize only the public key; patch jobs materialize
both keys.

### The signing key is bound to the release

Shorebird links the public key into the release binary and the installed app
verifies every patch signature against *that* key. Sign a patch with a rotated
private key and the app rejects it — on device, after download, with nothing in
the build log to explain it.

So provenance records `patch_public_key_sha256`, a plain SHA-256 of the
normalized public PEM, and the patch workflow aborts when the key it is about
to sign with is not the key the release was built with:

```
ERROR: patch signing key does not match the key this release was built with
```

The digest is deliberately not the keyed HMAC used for `config_fingerprints` —
the key is public, so a value anyone can recompute is worth more than
concealment. It covers the PEM with surrounding whitespace stripped, so
recompute it as:

```
printf '%s' "$(openssl pkey -pubin -in key.pem)" | shasum -a 256
```

The `$( )` is load-bearing: it drops the trailing newline `openssl` emits, and
`shasum` on the file directly returns a different digest.

When that error appears, restore the release's key pair rather than editing the
record; provenance is create-only.

Releases recorded before this field existed verify with a note on stderr rather
than an abort. Nothing can be checked for them, which is the reason to prefer
patching a release cut under the current scheme.

**Rotating the patch-signing pair strands every release built with the old
one**, exactly as moving the CLI pin does. Rotate immediately after a store
release, never while a shipped release is the only thing standing between
production and a hot fix, and retain the retired pair for as long as any
release signed with it can still be patched.

The `github_credentials` token used by release and patch jobs must have read
and write access to the private `divinevideo/divine-release-provenance`
repository. Provenance writes are create-only. Never delete or replace a record
for a release that may still be patched. The workflow accepts one HMAC key and
identifier at a time. When patching an older release after rotation, temporarily
replace both Codemagic values with that release's retained key pair, run only
the intended patch workflow, then restore the current pair. Do not run a store
release while the older pair is selected. Retain each pair securely until every
release fingerprinted with it is no longer patchable.

The token is currently generated from an individual's account. Moving it to a
Divine service identity is tracked in #7200.

## Local setup

Installing the CLI:

```
EXPECTED_SHOREBIRD_REVISION=45facdd4e4b3c39e0d260107977584f0b7c66bec
git init "$HOME/.shorebird"
git -C "$HOME/.shorebird" remote add origin https://github.com/shorebirdtech/shorebird.git
git -C "$HOME/.shorebird" fetch --depth 1 origin "$EXPECTED_SHOREBIRD_REVISION"
git -C "$HOME/.shorebird" checkout --detach FETCH_HEAD
"$HOME/.shorebird/bin/shorebird" --version
```

CI deliberately does not use the upstream installer because it clones and
immediately runs the mutable `stable` branch. It installs the exact reviewed CLI
revision directly and checks both its git revision and friendly version output
on every cache hit.

To upgrade Shorebird, review a tagged CLI revision, update the 40-character CLI
SHA and expected version together, then run the CI configuration tests. Never
replace the revision pin with a branch or tag.

**Upgrading strands every release recorded under the old pin.** Provenance
records `shorebird_cli_version` and `shorebird_cli_revision`, and the patch
workflow refuses to patch a release whose recorded CLI does not match the
pinned one. Moving the pin therefore makes every existing release permanently
unpatchable — the record is create-only and must not be rewritten to match.
Sequence an upgrade as: merge the pin bump, cut a **new** store release under
the new pin, and patch only releases recorded under it. Never upgrade while a
shipped release is the only thing standing between production and a hot fix.

Then `shorebird login`. You need access to the Divine organization; membership
is managed in the Shorebird console.

`shorebird doctor` from `mobile/` reports one known issue —
`ios/Podfile.lock` is not tracked in source control (`mobile/.gitignore`).
It is worth revisiting, since patches cannot change native code and a release
and its patches should resolve identical pods.

You cannot run `shorebird release android` or `shorebird patch android` on a
machine without a JDK and a complete Android SDK. Android release and patch
builds run on Codemagic, which provisions both. That is also the correct place
for them: a patch should be compiled in the same environment as the release it
targets.

### Known gotchas

**A release build is not idempotent after `shorebird release` succeeds.** If a
later upload or symbol step fails, the store build-number lookup can derive the
same version again, but Shorebird will refuse to create it twice. The preflight
stops that retry before the long build. Delete the failed Shorebird release or
bump the store build number before rerunning; do not bypass the preflight.

**App Store Connect rejects builds for an approved marketing version.** Once
Apple approves a version such as `1.0.20`, its pre-release train is closed and
a higher build number does not reopen it. Bump the version in
`mobile/pubspec.yaml`; the iOS preflight checks this before invoking Shorebird.

**`shorebird init` needs a JDK.** It calls `android/gradlew` directly for
flavor detection, so a machine set up only for iOS work will not have the JDK
that call needs; `mise install` provides one (pinned in `mobile/mise.toml`).
The wrapper itself is tracked as of #7201, so a fresh worktree no longer needs
a `flutter build` first — see
[ANDROID_LOCAL_SETUP.md](ANDROID_LOCAL_SETUP.md).

**The patch-source validator does not exist on older patch lines.** A release
whose baseline predates #7844 has no `mobile/scripts/shorebird_patch_source.rb`
in its tree, which is the design: the patch workflow copies the script from
`main` into `build/shorebird/` *before* checking out the patch branch, so the
rules that gate a patch always come from current trusted `main` rather than
from the release being patched. To dry-run the same checks locally, invoke
`main`'s copy against the patch worktree rather than looking for the script
inside it:

```bash
cd <patch-worktree>/mobile && ruby <main-checkout>/mobile/scripts/shorebird_patch_source.rb \
  --baseline <patch-baseline-commit> \
  --platform <platform> \
  --release-version <release-version> \
  --branch shorebird-patch/<platform>/<release-version>
```

It reads `refs/remotes/origin/main`, so fetch `main` first.

**`shorebird init` invents a `divineuitests` flavor.** Its iOS detection treats
every shared Xcode scheme that is not `Runner` as a product flavor, and picks up
the `DivineUITests` test target. The app has no product flavors — if a re-init
ever writes a `flavors:` block into `shorebird.yaml`, delete it.

## Reference

- [Shorebird docs](https://docs.shorebird.dev)
- [Codemagic integration](https://docs.shorebird.dev/code-push/ci/codemagic/)
- `codemagic.yaml` — release and patch workflows, setup steps in the header
