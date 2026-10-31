# Writing and publishing Divine release notes

Release notes explain what people can do and what works better. Write in Divine’s
voice: direct, human, slightly playful. Follow the brand quick reference and tone
of voice in `brand-guidelines`. Describe benefits, not commit subjects or internal
implementation details.

## Release record: 1.0.27

As of October 31, 2026, **1.0.27 is the current documented release**. Start with
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

## Prepare the notes

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

## Retry publication with the original files

Download and preserve the failed job's original signed artifacts from Codemagic.
Do not run the build again. For a production retry, verify the direct-release
readiness requirements above. In an isolated checkout of that job's **exact
source commit**, with its reviewed notes and matching pubspec version, run:

```sh
python3 mobile/scripts/publish_github_release.py \
  --repo divinevideo/divine-mobile \
  --channel PRODUCTION --backend PRODUCTION \
  --artifacts-dir /absolute/path/to/original-artifacts
```

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
promotion. For Zapstore, publish the resulting
stable GitHub release through the existing signed Zapstore tooling; do not
rebuild Android merely to trigger a store publication. Never promote a staging
or POC beta to production.

No script changes or repairs old tags automatically. If a production tag has
already shipped from a different source, use the next maintainer-approved
version rather than rewriting release history.
