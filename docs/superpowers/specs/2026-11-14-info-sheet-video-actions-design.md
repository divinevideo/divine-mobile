# Video actions in the info sheet

Date: 2026-11-14, revised 2026-11-15 after Rabble's review of PR #11044
Status: revision 3 — the newest revision section supersedes anything below it that conflicts

## Revision 3 (2026-11-15) — remix consent, credit and takedown

Rabble's direction: remixing is allowed by default; creators can block it on
one video or on their whole account; creators can see every video that
remixed theirs; a mean remix can be pulled down, through Trust & Safety for
now. The Remix button label is "Remix this video" on every video (classic
Vines included) — revision 2's "Remix this Vine" string is dropped.

*As built (2026-11-16):* at Rabble's request the full-width Remix button
became a Remix icon in the info sheet's action row ("ugly, bad UX and takes
over"). It is the row's first circle, labelled "Remix" (film slate icon), so
the row reads Remix, Save, then Edit and Delete on the viewer's own video,
then Report this remix. It shows exactly when the button did and behaves the
same: on the app it imports the video and opens the editor, with a spinner
while the remix is prepared and the rest of the row held; on the web it
closes the sheet and points to the app. The "Remix this video" string is
gone. Wherever this spec says "the Remix button", read "the Remix action".

*As built (#11066):* Remix no longer opens the editor. It saves or reuses the
video's footage, restoring an archived import, and opens the clip library on
From others, or on Clips for the viewer's own video. It leaves the editor
session alone; the autosave-kept-as-draft step below moved to the Library's
"Create video", which every way into the Library now shares. The footage
is then used from the library or through the editor's clip picker. Read "open
editor" in this spec as "open the clip library".

### Consent

- **Default flips to allowed.** A video may be remixed unless its creator
  said no. Per video: the event's `allow_video_reuse` tag — `false` blocks,
  `true` or absent allows (today only an exact `true` allows). Per account:
  a creator-wide block (below) overrides every video's tag.
  - Divine users' videos published while the default was "off" (since
    #10467, 2026-10-26) carry an explicit `allow_video_reuse=false` and stay
    off (Rabble, 2026-11-15). Videos published before the tag existed
    (absent) become remixable.
  - Production check (2026-11-15, internal read): 7,585,200 `platform=vine`
    event revisions, none with `allow_video_reuse=false`; all 3,413 `false`
    and 572 `true` revisions are Divine-made posts. So no archived Vine
    needs republishing — classic Vines are remixable through the client
    rule below. Republishing the archive is explicitly not part of this
    work.
  - A sound that forbids derivatives still forbids it
    (`soundForbidsDerivatives`), unchanged.
  - The editor's video-reuse toggle now defaults to on for new posts, and
    stays editable on a published video through the existing edit flow.
- **Account-wide block:** a setting in the creator's own settings ("Let
  people remix my videos", default on). Stored as a field in the creator's
  kind 0 profile so any client can read it with the profile it already
  fetches; Divine reads it before offering Remix or Add to clips.
  Builder's call: the exact field name (document it in
  `docs/NOSTR_EVENT_TYPES.md`).
  *As built:* REST profile projections drop custom keys, so Divine does not
  use the profile it already has. It reads the creator's raw kind 0 straight
  from the relays when Remix or Add to clips is tapped, and refuses the tap
  if the account blocks remixing; the buttons show either way.
- **Where consent is checked:** one shared rule (`canRemixVideo`, replacing
  `canAddVideoToClips`) used by the Remix button, the share sheet's Add to
  clips, and every other reuse entry point that calls the old rule. Own
  videos are always remixable by their owner. Classic Vines (`isOriginalVine`) are
  always ON by default (Rabble, 2026-11-15): any `allow_video_reuse` tag on
  an archived Vine event is an import artefact, not the creator's choice,
  and is ignored — the same stance the audio policy (#8464) takes on
  imported `allow_audio_reuse` tags. Only the creator's account-wide block
  turns a classic Vine off. A Viner who cannot sign in to their imported
  account asks Trust & Safety (see takedown).
- **Not enforced against other Nostr clients.** This is a published
  preference, honoured by Divine; server-side enforcement (like the audio
  reuse decision in #8467) is later work.

### Credit

- Already true and kept: a clip imported from someone's video publishes a
  `clip-source` `a` tag (the source's `34236:` coordinate) and `p` tag from
  the clips on the timeline, separate from the editable Inspired-by field,
  carried through split-screen and merge renders and preserved on metadata
  edits. Removing the clip is the only way to drop it.
- New: the editor's details screen shows a locked "Uses a clip from
  @creator" row per credited creator, with no remove control.
- New: a reply's info sheet shows its clip credits too (today a reply's
  parent context replaces them in `creditedInspiredByPubkeys`).
- New: tests that a video built from a reused clip publishes the credit
  even when the Inspired-by field is cleared, and keeps it through a
  metadata edit.

### Seeing and pulling down remixes

- **Remixes list.** A video's info sheet gets a "Remixes" section listing
  videos whose `clip-source` `a` tag names it (relay `#a` query through a
  repository method), newest first, shown when at least one exists.
  Visible to everyone, so creators and viewers can both find them.
- **Report a remix.** On a video whose clip credit names the viewer, the
  info sheet offers "Report this remix", which opens the existing report
  flow preselected for this case. It reaches Trust & Safety like any report;
  T&S decides and removes. No automatic takedown.
  *As built:* the report flow opens for the remix with no reason
  preselected.

### Still from revision 2

Remix button behaviour (import, open editor, web nudge, no duplicates,
draft-safe), the From others Library tab in every picker, the slimmed info
sheet actions, and screenshots in the PR.

## Revision 2 (2026-11-15)

Rabble rejected the first build (PR #11044). Reviewed on web, the info sheet
showed Save, Add to List, Event JSON, Event ID — and no way to use the classic
Vine at all, because Add to clips is hidden on web (the clip library and editor
don't run there). The point of the work is to get people making new videos
with classic Vines; the first build buried that as one small circle among
five, and showed nothing on web.

### What changes

1. **Remix button (the headline).** *As built:* now a Remix icon at the
   front of the action row; see revision 3's "As built (2026-11-16)" note.
   On a video the viewer may reuse
   (`canAddVideoToClips`: classic Vine, own video, or creator allows reuse),
   the info sheet shows one full-width primary `DivineButton` directly under
   the stats row: "Remix this Vine" on a classic Vine (`isOriginalVine`),
   "Remix this video" otherwise.
   - **App (iOS, Android, macOS):** tap imports the video into the clip
     library (no title prompt; the default title), then closes the info sheet
     and opens the editor with that clip on the timeline — the same path the
     Library uses when you select clips and tap create
     (`LibraryScreen._createVideoFromSelected`: `clipManager.insertClip`, then
     `VideoEditorRouteData(from: VideoEditorScreen.libraryOrigin)`), except
     that it clears the editor session with `keepAutosavedDraft: true` (the
     Drafts tab's draft-safe call) so an in-progress autosaved draft survives.
     While importing, the button shows its loading state and ignores taps; a
     failed import shows the existing "Couldn't add to clips" snackbar.
     *As built:* instead of `keepAutosavedDraft: true`, it first copies an
     autosave that holds clips into Drafts as a new draft, then calls
     `clearAll()` (see "The autosaved session is kept as a draft" below).
     A failed import shows its own "Couldn't start the remix. Try again."
     snackbar rather than the Add to clips one.
   - **Re-tapping does not duplicate.** If a non-trashed clip in the library
     already has this video's `sourceEventId`, it is reused instead of
     importing again.
   - **Credit:** the clip keeps its source credit, so a published remix whose
     timeline has exactly this one reused source is published "Inspired by"
     the original (`VideoEditorNotifier._attributionSourceFromClips`). No
     change needed; covered by an existing path.
   - **Web:** the same button shows. Tapping it shows a snackbar saying
     remixing happens in the Divine app, with a "Get the app" action that
     opens `AppConstants.downloadUrl` (`https://divine.video/download`).
2. **Info sheet secondary actions shrink to:** Edit and Delete (own videos
   only), then Save. Removed from the info sheet: Add to list (it overlaps
   Save; it stays in the share sheet), Event JSON and Event ID (debug tools;
   they stay in the share sheet), and the small Add to clips circle (the Remix
   button replaces it there). The share sheet is unchanged by revision 2.
3. **"From others" Library tab.** Clips whose source credit names someone
   other than the signed-in viewer (`sourceAuthorPubkey != null &&
   sourceAuthorPubkey != viewer`) — imported classic Vines and other people's
   videos, and clips received in DMs — move out of the Clips tab into a new
   Library tab, "From others". The Clips tab shows only the viewer's own
   clips (no source credit, or credited to the viewer).
   - Tab order: Drafts, Clips, From others, Sounds (Sounds absent in the
     recorder's `withoutSounds` mode, as today).
   - The editor's add-clips picker (`LibraryScreen` selection mode) today
     shows only Clips with no tab bar; it gains a two-tab bar, Clips and From
     others, so a Vine can be added to a remix from inside the editor.
   - Selection, sorting, grid size, archive/trash and category behaviour in
     From others match the Clips tab (it is the same clip grid with a
     different ownership scope). Category chips, Archive and Deleted filters
     apply within each tab.
4. **Screenshots in the PR.** The rework is run on the macOS app or iOS
   simulator and the PR gets screenshots of: a classic Vine's info sheet, the
   web nudge, an own video's info sheet, the editor opened by Remix, and the
   From others tab.

### New copy (ARB keys, translated into every locale per
`mobile/docs/LOCALIZATION_STYLE_GUIDE.md`, flagged for fluent review)

- Remix this video (*as built:* replaced by "Remix", the action row label)
- Remixing happens in the Divine app. (web snackbar)
- Get the app (web snackbar action)
- From others (Library tab)

Builder's call: exact key names (feature-prefixed), and whether the web
message reads better as one sentence or two.

### Decisions settled after the builder check (my calls, for Rabble to check)

- **The autosaved session is kept as a draft, not overwritten.** The editor
  has one autosave slot (`VideoEditorConstants.autoSaveId`), and the Remix
  session's own autosave would overwrite it within a second. So before Remix
  starts a session, an existing autosaved session is saved into Drafts as a
  regular draft, then the session is cleared. Nothing is asked; nothing is
  lost. (The Library's create-from-clips path discards the autosave today;
  Remix deliberately does better and the Library path is left alone.)
  *As built (#11066):* the step lives in the Library's "Create video", before
  it clears the session. It keeps only an edited autosave, by the rule the
  editor's close button asks by: an autosave holding clips alone would add a
  draft each time someone backs out of the editor and creates again.
- **Every clip picker gets the From others tab:** the editor's add-clips
  picker, the split-screen cell picker (reactions are what layouts are for),
  and the DM attach-clip picker all open `LibraryScreen(selectionMode: true)`;
  all three show Clips and From others.
- **What counts as "from others":** a clip whose footage is someone else's
  untouched video — a plain import (Add to clips, Remix, a received DM clip)
  credited to another account. Clips the viewer made in the editor
  (split-screen renders, merges, flattened saves) are the viewer's own even
  when they carry other people's credits. If the clip model cannot already
  tell a plain import from a derived clip, the builder adds the smallest
  persisted marker that can, set at import time; clips imported before this
  ships fall back to "single credit naming someone else".
  *As built:* the marker is `DivineVideoClip.importedSource`. An older clip
  counts as an import by its id prefix (`video_`, `classic_vine_`,
  `dm_clip_`), and as from others when its first credit names someone else.
- **Duplicate check** matches only plain imports of this exact video
  (`sourceEventId` or addressable coordinate), never derived clips.
- **One selection across both tabs.** Clips and From others are one clip
  grid state with an ownership scope per tab; a selection survives switching
  tabs (as it survives switching category chips today), so "my take + a
  Vine" can be selected together in the Library and in every picker. Category
  chips, Archive and Deleted filter within the active tab.
- **Leaving the editor unedited clears the Remix session.** If the viewer
  backs out of the editor Remix opened without editing, the session is
  cleared so the camera doesn't next open with the Vine on its timeline. An
  edited session behaves like any editor session (autosave, Drafts).
  *As built:* backing out shows the editor's usual save-or-discard prompt
  instead. A timeline holding a credited clip counts as edited, so nothing
  is cleared without asking.

### Non-goals (revision 2)

- Changing the share sheet.
- Merging Save and Add to list into one picker.
- A camera-first reaction flow (Remix opens the editor; the editor can add a
  recording).
- Analytics.

---

## Original design (revision 1)

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
