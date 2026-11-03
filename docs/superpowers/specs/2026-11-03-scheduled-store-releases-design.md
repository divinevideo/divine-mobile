# Scheduled Divine beta builds and store submissions

Status: proposed design, revised 2026-11-03 after review against
`divine-mobile` main at `1bf1e81c57fe62a385ee9f03fee074b63915ed37`. No
schedules or publishing settings are enabled.

## Intent and agreed scope

Rabble asked for TestFlight builds every six hours and daily Google Play and
App Store releases, with version identifiers that keep increasing. He confirmed
that the TestFlight destination is the public external-testing group. CI should
do the routine work. An agent may diagnose failures and propose fixes, but a
reasoning agent should not have to run every release.

The promise is scheduled builds and scheduled submission attempts. Apple and
Google control processing, review, and when a release is actually public. A
failed or pending submission stays visible and is never reported as released.

Turning this on changes release policy as well as tooling. Today a person
decides what reaches production. After this change, anything merged to `main`
that passes CI can reach both stores within about a day, with no person
choosing it. Feature flags, the merge queue, and the livestream hold become
the release gates. Rabble should approve that change explicitly, separately
from the tooling defaults.

## Current implementation

Source inspected at `1bf1e81c57fe62a385ee9f03fee074b63915ed37`:

- `codemagic.yaml` defines manual iOS and Android build workflows, choosing
  the production backend, setting up signing, uploading to the stores, and
  running build-number preflights. Store IPA and AAB files are built with
  `shorebird release`. Preserve its engine integration, signing, runtime
  configuration, and private release provenance.
- `verify_shorebird_release_source` rejects any build where
  `CM_BRANCH != main`, so a store release can always be patched from a baseline
  reachable on main. Codemagic reads the workflow definition from the ref that
  triggered the build.
- Marketing version: both preflights read `version:` from `mobile/pubspec.yaml`
  (currently `1.0.27+820`). No input overrides it.
- iOS build number: the latest App Store Connect build number plus one. The
  step fails closed if the lookup fails. `ios_store_version_preflight.rb`
  rejects a marketing version that is not newer than every released or approved
  App Store version.
- Android build number: the larger of `PROJECT_BUILD_NUMBER` and the latest Play
  version code plus one. **The Play lookup fails open.** `google-play
  get-latest-build-number ... 2>/dev/null || true` drops errors and falls back
  to the Codemagic counter. Android has no equivalent of the iOS
  marketing-version preflight.
- `build_apk` (direct-download APKs) uses `PROJECT_BUILD_NUMBER`, while the Play
  AAB uses the reconciled number. Scheduled builds set `PUBLISH_TO_GITHUB=NO`,
  so those APKs are discarded. They still add build time.
- iOS uploads only (`submit_to_testflight: false`, `submit_to_app_store:
  false`). Android uploads the AAB to Play internal testing.
- `shorebird_provenance_store.sh` writes create-only records to
  `divinevideo/divine-release-provenance`.
- Mobile CI runs on `push` to main, `pull_request`, and `merge_group`. Push runs
  on main use `cancel-in-progress`, so when merges arrive quickly, most main
  SHAs never get a completed push run. The merge-queue run does test the exact
  commit that lands on main.
- The Maestro smoke lane is staging-only and not required. Its webhook is
  inactive (#7504). No automated smoke test runs against a release-configured
  build today.
- `release-notes/README.md` keeps store promotion separate from GitHub Latest
  and Zapstore. `publish_github_release.py` names stable tags and notes files
  after the pubspec marketing version.
- The `AGENTS.md` livestream/LiveKit hold applies to anything this work ships.
- Existing scheduled GitHub workflows in the repo are
  `apple_required_reason_probe`, `coordinator_route_probe`, and
  `mobile_service_integration_tests`. None of them is a release schedule.

## Approaches

1. **Native Codemagic schedules.** This needs the least new infrastructure.
   A timer alone can't pair the two platforms on one source SHA, retry durably,
   promote daily, or reconcile store state. Each reconcile tick would also start
   a build machine.
2. **A GitHub Actions coordinator that calls the existing Codemagic workflows.**
   Decisions run one at a time, the source is selected exactly, and a durable
   release ledger records state. Codemagic still does all signing and
   uploading. The coordinator needs read and promote access to the stores (see
   Credentials).
3. **A persistent release agent.** Useful for investigating failures. It adds
   a runtime and discretionary decisions to routine signing and publication.

The builder recommends option 2, with optional agent diagnosis. This follows
the CI-owned approach discussed with Rabble. The exact coordinator design has
not been approved.

## Candidate source pinning

The Codemagic builds API (`POST /builds`) starts a build from a `branch` or a
`tag`. It has no commit-SHA parameter. Starting from `main` and checking out the
captured SHA afterwards does not work, because the workflow definition would
still come from main HEAD. That breaks configuration identity.

- For each candidate, the coordinator creates a lightweight tag
  `release-candidate/<full-40-hex-sha>` on the captured SHA and starts both
  platform builds from that tag. A tag ruleset restricts the
  `release-candidate/*` namespace to the coordinator's identity and blocks
  updates and deletions. The namespace must not overlap the `<version>` and
  `<version>-beta.*` tags that the GitHub publisher uses.
- Extend `verify_shorebird_release_source` so it accepts either
  `CM_BRANCH == main` (manual builds, unchanged) or a `CM_TAG` that matches
  `^release-candidate/[0-9a-f]{40}$`, where the SHA in the tag name equals
  `git rev-parse HEAD` and is an ancestor of the fetched `origin/main`. That
  keeps the guard's goal, a patch baseline reachable from main.
- Re-verify `HEAD` against the ledger's candidate SHA immediately before
  signing.

## Passing reserved identifiers to Codemagic

The workflows read `${{ inputs.* }}`, but the builds API page documents only
`environment`. Before implementation, confirm whether the API accepts workflow
`inputs`. If it does not, pass `RELEASE_TRAIN_VERSION`,
`RELEASE_TRAIN_BUILD_NUMBER`, and `RELEASE_TRAIN_ID` as environment variables
and add a validation step:

- When the variables are unset, behavior matches today's (pubspec plus store
  lookup), so manual builds keep working.
- When they are set, check the format, require version ≥ pubspec version and
  build number > the live store value, and write them to the existing
  `*_release.env`. Then the preflights, `shorebird release`, and provenance all
  see the same effective values. The override never edits a tracked file.
- Make the Android Play lookup fail closed when the variables are set. Prefer
  failing closed for manual builds too; that is a separate small PR.
- Add an Android marketing-version preflight that matches the iOS one. It
  rejects a `versionName` that is not newer than the highest one in any Play
  track.

## Cadence and eligibility

Proposed defaults, not extra requirements from Rabble:

- Build slots at 00:17, 06:17, 12:17, and 18:17 UTC. Both platforms build from
  one candidate tag.
- **Eligible source:** the newest commit on main whose required checks
  completed successfully, from its merge-group run or a non-cancelled push run.
  Main HEAD is often ineligible because push runs get cancelled; skip back to
  the newest eligible commit rather than waiting. Do not substitute a newer
  commit's result, and never treat a missing, skipped-for-unknown-reason, or
  cancelled required result as a pass.
