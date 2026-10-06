# Writing and publishing Divine release notes

Release notes explain what people can do and what works better. Write in Divine’s
voice: direct, human, slightly playful. Follow the brand quick reference and tone
of voice in `brand-guidelines`. Describe benefits, not commit subjects or internal
implementation details.

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
share the same beta release.

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

## Promote a tested beta without rebuilding

Once release notes for that beta’s version have been reviewed and committed,
run this from a checkout containing the publisher and those notes:

```sh
python3 mobile/scripts/publish_github_release.py \
  --repo divinevideo/divine-mobile \
  --promote-from <version>-beta.production.<full-source-sha>
```

The command verifies the beta source tag, downloads its existing assets, checks
all digests, and publishes those exact files under the stable version tag. The
notes must describe **that beta’s source**, even if this checkout is newer.
Ensure every intended platform has uploaded before promotion. Later platforms
can be promoted again from the same beta: identical assets are skipped.

This command promotes GitHub only. Promote the original artifacts separately
in App Store Connect and Play Console. For Zapstore, publish the resulting
stable GitHub release through the existing signed Zapstore tooling; do not
rebuild Android merely to trigger a store publication. Never promote a staging
or POC beta to production.

No script changes or repairs old tags automatically. If a production tag has
already shipped from a different source, use the next maintainer-approved
version rather than rewriting release history.
