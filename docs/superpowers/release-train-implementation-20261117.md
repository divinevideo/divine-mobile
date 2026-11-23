# Scheduled store release operations

Implements the approved November 3 release design (revision 7), tracking #10709.
Both levels default to `off`; merging this implementation does not enable it.
Patches and livestreams remain under their existing holds.

The main-only `Store release train` workflow runs hourly at :17 UTC and accepts
manual dispatch. Automatic iOS builds are spaced at least six hours apart,
including retries, and require app-affecting changes. The hourly tick still
observes testing exposure and store reviews; it is not an hourly native build.
The explicit manual iOS release workflow remains an operator-triggered path.
The coordinator uses exact-source Mobile CI results, immutable
candidate tags, platform-specific Codemagic builds, the private allocation and
operational ledger, and provider observations. The scheduled iOS lane uploads
internally; manual iOS retains its four external groups. Scheduled public
selection also retains all four existing external groups. OpenVineTesters is the
designated public cohort for external TestFlight distribution. App Store
submission uses the newest processed, CI-verified build without a mandatory
TestFlight waiting period. New betas never replace an in-flight store review.

## Approved Android direct distribution

At the `production` Android level the coordinator also observes GitHub/Zapstore
distribution. Native candidates retain their original ARM APK digests and notes
in `artifacts/android-downloads/<number>.json`. Only the newest actually
published Play production candidate, verified against source CI and retained
identity, qualifies. A pending/rejected/partial Play observation cannot authorize
publication. Missing historical evidence is reported; do not rebuild it.

The coordinator records an immutable, short-lived approval observation and a
durable `android-distribution` operation before dispatching the existing
`zapstore-publish` workflow on main. Its non-secret inputs name the exact build,
version, source, attempt and approval observation. The existing scoped ledger
credential is refreshed securely in `store_release_credentials`; public GitHub
and Zapstore signing credentials stay in their existing groups.

That workflow verifies the original completed build and provenance, downloads
the original retained APKs, verifies hashes, publishes/verifies stable GitHub
metadata and assets, and only then signs the exact GitHub tag for Zapstore.
Successful signer exit and a final GitHub read-back produce an immutable receipt
at `distributions/android/<number>.json`. This receipt records successful CLI
publication; it does not independently attest every downstream relay/cache.

The next observation reconciles provider status and the exact receipt. A
dispatch response alone does not mean distribution completed. Confirmed terminal
failures permit at most three automatic attempts with the same original files;
unknown acceptance, conflicting jobs/receipts and exhausted retries create an
`android-distribution` hold without changing native attempt counts or store
cadence. Existing Android store holds also stop new distribution. Dry runs
propose the handoff without writes; the Android kill switch still controls it.

## Credentials and configuration

The `store-release` GitHub Environment must allow only `main`. No PR or tag
workflow receives release credentials. It holds:

- `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_ID`, and
  `APP_STORE_CONNECT_PRIVATE_KEY`: dedicated store release API credentials.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: a dedicated service account with release
  access to `co.openvine.app` only.
- `PROVENANCE_APP_ID` and `PROVENANCE_APP_PRIVATE_KEY`: dedicated GitHub App
  installed on the mobile and private provenance repositories only. The workflow
  mints separate repository-limited tokens; the private ledger token cannot
  write the mobile repository, and the tag token cannot read the private ledger.
- `CODEMAGIC_API_TOKEN`: existing repository secret is inherited by the
  environment. Signing and Shorebird secrets remain in Codemagic.

Before starting each store build, the GitHub driver refreshes the existing
application-scoped Codemagic `store_release_credentials` group with a secure,
private-ledger-scoped App token. Native store workflows and the main-only
approved Android distribution workflow import this group;
shared credentials used by other manual workflows remain unchanged.
`PROVENANCE_TOKEN` can access only the private release ledger. Native public
publishing retains the existing `github_credentials` credential, with its
separate permissions and lifetime. The candidate-tag App token stays in GitHub
Actions, is revoked when the coordinator exits, and is never copied into native
builds. Any obsolete `GH_TOKEN`/`GITHUB_TOKEN` entries in the scoped ledger group
are deleted and their absence verified before dispatch. Ledger operations
select that private token without changing the public publisher's environment.
The repository public-list policy is forwarded into the same secure group,
so native builds do not need Actions-variable access. Token values are not placed in build request variables or printed in summaries.
The App private key remains in the main-only GitHub Environment and Secret Manager.

Delegated tokens are not revoked when the dispatch job exits, because Codemagic
continues independently. GitHub's one-hour token expiration still applies:
queued or unusually long builds can outlive it. There is no in-build refresh,
and the native workflow's 60-minute duration does not include provider queue
time or guarantee completion before expiry. Native operations fail when their
scoped token expires; use the partial-result recovery procedure below before
any new dispatch. Token refresh does not repair a previous external mutation.