- **Smoke checks:** v1 eligibility is required CI plus the build-time checks
  already in `ios-build` and `android-build` (signing contract, privacy-manifest
  coverage, analytics product, coordinator route, supporters config), plus the
  tester soak. Maestro becomes a gate only after it meets its own promotion bar
  (at least 30 runs with a pass rate of 95% or better, #7504 fixed) and runs
  against a release-configured build.
- **Skipping unchanged source:** decide whether to build by comparing paths
  that affect the app (`mobile/` excluding docs, `codemagic.yaml`, and the
  pinned toolchain versions) against the last successful candidate for the
  active version. Do not compare commit SHAs. A docs-only merge should not cost
  two Mac builds. A platform that failed may retry on its own.
- A daily production evaluation runs at 23:47 UTC. It selects the newest
  eligible candidate that has had at least six hours of tester availability on
  the platform being promoted, as read back from the store. It never rebuilds
  for production. If nothing qualifies, record "no eligible candidate" for that
  day. Do not lower the bar.
- A reconcile tick every 30 minutes resumes upload, processing, review, and
  promotion work. It runs in GitHub Actions and never starts Codemagic. Late or
  duplicate scheduler runs do nothing new. After an outage, do not replay every
  missed slot.
- Android and iOS promote independently. A pending Apple review does not stop a
  qualified Play candidate, and each channel records its own actual
  availability.
- GitHub scheduling is best effort. Record the requested, started, uploaded,
  submitted, approved, and available times separately.

## One submission in review per channel

There are three review queues: TestFlight beta review, App Store review, and
Play production review. The coordinator never submits to a queue while its
previous submission there is still waiting for a decision. This is our rule
and is stricter than what the stores allow. Apple, for example, would accept a
new version's build into beta review while an older version's build is still
pending.

- A submission is waiting until it reaches a final store state. On Apple that
  is approved or ready for distribution, rejected, or withdrawn by the
  developer. On Play it is published or rejected. Read the state from the
  store on every tick. Do not infer it from elapsed time or from the ledger.
- Uploading is not submitting. Play internal-testing uploads go to testers
  without review, so Android beta builds keep their normal schedule.
- While an iOS beta review is waiting, keep at most one uploaded iOS build that
  hasn't been submitted, and skip further iOS build slots. Once the review
  clears, submit that queued build. Builds that were never submitted are
  recorded as superseded, not as failures.
- Production works the same way. If the previous App Store or Play production
  submission is still waiting at 23:47 UTC, record "waiting on previous review"
  for that platform and day, and evaluate again at the next daily evaluation.
  Production cadence is therefore set by review latency.
- Never cancel or withdraw a waiting submission to make room for a newer one.
- Default chosen by the builder: a rejection keeps that queue closed until an
  operator acknowledges it. A rejection usually applies to the next build too,
  so the coordinator does not automatically submit the next candidate.
- The three queues are independent. A waiting App Store review does not block
  TestFlight submissions for the next version, and neither Apple queue blocks
  Play.

## Version allocation and durable state

Keep a separate release-train ledger in the private provenance repository. Never
change the existing create-only Shorebird records. Ledger updates use
compare-and-swap against the stored Git object SHA, on top of the coordinator's
`concurrency` group. Never store credentials or signed download URLs there.

**Version namespace ownership — decision required.** Daily store trains move
the marketing version ahead of `pubspec.yaml` (1.0.27 today) within days. If
nothing else changes, the next manual GitHub or Zapstore production release
built from pubspec would reuse a version string that the stores already shipped
from different source, and the release-notes file name would point at the wrong
build. Recommended: the allocator owns marketing versions for every channel.

- Pubspec acts as a floor. Raise it with a normal PR when needed (major or minor
  bumps).
- `publish_github_release.py` stable publication and `--promote-from` take the
  effective version from the candidate's ledger and provenance record, not from
  pubspec.
- Store notes come from the ledger. Files under `release-notes/` stay
  hand-written for direct-distribution releases.
- Check every client-side consumer of the package version (`app_version_client`,
  the GitHub-Latest update prompt) against store versions running ahead of
  GitHub Latest.

Allocation:

- Allocate a numeric marketing version for each daily train by incrementing the
  patch component past the highest version seen or reserved. Before allocating,
  read both stores (every Play track, every App Store version), existing trains,
  the source pubspec, and ledger reservations. If any lookup is unavailable,
  fail closed.
- Retries reuse the day's reservation. A released version is never reused. If an
  out-of-band release takes the reserved version, close that train to new builds
  and reserve the next valid version.
- Open the next train as soon as the daily production cut is made, so the first
  build of the new version can enter TestFlight review as soon as the beta
  review queue is free.
- Beta builds within a train increment their platform build identifiers. Build
  identifiers must exceed both the store's value and earlier ledger
  reservations, including in-flight and manual Codemagic builds. Manual release
  builds either go through the same allocator or are rejected before signing if
  they overlap.
- Before building again, match existing uploads to ledger entries by identity.
  An ambiguous upload must never cause a different binary to be substituted
  under that release identity.

Record the source SHA, candidate tag, effective version, platform, configuration
identity (workflow file blob SHA, Flutter/Xcode/Shorebird versions), Codemagic
build ID, store build ID or version code, artifact digests, CI evidence (the run
IDs that made the commit eligible), release-note text and digest, timestamps,
and phase transitions. Also record which Shorebird release versions reach
production, so patch tooling targets builds users actually have.

## Public TestFlight and Play internal testing

Look up the existing public TestFlight group in App Store Connect and store its
stable ID in configuration. Do not create a second group or change the
public-link audience. Check that the group is external, still has its public
link, and contains the exact uploaded build. Keep earlier builds available.

Apple constraints (as of 2026-11-03, from the "Invite external testers" page):

- "You can submit up to six builds for TestFlight App Review within a 24-hour
  period." The one-waiting-submission rule keeps the coordinator well below
  this limit. Manual submissions still count against it, so read the remaining
  budget before submitting.
- "You can only have one build of each version in review at a time." The
  coordinator's own rule is stricter and covers every version (see One
  submission in review per channel).
- "The first build you submit requires a full review, but later builds for the
  same version might not." Because the marketing version changes every day,
  every day's first build needs full beta review. The six-hour production soak
  therefore depends on review latency. Expect days with no eligible iOS
  candidate, and report them as such.

Codemagic post-processing can time out even when the upload succeeded. Check
App Store Connect directly before reporting public-beta availability or retrying
a submission. The soak clock starts at the availability observed in the store,
not at upload or build completion. Play internal-testing availability is also
read back from the store.

## Daily production submission

- iOS: submit the eligible existing build for App Store review, set to release
  after approval. Turn phased release off for these versions, or confirm it is
  off. A seven-day phased rollout restarted every day would never complete.
- Android: promote the exact tested version code from internal testing to
  production through `edits.tracks`. Default to a full rollout after review.
  Once a Play release is completed it cannot be halted, only replaced. A staged
  rollout keeps the halt option but leaves part of the user base one release
  behind, since daily releases keep superseding each other. Rabble decides
  which.
- Read the managed-publishing settings on both stores and do not change them
  silently. If they require a separate publish step, include the supported API
  call in the release phase or report the exact console step that remains.
- Never submit a production release while the previous one on that store is
  still waiting for approval, and never cancel a waiting review to keep to the
  schedule. Keep reconciling it and keep building betas (see One submission in
  review per channel).
- A rejected release is reported as a failure. That queue stays closed until an
  operator acknowledges the rejection.
- Store notes use the reviewed generic template: "This update includes the
  latest tested changes to Divine." That avoids inventing claims from commit
  subjects. Reviewed version-specific notes can replace it. An agent may propose
  richer notes and code repairs through normal PR review. It may not merge its
  own fixes or bypass checks. The release cadence does not need an autonomous
  repair executor.

## Credentials and trust boundary

The reconcile and promotion phases run in GitHub Actions, so the coordinator
needs some store access outside Codemagic. Keep that access as narrow as
possible:

- A GitHub Environment `store-release`, restricted to `main` and to `schedule`
  and `workflow_dispatch` triggers, with no `pull_request` path. Pin third-party
  actions by SHA.
- App Store Connect API key with the lowest role that can manage TestFlight
  groups and submit for review. Confirm whether that is App Manager.
- Play service account with release permissions on `co.openvine.app` only.
- Codemagic API token that can only trigger builds.
- GitHub App installation token with `contents: write` on
  `divine-release-provenance`, plus permission to create `release-candidate/*`
  tags in `divine-mobile`.

Signing keys and the Shorebird credentials stay in Codemagic. PR code never
receives publishing credentials. The workflow summary reports phases, status,
and evidence. It sends no Slack or email and does not expose private provenance
or configuration.

## Cost and capacity

Each slot can start two Mac builds capped at 60 minutes each (`mac_mini_m2` for
iOS, `mac_mini_m4` for Android). That is up to 8 Mac builds a day, each also
creating a Shorebird release and a provenance record. Before enabling:

