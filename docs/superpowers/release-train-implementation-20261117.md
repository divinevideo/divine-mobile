# Scheduled store release operations

Implements the approved November 3 release design (revision 7), tracking #10709.
Both levels default to `off`; merging this implementation does not enable it.
Patches and livestreams remain under their existing holds.

The main-only `Store release train` workflow runs hourly at :17 UTC and accepts
manual dispatch. The coordinator uses exact-source Mobile CI results, immutable
candidate tags, platform-specific Codemagic builds, the private allocation and
operational ledger, and provider observations. The scheduled iOS lane uploads
internally; manual iOS retains its four external groups. Scheduled public
selection also retains all four existing external groups. OpenVineTesters is the
designated public cohort used to observe the six-hour production exposure.

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
Record the Android rejection-email operator at activation. The accepted policy
uses Play rejection emails and the Android kill switch; the selected API does
not supply an automated rejection hold. There is no new QA or crash gate.

A public iOS submission needs four-hour spacing and fewer than six beta
submissions in the trailing 24 hours. Production needs six observed hours of
availability and fewer than one submission in the trailing 24 hours. Android
replacement also preserves the current internal candidate's full continuous
six hours, including when a manual build supersedes a scheduled candidate.

## Recovery

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
