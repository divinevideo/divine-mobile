# Scheduled Divine beta builds and store submissions

Status: approved design, revision 7 (2026-11-07), checked against
`divine-mobile` main at `dbdfe110beb018e27d085cad43b9951753b49027`. Nothing is
enabled. Rabble settled the open decisions on 2026-11-04 and 2026-11-05 (see
Decisions). Google Play is in the first version, and both platforms share one
version allocator.

## Requirements

Rabble, 2026-11-04:

1. Every hour, if pull requests have merged to `main` since the last scheduled
   build, build the app and send it to public TestFlight.
2. Submit to the App Store at most once a day.
3. Never submit while an earlier submission is still waiting for review.
4. Include Google Play in the first version: a daily production release, on
   the same rules as the App Store. Build both platforms' complete path before
   enabling anything.

Still standing from 2026-11-03: version identifiers keep increasing, the
TestFlight destination is the existing public external group, and CI does the
routine work. An agent may diagnose failures and propose fixes through normal
pull requests, but no reasoning agent runs the releases.

This changes release policy as well as tooling. Today a maintainer chooses the
marketing version and the build that goes to review
(`mobile/docs/SHOREBIRD_CODE_PUSH.md`, "Cutting a release", and the
version-train rule from #9061). After this change CI chooses both, and anything
that merges to `main` reaches store review within about a day. The merge queue,
feature flags, and the livestream hold become the release gates. Rabble
explicitly accepted automatic production releases and the occasional escaped
bug in exchange for release speed on 2026-11-04. This policy decision is resolved;
it does not require another approval (see Release validation policy).

## Release validation policy

Rabble confirmed that existing unit and integration tests and agent code review
provide sufficient validation for this release cadence. Production eligibility
requires successful required CI on the exact source, the existing build-time
checks, and the six-hour availability period on the platform being promoted:
public TestFlight for iOS, the internal testing track for Play. Existing code
review and merge protections continue to apply.

The availability period is elapsed exposure, not proof that a tester exercised
every feature. Rabble accepts that tradeoff. No manual QA sign-off, runtime
smoke suite, crash-rate threshold, or minimum tester-session count is required
before automatic submission. Improvements to those tools may be separate work;
they must not become a prerequisite for delivering or enabling this automation.

Build failures, store rejections, unknown store states, and explicit release
holds still follow the controls below. Acceptance of product bug risk does not
authorize canceling a pending review or treating a failed check as successful.

## Revision history

- **Revision 2** (2026-11-03): six-hourly builds for both stores, a private
  ledger with reservations, and a daily evaluation at 23:47 UTC.
- **Revision 3** (2026-11-04): hourly change-driven builds. Public TestFlight
  takes the newest build within Apple's six-a-day beta review cap. The App
  Store gate runs every tick with at most one submission in any 24 hours, and
  state is read from the stores, with observed timestamps in GitHub
  Deployments.
- **Revision 4** (2026-11-04): records Rabble's release-validation policy,
  requires review-preserving Play commits on every publishing path, and makes
  shared version allocation and publisher migration prerequisites for Play.
- **Revision 5** (2026-11-04): Play joins the first version. One shared
  allocator now owns marketing versions and build identifiers for both
  platforms, for manual builds, and for direct distribution. It replaces
  revision 3's iOS-only rule, which derived the version from App Store state,
  and its `RELEASE_TRAIN_VERSION` override. Rabble's decisions are recorded.
- **Revision 6** (2026-11-05): review fixes from hm21 and Daniel Cadenas. A
  build that reached `shorebird release` has spent its number. A refused Play
  upload is retried with the same signed AAB, and new Android builds pause
  behind it. Each internal Android build keeps its full six-hour availability
  period, and missing production claims are repaired. Rabble decided that Play
  rejections are handled by email and the Android kill switch.

- **Revision 7** (2026-11-07): addresses allocator review feedback: separate
  build-number floors from store-upload evidence, skip draft Play claims, and
  make spent-identity retries explicit. The maintainer enabling Android
  production owns rejection-email response; the November 5 policy is unchanged.

## What constrains the design

Checked 2026-11-04:

- **Apple caps public TestFlight.** "You can submit up to six builds for
  TestFlight App Review within a 24-hour period." "You can only have one build
  of each version in review at a time." "The first build you submit requires a
  full review, but later builds for the same version might not."
  ([Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/))
- **`main` changes more often than that.** From 2026-10-22 to 2026-11-03,
  merges landed in 9 to 14 distinct UTC hours on each weekday and 1 to 6 on
  weekend days (`git log --first-parent origin/main`). Hourly public builds
  would need up to 14 beta submissions on a busy day.
- **Internal testers have no cap.** On iOS, every upload reaches the **Divine
  Internal** group through App Store Connect's Automatic Distribution, with no
  review (`SHOREBIRD_CODE_PUSH.md`). On Play, the internal testing track
  reaches up to 100 testers immediately, with no review
  (`mobile/docs/ANDROID_DEPLOYMENT.md`).
- **Every `main` commit was tested as itself.** The "CI workflow rule" ruleset
  requires `Mobile CI` and a merge queue (squash, ALLGREEN, up to five entries)
  with no bypass actors. Each commit on `main` therefore has a `merge_group` run
  of `Mobile CI` on that exact SHA. Push runs on `main` are cancelled in
  progress and can't be relied on.
- **Codemagic builds from a branch or a tag, not a SHA.** The builds API
  documents `environment` overrides, not workflow `inputs`
  ([Builds API](https://docs.codemagic.io/rest-api/builds/)).
- **No store or Codemagic credentials exist in GitHub.** The repository secrets
  are Cloudflare and Zendesk only. The App Store Connect key lives in Codemagic's
  `app_store_connect` integration. The Play service account lives in its
  `google_play_credentials` group.
- **What `ios-build` does today** (`codemagic.yaml`): it refuses any branch
  except `main` and reads the marketing version from `mobile/pubspec.yaml`
  (currently `1.0.28+820`). It rejects a version that isn't newer than every
  taken App Store version (`mobile/scripts/ios_store_version_preflight.rb`) and
  sets the build number to App Store Connect's latest plus one, failing closed.
  It then builds with `shorebird release ios`, writes a create-only provenance
  record, and uploads without submitting (`submit_to_testflight: false`,
  `submit_to_app_store: false`).
- **What `android-build` does today**: it reads the marketing version from
  pubspec. Its build number is the larger of `PROJECT_BUILD_NUMBER` and Play's
  latest plus one, but the Play lookup fails open:
  `google-play get-latest-build-number ... 2>/dev/null || true` drops errors and
  falls back to the Codemagic counter. It has no marketing-version preflight.
  `build_apk` builds the direct-download APKs from pubspec's version name and
  `PROJECT_BUILD_NUMBER`. `build_aab` runs `shorebird release android`.
  Codemagic's `google_play` publisher uploads the AAB to the internal track.
- **Provenance is create-only.** `shorebird_provenance_store.sh` writes
  `releases/<platform>/<version>+<build>.json` to the private
  `divinevideo/divine-release-provenance` repository through the GitHub contents
  API, using the `github_credentials` group. A `PUT` without a blob SHA fails if
  the path exists, which makes each write an atomic claim.
- `ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`, so iOS uploads
  need no export-compliance answer.

## Cadence

A GitHub Actions coordinator ticks every hour at :17 UTC. GitHub schedules are
best effort. A late or dropped tick only delays work, and a later tick never
replays the ticks it missed.

| Step | Happens when | Reaches |
|---|---|---|
| iOS build | App-affecting changes merged since the last iOS candidate, and no `ios-build` is queued or running | Divine Internal, automatically |
| Public TestFlight | The newest processed iOS build isn't public, no beta review is waiting, the last beta submission was at least 4 h ago, and there were fewer than 6 in the trailing 24 h | Public group, after beta review |
| App Store | No App Store submission is waiting or approved but not live, none in the trailing 24 h, and a candidate has had 6 h in public TestFlight | App Store review, released automatically on approval |
| Android build | App-affecting changes merged since the last Android candidate, the last Android build started at least 4 h ago, no `android-build` is queued or running, no upload is deferred, and replacing the current internal build would not interrupt its six-hour availability period | Play internal testing |
| Play production | No Play production promotion in the trailing 24 h, a candidate has had 6 h on the internal track, and Play accepts the commit without cancelling a review in progress | Play review, then full rollout |

Internal iOS testers get every hourly build. Public iOS testers get the newest
build up to six times a day: every four hours on busy days, within the hour on
quiet ones. A build that never goes public is recorded as internal-only, not as
a failure.

Android builds have no public beta stage in this design, and nothing outside
Play's own review gates their production promotion. A four-hour minimum spacing
gives Play internal testers several builds a day for about half the build-slot
time of hourly builds, but only while no production review is pending. During
one, Play refuses internal-track commits as well (see Google Play), so internal
testers get the deferred build only after the review ends. Once an upload is
deferred, the coordinator pauses new Android builds until that upload succeeds
or a person clears the failure. It does not accumulate a backlog of AABs.
`mobile/docs/ANDROID_DEPLOYMENT.md` puts production review at one to seven
days. The interval is configuration. Scheduled Android builds skip
`build_apk`, because they never publish direct downloads.

**App-affecting changes** means anything under `mobile/`, `codemagic.yaml`, or a
root-level script that `codemagic.yaml` runs. It excludes Markdown,
`mobile/docs/`, and test-only directories. Docs-only and test-only merges don't
cost a Mac build. The path list lives beside the coordinator with its own tests.

**Failed builds** are retried once on the next eligible tick. The retry reuses
the candidate's reservation only if the first attempt failed before
`shorebird release` (see Build identifiers). After a second failure for the
same candidate and platform, the coordinator waits for a newer candidate, and
the run summary reports the failure. A completed Android build whose upload is
refused only because a review is pending is deferred publishing, not a failed
build attempt; it does not consume this rebuild retry.

## Source pinning

- The candidate is the newest `main` commit with a successful `merge_group`
  `Mobile CI` run on that SHA. A successful push run that wasn't cancelled also
  counts. A missing, skipped, or cancelled result never counts as a pass, and a
  newer commit's result never stands in for an older one.
- The coordinator creates the lightweight tag
  `release-candidate/<full-40-hex-sha>` and starts builds from that tag, so
  Codemagic reads the workflow definition and the source from the same commit.
  Both platforms build from the same tag when they build the same candidate.
  A tag ruleset limits the `release-candidate/*` namespace to GitHub Actions and
  blocks updates and deletions. The namespace doesn't overlap the `<version>` and
  `<version>-beta.*` tags that the GitHub publisher uses.
- `verify_shorebird_release_source` accepts either `CM_BRANCH == main` (manual
  builds, unchanged) or a `CM_TAG` matching `^release-candidate/[0-9a-f]{40}$`
  whose SHA equals `git rev-parse HEAD` and is an ancestor of the fetched
  `origin/main`. Its goal is unchanged: every Shorebird release has a patch
  baseline reachable from `main`.
- Per platform, the newest candidate that platform has built is the baseline
  for change detection.

## Release identity allocator

One allocator owns new marketing versions and build identifiers for scheduled
and manual store builds and for direct-distribution releases. It runs as a
Codemagic step in `ios-build` and `android-build` before anything is signed,
for manual and scheduled builds alike, so there is one implementation of the
rules. It is a standard-library Python package shared with the coordinator.

### Ledger

The allocator writes to a new `allocations/` tree in the private
`divinevideo/divine-release-provenance` repository. It uses the same
create-only contents-API writes and the same Codemagic credentials as
provenance. The existing `releases/` records stay immutable and untouched.

- `allocations/builds/<platform>/<build-number>.json` reserves an iOS build
  number or an Android `versionCode`. It records the version, source SHA,
  origin (scheduled or manual), reservation key, Codemagic build ID, and time.
  Two builds can't create the same path, so concurrent allocations can't
  collide.
- `allocations/claims/<version>/<channel>.json` records a production channel's
  first use of a marketing version. The channel is `app-store`,
  `play-production`, or `github-stable`. The coordinator writes claims when it
  submits or promotes. Reconciliation writes claims for releases that people
  made by hand.

### Marketing version

The version is the larger of two values:

- the `pubspec.yaml` version at the source. Pubspec remains the floor, and
  people raise it by pull request only for major or minor bumps.
- the next patch after the highest claimed version on any channel.

Before deriving the version, the allocator reconciles. It reads its own store's
production state: App Store versions in any submitted state for iOS, and Play
production `versionCode`s for Android. It also reads GitHub stable tags
(`<version>`). Every production identity it finds must match a claim, an
allocation, or a provenance record. A Play track's release name is not an
authoritative manifest `versionName`, so a production `versionCode` is mapped
to its version through `allocations/builds/android/` or
`releases/android/*+<versionCode>.json`. An unrecorded identity that maps
cleanly is written as a claim. Specifically, every observed production identity
missing its channel's claim gets that claim even if an allocation or provenance
record already exists. This repairs a run interrupted after the store accepted
a submission but before the claim write. One that can't be reconciled fails the
build closed, naming the identity. Reconciliation finishes before allocating a
new version; observing a matching allocation alone never substitutes for the
production claim.

Versions only move forward. Once any channel claims a version, later builds use
the next one, even if that submission is rejected. Builds between claims share
the current train version and differ by build identifier. Each store promotes
its own candidates, so one version can reach the App Store and Play from
different builds of the same train. That already happens with manual releases.
Build identifiers and provenance still pin each artifact to its exact source.

Play reconciliation ignores `draft` releases, even when they carry version
codes; those releases have not been submitted. `completed`, `inProgress` and
`halted` releases keep their version claims. Unknown statuses and an empty
submitted production code set fail closed. iOS claims include pending and
rejected submissions; claims remain permanent.

### Build identifiers

- The reserved number is one more than the larger of the store's latest build
  number and the highest reservation for that platform, raised to the configured
  minimum candidate number if needed. Keep `--build-number-floor` separate from
  `--store-latest-build`: a CI floor is not evidence of an upload. The store
  lookup fails closed on both platforms. On a create conflict the allocator rereads the
  ledger and tries the next number, a bounded number of times.
- The coordinator passes a reservation key
  (`scheduled/<platform>/<candidate-sha>`) to scheduled builds. A retry with the
  same key reuses its reservation, version and number, as long as nothing was
  recorded under that identity: no Shorebird release, no provenance record,
  and no store upload. The Shorebird release preflight refuses a second
  release of the same `<version>+<build>`, and provenance is create-only, so a
  build that failed during or after `shorebird release` has spent its number
  even when nothing reached the store. Its retry reserves a new number under
  the same key. A refused Play upload is the exception: it is retried without
  rebuilding (see Google Play). If the store already has the number, the
  coordinator resumes from that upload rather than triggering a rebuild. If
  the allocator is invoked anyway, that reservation is spent and it reserves
  a new number; it never rebuilds under the uploaded identity. Manual builds use
  `manual/<codemagic-build-id>`, so a manual build running beside a scheduled
  one never shares a number.
- The allocator writes `SHOREBIRD_BUILD_NAME`, `SHOREBIRD_BUILD_NUMBER`, and
  `SHOREBIRD_RELEASE_VERSION` to the existing `*_release.env`. Then the
  preflights, `shorebird release`, provenance, and the GitHub publisher all see
  the same values. Nothing edits a tracked file.

### Validation kept as defense in depth

- iOS: `ios_store_version_preflight.rb` still rejects a version that isn't newer
  than every taken App Store version.
- Android, new: the `versionName` may equal the active train version but must
  not go backwards from the highest production version. Production versions are
  verified through provenance, not release names. Repeated internal builds of
  one version pass, with increasing `versionCode`. Revision 2's "newer than
  every track" rule would have blocked the second build of a version.
- Both platforms keep the Shorebird release preflight.

### Bootstrap

A one-time `bootstrap` command does three things. It reads App Store versions,
every Play track, GitHub stable and beta tags, and the existing provenance
records. It writes claims for the versions already in production. And it lists
anything it can't reconcile, failing closed until a person resolves that.
Allocation stays disabled until the bootstrap succeeds.

### Direct distribution

`publish_github_release.py` and its callers stop reading pubspec. New
publications use the verified effective version from the build's
`*_release.env`, for both the tag name and release-note selection. Historical
`--promote-from` tags retain their original version, source, artifacts, and
note-file mapping. Retries never rewrite them. When an older record lacks an
effective-version field, it is resolved from its existing verified release
identity (the beta tag and its provenance), never guessed from today's pubspec.
`build_apk` passes `--build-name=$SHOREBIRD_BUILD_NAME`, so direct-download APKs
carry the same version name. Their `versionCode` stays `PROJECT_BUILD_NUMBER`,
so update ordering for existing sideloaded installs doesn't change.

Client-side consumers of the package version (`app_version_client`, the GitHub
Latest update prompt, the settings changelog) are checked against store
versions that run ahead of GitHub Latest before production is enabled.

## Public TestFlight

- The public group's ID is configuration, looked up once and never created.
  Each tick checks that the group is external and still has its public link. The
  coordinator never changes the audience.
- For the newest processed (`VALID`) build that is newer than the last public
  build and not yet submitted:
  1. Set What to Test to the user-facing changes since the previous public
     build: subjects of `feat` and `fix` commits that touched app code, within
     Apple's length limit, with a generic fallback.
  2. Submit the build for beta review and add it to the public group.
- **Waiting** means any build whose external state is `WAITING_FOR_BETA_REVIEW`
  or `IN_BETA_REVIEW`. While one is waiting the coordinator submits nothing.
  This is Rabble's rule, and it is stricter than Apple's one-per-version rule.
- **Budget**: count beta submissions in the trailing 24 hours from App Store
  Connect, including manual ones. Submit only if there are fewer than six and
  the most recent was at least four hours ago.
- The first build of each new version needs a full beta review. Public
  testers wait for that review once a day, and then the 4-hour rhythm resumes.
- A beta-review rejection holds public submissions until a person acknowledges
  it (see Controls). Internal builds continue.
- Codemagic can report success before App Store Connect finishes processing. It
  can also report a post-processing timeout after a good upload. The
  coordinator acts only on what App Store Connect reports.

## App Store

The coordinator checks every tick and submits only when all of these hold:

- No iOS review submission is waiting or in review. No App Store version is
  approved but not yet live (`ACCEPTED`, `PENDING_DEVELOPER_RELEASE`,
  `PENDING_APPLE_RELEASE`, `PROCESSING_FOR_DISTRIBUTION`). The coordinator never
  cancels or withdraws a submission to make room for a newer one.
- No App Store submission in the trailing 24 hours. With the waiting rule, the
  actual cadence is set by review latency.
- The latest version is not in `REJECTED`, `METADATA_REJECTED`,
  `INVALID_BINARY`, or `DEVELOPER_REJECTED`, unless a person has acknowledged
  that version.
- A candidate exists: the newest build, with a version above the highest
  version the App Store has claimed, that public testers have had for at least
  six hours. The six hours start when the coordinator first saw the build
  approved in the public group, not at upload. A first build stuck in full beta
  review therefore can't skip the soak. Some days will have no eligible
  candidate, and the summary says so.

To submit, the coordinator does the following:

- Reuse the editable App Store version record if one exists: either
  `PREPARE_FOR_SUBMISSION`, or a rejected record after acknowledgement. Set its
  version string. Otherwise create a record.
- Attach the build. Set the release type to after approval and turn phased
  release off, because a seven-day phased rollout restarted every day would
  never finish.
- Use "This update includes the latest tested changes to Divine." as What's
  New, so no claims are invented from commit subjects. Reviewed
  version-specific notes can replace it later through a normal pull request.
- Submit through the review submissions API, then write the `app-store` claim.
  The next build takes the next version.

Read the store's release settings and never change them silently. If a setting
blocks the flow, stop that queue and name the setting.

## Google Play

Every `edits.commit`, including internal-track uploads, manual publishing,
production promotion, and retries, passes
`changesInReviewBehavior=ERROR_IF_IN_REVIEW`, because the default cancels
changes already in review
([edits.commit](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit)).
Reading review state first does not close the race with a concurrent
submission. Verify that Codemagic's publisher and its pinned CLI pass this
option; if they do not, perform the edit commit through an explicit supported
API path. Treat `CHANGES_ALREADY_IN_REVIEW` as deferred work, preserving the
edit and review rather than retrying with cancellation enabled. Test the case
where a review starts between the status read and commit.

- **Internal uploads** need no review, so they have no Apple-style cap. They
  still perform a guarded edit commit. If Play refuses the commit because
  another review is in progress, the upload is deferred and retried with the
  same AAB. It is never rebuilt: the build has already created the Shorebird
  release and provenance record for its `versionCode`.
  The coordinator owns this retry. The build retains the signed AAB as a
  Codemagic artifact and records its SHA-256 digest and release identity in the
  private ledger after signing, before the first publishing attempt. The
  coordinator records the build ID, artifact identity and versionCode when it
  observes the publishing deferral, before attempting a retry. It uses the
  build-recorded digest, never one derived solely from its first download.
  On a later tick it retrieves those bytes through Codemagic's authenticated
  artifacts API, verifies their digest and release identity, and uploads them
  with its Play service account through a fresh guarded edit. An expired or
  conflicting edit does not require a rebuild. Missing or expired artifact
  storage stops the queue for a person; it never falls back to rebuilding a
  spent identity. Artifact access links and credentials never enter public
  deployment payloads. Retention must cover the pending-review interval, and
  the deferred record survives coordinator restarts.
- **Internal availability.** A new internal release replaces the build offered
  to testers. Do not upload its replacement until the current candidate has
  completed six continuous hours as the offered internal build. The four-hour
  build interval is a minimum, not permission to interrupt that period.
  If a manual upload replaces it sooner, its unfinished period is discarded;
  measure the replacement from when it is first observed. Promotion selects a
  build with a recorded completed period, never one that merely reached six
  hours of age after being superseded.
- **Production promotion** checks every tick and promotes only when all of these
  hold:
  - The Android level is `production`.
  - No Play production promotion in the trailing 24 hours.
  - A candidate exists: the newest internal-track build whose version is above
    the highest Play production version and that has had at least six hours on
    the internal track, measured from when the coordinator first saw it there.

  Promotion moves that exact tested `versionCode` from internal to production
  through `edits.tracks` as a full rollout, with the same generic release notes.
  It never rebuilds. A `CHANGES_ALREADY_IN_REVIEW` refusal is recorded as
  "waiting on previous review" and retried on later ticks. After a successful
  commit the coordinator writes the `play-production` claim.
  Reconciliation records a manual production release's first-observed time in
  its deployment too. Because Play supplies no promotion timestamp, that time
  conservatively starts a new 24-hour wait, rather than treating a manual
  promotion as permission to submit another release immediately.
- **Rejections.** The selected Codemagic `google-play tracks get` / edit-track
  integration does not expose review outcomes, so this version of the
  coordinator cannot detect a Play rejection automatically. Rabble chose
  email-only handling on 2026-11-05 as an explicit limitation, which means the automated rejection
  hold covers Apple's queues only. The maintainer who enables Android
  `production` owns monitoring Play Console's rejection emails and sets
  `RELEASE_TRAIN_ANDROID` to `build` when a rejection arrives, until the
  problem is fixed. They retain that responsibility unless another release
  operator explicitly accepts it; the activation record names that operator.
  Until someone applies the kill switch, the coordinator keeps promoting at
  most one candidate a day, so a missed email means rejected updates are resubmitted
  daily. Any commit error other than changes-in-review still stops the Play
  production queue until a person acknowledges it.
  Google's newer `applications.tracks.releases` API documents review lifecycle
  states. That is a possible replacement for email handling, but it is not
  consumed by this train and is not an assumed automated hold. Adding it
  requires verifying the response, access and rejection transitions before
  changing the selected integration or the accepted policy.
- **Settings.** Read the managed-publishing state and never change it. If it
  holds approved changes for a manual publish step, stop the production queue
  and name the console step that remains.
- **Rollout.** A completed Play release can't be halted, only replaced. A
  staged rollout keeps a halt option but leaves part of the user base one
  release behind, because daily releases keep superseding each other. This
  design uses a full rollout, matching phased release off on iOS.

## State and audit

A workflow `concurrency` group serializes the coordinator. Release identities
live in the allocation ledger. Operational state is read from these sources:

- **Git**: `release-candidate/*` tags record what was built.
- **App Store Connect**: builds, beta review states, group membership, App Store
  versions, and review submissions. It is authoritative for everything Apple
  decides.
- **Google Play**: track contents and edit-commit outcomes.
- **Codemagic**: whether a build is queued or running, and each build's outcome.
- **Allocation ledger**: reservations and claims, as described above.
- **GitHub Deployments**, which the coordinator writes. The environments are
  `ios-testflight-internal`, `ios-testflight-public`, `ios-app-store`,
  `android-play-internal`, and `android-play-production`, with one deployment
  per build and statuses for queued, in review, available, rejected,
  acknowledged, and failed. They record the timestamps the stores don't
  expose, such as when a build was first seen available. The repository's
  Environments page shows the history. The repository is public, so payloads
  hold only versions, build numbers, SHAs, and store IDs.

Provenance records are unchanged and still bind each build to its source.

## Controls

- Each platform has a repository variable:
  - `RELEASE_TRAIN_IOS` takes `off` (the default), `dry-run`, `build`,
    `testflight`, or `app-store`.
  - `RELEASE_TRAIN_ANDROID` takes `off` (the default), `dry-run`, `build`, or
    `production`.

  Each level includes the ones before it. Changing a level needs no pull
  request, so these variables are also the kill switches.
- `workflow_dispatch` runs a tick immediately. It can run as a dry run, or
  acknowledge a rejected build, version, or Play commit failure. The
  acknowledgement is recorded on that item's deployment.
- The run summary lists what the coordinator saw, what it did, and why it
  skipped anything. Version 1 sends no Slack message or email; a failed
  scheduled run sends GitHub's default failure email.
- Missing auth, an unsigned agreement, missing metadata, throttling, or an
  unknown store state stops the affected queue with a message that names the
  fix. The coordinator never edits agreements, metadata declarations,
  permissions, or review answers.
- Setting a level lower stops new submissions only. It can't recall a
  submission already with Apple or Google, which releases after approval.
  Stopping that release takes a person in the store console, and the summary
  never claims otherwise.

## Credentials and trust boundary

A GitHub Environment named `store-release` can be deployed only from `main`, by
`schedule` and `workflow_dispatch` runs, with no `pull_request` path.
Third-party actions are pinned by SHA. The environment holds:

- An App Store Connect API key (issuer ID, key ID, `.p8`) that can read builds
  and versions, manage TestFlight groups, and submit for review. Confirm
  whether App Manager is the lowest role that can. Use a key separate from
  Codemagic's, so that either can be revoked alone.
- A Play service account with release permissions on `co.openvine.app` only,
  separate from Codemagic's.
- A Codemagic API token that can list and start builds and read their retained
  artifacts for deferred-upload retries. Check what else it can
  reach. If it can't be narrowed, it is the broadest secret here.
- A GitHub App installation token with `contents: write` on
  `divine-release-provenance` only, used for claims, deferred-upload records and
  reads of the ledger.

The workflow's own `GITHUB_TOKEN` gets `contents: write` for candidate tags,
plus `deployments: write`, `actions: read`, and `checks: read`.

Signing keys and the Shorebird credentials stay in Codemagic. In-build
allocation uses Codemagic's existing provenance credentials. Pull request code
never receives publishing credentials.

## Cost

Divine is on Codemagic's fixed-price plan (Rabble, 2026-11-04). Scheduled
builds add no per-minute charge. The constraint is concurrency: the plan
includes three concurrent builds ([pricing](https://codemagic.io/pricing/)).

- One `ios-build` takes roughly half an hour on `mac_mini_m2`, capped at 60
  minutes. At the observed merge rate that is about 10 builds per weekday and 3
  per weekend day.
- `android-build` runs on `mac_mini_m4`, at most once every four hours and
  without `build_apk`. That is about 5 builds per weekday.
- Together they hold about one of the three slots through a busy workday.
  Manual builds, the `e2e-smoke-*` lanes, and the perf lanes wait in the queue
  when all three slots are busy; Codemagic queues them rather than failing
  them. The coordinator never starts a workflow that is already queued or
  running, so scheduled builds can't pile up.
- Codemagic lists M4 machines on the fixed plan as "available on request".
  Confirm the plan covers the `mac_mini_m4` that `android-build` uses. If it
  doesn't, Android minutes bill at $0.114 a minute, about $400 a month at this
  cadence.
- Before activation, measure real build durations and queue waits. If manual
  builds start waiting, add concurrency or lower the iOS build cadence. The
  four-hour public TestFlight rhythm doesn't depend on hourly builds.
- The coordinator itself runs on GitHub-hosted runners, which are free for this
  public repository.

## Not in this change

Out of scope:

- Shorebird patches.
- Scheduled publication to GitHub Latest or Zapstore. Manual direct
  distribution keeps working, with effective versions.
- Play open or closed testing tracks.
- An always-running repair agent.
- Notifications.

Runtime smoke tests and crash-rate gates are not prerequisites for this release
automation. Rabble accepted the existing tests and code review as sufficient;
see Release validation policy. Maestro's current limitations do not block it.

## Pull request sequence

Each pull request merges to `main` on its own and keeps manual releases usable.
Merging changes nothing scheduled: both platform levels stay `off`. Activation
starts only after the last step has merged, as Rabble asked.

1. **Fail-closed store lookups.** The Play build-number lookup fails closed,
   just as the iOS lookup already does. This is useful on its own.
2. **Shared allocator and manual-build migration.** Add the ledger, allocation,
   reconciliation, bootstrap, and Android version validation. Both Codemagic
   workflows allocate before signing. Before any build caller uses the allocator,
   add bounded conflict backoff, atomic output writes, and enforcement of one
   active builder per scheduled platform/source key. Reuse intentionally returns
   the same unspent number for that key; create-only writes arbitrate other keys.
3. **Publisher and note-selection migration.** Use effective versions and keep
   historical `--promote-from` compatibility. Add `--build-name` to
   `build_apk`.
4. **Guarded Play publishing.** Every edit commit passes `ERROR_IF_IN_REVIEW`.
   If the Codemagic publisher can't do that, an explicit API path replaces it.
5. **Scheduled candidates.** The source guard accepts `release-candidate/<sha>`
   tags, and the tag ruleset is added.
6. **Coordinator, dry run.** Add `.github/workflows/release_train.yml`. Its
   decisions are pure functions over a snapshot of git, CI, Codemagic, App Store
   Connect, Play, and ledger state, tested with fakes, and it writes the plan to
   the run summary.
7. **Scheduled builds** for both platforms: candidate tags, Codemagic triggers,
   reservation keys, and deployments.
8. **Public TestFlight submission.**
9. **Production:** App Store submission and Play promotion.

Activation, observing each stage before the next:

1. Run the bootstrap from `main` after checking a dry run. The maintainer
   enabling Android production records who owns rejection-email response.
2. Set both levels to `dry-run`.
3. Set `build`, and watch one iOS build reach Divine Internal and one Android
   build reach Play internal testing.
4. Set iOS to `testflight`, and watch one build reach the public group.
5. Set iOS to `app-store` and Android to `production`, and watch one submission
   per store go through review and release.

Cases to test with fakes:

- **Changes and CI**:
  - No app-affecting change, including a docs-only merge.
  - The newest commit lacks a merge-group result, or its CI was cancelled or
    is missing.
- **Builds**:
  - A scheduled or manual build is already running.
  - A build that failed before `shorebird release` is retried once and reuses
    its reservation.
  - A build that failed during or after `shorebird release` is retried under a
    new reservation, never under its spent number.
  - A retry whose number already reached the store fails closed.
- **Allocation**:
  - Concurrent manual and scheduled allocation get distinct numbers.
  - A run stops after the store accepts a submission but before its claim is
    written; reconciliation creates the missing channel claim despite the
    existing allocation, before deriving the next version.
  - Two internal Android builds with the same marketing version and different
    increasing build identifiers, followed by promotion of those exact tested
    bytes.
  - A manual release after iOS has advanced beyond pubspec.
  - An unreconcilable store identity fails closed.
  - The bootstrap succeeds, and the bootstrap reports a conflict.
  - Version derivation, including the pubspec floor and moving forward after a
    rejection.
- **Direct distribution**:
  - A historical beta promotion.
  - A publication retry.
  - Release-note selection uses the effective version.
- **Public TestFlight**:
  - A beta review is waiting.
  - Six submissions were made in 24 hours, or the last submission was under
    four hours ago.
  - The first build of a new version is in full review.
  - Processing isn't finished, or a good upload ended in a post-processing
    timeout.
  - A beta rejection holds the queue until acknowledged.
- **App Store**:
  - A version is waiting, approved but not live, rejected, or acknowledged.
  - A submission was made in the trailing 24 hours.
  - An editable version record is reused.
- **Play**:
  - `CHANGES_ALREADY_IN_REVIEW` on an internal upload and on promotion.
  - A refused internal upload is retried with the same AAB, not rebuilt.
  - A deferred upload prevents new Android builds, survives a coordinator
    restart and does not consume the failed-build retry.
  - The original edit expires; a new guarded edit uploads the retained bytes.
  - A deferred artifact is missing or has a different digest; the queue stops.
  - A review starts between the status read and the commit.
  - Any other commit error stops the queue until acknowledged.
  - Setting `RELEASE_TRAIN_ANDROID` to `build` stops production promotion on
    the next tick. This is the documented response to a Play rejection email.
  - No promotion happened in the trailing 24 hours.
- **Eligibility and soak**:
  - No candidate has soaked, or the soak is measured from observed
    availability.
  - App changes arrive every four hours; an Android candidate remains offered
    for six hours before another internal upload can replace it.
  - A manual internal upload supersedes an Android candidate before six hours;
    the old candidate never becomes eligible merely by getting older.
  - Passing CI and build checks plus the required availability period permit
    submission without a separate runtime-smoke or manual-QA result.
- **Safety**:
  - No submission or review is ever cancelled.
  - Throttling or an unknown store state fails that queue closed.

## Decisions (resolved 2026-11-04 and 2026-11-05)

1. **Cadence.** Build iOS hourly for internal testers, and send the newest
   build to public TestFlight at most every four hours, within Apple's
   six-a-day cap.
2. **Automatic production from `main`,** with no person choosing the build or
   the version. Rabble accepted this release-speed tradeoff and occasional
   escaped bugs. This retires the maintainer-confirms-version rule from #9061;
   do not ask for approval again.
3. **Google Play is in the first version.** Both platforms' complete paths
   merge before anything is enabled.
4. **Spend.** Divine is on the fixed-price Codemagic plan, so the cost is
   build concurrency, not minutes: scheduled builds hold about one of three
   concurrent slots on a busy day. Measure queue waits before activation.
5. **Play rejections (2026-11-05): email plus the kill switch.** The automated
   rejection hold covers Apple only. A Play rejection arrives by email, and
   the maintainer enabling Android production owns monitoring it and setting
   `RELEASE_TRAIN_ANDROID` to `build` until it is fixed, unless another release
   operator explicitly accepts that responsibility. Rabble chose this over
   a per-release confirmation click and over waiting for Play vitals to show users on each release.

These defaults stand unless Rabble changes them:

- Skip docs-only and test-only merges.
- A six-hour availability period before production.
- Release on approval.
- Phased release off, and a full rollout on Play.
- The generic store notes.
- Android builds at most every four hours.
- An Apple rejection holds its queue until someone acknowledges it. A Play
  rejection is handled by email (decision 5).

These need a person with access:

- Create the App Store Connect API key, the Play service account, the Codemagic
  API token, and the provenance GitHub App installation, and add them to the
  `store-release` environment.
- Confirm the fixed-price Codemagic plan covers the `mac_mini_m4` machines that
  `android-build` uses.
- Name the public TestFlight group if there is more than one external group.
- Confirm that Play managed publishing is off, or say how it should be handled.

## References

- https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/
- https://docs.codemagic.io/rest-api/builds/ (branch or tag only; no commit SHA)
- https://docs.codemagic.io/rest-api/artifacts/ (authenticated retained-artifact retrieval)
- https://docs.codemagic.io/yaml-running-builds/scheduling/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/
- https://docs.codemagic.io/yaml-publishing/google-play/
- https://codemagic.io/pricing/
- https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit
- https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks
- https://developers.google.com/android-publisher/api-ref/rest/v3/applications.tracks.releases/list
- https://developers.google.com/android-publisher/api-ref/rest/v3/applications.tracks.releases