Start manual builds through `iOS TestFlight Release` or `Android Store Release`
on GitHub Actions `main`. Both retain `default_env`, `release_channel`, and
`publish_to_github` inputs; production publication requires the production
backend. The scheduled coordinator remains the Android production-promotion
entrypoint. Direct Codemagic UI/API native starts are retired: the first source
step requires the exact expected SHA supplied by a controlled GitHub dispatch,
and stops with the replacement workflow names when it is absent. Do not copy
an expected SHA into a direct start to evade this check. Other manual workflows
(including publishing an existing release) retain their existing credentials.

Repository variables:

- `RELEASE_TRAIN_IOS`: `off`, `dry-run`, `build`, `testflight`, `app-store`.
- `RELEASE_TRAIN_ANDROID`: `off`, `dry-run`, `build`, `production`.
- `TESTFLIGHT_PUBLIC_GROUP_ID`: defaults to the existing OpenVineTesters ID.
- `TESTFLIGHT_GROUP_IDS`: JSON array of the four existing external group IDs;
  defaults preserve every existing audience. The coordinator never changes a
  group's public link, audience, or access policy.
- `PLAY_MANAGED_PUBLISHING`: `off` or `on`, recorded after checking Play Console.
  The selected edit/track API does not expose this console setting. Unknown
  state holds the production queue; `on` names the remaining console publish
  step and never changes it. Recheck this attestation after console changes.

GitHub rejects a tag creation ruleset bypass for its built-in Actions integration.
The provider-supported adjustment is a dedicated mobile-scoped App token for
candidate tag creation. Configure a creation restriction allowing that App only,
and a separate no-bypass update/deletion ruleset for `release-candidate/*`.
The normal workflow token has contents read, actions read, checks read, and
deployments write. Third-party Actions are pinned to commit SHAs.

## Production store review preflight

When the train selects a production candidate, it compares that build’s
verified source commit with the currently published build on the same store.
The Actions summary names the checks to run before App Store submission or
Play production promotion. A dry run reports the same source findings without
submitting. TestFlight and Play internal testing stay available to test fixes.

- **Apple** blocks the return of unsupported audio or Bluetooth background
  modes, which caused review trouble before. Changes to supported devices or
  store assets prompt an iPad screenshot check. Permission purpose strings,
  entitlements, privacy manifests and export declarations prompt a review of
  the applicable App Store Connect answers. Use the documented past
  [Apple review resolutions](../../mobile/docs/APPLE_REVIEW_RESPONSE.md#appendix-a-historical-review-resolutions)
  and the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- **Google Play** flags Android manifest, app Gradle and listing changes for
  checking the merged bundle’s permissions, target API and App content
  declarations. The production track edit must pass the
  [Android Publisher edit validation](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/validate)
  before the coordinator commits it. A refused validation leaves the build
  available for retry after the issue is fixed. Check Play Console’s
  [pre-review checks](https://support.google.com/googleplay/android-developer/answer/14807773)
  when reviewing the listing and the candidate.
- **Both stores** flag changes to known moderation, reviewer access, account
  deletion, consent and legal/support code. Exercise the affected flows on the
  selected build and update reviewer access instructions or disclosures as needed.

Fix confirmed problems before submitting. When the flagged flows and store
listing are ready, copy the summary’s `approve_store_review` value into a
manual `Store release train` dispatch with `dry_run=false`. The confirmation
applies to one platform, build, production baseline and set of findings in
that run. If the next candidate or baseline changes, use its new report. Missing
provenance and known regressions require a fix before the train can proceed.

The source comparison is a targeted check. Actual screenshots, reviewer login,
console declarations, remotely enabled features and live moderation still need
verification on the candidate when applicable.

## Bootstrap and activation

Dispatch with `setup_codemagic=true`, `dry_run=true` to preview, then
`dry_run=false` to securely upsert the inherited API token into the existing
Codemagic `github_credentials` group. The v3 API uses `secure:true`. The script
verifies encryption metadata and never prints values. Subscription output is
restricted to plan category, pricing model and status; confirm three concurrent
builds and M4 coverage with the provider before activation.

Dispatch with `bootstrap=true`, first dry and then live, to reconcile existing
store versions, every Play track's identities, and existing GitHub stable tags.
Unmapped or conflicting Play identities stop bootstrap. Existing provenance
remains immutable.

After both complete paths have merged: observe `dry-run` for both platforms,
then `build` and one actual internal availability on each store, then
`testflight` and one public availability, then `app-store`/`production`.
Record the Android rejection-email operator at activation. Use the Play
lifecycle hold, rejection emails and the Android kill switch to stop and
investigate a rejected release.

A public iOS beta submission needs four-hour spacing and fewer than six beta
submissions in the trailing 24 hours. App Store submission has no TestFlight
waiting period; it preserves the limit of one submission in the trailing
24 hours and leaves an existing review queued unless a real bug requires
withdrawal. Android replacement preserves the current internal candidate's
full continuous six hours, including when a manual build supersedes a
scheduled candidate.

### Google Play review and availability

The controller and release-note baseline reader use the documented
`applications.tracks.releases.list` lifecycle API through protected service-account
credentials. These observation reads do not create or invalidate publishing edits.
Only `PUBLISHED` releases count as available or start internal testing exposure;
a configured track's `completed` rollout status does not prove publication.
Pending review/publication is preserved, and current rejections or incomplete
lifecycle reads stop Android release actions. Published, pending, and rejected
states are reflected separately in deployment audit statuses. A superseded
rejection stays in the audit when its build has a provenance record.

The first complete lifecycle read initializes versioned publication evidence.
Published internal builds start a fresh six-hour exposure period. The highest
published production build starts the daily wait, preserving any later recorded
promotion time. A later observation of the same or an older production build
preserves that clock. Incomplete lifecycle reads leave both timers untouched.

An API error requiring review submission through Play Console is a provider
restriction, not successful publication. The controller does not silently stage
changes with `changesNotSentForReview=true`, acknowledge failures, or rebuild
retained signed artifacts to conceal that restriction.

## Recovery

### Native credential expiry and partial results

A native failure is not proof that nothing was published. Do not rerun an old
Codemagic job with its captured credentials, or treat fresh credentials as a
recovery mechanism. Inspect the exact Codemagic build and its allocated
`<platform>_release.env`, Shorebird release list, App Store Connect build or
Play internal track, any requested GitHub release publication, and private
ledger before starting another build.

- Before identity allocation or external mutation, a new GitHub dispatch can
  retry after the failed provider build is terminal.
- After Shorebird registration, that release identity is spent even if the
  provenance write failed. Preserve the signed native artifacts and retained
  `<platform>_provenance.json`; never rebuild or overwrite that identity.
- An allocated store build without completed provenance is observation-only,
  excluded from promotion and CI eligibility. Its presence does not block
  later eligible candidates; existing cadence/exposure rules still apply.
  A conflicting record holds the queue for reconciliation. Restore only the
  original authenticated record through the
  existing private provenance create-only procedure, with its original source,
  version, and HMAC verification. Never reconstruct it from current settings.
  If the original record is unavailable or cannot be authenticated, recovery of
  that release is unsupported: leave it unpromoted, resolve its store/provider
  state, and create a new identity through GitHub dispatch. Do not enable
  patching for that orphan release.
- If Play accepted an upload before the ledger receipt failed, verify the exact
  version code on its track first. The artifact identity and digest are recorded
  before upload; the coordinator observes actual track membership and does not
  upload an already-present candidate again. If acceptance is unknown, leave it
  held until resolved. A failed receipt is not permission to upload or rebuild.

For a retained original record, `shorebird_provenance.rb policy-required`
authenticates its HMAC without needing raw dart-defines. Run it in the trusted
environment containing the original provenance HMAC key and key ID, verify its
source and version against the recorded build and native artifact, then use
`shorebird_provenance_store.sh create`. The existing create-only history guard
still applies. Do not replace an existing record or place either key into an
artifact, command argument, or log.

There is no automatic restoration of missing provenance or ambiguous store
receipts in this credential repair. An operator must reconcile those partial
results. Expiry may require a new native build after reconciliation; neither
token renewal nor a successful controller run proves that an earlier release
completed. Preserved artifacts remain subject to Codemagic retention.

Dispatch `acknowledge` with the exact item from the run summary: an
`ios-build:<store-id>` beta rejection, `ios-version:<store-id>` store rejection,
or a failed operation identity. Resolve the provider failure before acknowledging.
The acknowledgement is durable and recorded in the deployment history. Version
acknowledgements are bound to the observed marketing version as well as the store
record ID. Positive submission acceptance consumes the grant, and a newer review
submission timestamp invalidates an older acknowledgement, so a later rejection
requires a new acknowledgement even when the record and version are reused.
A repeated provider failure creates a new hold even after an earlier acknowledgement.

An acknowledged App Store rejection resolves only its exact existing review item
and resubmits that submission. It never removes unrelated items or cancels a
review. Interrupted draft/item creation is resumed using the same resources;
only positive accepted-review evidence completes the mutation journal. When an
error stopped after version edits, acknowledge the current rejected version and
the named operation hold after checking the provider state. A manual accepted
submission of the same or a newer version supersedes an older interrupted intent,
so the old artifact is not replayed.

A failed build is retried once. The shared allocator reuses only an unspent
identity and verifies the previous scheduled builder is terminal; spent
Shorebird/provenance/store identities receive a new reservation. An ambiguous
build start is located by its durable provider label before anything is retried.
An unresolved start holds the queue instead of sending another POST.

Every Play commit, including manual internal publishing and retained-artifact
retries, uses `ERROR_IF_IN_REVIEW`. A refused upload retains the signed AAB,
original digest, source, build number, artifact name and Codemagic build ID in
private state. Retries authenticate artifact retrieval and verify the
build-recorded digest before upload; expired bytes stop the queue and are never
replaced by a rebuild of that identity. Preserve Codemagic artifact retention
longer than pending-review intervals.

Set iOS to `build` to stop public/store submissions; set Android to `build` on a
rejection email to stop production promotions. `off` stops new work. Lowering a
level cannot recall a submission already accepted by a store; use the owning
store console when an accepted release must be stopped.

Public deployment payloads contain only version, build number, source SHA and
store ID. Artifact URLs and private ledger state never enter public payloads.