- Estimate monthly Codemagic minutes and cost from recent `ios-build` and
  `android-build` durations, and get the spend approved.
- Check Codemagic concurrency, so scheduled builds don't queue behind, or block,
  manual release builds and the perf lanes.
- Skipping unchanged source and skipping during an outage are the main cost
  controls.

## Controls and verification

- Separate pause switches for beta and production, dry-run planning, manual
  reconcile, candidate exclusion, and a global release hold that the daily
  production evaluation checks. Retries are limited in number and back off.
- Missing auth, metadata, export compliance, agreements, signing, or an unknown
  store state each produce an explicit failure that says what to fix. Never
  change agreements, metadata declarations, permissions, or review answers
  automatically.
- Pausing stops new submissions and distribution actions that the coordinator
  owns. It does not recall a submission already handed to a store for automatic
  release after approval. Read-only reconciliation continues while paused, and
  in-flight submissions are shown prominently. Stopping an already-submitted
  release takes an explicit operator action in the store console. Never claim
  that pausing did this, and never cancel a review automatically. (This pause
  behavior is the builder's choice.)

Test first with fakes: allocation races, one platform succeeding while the other
fails, duplicate ticks, unchanged source (including docs-only merges), failed
and cancelled CI, an eligible commit behind HEAD, manual builds overlapping, an
ambiguous upload, store throttling and the six-per-24h budget, pending and
rejected beta review, first-build full review delaying the soak, post-processing
timeout, pending production review, missing metadata, Play lookup failure (must
fail closed), tag-guard acceptance and rejection, pause/resume, and promoting
the exact artifact. For each of the three review queues, test that a
submission is refused while the previous one is still waiting, that only one
iOS build is queued, that superseded builds are recorded, and that a rejection
keeps the queue closed until an operator acknowledges it.

Then run an authenticated read-only inventory, one controlled public-beta
candidate, and one daily promotion. Read back the actual TestFlight group and
build and the store release state. Configuration tests alone don't prove
anything was delivered.

Keep the existing release source and provenance guards (extended only as
described above) and the livestream hold. Out of scope for this change:
Shorebird OTA patches, feature activation, GitHub Latest, Zapstore publication,
and an always-running repair agent.

## Suggested PR sequence (each mergeable to main on its own)

1. The Android Play lookup fails closed, and an Android marketing-version
   preflight is added. Useful on its own.
2. A validated env override for version and build number in both workflows.
   No-op when unset.
3. The source guard accepts `release-candidate/<sha>` tags (ancestry and SHA
   checks), plus the tag ruleset.
4. The coordinator in dry-run only: ledger, allocator, eligibility, planning
   output.
5. Coordinator beta phase with the pause switch off by default. Then one
   controlled candidate.
6. Production phase with the pause switch off by default. Then one controlled
   promotion.

## Outstanding inventory and approval

Implementation must find, using authenticated access, the real public beta
group, current store versions on every Play track and App Store state, the
managed-publishing and phased-release settings, which credentials are available,
Codemagic concurrency and minute usage, and whether the builds API accepts
`inputs`. Don't ask Rabble for values that the inventory can find. Missing
access must name the exact operation and the grant needed, without asking for
secrets in chat.

Decisions for Rabble:

- Automatic daily production from main with no person choosing the candidate
  (the policy change above).
- Who owns the version namespace: the allocator for every channel (recommended),
  or another scheme.
- UTC cadence and the six-hour beta soak, given that first-build full review
  and the one-waiting-submission rule will cause some iOS days to be skipped.
- Whether a rejection keeps its queue closed until an operator acknowledges it
  (the builder's default).
- Release on approval. Play: full rollout or staged.
- Generic reviewed store notes.
- CI coordination without a persistent repair agent.
- The Codemagic spend estimate.

## Protocol and service references

- https://docs.codemagic.io/yaml-publishing/app-store-connect/
- https://docs.codemagic.io/yaml-running-builds/scheduling/
- https://docs.codemagic.io/rest-api/builds/ (branch or tag only; no commit SHA)
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/
- https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks
