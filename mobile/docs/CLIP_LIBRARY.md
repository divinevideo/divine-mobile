# Clip library

Status: Current
Validated against: clip library code on `main` on 2026-11-02.

The clip library keeps every take the user records on the device, so one recording can go into any number of videos. Users see it as the Clips tab of the library screen. Other screens open the same library as a picker to choose clips: the editor, a split-screen layout, the chroma-key backdrop and direct messages.

This page covers how the library is put together. Topics that already have their own document are linked, not repeated:

- How a take reaches the library during recording: [`CAMERA_ARCHITECTURE.md`](CAMERA_ARCHITECTURE.md#stop).
- What the editor does with picked clips: [`VIDEO_EDITOR_FEATURES.md`](VIDEO_EDITOR_FEATURES.md).
- Sharing clips in direct messages, the C2PA check, importing from and backing up to the device gallery: [`DM_CLIP_SHARING.md`](DM_CLIP_SHARING.md).
- Leftover files and broken clips: [`STORAGE_MANAGEMENT.md`](STORAGE_MANAGEMENT.md).

The two plans [`plans/2025-12-18-clip-library-redesign.md`](plans/2025-12-18-clip-library-redesign.md) and [`plans/2025-12-18-clip-library-implementation.md`](plans/2025-12-18-clip-library-implementation.md) describe an earlier design, with SharedPreferences storage and a `SavedClip` model, and are historical.

## Layers

| Layer | Code | Role |
|---|---|---|
| UI | [`LibraryScreen`](../lib/screens/library_screen.dart), widgets in [`lib/widgets/library/`](../lib/widgets/library/) | Tabs, clip grid, selection, category chips, trash list |
| BLoC | [`ClipsLibraryBloc`](../lib/blocs/clips_library/clips_library_bloc.dart) | Loads, filters, sorts, selects, organizes and trashes clips |
| Service | [`ClipLibraryService`](../lib/services/clip_library_service.dart) | Reads and writes one account's clips and categories; runs the trash and startup sweeps |
| Data | `ClipsDao`, `ClipCategoriesDao` in [`db_client`](../packages/db_client/lib/src/database/daos/) | The `clips` and `clip_categories` Drift tables |

`clipLibraryServiceProvider` in [`social_providers.dart`](../lib/providers/social_providers.dart) builds the service for the account that owns local content (see [Accounts](#accounts)) and rebuilds it when the account changes. Saving clips to the device gallery is a separate cubit (`ClipGallerySaveCubit`), and so is bringing them back (`GalleryClipImportCubit`, described in [`DM_CLIP_SHARING.md`](DM_CLIP_SHARING.md#back-from-the-gallery)).

The library does not run on the web; `LibraryScreen` shows a placeholder there.

## What a clip is

A clip is a [`DivineVideoClip`](../lib/models/divine_video_clip.dart): a video file in the app's documents directory, with a thumbnail, a ghost frame (its last frame, for the recorder's overlay), its duration, the aspect ratio it was recorded for and its capture proof. A stop-motion set is a clip too (`isStopMotion`), built from stills rather than a rendered video.

File paths are stored as names relative to the documents directory and resolved against it when a clip is read.

## Rows

Each clip is a row in the `clips` table. Columns hold the draft id, owner, recording time, duration, file names, and the category, archive and trash state. The rest of the clip is a JSON blob in `data`. Category, archive and trash state live only in their columns; the service copies them onto the parsed clip, so the column is the source of truth.

The same table stores the clips of drafts, so one recording can have several rows:

| Row id | `draft_id` | What it is |
|---|---|---|
| `<clipId>` | `NULL` | The library row. `saveClip` writes it. |
| `<draftId>:<clipId>` | the draft | The clip inside a saved draft. Not listed in the library. |
| `<autoSaveId>:<clipId>` | `VideoEditorConstants.autoSaveId`, or `NULL` once the recorder's delete has detached it | The copy in the editor's autosave draft. Listed in the library, so a take the editor is holding stays visible. |

`getAllClips` keeps one entry per clip id and prefers the library row. Because a clip can be loaded from either its library row or its autosave copy, these changes write both: `softDelete`, `restore`, `hardDelete`, `setClipCategory` and `setClipArchived`. `saveClip` and the other writes (`setGalleryBackup`, `rememberRecordingHash`, `deleteClipRow`) touch the library row only. A change that writes only one row is undone the next time the other row is the one loaded. When `saveClip` creates the library row, it carries the category and archive state over from an existing autosave copy.

Placeholders (the still that fills the slot a detached clip left behind) and freeze frames (a frame held still for a beat) are stills the editor renders to video. They live in the autosave draft but never show in the library or the trash.

`saveClip` is an upsert that keeps three things the stored entry may know and the caller's copy may not. The recording hash is kept when the caller's copy carries none and still plays the same file. A C2PA proof added after recording is kept when the caller's proof names no manifest and the file is the same. The stored entry's gallery backup state wins when it has one; otherwise the caller's copy keeps its own. The upsert leaves the category, archive and trash columns alone. [`DM_CLIP_SHARING.md`](DM_CLIP_SHARING.md#how-a-clip-is-signed) explains why each one matters.

## Accounts

All accounts on a device share the table. Each row carries `owner_pubkey`. The service's owner is the signed-in account while a session is live. While one is still being restored it is the account this device last signed into, unless the known-accounts registry names a different account as the most recently used. Otherwise it is the marker owner `DraftStorageService.anonymousOwnerPubkey`, which rows recorded while signed out carry. Library listings return the owner's rows plus legacy rows that have no owner, so marker rows stay hidden from every real account until a claim assigns them. At sign-in and after an account switch, legacy rows and marker rows are assigned to the account (`claimLegacyRows`). Switching accounts keeps every account's clips. Deleting an account's data removes its clip and category rows (`deleteAllForUser`).

Operations that take a clip id (`getClipById`, trashing, restoring, deleting, filing and archiving) do not check the owner, so an id can belong to another account. `saveClip` goes further: its upsert stamps the row with this service's owner, so saving over another account's clip id moves that row to this account. Check `belongsToAnotherAccount` before acting on one that may come from outside this library, as `VideoClipImportService` does before it restores a clip from the trash.

[`ClipRecoveryService`](../lib/services/clip_recovery_service.dart) is a developer-only tool for recordings the library can no longer show: rows stored under another owner, and files whose rows are gone.

## Organizing

The grid shows one filter at a time (`ClipLibraryFilter`):

- **All**, the default: clips that are neither archived nor trashed.
- **Archive**: archived clips.
- **Deleted**: the trash.
- **A category** the user created.

A clip belongs to at most one category. Categories are stored per account in `clip_categories`, in the order of the chip row. Category names are the user's own text and are not localized. Deleting a category keeps its clips.

Archiving and categories are independent. Archiving takes a clip out of All, but the clip stays in its category unless the user removes it from there while archiving. Every organize action (move to a category, remove from one, archive, unarchive) produces a `ClipsLibraryOrganizeResult`, which the UI shows as a snackbar. Only archiving offers undo, and it also puts back any category the archive removed.

The sort order (`ClipSort`) and the number of grid columns are kept in SharedPreferences, so they apply to every account on the device. Pinching the grid changes the column count, from 2 to 5 (3 to start). A grid-size menu does the same for assistive technology, which cannot pinch.

## Selecting

A selection is for acting on clips in the library (delete, organize, save to the gallery, open in the editor) or for picking clips for another screen. Dragging across the grid selects a range.

The bloc and the library screen enforce these rules:

- A selection holds either stop-motion sets or video clips, not both. The exceptions are the editor's two pickers (`allowsMixedClipTypes`): the one for adding clips converts every pick to the session's kind, and the split-screen cell picker takes both.
- A selection holds clips of one aspect ratio, and the grid disables every other shape. In the editor's add-clips picker that is the shape of the timeline's first clip; elsewhere it is the shape of the first clip selected. The split-screen cell picker is the exception, below.
- The recorder opens the library showing only its mode's type (`LibraryClipTypeFilter`). The direct-message picker and the chroma-key picker show video clips only.
- In the editor's add-clips picker, clips already on the timeline are pre-selected and cannot be deselected (`disabledClipIds`). The split-screen cell picker pre-selects nothing.
- A split-screen cell picker accepts clips of any shape, since each one is cropped to the cell (`allowsMixedAspectRatios`). It allows no more clips than the layout has free cells (`maxSelectedClips`); with one free cell, a tap swaps the pick.
- Delete and organize act only on selected clips the current filter shows. Clips selected under another filter stay selected and are left alone.

## Trash

Deleting from the library is a soft delete: `deleted_at` is set and the files stay on disk. A snackbar offers undo. The Deleted filter lists trashed clips with the days left before they go; from there a clip can be restored or deleted for good, and the whole trash can be emptied.

At every app start and after an account switch, once signed in, `purgeExpiredTrash` permanently deletes the current account's clips (and legacy clips with no owner) that have been in the trash longer than `ClipLibraryConstants.trashRetention` (30 days). Another account's expired trash waits until that account signs in. The trash list reads the same constant for its countdown.

When the recorder deletes the last take, the clip goes to the trash too. It passes `clearDraftId: true`, so a restore puts the clip back in the library instead of in a draft that may be gone. The recorder has its own undo for this (`ClipManagerNotifier.undoPendingDeletion`).

A permanent delete removes both rows first, then the files through `FileCleanupService`. That service keeps any file that another clip or draft still uses.

## Startup and background work

Once the user is signed in, `AppLifecycleHandler` runs three clip steps in order, after it has resumed pending publishes. Between the first and the second it also migrates old drafts. An account switch rebuilds the app subtree, so the steps run again for the new account.

1. `migrateOldClips` moves clips from the SharedPreferences store of earlier builds into Drift. It is a temporary migration, marked for removal.
2. `purgeExpiredTrash` empties the current account's expired trash (see [Trash](#trash)).
3. `purgeOrphanedDraftClips` removes rows of drafts that no longer exist, for every account (see [`STORAGE_MANAGEMENT.md`](STORAGE_MANAGEMENT.md#background-janitors)).

Only the two purges are failure-isolated: each runs through `_runStartupSweep`, which logs a failure and carries on, so a failing purge neither blocks startup nor stops the other. Everything before them is awaited bare, so if `migrateOldClips` throws, neither purge runs on that launch.

When the library loads, clips missing a thumbnail or ghost frame get them regenerated in the background (`recoverMissingAssets`). The grid then refreshes in place with `ClipsLibraryClipsChanged`, not with a new load: a new load would start recovery again and could loop.

## How clips get in

| Source | Code |
|---|---|
| Recording a take | `ClipManagerNotifier.saveClipToLibrary`, right after the take stops ([`CAMERA_ARCHITECTURE.md`](CAMERA_ARCHITECTURE.md#stop)) |
| Stop motion | `StopMotionSessionStore`, each still as it is taken ([`CAMERA_ARCHITECTURE.md`](CAMERA_ARCHITECTURE.md#modes)) |
| Saving one clip from the editor timeline | [`VideoEditorClipLibrarySaveService`](../lib/services/video_editor/video_editor_clip_library_save_service.dart), which renders the trimmed part into a new file |
| Share sheet, "Add to clips" | `VideoClipImportService.importToLibrary`, for classic Vines, the user's own videos and any video that allows reuse |
| Direct messages | `VideoClipImportService.importReceivedClip` and `importReceivedVine` ([`DM_CLIP_SHARING.md`](DM_CLIP_SHARING.md#in-the-library)) |
| Device gallery | `VideoClipImportService.importGalleryClip` ([`DM_CLIP_SHARING.md`](DM_CLIP_SHARING.md#back-from-the-gallery)) |
| A clip the editor creates, such as a split-screen layout render | The editor's autosave draft, which `getAllClips` lists as library clips (see [Rows](#rows)) |
| Developer recovery tool | `ClipRecoveryService`, which saves recovered recordings back (see [Accounts](#accounts)) |

A clip received in a direct message or brought back from the gallery gets in only after the C2PA check described in [`DM_CLIP_SHARING.md`](DM_CLIP_SHARING.md#the-c2pa-check). Two paths run no such check: an archived Vine is matched by its file hash instead, and the share sheet's "Add to clips" brings in a published video as it is.

## Where the library opens

| From | Code | Shows |
|---|---|---|
| Library routes | `RoutePaths.libraryDrafts`, `RoutePaths.libraryClips` in [`library_routes.dart`](../lib/router/routes/library_routes.dart) | Drafts, Clips and Sounds tabs |
| Recorder | `openRecorderLibrary`, `RoutePaths.libraryClipsOnly` | Drafts and Clips; clips of the recording mode's type only |
| Editor, adding clips | `LibraryScreen(selectionMode: true, allowsMixedClipTypes: true)` in a sheet | Clips tab as a picker; timeline clips pre-selected |
| Editor, split-screen cell | `_pickLayoutCellClips` in [`video_editor_screen.dart`](../lib/screens/video_editor/video_editor_screen.dart) | Picker with the cell's crop on each thumbnail |
| Chroma-key backdrop | `showChromaKeyClipPicker` | A single-clip picker of video clips, with its own `ClipsLibraryBloc` |
| Direct message | `_onAttachClip` in [`conversation_view.dart`](../lib/screens/inbox/conversation/conversation_view.dart) | Picker of video clips; the picked clips are sent |

## Tests

- [`test/services/clip_library_service_test.dart`](../test/services/clip_library_service_test.dart)
- [`test/blocs/clips_library/`](../test/blocs/clips_library/)
- [`test/widgets/library/`](../test/widgets/library/)
- [`test/screens/library_screen_test.dart`](../test/screens/library_screen_test.dart)
- [`test/widgets/app_lifecycle_handler_test.dart`](../test/widgets/app_lifecycle_handler_test.dart), for the startup steps
- [`test/services/video_clip_import_service_test.dart`](../test/services/video_clip_import_service_test.dart)
- [`test/services/clip_recovery_service_test.dart`](../test/services/clip_recovery_service_test.dart)
- [`clips_dao_test.dart`](../packages/db_client/test/src/database/daos/clips_dao_test.dart) and [`clip_categories_dao_test.dart`](../packages/db_client/test/src/database/daos/clip_categories_dao_test.dart) in `db_client`
