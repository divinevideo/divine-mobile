# Video actions in the info sheet

Date: 2026-11-14
Status: approved direction (Rabble), visual polish to follow from design (Sebastian)

## Intent

People aren't finding "Add to clips" among all the options in the share
sheet. The original ask: take any classic Vine, pull it into your clips, and
make a reaction or remix from it in the editor (split screen, green screen,
detached clips, drawing and voice-over all exist already).

The broader direction: the info sheet (`MetadataExpandedSheet`, opened from
the three-dot "more" button) becomes the place for "do something with this
video". The share sheet stays the place for "send this somewhere".

## Goals

- The info sheet gets an action row with every content action the share
  sheet's "More actions" row offers that is about the video rather than about
  sending it:
  - Add to clips
  - Save / Remove from saved (bookmark)
  - Add to list
  - Edit video (own videos only)
  - Delete video (own videos only)
  - Event JSON, Event ID (debug tools flag only)
- The same actions **stay** in the share sheet. Both places, by Rabble's
  call.
- Both sheets run each action through the same code, so behaviour, feedback
  and failure handling cannot drift apart.

## Non-goals

- Removing anything from the share sheet.
- Moving the download actions ("Save video" / "Save with watermark", "Save
  to gallery") or Crosspost. Rabble's split keeps them share-sheet only:
  they are about sending the video out of the app.
- Analytics for which sheet an action came from. Nothing records these taps
  today; adding it is a separate change (my call, YAGNI).
- A one-tap "make a reaction" flow that imports a Vine and opens the editor
  with it. Worth doing later; out of scope here.
- Add to clips on web (it stays hidden on web, as today).
- A final visual design. There is no Figma for the action row: frame
  `15675:27353` ("metadata-expanded") shows no actions. Sebastian will refine
  the look afterwards.

## Anti-goals

- Two copies of the same action logic, one per sheet.
- Making the share sheet's logic (`ShareSheetBloc`) do work for the info
  sheet: it loads contacts and ranking signals on open, which the info sheet
  must not trigger.

## Constraints

- Layering: UI -> BLoC/Cubit -> Repository/Service. State holds status
  enums, never error strings (`.claude/rules/state_management.md`).
- Visibility rules match the share sheet exactly:
  - Add to clips: `(video.isOriginalVine || isOwnContent ||
    video.allowVideoReuse) && !kIsWeb`.
  - Edit / Delete: own content only, decided once when the sheet opens (the
    share sheet decides in `initState` so auth flipping mid-sheet can't expose
    owner UI without its cubit; the info sheet must do the same).
  - Event JSON / ID: `FeatureFlag.debugTools`.
- Snackbars raised while a sheet is open land under it
  (`.claude/rules/ui_theming.md`). The share sheet closes itself before
  showing feedback or presenting the next screen (`_presentAfterDismiss`,
  `_safePop`); the info sheet follows the same pattern, for a failed delete
  too. Only the clip-title prompt and the delete confirmation open over it.
- Strings: reuse the existing `shareSheet*` / `shareMenu*` ARB keys. No new
  copy is needed unless the builder adds a section label (see below).
- Existing guards apply (raw TextStyle/colors ceilings, post-close emit,
  l10n delegates in tests, etc.). Extracting existing code must not raise any
  ceiling.

## Approaches considered

- **A. Pull the content actions into shared code both sheets use** (chosen).
  Bookmark status/toggle, add-to-clips import and event JSON/ID move out of
  `ShareSheetBloc` into a new small cubit. Edit/Delete already live in
  `OwnerVideoActionsCubit`, which both sheets create. Add to list is a UI-only
  call to `showSelectListSheet`. The action row widget is shared.
  `ShareSheetBloc` shrinks to contacts, sending, copy link and share via.
- **B. Info sheet creates its own `ShareSheetBloc`.** Less code moved, but
  opening the info sheet would load contacts and ranking signals for nothing.
- **C. Info sheet buttons close it and open the share sheet at that action.**
  Tiny diff, clunky to use, defeats the point.

Rabble picked A.

## Design

### Placement and look

- A new action row directly after `MetadataStatsRow` and before
  `MetadataCreatorSection` in `_MetadataContent`.
- It is the share sheet's existing row: circle icon buttons with labels
  below, scrolling horizontally (`_MoreActionsSection` / `_ActionCircle` /
  `_ActionData` in `share_sheet_more_actions.dart`). Following the app's
  existing example rather than inventing a new control.
- Order: Edit, Delete (own only), Save, Add to clips, Add to list, then debug
  Event JSON, Event ID.
- *Builder's call:* whether the row has a section label. The share sheet's
  row is headed "More actions" (`shareSheetMoreActions`), which reads oddly
  in a sheet with no other actions. Default: no label in the info sheet, so
  no new ARB key.

### Shared logic

- New cubit (working name `VideoContentActionsCubit`, under
  `mobile/lib/blocs/`) for one video. Owns:
  - bookmark status load + toggle (from `ShareSheetBloc`
    `_onBookmarkStatusRequested` / `_onSaveRequested`),
  - add-to-clips import via `VideoClipImportService.importToLibrary` (from
    `_onAddVideoToClipsRequested`),
  - event JSON and nevent payloads (from `_onCopyEventJsonRequested` /
    `_onCopyEventIdRequested`; needs the relay URL).
- Bookmark status loads the same way in both sheets: the share sheet's
  current open-time load (`syncGlobalBookmarks`, then read status), started
  when the cubit is created. The info sheet opens more often than the share
  sheet, so this is one more relay query per info-sheet open. My call: one
  code path and the same "unknown renders as Save" behaviour in both sheets
  outweigh the extra query; the repository serializes syncs. Revisit if it
  shows up in relay load.
- Emits status enums plus one-shot results for the UI (snackbar text,
  clipboard), mirroring how `ShareSheetActionResult` works today. Every
  emit stays inside a handler's own emitter, which `close()` cancels.
- `ShareSheetBloc` drops those handlers, events and results. The share sheet
  provides the new cubit alongside its bloc and wires the same buttons to it.
  Its existing tests for those behaviours move to the cubit's tests.

### Shared UI

- The action row widget (`_ActionData`, `_ActionCircle`, the horizontal list)
  becomes a public widget in its own file, used by both sheets. The share
  sheet keeps its "More actions" heading; the info sheet passes none.
- The clip-title prompt (`_ClipTitleSheet`) moves to its own file so both
  sheets can ask for a clip title before importing.
- The owner Edit/Delete handlers (`_handleEditVideo`, `_handleDeleteVideo`,
  `_deleteVideo`: confirmation dialog, `OwnerVideoActionsCubit.deleteVideo`,
  success/failure snackbars, cleanup completion) are extracted so both sheets
  call one implementation instead of copying them.
- Feedback behaviour per action matches the share sheet: close the sheet,
  then show the snackbar or push the next screen.

### Info sheet wiring

- `MetadataExpandedSheet.show` already builds a `MultiBlocProvider` for the
  modal. It adds the new cubit (and `OwnerVideoActionsCubit` when the viewer
  owns the video), created there from `ProviderScope.containerOf` reads,
  closed with the modal. Ownership is decided once, at `show`.
- The sheet's ABOUTME and class doc say it is "read-only, no new BLoC
  needed"; update them.

## Testing

- `blocTest`s for the new cubit covering every behaviour moved out of
  `ShareSheetBloc` (moved tests, not rewritten from scratch where possible).
- Widget tests for the info sheet action row: which actions show for a
  classic Vine, an own video, a reuse-allowed video, a plain other-person
  video, and with debug tools on; tapping Add to clips prompts for a title and
  requests the import. The shared feedback tests cover the import's
  snackbar.
- Share sheet tests keep passing with the actions routed to the shared cubit.
- Run the guards and `flutter analyze`; check whether an info-sheet golden
  exists under `test/goldens/` and update it on the runner if so.

## Left to the builder

- Exact cubit, file and widget names.
- Whether the shared Edit/Delete code is a mixin, helper functions or a
  small widget.
- Whether the info sheet's row has a heading (default: no).
