# Storage management

What Settings → Storage measures, what each of its actions removes, and — just
as important — what each one deliberately leaves alone. The screen is
`lib/screens/settings/storage/storage_management_page.dart`, driven by
`StorageCubit` over `StorageManagementService`
(`lib/services/storage_management_service.dart`). The last-resort reset is
`CacheRecoveryService`.

## Where the app's footprint lives

| Root | What sits there | Who reclaims it |
|---|---|---|
| Temporary (`getTemporaryDirectory`) | Feed video cache, image cache, every render the editor writes while working (`trimmed_*`, `cropped_*`, `normalized_*`, `speed_*`, `merged_*`, `watermarked_*`, `extracted_audio_*`, `strip_*`), the `speed_clips/` cache and the `divine_player_*` scratch directories | Clear cache; Reset app data |
| Documents (`getApplicationDocumentsDirectory`) | Recordings, imports, `divine_<micros>.mp4` renders, stop-motion stills, thumbnails, ghost frames, chroma-key and transform outputs, the sound library (`library_audio_imports/`), voice-overs (`voice_over_recordings/`), extracted clip audio (`extracted_clip_audio/`), plus the regenerable `transition_seams/` and `transition_frames/` previews | Remove leftover files (unreferenced media); Clear cache (the two preview directories); deleting clips and drafts |
| Application Support | The durable SQLite database (`openvine/database/`), the durable Hive boxes, the disposable `cache_sync` database and hashtag/people-list boxes | Reset app data (everything except the durable database and boxes) |
| Caches (`getApplicationCacheDirectory`) | Platform cache directory; on Android the same directory as Temporary | Reset app data |

The screen shows two "in use" figures so the split is visible: **Cached
media** is what the app can re-download or regenerate, and **Your clips and
drafts** is what it cannot. Before #7641 only the first figure existed, so an
install the OS reported at tens of gigabytes could show a couple of gigabytes
in the app with nothing to do about the rest.

## Actions

### Clear cache

`StorageManagementService.clearCaches()` — routine, safe to run any time.

Removes:

- the feed video download cache (`temp/openvine_video_cache`) and the image
  cache (`temp/openvine_image_cache`), including files the cache database lost
  track of;
- every temp render matching `TempRenderPatterns.all` directly under the
  temporary directory, and the whole of each `TempRenderDirectories.all`
  subtree (`speed_clips/`, `divine_player_assets/`, `divine_player_memory/`,
  `divine_player_audio_assets/`, `divine_player_audio_memory/`);
- the transition previews under the documents directory:
  `transition_seams/` and `transition_frames/`.

Leaves alone: a temp render that is the input of a pending upload (protected
by path); everything else under the documents directory; Application Support;
the database; preferences. The reported "in use" size is exactly the set this
action deletes, so the number goes to zero afterwards unless something is
protected.

### Remove leftover files

`StorageManagementService.removeOrphanedFiles()` — the sweep for renders that
were abandoned, interrupted, or failed and left a full-size file nothing points
at. Such a file is invisible in the Library and absent from every draft, so
this is the only place it can be reclaimed short of reinstalling.

A file is removed when **all** of these hold:

1. It sits directly in the documents root — subdirectories are never
   descended, so the sound library, voice-overs, extracted audio and the
   database's legacy location are out of reach.
2. Its extension is one the app writes for media (`.mp4`, `.mov`, `.m4v`,
   `.webm`, `.jpg`, `.jpeg`, `.png`, `.webp`, `.wav`, `.m4a`, `.aac`,
   `.mp3`). A `.hive`, `.lock` or `.db` file left by an old build is counted
   as content and never touched.
3. No clip row references its basename — checked against **every** row in
   the database, every account and the trash included, through
   `ClipsDao.referencedFilenames`, which also reads the stills, ghost frames,
   reverse caches and chroma-key sources stored inside the clip JSON.
4. No draft row references its basename — `DraftsDao.referencedDraftFilenames`
   covers the rendered file, both thumbnails and the layer manifest.
5. No pending upload names it as its video or thumbnail (matched by basename,
   because iOS moves the container on update and the upload stored the old
   absolute path).
6. It was last modified more than `StorageManagementService.orphanGraceAge`
   ago (one hour, the same as `TempRenderJanitor.staleRenderAge`). A render
   writes its output before any row exists for it, and the camera holds a
   fresh recording in memory until the session is saved — the modification
   time is what keeps an in-flight render safe.

References are re-checked at the moment of deletion, not at the moment the
number was shown, so a file that gained a row in between is kept.

What it will remove that you might not expect: a camera recording (`VID_*`)
whose row was lost. From the user's side that recording was already gone —
nothing in the app could show it — but Developer Options → Clip recovery can
rebuild rows for exactly those files, so run that first when a support case
is about a missing library rather than a full disk.

### Remove broken clips

`findBrokenClips()` / `removeBrokenClips()` — the mirror image of the sweep:
library rows whose media is gone. Removes the rows (and, through the library's
hard delete, any files they still own). Scoped to the signed-in account. A
stop-motion set with at least one readable still is salvageable and is not
reported.

### Reset app data

`CacheRecoveryService.clearAllCaches()` — the repair for a corrupted install.
Wipes the disposable Hive boxes, the disposable `personal_events` table,
Application Support minus the durable database directory and the durable
boxes, the whole temporary directory, and the cache directory. Signs the user
out; the app needs a restart afterwards.

Leaves alone: **the entire documents directory**. Recordings, drafts, renders,
sounds and the leftover files above all survive a reset, which is why a large
footprint that survives "Reset app data" is a documents-directory footprint.

## Diagnosing a report

1. Developer Options → Storage Footprint walks all four roots and lists the
   largest entries per root (`StorageManagementService.measureFootprint`).
   Ask for that output first; it says which root the bytes are in.
2. Documents root, files with no row → Remove leftover files.
3. Documents root, files with rows → the user's library; delete clips.
4. Documents subdirectories → sounds and voice-overs are content; the two
   `transition_*` directories are cache.
5. Application Support, `openvine/database/` → the SQLite file. Its retention
   and `VACUUM` are tracked in #6987 and nothing on this screen shrinks it.

## Background janitors

Independent of the screen, three sweeps run on their own:

- `TempRenderJanitor.deleteStaleTempRenders` — called before a new watermark
  render and before a merged upload render, for that pattern only, older than
  one hour, never a pending upload's input.
- `C2paDebrisJanitor` — at startup, deletes *empty* `c2pa_signed_*.mp4` files
  older than one hour from the documents and temporary directories.
- The media caches enforce their own byte budgets (`kCacheLimitDefaultBytes`,
  adjustable on this screen; `kSeamCacheLimitBytes` for the seams).

None of them touch a non-empty file under the documents root — that is what
the sweep on this screen is for.
