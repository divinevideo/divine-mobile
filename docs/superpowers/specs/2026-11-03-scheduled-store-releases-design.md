# Scheduled Divine iOS beta builds and App Store submissions

Status: proposed design, revision 4 (2026-11-04), checked against
`divine-mobile` main at `dbdfe110beb018e27d085cad43b9951753b49027`. Nothing is
enabled. Revision 2 (2026-11-03) planned six-hourly builds for both stores.
This revision follows Rabble's restated requirements and the Codex review of
revision 2.

## Requirements

Rabble, 2026-11-04:

1. Every hour, if pull requests have merged to `main` since the last scheduled
   build, build the app and send it to public TestFlight.
2. Submit to the App Store at most once a day.
3. Never submit while an earlier submission is still waiting for review.

Still standing from 2026-11-03: version identifiers keep increasing, the
TestFlight destination is the existing public external group, and CI does the
routine work. An agent may diagnose failures and propose fixes through normal
pull requests, but no reasoning agent runs the releases.

This changes release policy as well as tooling. Today a maintainer chooses the
marketing version and the build that goes to review
(`mobile/docs/SHOREBIRD_CODE_PUSH.md`, "Cutting a release", and the
version-train rule from #9061). After this change CI chooses both, and anything
that merges to `main` reaches App Store review within about a day. The merge
queue, feature flags, and the livestream hold become the release gates. Rabble
explicitly accepted automatic production releases and the occasional escaped
bug in exchange for release speed on 2026-11-04. This policy decision is resolved;
it does not require another approval (see Release validation policy).

## Release validation policy

Rabble confirmed that existing unit and integration tests and agent code review
provide sufficient validation for this release cadence. Production eligibility
requires successful required CI on the exact source, the existing build-time
checks, and the six-hour public TestFlight availability period. Existing code
review and merge protections continue to apply.

The availability period is elapsed exposure, not proof that a tester exercised
every feature. Rabble accepts that tradeoff. No manual QA sign-off, runtime
smoke suite, crash-rate threshold, or minimum tester-session count is required
before automatic submission. Improvements to those tools may be separate work;
they must not become a prerequisite for delivering or enabling this automation.

Build failures, store rejections, unknown store states, and explicit release
holds still follow the controls below. Acceptance of product bug risk does not
authorize canceling a pending review or treating a failed check as successful.

## Changes from revision 2

- Hourly change-driven builds replace four fixed six-hour slots. Apple's beta
  review cap limits public TestFlight to six submissions a day, so internal
  testers get every build and public testers get the newest one at most every
  four hours.
- iOS ships first. Google Play becomes phase 2 and carries both Codex
  corrections (see Android).
- No private release ledger. State is read from git tags, App Store Connect,
  and Codemagic. The few timestamps Apple doesn't expose go into GitHub
  Deployments.
- The marketing version is derived from App Store state, with `pubspec.yaml`
  as a floor. A serialized coordinator doesn't need version reservations.
- The App Store gate is checked every tick, not once at 23:47 UTC, and allows
  at most one submission in any 24 hours.
- Revision 4 records Rabble's accepted release-validation policy, specifies
  review-preserving Play commits for every publishing path, and makes shared
  version allocation and publisher migration explicit prerequisites for phase 2.

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
- **Internal testers have no cap.** Every upload reaches the **Divine
  Internal** group through App Store Connect's Automatic Distribution, with no
  review (`SHOREBIRD_CODE_PUSH.md`).
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
  `app_store_connect` integration.
- **What `ios-build` does today** (`codemagic.yaml`): it refuses any branch
  except `main` and reads the marketing version from `mobile/pubspec.yaml`
  (currently `1.0.28+820`). It rejects a version that isn't newer than every
  taken App Store version (`mobile/scripts/ios_store_version_preflight.rb`) and
  sets the build number to App Store Connect's latest plus one, failing closed.
  It then builds with `shorebird release ios`, writes a create-only provenance
  record, and uploads without submitting (`submit_to_testflight: false`,
  `submit_to_app_store: false`).
- `ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`, so uploads need no
  export-compliance answer.

## Cadence

A GitHub Actions coordinator ticks every hour at :17 UTC. GitHub schedules are
best effort. A late or dropped tick only delays work, and a later tick never
replays the ticks it missed.

| Step | Happens when | Reaches |
|---|---|---|
| Build | App-affecting changes merged since the last candidate, and no `ios-build` is queued or running | Divine Internal, automatically |
| Public TestFlight | The newest processed build isn't public, no beta review is waiting, the last beta submission was at least 4 h ago, and there were fewer than 6 in the trailing 24 h | Public group, after beta review |
| App Store | No App Store submission is waiting or approved but not live, none in the trailing 24 h, and a candidate has soaked 6 h in public TestFlight | App Store review, released automatically on approval |

Internal testers get every hourly build. Public testers get the newest build
up to six times a day: every four hours on busy days, within the hour on quiet
ones. A build that never goes public is recorded as internal-only, not as a
failure.

A cheaper variant builds only when a public slot is open, so at most six builds
a day. Internal testers then lose the hourly builds. See Decisions.

**App-affecting changes** means anything under `mobile/`, `codemagic.yaml`, or a
root-level script that `codemagic.yaml` runs. It excludes Markdown,
`mobile/docs/`, and test-only directories. Docs-only and test-only merges don't
cost a Mac build. The path list lives beside the coordinator with its own tests.

**Failed builds** are retried once on the next tick. After a second failure for
the same candidate, the coordinator waits for a newer one and the run summary
reports the failure.

## Source pinning

- The candidate is the newest `main` commit with a successful `merge_group`
  `Mobile CI` run on that SHA. A successful push run that wasn't cancelled also
  counts. A missing, skipped, or cancelled result never counts as a pass, and a
  newer commit's result never stands in for an older one.
- The coordinator creates the lightweight tag
  `release-candidate/<full-40-hex-sha>` and starts `ios-build` from that tag, so
  Codemagic reads the workflow definition and the source from the same commit.
  A tag ruleset limits the `release-candidate/*` namespace to GitHub Actions and
  blocks updates and deletions. The namespace doesn't overlap the `<version>` and
  `<version>-beta.*` tags that the GitHub publisher uses.
- `verify_shorebird_release_source` accepts either `CM_BRANCH == main` (manual
  builds, unchanged) or a `CM_TAG` matching `^release-candidate/[0-9a-f]{40}$`
  whose SHA equals `git rev-parse HEAD` and is an ancestor of the fetched
  `origin/main`. Its goal is unchanged: every Shorebird release has a patch
  baseline reachable from `main`.
- The newest `release-candidate/*` tag is the last candidate for change
  detection.

## Versions

- The marketing version of a scheduled build is the larger of two values:
  - the `pubspec.yaml` version at the candidate. This is the floor, and people
    still raise it with a normal pull request for minor or major bumps.
  - the next patch after the highest App Store version ever submitted for
    review, meaning any state except `PREPARE_FOR_SUBMISSION` and
    `READY_FOR_REVIEW`.

  Versions only move forward. Once a version has been submitted, later builds
  use the next one, even if that submission is rejected.
- The coordinator passes the value to `ios-build` as `RELEASE_TRAIN_VERSION`.
  `ios-build` checks the format and that the value is at least the pubspec
  version. The existing preflight also checks that it is newer than every taken
  App Store version. The value is then used for `--build-name` and written to
  `ios_release.env`, so Shorebird and provenance record the same value. When the
  variable is unset, behavior is unchanged and manual builds keep working.
- Build numbers don't change: App Store Connect's latest plus one, failing
  closed. The coordinator never starts an `ios-build` while another one, whether
  scheduled or manual, is queued or running, so two builds can't take the same
  number.
- Between pubspec bumps, the iOS store version runs ahead of `pubspec.yaml`.
  Android, GitHub Latest, and Zapstore keep reading pubspec, so iOS and Android
  version strings will differ until Play joins the train. Scheduled iOS builds
  never publish to GitHub (`PUBLISH_TO_GITHUB=NO`). Before enabling the App Store
  step, check every client-side consumer of the package version
  (`app_version_client`, the GitHub Latest update prompt, the settings
  changelog) against an iOS version that is ahead of GitHub Latest.

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
  submitted one, that public testers have had for at least six hours. The
  six hours start when the coordinator first saw the build approved in the
  public group, not at upload. A first build stuck in full beta review
  therefore can't skip the soak. Some days will have no eligible candidate, and
  the summary says so.

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
- Submit through the review submissions API and record the submission. The next
  build takes the next version automatically.

Read the store's release settings and never change them silently. If a setting
blocks the flow, stop that queue and name the setting.

## State and audit

There is no separate ledger. A workflow `concurrency` group serializes the
coordinator, and it reads its state from these sources:

- **Git**: `release-candidate/*` tags record what was built.
- **App Store Connect**: builds, beta review states, group membership, App Store
  versions, and review submissions. It is authoritative for everything Apple
  decides.
- **Codemagic**: whether an `ios-build` is queued or running, and each build's
  outcome.
- **GitHub Deployments**, which the coordinator writes. The environments are
  `ios-testflight-internal`, `ios-testflight-public`, and `ios-app-store`, with
  one deployment per build and statuses for queued, in review, available,
  rejected, acknowledged, and failed. They record the timestamps App Store
  Connect doesn't expose, such as when a build first became available to
  public testers. The repository's Environments page shows the history. The
  repository is public, so payloads hold only versions, build numbers, SHAs,
  and store IDs.

The existing create-only provenance records are unchanged and still bind each
build to its source.

## Controls

- The repository variable `IOS_RELEASE_TRAIN` takes one of these values: `off`
  (the default), `dry-run`, `build`, `testflight`, or `app-store`. Each level
  includes the ones before it. Changing it needs no pull request, so it is also
  the kill switch.
- `workflow_dispatch` runs a tick immediately. It can run as a dry run, or
  acknowledge a rejected build or version, which is recorded on that item's
  deployment.
- The run summary lists what the coordinator saw, what it did, and why it
  skipped anything. Version 1 sends no Slack message or email; a failed
  scheduled run sends GitHub's default failure email.
- Missing auth, an unsigned agreement, missing metadata, throttling, or an
  unknown store state stops the affected queue with a message that names the
  fix. The coordinator never edits agreements, metadata declarations,
  permissions, or review answers.
- Setting the level lower stops new submissions only. It can't recall a
  submission already with Apple, which releases on approval. Stopping that
  release takes a person in App Store Connect, and the summary never claims
  otherwise.

## Credentials and trust boundary

A GitHub Environment named `store-release` can be deployed only from `main`, by
`schedule` and `workflow_dispatch` runs, with no `pull_request` path.
Third-party actions are pinned by SHA. The environment holds:

- An App Store Connect API key (issuer ID, key ID, `.p8`) that can read builds
  and versions, manage TestFlight groups, and submit for review. Confirm
  whether App Manager is the lowest role that can. Use a key separate from
  Codemagic's, so that either can be revoked alone.
- A Codemagic API token that can list and start builds. Check what else it can
  reach. If it can't be narrowed, it is the broadest secret here.

The workflow's own `GITHUB_TOKEN` gets `contents: write` for candidate tags,
plus `deployments: write`, `actions: read`, and `checks: read`.

Signing keys and the Shorebird credentials stay in Codemagic. Pull request code
never receives publishing credentials.

## Cost

- One `ios-build` takes roughly half an hour on `mac_mini_m2`, capped at 60
  minutes. Measure this from recent Codemagic builds before enabling.
- At the observed merge rate, that is about 10 builds per weekday and 3 per
  weekend day, roughly 250 builds and 125 Mac hours a month.
- Pay-as-you-go `mac_mini_m2` costs $0.095 a minute
  ([pricing](https://codemagic.io/pricing/)), about $700 to $1,000 a month. The
  fixed-price M2 plan has unlimited minutes and three concurrent builds, so
  there is no minute cost, but scheduled builds occupy one of the three slots
  for a large share of each weekday.
- The build-only-for-public variant costs about half.
- The coordinator itself runs on GitHub-hosted runners, which are free for this
  public repository.

## Android (phase 2, not in this change)

Play gets the same coordinator once iOS runs cleanly. These corrections from
the Codex review of revision 2 carry over:

- The Play build-number lookup must fail closed. Today
  `google-play get-latest-build-number ... 2>/dev/null || true` falls back
  silently.
- The Android version preflight must allow repeated internal builds of the
  current train version with increasing `versionCode`. The marketing version
  may equal the active train version; it must not go backwards from production.
  Validate membership in the allocated train, and require a build identifier
  above both live store state and existing reservations. Revision 2's "newer
  than every track" rule would block the second build of a version. Regression
  coverage must include two internal builds with the same marketing version and
  different increasing build identifiers, followed by promotion of those exact
  tested bytes. Use verified artifact/provenance versions; a Play track's release
  name is not an authoritative manifest `versionName`.
- Every `edits.commit`, including internal-track uploads, manual publishing,
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
- Internal-track uploads need no review, so hourly Android builds have no
  Apple-style cap. They still perform a guarded edit commit: if Play refuses
  that commit while another review is in progress, defer publication. Production
  promotion follows the same daily and waiting rules.
- **Version ownership and migration must land before phase 2 activation.** A
  shared allocator owns new marketing versions and build reservations for
  scheduled and manual store candidates and direct-distribution releases.
  Pubspec remains the major/minor floor. Bootstrap from existing iOS trains,
  live store/artifact versions, stable and beta tags, and existing provenance;
  fail closed when those identities cannot be reconciled. Allocate once and
  reuse the reservation on retries. Route manual builds through the same
  allocator before enabling scheduled Play builds.
- In that migration, `publish_github_release.py` and its callers use the
  verified effective candidate version for publication and release-note
  selection. Historical `--promote-from` tags retain their original version,
  source, artifacts, and note-file mapping; retries never rewrite them. Existing
  create-only provenance remains immutable. When an older record lacks an
  effective-version field, resolve it from its existing verified release
  identity rather than guessing from today's pubspec. Regression coverage must
  include a manual release after iOS has advanced beyond pubspec, a historical
  beta promotion, a publication retry, and concurrent manual/scheduled allocation.

Phase 2 implementation order is: fail-closed Play lookups and compatible version
validation; shared allocator and manual-build migration; publisher and note
selection migration with historical compatibility; guarded Play publishing;
then scheduled internal builds and production promotion. Each step must keep
existing manual releases usable, and activation waits for this complete path.

## Not in this change

Out of scope:

- Shorebird patches, GitHub Latest, and Zapstore.
- Android and Play (phase 2).
- Crash-rate gating.
- An always-running repair agent.
- Notifications.

Runtime smoke tests and crash-rate gates are not prerequisites for this release
automation. Rabble accepted the existing tests and code review as sufficient;
see Release validation policy. Maestro's current limitations do not block it.

## Pull request sequence

Each pull request merges to `main` on its own. Nothing ships until step 3 sets
the variable.

1. **`ios-build` accepts scheduled candidates.** `verify_shorebird_release_source`
   accepts `release-candidate/<sha>` tags, and a validated
   `RELEASE_TRAIN_VERSION` override is written to `ios_release.env`. There is no
   behavior change when the tag and the variable are absent. Tests for both go
   in `.github/scripts/tests/`.
2. **Coordinator, dry run.** `.github/workflows/ios_release_train.yml` plus a
   standard-library Python module. Its decisions are pure functions over a
   snapshot of git, CI, Codemagic, and App Store Connect state, tested with
   fakes. It writes the plan to the run summary, and the level defaults to `off`.
3. **Builds.** Add the tag ruleset, candidate tags, the Codemagic trigger, and
   deployments. Set the level to `build` and watch one hourly build reach
   Divine Internal.
4. **Public TestFlight.** Set `testflight` and watch one build reach the public
   group through beta review.
5. **App Store.** Set `app-store` and watch one submission go through review and
   release.

Cases to test with fakes:

- No app-affecting change, including a docs-only merge.
- The newest commit lacks a merge-group result, or its CI was cancelled or is
  missing.
- A scheduled or manual build is already running.
- A failed build is retried once.
- A beta review is waiting, six submissions were made in 24 hours, or the last
  submission was under four hours ago.
- The first build of a new version is in full review.
- Processing isn't finished, or a good upload ended in a post-processing
  timeout.
- A beta rejection holds the queue until acknowledged.
- An App Store version is waiting, approved but not live, rejected, or
  acknowledged.
- A submission was made in the trailing 24 hours.
- No candidate has soaked, or the soak is measured from observed availability.
- Passing CI and build checks plus the required availability period permit
  submission without a separate runtime-smoke or manual-QA result.
- Version derivation, including the pubspec floor and moving forward after a
  rejection.
- An editable version record is reused.
- No submission is ever cancelled.
- Throttling or an unknown store state fails that queue closed.

## Decisions for Rabble

1. **Public TestFlight cadence.** Apple allows six public submissions a day.
   Proposed: build hourly for internal testers and send the newest build public
   at most every four hours. The alternative builds only when a public slot is
   open, for about half the cost.
2. **Resolved: automatic App Store submission from `main`,** with no person
   choosing the build or the version. Rabble accepted this release-speed
   tradeoff and occasional escaped bugs on 2026-11-04. This retires the
   maintainer-confirms-version rule from #9061; do not ask for approval again.
3. **Spend:** about $700 to $1,000 a month on pay-as-you-go Codemagic, or one
   of three concurrent slots on the fixed plan.
4. **Android and Play:** phase 2 (proposed) or now.

These defaults apply unless Rabble says otherwise: skip docs-only and test-only
merges, a six-hour public soak, release on approval, phased release off, the
generic App Store notes, and a rejection holds its queue until someone
acknowledges it.

These need a person with access:

- Create an App Store Connect API key and a Codemagic API token and add them to
  the `store-release` environment.
- Name the public TestFlight group if there is more than one external group.

## References

- https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/
- https://docs.codemagic.io/rest-api/builds/ (branch or tag only; no commit SHA)
- https://docs.codemagic.io/yaml-running-builds/scheduling/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/
- https://codemagic.io/pricing/
- https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit
- https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks
