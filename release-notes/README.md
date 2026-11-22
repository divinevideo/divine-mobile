# Writing and publishing Divine release notes

Release notes explain what people can do and what works better. Write in Divine’s
voice: direct, human, slightly playful. Follow the brand quick reference and tone
of voice in `brand-guidelines`. Describe benefits, not commit subjects or internal
implementation details.

## Automated native store notes

Protected main-branch release drivers generate notes automatically before they
start a native build. The baseline is the actual previous numbered production
release in the owning store, mapped to its retained source provenance. A previous
beta or an unverified GitHub tag is not a baseline.

One LunaRoute request rewrites the complete app changelog into plain-language
TestFlight instructions and store benefits in Divine's [brand voice](BRAND_VOICE.md).
TestFlight notes welcome people upgrading from the App Store and group the
useful changes across the full release range, with a few concrete things to try.
Code checks the build identity, exact language set, nonblank text, store limits
and accidental copies of English before anything is published. Google Play gets
all 23 shipped locales with at most 500 Unicode characters each; Apple gets its
configured locales with at most 4000 each. Notes are never silently cut to fit.

The protected `store-release` environment supplies
`RELEASE_NOTES_LUNAROUTE_API_KEY`. `RELEASE_NOTES_MODEL` accepts `glm-5.3` (the default)
or `deepseek-4.1-flash`. Use the existing managed Lunaroute credential in this protected environment. No model credential
is sent to Codemagic. Generation uses `store:false`.

The completed bundle is retained create-only in the private release ledger. A bundle is bound to platform, exact source, original
production baseline and brand-policy digest. Build uploads and later promotion
reuse it. Android retained-artifact retries preserve their original localized
bundle. Native builds reject missing, malformed or mismatched bundles; there is
no generic English or commit-title fallback. Generation errors stop before a new
native attempt is consumed.

The beta-note update helper changes copy without itself resubmitting Beta App Review;
the public-beta flow calls it before handling review and group assignment.
This does not lift any App Store hold. In particular, 1.0.30+916 is explicitly
excluded from App Store submission after the reported database-startup failure.
A later corrected build needs its own source verification and public exposure.

