# Info Sheet Video Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The info sheet (`MetadataExpandedSheet`) gets an action row with Edit, Delete (own videos), Save, Add to clips, Add to list, and debug Event JSON / Event ID, sharing one implementation with the share sheet, which keeps all its actions.

**Architecture:** Bookmark status/toggle, add-to-clips import and event JSON/ID move out of `ShareSheetBloc` into a new `VideoContentActionsBloc` (handlers moved verbatim, tests moved with them). The share sheet's action-row widget, clip-title prompt, sheet-dismissal helpers and result feedback become shared widgets/functions; the owner delete flow reuses the existing one in `owner_video_actions_sheet.dart`. Both sheets provide the bloc and render the shared row.

**Tech Stack:** Flutter, flutter_bloc + bloc_concurrency, Riverpod (legacy DI reads only), mocktail, bloc_test.

**Spec:** `docs/superpowers/specs/2026-11-14-info-sheet-video-actions-design.md`

## Global Constraints

- All commands run from `mobile/` with the mise-pinned SDK (`mise exec -- flutter ...`).
- Add to clips visible iff `(video.isOriginalVine || isOwnContent || video.allowVideoReuse) && !kIsWeb`.
- Edit / Delete visible only when the viewer owns the video, decided once when the sheet opens (an `OwnerVideoActionsCubit` is provided iff owned).
- Event JSON / Event ID visible only when `isFeatureEnabledProvider(FeatureFlag.debugTools)` is true.
- Info sheet order: Edit, Delete, Save, Add to clips, Add to list, Event JSON, Event ID. Placed after `MetadataStatsRow`, before `MetadataCreatorSection`. No heading.
- Every action closes the sheet it was tapped in before showing a snackbar or presenting the next screen.
- Share sheet keeps every action it has today, including download, Save to gallery and Crosspost. Info sheet does not get download, Save to gallery or Crosspost.
- No new ARB keys. Reuse `shareSheet*`, `shareMenu*`, `share*` keys.
- Files under `lib/**/widgets/**` must not import `package:openvine/services/...` (`check_ui_service_boundary.sh`; new files may not be added to its baseline).
- New files may not contain raw `TextStyle(`, raw colors, or `Future.delayed` (per-file ceilings fail on new keys). Use `VineTheme.*Font()` and `context.vineColors.*`; wait for a frame with `WidgetsBinding.instance.endOfFrame`. Lock lowered ceilings in the same commit with `UPDATE_BASELINE=1 bash scripts/check_<name>.sh`.
- State holds status enums and one-shot results, never error strings. Blocs mix in `CloseGuardedEmit`.
- Every test file's declarations live in `group()`s; widget tests use `testMaterialApp` / `appLocalizationsDelegates`.

## Review Focus

1. **Sheet dismissed while an action is in flight** (swipe the info sheet away during a bookmark toggle or clip import): no "emit after close" error and no crash; the operation's late result is dropped. Test in Task 1.
2. **Double tap on Save or Add to clips** before the first finishes: the repository / importer is called once. Test in Task 1.
3. **Signed-out viewer opens the info sheet:** no Edit/Delete; Save tap with no bookmarks repository reports a failure snackbar instead of crashing. Test in Task 4.
4. **Web:** Add to clips never appears in either sheet. Test in Task 2 (`canAddVideoToClips(..., isWeb: true)`).
5. **Delete success from a sheet:** the success snackbar still appears after the sheet is closed (the shared delete flow must not drop it because the sheet's context unmounted). Test in Task 3.

---

### Task 1: `VideoContentActionsBloc`

Move, don't rewrite: the handler bodies come from `lib/blocs/share_sheet/share_sheet_bloc.dart` (`_onBookmarkStatusRequested`, `_onSaveRequested`, `_onAddVideoToClipsRequested`, `_onCopyEventJsonRequested`, `_onCopyEventIdRequested`) with types renamed. `ShareSheetBloc` is left untouched in this task.

**Files:**
- Create: `lib/blocs/video_content_actions/video_content_actions_bloc.dart` (with `part` files `video_content_actions_event.dart`, `video_content_actions_state.dart`)
- Create: `lib/blocs/video_content_actions/reportable_sites.dart`
- Test: `test/blocs/video_content_actions/video_content_actions_bloc_test.dart`

**Interfaces:**
- Produces:
  - `VideoContentActionsBloc({required VideoEvent video, required String relayUrl, BookmarksRepository? bookmarksRepository, VideoClipImportService? videoClipImportService})`, `extends Bloc<VideoContentActionsEvent, VideoContentActionsState> with CloseGuardedEmit<VideoContentActionsState>`.
  - `String get defaultClipTitle` → `VideoClipImportService.defaultLibraryTitleFor(video)` (so widgets never import the service).
  - Events (sealed `VideoContentActionsEvent extends Equatable`): `VideoContentBookmarkStatusRequested()`, `VideoContentSaveRequested()`, `VideoContentAddToClipsRequested({String? libraryTitle})`, `VideoContentCopyEventJsonRequested()`, `VideoContentCopyEventIdRequested()`. Same transformers as today (`droppable()` for status, save, add to clips).
  - `enum VideoBookmarkStatus { unknown, saved, notSaved }` (moved doc comment from `ShareSheetBookmarkStatus`).
  - `VideoContentActionsState({bool isSaving = false, VideoBookmarkStatus bookmarkStatus = VideoBookmarkStatus.unknown, VideoContentActionResult? actionResult})` with `copyWith(..., bool clearActionResult = false)`.
  - Sealed non-const `VideoContentActionResult` with: `VideoContentSaveResult({required bool succeeded, bool removed = false, bool wasBookmarkedBeforeToggle = false, BookmarkToggleFailure? failure})`, `VideoContentClipImportResult({required bool succeeded, String? libraryTitle})`, `VideoContentCopiedToClipboard({required VideoContentCopiedKind kind, required String text})` with `enum VideoContentCopiedKind { eventJson, eventId }`, `VideoContentActionFailure()`.
  - `abstract class VideoContentActionsReportableSites` with the five handler names.

- [ ] **Step 1: Move the tests.** Copy the `ShareSheetSaveRequested`, `ShareSheetAddVideoToClipsRequested`, `ShareSheetCopyEventJsonRequested`, `ShareSheetCopyEventIdRequested`, `ShareSheetBookmarkStatusRequested` and `addressable video` groups from `test/blocs/share_sheet/share_sheet_bloc_test.dart` into the new test file under `group(VideoContentActionsBloc, ...)`, renamed to the new types. Build the bloc with only the four constructor arguments. Add:

```dart
blocTest<VideoContentActionsBloc, VideoContentActionsState>(
  'drops a second add-to-clips request while the first is in flight',
  build: () {
    when(() => importer.importToLibrary(any(), libraryTitle: any(named: 'libraryTitle')))
        .thenAnswer((_) => importCompleter.future);
    return buildBloc();
  },
  act: (bloc) {
    bloc
      ..add(const VideoContentAddToClipsRequested(libraryTitle: 'a'))
      ..add(const VideoContentAddToClipsRequested(libraryTitle: 'a'));
    importCompleter.complete(VideoClipImportSuccess(clip));
  },
  verify: (_) => verify(
    () => importer.importToLibrary(any(), libraryTitle: any(named: 'libraryTitle')),
  ).called(1),
);

test('close during an in-flight toggle drops the late result without error', () async {
  when(() => bookmarks.toggleVideoInGlobalBookmarks(any(), addressableId: any(named: 'addressableId')))
      .thenAnswer((_) => toggleCompleter.future);
  final bloc = buildBloc()..add(const VideoContentSaveRequested());
  await pumpEventQueue();
  expect(bloc.state.isSaving, isTrue);
  await bloc.close();
  toggleCompleter.complete(successResult);
  await pumpEventQueue();
  expect(bloc.state.isSaving, isTrue); // nothing emitted after close
});
```

Also: `defaultClipTitle` returns the video's title for a titled video.

- [ ] **Step 2: Run, expect failure** — `mise exec -- flutter test test/blocs/video_content_actions/` → compile errors (types don't exist).
- [ ] **Step 3: Implement** the bloc, events, state, sites by moving the five handler bodies. Replace `_addUnexpectedError` with the same `Reportable` wrapping `ShareSheetBloc` uses (copy its private helper). Use `emitIfOpen` where the moved code emitted after an `await` outside the handler's `emit` (keep handler `emit` calls as-is).
- [ ] **Step 4: Run, expect pass** — same command; plus `mise exec -- flutter analyze lib/blocs/video_content_actions test/blocs/video_content_actions`.
- [ ] **Step 5: Commit** — `feat(video-actions): add a bloc for per-video content actions`.

### Task 2: Shared sheet UI pieces (pure refactor of the share sheet)

**Files:**
- Create: `lib/widgets/video_feed_item/actions/video_action_row.dart` — from `_MoreActionsSection`'s list rendering, `_ActionData`, `_ActionCircle` in `share_sheet_more_actions.dart`.
- Create: `lib/widgets/video_feed_item/actions/clip_title_sheet.dart` — from `_ClipTitleSheet` / `_ClipTitleSheetState` in `share_action_button.dart`.
- Create: `lib/widgets/video_feed_item/actions/sheet_dismissal.dart` — from `_safePop` and `_presentAfterDismiss`.
- Create: `lib/widgets/video_feed_item/actions/video_content_action_rules.dart`
- Modify: `share_sheet_more_actions.dart`, `share_action_button.dart` to use them.
- Modify: `scripts/baseline/raw_textstyle.txt`, `scripts/baseline/future_delayed_production_counts.txt` (lowered ceilings).
- Test: `test/widgets/video_feed_item/actions/video_action_row_test.dart`, `sheet_dismissal_test.dart`, `video_content_action_rules_test.dart`

**Interfaces:**
- Produces:
  - `class VideoActionRowItem` (public `_ActionData`: `icon`, `label`, `onTap`, `isPending`, `isDisabled`, `onShown`).
  - `class VideoActionRow extends StatelessWidget` — `VideoActionRow({required List<VideoActionRowItem> actions, String? title})`; renders the title (if any) with `VineTheme.titleSmallFont(color: context.vineColors.primaryText)` (or the closest existing `VineTheme` font to 16/w600) and the 86-px horizontal list. Labels use a `VineTheme` font in place of the raw 11-px `TextStyle`.
  - `class ClipTitleSheet` with `static Future<String?> show({required BuildContext context, required String initialTitle})`.
  - `void dismissSheet(BuildContext sheetContext)` — `_safePop` body (mounted guard, GoRouter pop, Navigator fallback).
  - `Future<T?> presentAfterSheetDismiss<T>(BuildContext sheetContext, Future<T?> Function(BuildContext hostContext) presenter)` — captures root navigator context, `dismissSheet`, `await WidgetsBinding.instance.endOfFrame` (replaces `Future.delayed(Duration.zero)`), checks `hostContext.mounted`, runs `presenter`.
  - `bool canAddVideoToClips({required VideoEvent video, required bool isOwnContent, bool isWeb = kIsWeb})`.

- [ ] **Step 1: Write failing tests:**
  - `VideoActionRow` renders each item's label; tapping calls `onTap`; `isPending` shows `DivineCircularProgressIndicator` and ignores taps; `title: null` renders no heading.
  - `presentAfterSheetDismiss` from inside a sheet opened with `VineBottomSheet.show` pops the sheet, then runs `presenter` with a mounted host context (assert sheet gone and presenter called once).
  - `canAddVideoToClips`: true for classic Vine / own / `allowVideoReuse`; false for a plain other-person video; false for any video with `isWeb: true`.
- [ ] **Step 2: Run, expect failure** — `mise exec -- flutter test test/widgets/video_feed_item/actions/video_action_row_test.dart test/widgets/video_feed_item/actions/sheet_dismissal_test.dart test/widgets/video_feed_item/actions/video_content_action_rules_test.dart`.
- [ ] **Step 3: Implement** the four files and switch the share sheet to them (`_MoreActionsSection` builds `VideoActionRowItem`s and returns `VideoActionRow(title: context.l10n.shareSheetMoreActions, ...)`; `_safePop` / `_presentAfterDismiss` call sites use the shared functions; `canAddVideoToClips` replaces the inline condition).
- [ ] **Step 4: Run** the new tests and `test/widgets/video_feed_item/actions/share_action_button_test.dart` → PASS. Then `bash scripts/check_raw_textstyle_ceiling.sh` and `bash scripts/check_future_delayed_production_ceiling.sh`; they report the lowered counts — lock with `UPDATE_BASELINE=1` for each. Run `bash scripts/check_ui_service_boundary.sh` → PASS.
- [ ] **Step 5: Commit** — `refactor(share-sheet): extract the action row, clip title prompt and sheet dismissal for reuse`.

### Task 3: Share sheet runs content actions through the shared bloc

**Files:**
- Create: `lib/widgets/video_feed_item/actions/video_content_action_feedback.dart`
- Modify: `lib/blocs/share_sheet/share_sheet_bloc.dart`, `share_sheet_event.dart`, `share_sheet_state.dart`, `reportable_sites.dart` — delete the five moved handlers, their events, `ShareSheetSaveResult`, `ShareSheetVideoClipImportResult`, `ShareSheetBookmarkStatus`, `isSaving`, `bookmarkStatus`, the `bookmarksRepository` / `videoClipImportService` constructor params, and the `eventJson` / `eventId` values of `ShareSheetCopiedKind`.
- Modify: `lib/widgets/owner_video_actions_sheet.dart` — make `_confirmAndDelete` public as `confirmAndDeleteOwnerVideo` and build the success snackbar before `onDeleted` runs.
- Modify: `share_action_button.dart`, `share_sheet_more_actions.dart`.
- Test: move the corresponding groups out of `test/blocs/share_sheet/share_sheet_bloc_test.dart` (now covered by Task 1); update `share_action_button_test.dart`; add `test/widgets/video_feed_item/actions/video_content_action_feedback_test.dart`; extend `test/widgets/owner_video_actions_sheet_test.dart` (or its existing test file).

**Interfaces:**
- Consumes: Task 1 bloc/state/results; Task 2 `dismissSheet`, `presentAfterSheetDismiss`, `ClipTitleSheet`, `canAddVideoToClips`.
- Produces:
  - `void showVideoContentActionFeedback(BuildContext sheetContext, VideoContentActionResult result)` — the share sheet's existing `ShareSheetSaveResult` / `ShareSheetVideoClipImportResult` / event-copy / failure branches of `_handleActionResult`, moved: dismiss the sheet, then snackbar (same copy, same failure mapping) or clipboard + snackbar.
  - `class VideoContentActionsFeedbackListener extends StatelessWidget` — `BlocListener<VideoContentActionsBloc, VideoContentActionsState>` with `listenWhen: (p, c) => c.actionResult != null && p.actionResult != c.actionResult`, calling `showVideoContentActionFeedback` (guard `ModalRoute.of(context)?.isCurrent == false` as today).
  - `Future<void> requestAddToClips(BuildContext sheetContext)` — reads `VideoContentActionsBloc`, awaits `ClipTitleSheet.show(initialTitle: bloc.defaultClipTitle)`, dispatches `VideoContentAddToClipsRequested(libraryTitle:)` if non-null and mounted.
  - `Future<void> confirmAndDeleteOwnerVideo({required BuildContext context, required VideoEvent video, required OwnerVideoActionsCubit cubit, Future<void> Function()? onDeleted})`.

- [ ] **Step 1: Write failing tests:**
  - `showVideoContentActionFeedback` inside a sheet: `VideoContentSaveResult(succeeded: true)` → sheet closed and `l10n.shareAddedToBookmarks` snackbar; `failure: timedOut` → `l10n.profileSetupNoRelaysConnected`; `VideoContentClipImportResult(succeeded: true, libraryTitle: 'x')` → `l10n.shareSheetSavedClipToClips('x')`; `VideoContentCopiedToClipboard(kind: eventId)` → clipboard holds the text and `l10n.shareCopiedEventId` shows.
  - `confirmAndDeleteOwnerVideo` with `onDeleted` that pops the sheet: the success snackbar still appears (Review Focus 5).
  - `share_action_button_test.dart`: existing Save / Add to clips / event-copy tests pass against the new bloc (update their setup to the new provider).
- [ ] **Step 2: Run, expect failure** for the new tests.
- [ ] **Step 3: Implement.** The share sheet creates `VideoContentActionsBloc` in `initState` (same `ref.read`s it passes today) `..add(const VideoContentBookmarkStatusRequested())`, closes it in `dispose`, provides it with `BlocProvider.value` beside `ShareSheetBloc`, wraps the view in `VideoContentActionsFeedbackListener`, and reads `isSaving` / `bookmarkStatus` from it for the Save item. Delete calls `confirmAndDeleteOwnerVideo(..., onDeleted: () async => dismissSheet(context))`. Remove the share sheet's own `_handleDeleteVideo` / `_deleteVideo` and the moved `_handleActionResult` branches. Drop `share_action_button.dart`'s `video_clip_import_service.dart` import if now unused.
- [ ] **Step 4: Run** `mise exec -- flutter test test/blocs/share_sheet test/blocs/video_content_actions test/widgets/video_feed_item/actions test/widgets/owner_video_actions_sheet_test.dart test/widgets/profile test/widgets/composable_video_grid_test.dart` → PASS (the last two cover the other `confirmAndDeleteOwnerVideo` callers; skip any path that does not exist). `bash scripts/check_ui_service_boundary.sh` → if `share_action_button.dart` no longer imports services it reports STALE: lock with `UPDATE_BASELINE=1`. Run `bash scripts/check_post_close_emit_ceiling.sh` → PASS.
- [ ] **Step 5: Commit** — `refactor(share-sheet): run save, add-to-clips and event copy through the shared video actions bloc`.

### Task 4: Action row in the info sheet

**Files:**
- Create: `lib/widgets/video_feed_item/metadata/metadata_actions_section.dart`
- Modify: `lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart` (ABOUTME + class doc no longer "read-only, no new BLoC"; `show` provides the blocs; `_MetadataContent` inserts the section after `MetadataStatsRow`).
- Test: `test/widgets/video_feed_item/metadata/metadata_actions_section_test.dart`; keep `metadata_expanded_sheet_test.dart` green.

**Interfaces:**
- Consumes: Tasks 1–3 (`VideoContentActionsBloc`, `VideoActionRow`, `VideoActionRowItem`, `canAddVideoToClips`, `requestAddToClips`, `presentAfterSheetDismiss`, `dismissSheet`, `confirmAndDeleteOwnerVideo`, `VideoContentActionsFeedbackListener`).
- Produces: `class MetadataActionsSection extends ConsumerWidget` — `MetadataActionsSection({required VideoEvent video})`. Renders `SizedBox.shrink()` when no `VideoContentActionsBloc` is provided (keeps the `@visibleForTesting` constructor path working). `isOwnContent` = `context.read<OwnerVideoActionsCubit?>() != null`.

- [ ] **Step 1: Write failing tests** (pump the section inside `testMaterialApp` with `BlocProvider<VideoContentActionsBloc>` from a mocked bloc and, for own videos, a mocked `OwnerVideoActionsCubit`; override `isFeatureEnabledProvider`):
  - classic Vine, not own: shows Save, Add to clips, Add to list; no Edit/Delete, no Event JSON.
  - own video: Edit and Delete come first, then Save.
  - plain other-person video with `allowVideoReuse == false`: no Add to clips.
  - debug tools on: Event JSON and Event ID shown, tapping Event ID adds `VideoContentCopyEventIdRequested`.
  - Save while `isSaving` shows the pending spinner; tap adds nothing.
  - Signed-out viewer (no owner cubit, bloc built with `bookmarksRepository: null` via a real bloc): tapping Save shows `l10n.shareFailedToAddBookmark` and does not throw (Review Focus 3).
  - Tapping Add to clips opens `ClipTitleSheet` prefilled with `defaultClipTitle`; confirming adds `VideoContentAddToClipsRequested(libraryTitle: ...)`.
  - `metadata_expanded_sheet_test.dart`: new test that `MetadataExpandedSheet.show` renders the action row between the stats row and the Creator section (compare `tester.getTopLeft` y of the three).
- [ ] **Step 2: Run, expect failure** — `mise exec -- flutter test test/widgets/video_feed_item/metadata/`.
- [ ] **Step 3: Implement.** In `show`, read from the container: `authServiceProvider` (owned iff authenticated and `currentPublicKeyHex == video.pubkey`), `currentEnvironmentProvider`, `bookmarksRepositoryProvider`, `videoClipImportServiceProvider`, and the three `OwnerVideoActionsCubit` dependencies exactly as `_UnifiedShareSheetState.initState` passes them. Add `BlocProvider<VideoContentActionsBloc>(create: ... ..add(const VideoContentBookmarkStatusRequested()))` and, when owned, `BlocProvider<OwnerVideoActionsCubit>(create: ...)`. Wrap `_MetadataContent` in `VideoContentActionsFeedbackListener`. Item handlers: Edit → `presentAfterSheetDismiss(context, (host) => VideoMetadataEditRouteData(videoId: video.id, $extra: video).push<void>(host))`, skipped while `cubit.isDeleteInProgress(video.id)`; Delete → `confirmAndDeleteOwnerVideo(..., onDeleted: () async => dismissSheet(context))`; Add to list → `presentAfterSheetDismiss(context, (host) => showSelectListSheet(host, video: video))`; Add to clips → `requestAddToClips(context)`; Save / event copy → bloc events.
- [ ] **Step 4: Run** `mise exec -- flutter test test/widgets/video_feed_item/` → PASS.
- [ ] **Step 5: Commit** — `feat(info-sheet): add video actions to the info sheet`.

### Task 5: Verify and open the PR

- [ ] **Step 1:** `mise exec -- dart format` on every changed Dart file; `mise exec -- flutter analyze lib test integration_test` → no issues.
- [ ] **Step 2:** `bash scripts/ci/run_guards.sh` → all guards pass (lock any further lowered ceilings with `UPDATE_BASELINE=1` and commit).
- [ ] **Step 3:** `ls test/goldens/**/ | grep -i -E "share|metadata"`. If a golden covers either sheet, regenerate on the runner (`gh workflow run "Mobile CI" --ref feat/info-sheet-video-actions -f update_goldens=true`), download the `goldens` artifact and commit it.
- [ ] **Step 4:** `git fetch origin && git rebase origin/main`, re-run Step 1, `git push --force-with-lease -u origin feat/info-sheet-video-actions > /tmp/push.log 2>&1`.
- [ ] **Step 5:** Open the PR against `main`, title `feat(info-sheet): add save, add-to-clips, list, edit and delete actions to the info sheet`, body per the spec (state that the row's look is a placeholder for design, and what was not verified on device). Request review from Sebastian. `gh pr checks <n> --watch`, then read the per-check table; fix anything red.