API references: [Responses structured outputs](https://docs.lunaroute.com/api/responses/),
[Play localized release notes](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks),
[Play's 500-character limit](https://support.google.com/googleplay/android-developer/answer/9859348).

## Historical release record: 1.0.27

As of October 31, 2026, **1.0.27 was the documented release**. Start with
the [1.0.27 release notes](1.0.27.md) or the
[latest stable GitHub release](https://github.com/divinevideo/divine-mobile/releases/latest)
for downloads. Keep the marketing version prominent in release titles; full
source SHAs belong in the build-provenance line rather than the title.

| Channel | Recorded availability |
| --- | --- |
| Google Play | 1.0.27 publication confirmed by the release owner on October 31; the track, version code and rollout percentage were not independently checked. |
| GitHub | [1.0.27](https://github.com/divinevideo/divine-mobile/releases/tag/1.0.27): 64-bit and 32-bit ARM APKs, promoted from the original production-backend candidate without rebuilding. |
| App Store / macOS | Availability for this version is not verified by this record; this GitHub publication contains Android APKs only. |

The GitHub APK source is
`e7eef34eecc2f1072092c35fa54a100bc370f25a`. The reviewed copy describes that
commit, not later changes on `main`. The Google Play confirmation establishes
the version's publication, not an independently verified store-artifact/source
match. Publication here reuses the candidate's files without rebuilding or
promoting a store track.

Earlier `1.0.26-beta.production.*` entries remain historical testing candidates;
there is no stable `1.0.26` GitHub tag. The earlier 1.0.24 and 1.0.25 beta entries
remain build archives alongside their stable releases. Preserve those tags and
downloads, give the entries short version-first titles, and link their notes
to the stable release rather than leaving generic "early build" copy as the
only explanation.

## Prepare manual GitHub release notes

1. Find the **actual source commit** of the previous shipped build and the next
   candidate. Verify historical tags against build provenance: the original
   `1.0.23` tag predates the binaries uploaded on October 6, 2026. Never move that
   tag or use it blindly as the comparison baseline.
2. From the repository root, generate an editing inventory:

   ```sh
   python3 mobile/scripts/prepare_release_notes.py \
     --base <previous-shipped-source-commit> \
     --head <candidate-source-commit> \
     --output release-notes/<version>.md
   ```

   This uses first-parent history and groups changes into features, fixes, and
   other work to review. It refuses to overwrite an existing file. The output is
   a **working draft**, not automatically publishable copy.
3. Rewrite the inventory into concise, user-facing sections. Check the actual
   diff and feature flags; exclude reverted changes, unavailable features,
   maintenance-only work, and sensitive details. Mention platform restrictions.
   Ask for review through the release-notes PR. Remove `<!-- DRAFT -->` only when
   the copy is ready. Commit the notes before building the production candidate.
4. Keep the filename aligned with the marketing version in `mobile/pubspec.yaml`:
   for example, `release-notes/1.0.24.md`. The publisher adds the exact build SHA.

`1.0.23.md` preserves the reviewed notes already published for that release. It
is not permission to rebuild or replace its existing downloads.

## Choose the Codemagic channel

### Automated Android GitHub and Zapstore publication

Scheduled Android candidates now retain the original ARM APKs, their SHA-256
hashes and the validated source-bound notes during the original build. The
coordinator waits for that exact candidate to be observed as **published on
Google Play production**, with complete lifecycle reads, completed provenance
and successful source CI. Drafts, submissions awaiting review, internal-only
builds and rejected or unknown release state do not qualify.

The existing `zapstore-publish` workflow then publishes those original APKs as
a stable GitHub release before signing that exact release for Zapstore. It
reuses the retained English Android notes and identifies their original store
baseline. It does not claim that iOS or macOS is available. This automatic path
waits for Play availability; the independent manual channel policy below is
unchanged.

Distribution is journaled separately from native build and store submission
budgets. A lost dispatch response is reconciled by its exact provider label;
it never triggers a blind second signing job. Confirmed failed jobs can retry
the same files up to three attempts, after which distribution is held for
investigation. An unknown result or a finished job without its exact completion
receipt also holds distribution. No retry rebuilds APKs or replaces release
assets, notes or tag targets. Existing store rejection holds remain in force.

Older candidates without retained APK evidence are not automatically backfilled.
Manual candidates retain their existing direct-download numbering and remain on
the manual publication path; they do not produce scheduled download evidence.
Their absence is reported rather than repaired with rebuilt files. Dry runs
show the proposed handoff without generating an approval record, dispatching a
job, publishing a release or signing anything. Lowering the Android release
level below `production` stops new automatic distribution.

`PUBLISH_TO_GITHUB=YES` enables GitHub publishing. It remains off by default.
The iOS, Android, and macOS build workflows expose `RELEASE_CHANNEL`:

| Channel | GitHub | Zapstore |
| --- | --- | --- |
| `BETA` (default) | Prerelease, never Latest; tag `<version>-beta.<backend>.<full-source-sha>` | Not published |
| `PRODUCTION` | Stable; GitHub selects Latest automatically by date/version; tag `<version>`; requires finished notes and production backend | Android publishes the stable release |

`DEFAULT_ENV` selects the backend, independently of release readiness. A build
using the production backend can still be a beta. Different beta backends and
source commits get separate tags. iOS and Android from the same source/backend
share the same beta release. Record one full candidate commit SHA before starting
any platform job, and start every platform build from that exact commit. Check
each job’s checked-out SHA before publication; a moving branch name alone does
not identify a candidate. If the build launcher cannot select that commit, stop
and use a launcher that can; do not rebuild from a newer main under the same tag.

### Publish each distribution channel when it is ready

GitHub direct downloads, Zapstore, App Store and Google Play are independent
release channels. A tested production-backend APK can ship as a stable GitHub
release with finished release notes before either store approves or completes
its rollout. Store review, internal testing and staged rollout do not block
GitHub Production publication, promotion or retries. The same independence
applies to macOS direct downloads.

Use `RELEASE_CHANNEL=BETA` while a candidate is still being tested. Once the
release owner accepts that candidate for direct distribution and its notes are
reviewed, promote its original production-backend artifacts on GitHub without
rebuilding. Publish to Zapstore through the signed manual command when that
channel is ready. Independently promote the original store artifacts through
App Store Connect and Play Console and verify each store's rollout there.
GitHub publication does not establish or change store availability.

Record the candidate source SHA, available downloads, and each channel's
verified availability in the release handoff. If a store or platform is still
pending, say so plainly in the release notes; do not describe a direct release
as available in every store. An Android release need not wait for an iOS or
macOS artifact. Add later platform artifacts only from the same candidate,
using the publisher's digest checks.

**Current update-prompt limitation:** stable GitHub publication updates Latest.
The shipped update checker reads that version for every install source, then
opens the install source's own download URL. It does not check that store's
available version. Store users may therefore see a prompt before their store
has the update. Record that limitation when channels differ; it is not a veto
on direct downloads. Update availability should ultimately be checked per
installation channel. This policy change does not change shipped clients.

Do not start another iOS or Android build merely to promote a tested beta:
iOS preflight rejects a version already live in the store, and Android would
create and upload another build rather than promote the tested artifacts.
Use `--promote-from` below. Publication retries reuse the original files;
they are not new store builds. A new macOS Production build can publish its
own ready artifact independently of the stores.

Production publishing uses GitHub’s automatic Latest selection instead of
forcing its own release over a concurrently published newer version. Latest is
verified to be this version or a higher version.

Production publishing stops if the version’s tag points to another commit,
notes are missing or marked DRAFT, or a newer stable version is already Latest.
Existing downloads are never clobbered: identical bytes are skipped; different
bytes or an unavailable digest cause a failure. A new release stays a draft
until its artifact upload succeeds. Retry a failed upload using the original
files; rebuilding signed binaries may produce different bytes.

All published metadata, source tags, and artifact digests are read back and
verified. Concurrent first uploads can cause one platform job to fail safely;
retry publication with its original artifacts after the other job completes.

This does **not** change store submission: iOS still uploads without submitting
for review, and Play still receives the internal-testing AAB. App Store and
Play promotion remain explicit store operations.

Promote the internal-testing release Codemagic uploaded; do not upload its AAB
again. If an artifact ever has to be attached by hand, use the Shorebird AAB
(`app-release.aab`), never a per-ABI split APK (those are for Zapstore / direct
download only). If Play warns that the release **"no longer supports N
devices"**, stop and inspect the artifact rather than clicking through: it is
almost always a 64-bit-only binary that dropped the 32-bit (`armeabi-v7a`)
slice. The full device-support policy and upload runbook are in
[`mobile/docs/ANDROID_DEVICE_SUPPORT.md`](../mobile/docs/ANDROID_DEVICE_SUPPORT.md).

## Retry publication with the original files

Download and preserve the failed job's original signed artifacts from Codemagic.
Do not run the build again. For a production retry, verify the direct-release
readiness requirements above. In an isolated checkout of that job's **exact
source commit**, with its reviewed notes and the original effective identity
(`build/shorebird/<platform>_release.env`) downloaded from the same job, run:

```sh
python3 mobile/scripts/publish_github_release.py \
  --repo divinevideo/divine-mobile \
  --channel PRODUCTION --backend PRODUCTION \
  --artifacts-dir /absolute/path/to/original-artifacts \
  --release-env /absolute/path/to/original-artifacts/android_release.env
```

Use the matching iOS or macOS identity filename for those artifacts. The identity
must match the checked-out source; never regenerate it from today's pubspec.
For a historical pre-allocator job, use that job's original publisher at its
source revision or promote its verified existing beta tag with `--promote-from`;
those tags preserve their original version, source, artifacts and note mapping.

The directory may contain nested downloads. The same files as a normal publish
are selected: arm64/armeabi APKs, IPAs and DMGs. Other APK variants are excluded;
include only this candidate's original files. The publisher checks
existing asset digests, skips byte-identical assets, uploads missing files, and
refuses to replace anything. It also refuses a tag pointing to another commit.
Use `--channel BETA` and the original backend for a beta retry. Recovery still
applies channel readiness checks; it does not coordinate store rollout.

If GitHub publication succeeded and only Zapstore failed, do not rebuild or
republish GitHub. Retry the signed Zapstore command in the repository's Zapstore
publishing instructions against that verified stable release, including its
existing signing environment and `--skip-certificate-linking` option.

## Promote a tested beta without rebuilding

Once the beta has passed testing for the platforms being published, the release
owner accepts it for direct distribution, and its release notes have been
reviewed and committed, run this from a checkout containing the publisher and
those notes. Store approval and rollout are independent:

```sh
python3 mobile/scripts/publish_github_release.py \
  --repo divinevideo/divine-mobile \
  --promote-from <version>-beta.production.<full-source-sha>
```

The command verifies the beta source tag, downloads its existing assets, checks
all digests, and publishes those exact files under the stable version tag. The
notes must describe **that beta’s source**, even if this checkout is newer.
Verify the artifacts for the platforms being published are present before
promotion. Other platforms need not delay them. Later platforms can be promoted
again from the same beta: identical assets are skipped.

This command promotes GitHub only; it does not require or perform store
promotion. For Zapstore, run Codemagic's manual **Publish existing release to
Zapstore** workflow (`zapstore-publish`) from `main`. It uses the existing
`zapstore_credentials` signing key and publishes only the stable GitHub release
matching `mobile/pubspec.yaml`. Its shared publisher refuses a missing or
different newest stable release, and pins Zapstore's release filter to the exact
version so a missing APK cannot select an older release. This workflow does not
build APKs, upload to GitHub, or submit to Play. Keep the existing APKs; do not rebuild Android merely
to trigger publication. The signed manual Zapstore command remains available
for an already configured local signer. Never promote a staging or POC beta to
production.

No script changes or repairs old tags automatically. If a production tag has
already shipped from a different source, use the next maintainer-approved
version rather than rewriting release history.
