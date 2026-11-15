# Remix Consent and Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "Remix this video" the headline of the info sheet — import the video and open the editor with it — under a remix-by-default consent rule creators can switch off per video or per account, with locked credit, a "From others" Library tab, a Remixes list and a "Report this remix" path.

**Architecture:** Builds on the branch's existing `VideoContentActionsBloc`, shared action items and info-sheet action section (revision 1). Consent is one pure rule (`canRemixVideo`) plus an async account check through `RemixConsentRepository`, which reads the author's raw kind 0 with `ProfileReader.readRawProfileFromRelays`; the remix itself is a new bloc event whose result the info sheet turns into navigation. The Library gains an ownership scope on the existing clip grid, driven by a persisted `importedSource` marker on `DivineVideoClip`.

**Tech Stack:** Flutter, flutter_bloc, Riverpod (DI reads only), Drift (clips table `data` JSON column — no schema change), nostr_client `Filter(a:)` queries, mocktail, bloc_test.

**Spec:** `docs/superpowers/specs/2026-11-14-info-sheet-video-actions-design.md` — Revision 3 and Revision 2 sections. Research notes with file:line facts (cited below as "research §N") were kept in a local-only, git-ignored file and are not in the repo.

## Global Constraints

- All Flutter commands from `mobile/` via `mise exec -- flutter ...`; `flutter test` needs `--no-pub` in this worktree.
- Consent table (exact): no `allow_video_reuse` tag → remixable; `["allow_video_reuse","true"]` → remixable; `["allow_video_reuse","false"]` → not remixable unless classic Vine; classic Vine (`video.isOriginalVine`) → remixable whatever its tag; creator account block → not remixable, overrides all; the viewer's own video → always remixable by them; a sound that forbids derivatives still writes `false` at publish (`offersVideoReuse`), unchanged.
- The editor's video-reuse switch defaults to **on** for new posts.
- Account-wide block: kind 0 content key `divine_allow_video_reuse` with JSON boolean `false` = blocked; absent or `true` = allowed. Written only by the creator's own setting.
- Account check fails **closed**: if no read of the author's raw kind 0 settles the answer (all timed out, refused or threw), Remix/Add to clips refuses with a retry message. A read that confirms the author has no kind 0 allows.
- Button label everywhere: "Remix this video". New strings (en): "Remix this video", "Remixing happens in the Divine app.", "Get the app", "From others", "This creator doesn't allow remixes.", "Couldn't check whether this video can be remixed. Try again.", "Let people remix my videos" (+ one-line subtitle "Others can use your videos as clips in their own posts."), "Uses a clip from {name}", "Remixes", "Report this remix". Every new key mirrored into all `app_*.arb` locales (translated per `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`) in the task that adds it, and read through `context.l10n` in the same task.
- Info sheet action row for everyone: Edit, Delete (own only), Save. Not in the info sheet: Add to list, Event JSON, Event ID, small Add to clips circle. Share sheet keeps all its actions.
- Remix on web: same button; tap shows a snackbar "Remixing happens in the Divine app." with action "Get the app" opening `AppConstants.downloadUrl` in the external browser.
- Repo guards apply (no raw TextStyle/colors/Future.delayed in new files; widgets don't import `package:openvine/services/`; baselines only shrink; orphan ARB ratchet; l10n delegates in tests; tests in groups). New Dart files start with two `// ABOUTME: ` lines.
- No republishing of archived Vines. No server/funnelcake changes.

## Review Focus

1. **Tapping Remix twice / tapping Remix on a Vine already in the library:** no duplicate clip; the existing plain import is reused. Test in Task 4.
2. **An in-progress autosaved editor session when Remix is tapped:** it is saved to Drafts before the remix session starts, and still listed there afterwards. Test in Task 4.
3. **Author's profile unreachable (offline, relay timeout):** Remix and Add to clips refuse with the retry message; nothing is imported. Test in Task 2.
4. **A reaction the viewer built from a Vine (split-screen render / merge):** stays in Clips, not From others, and is never picked as the Vine's duplicate. Test in Task 3.
5. **Remix on a video reply / a video whose `addressableId` is null:** the Remixes section is hidden instead of querying an empty coordinate, and the remix still credits the source. Test in Task 6.

---

### Task 1: Remix-by-default consent rule and switch default

**Files:**
- Modify: `mobile/lib/blocs/video_content_actions/video_content_action_rules.dart` (replace `canAddVideoToClips`; the file has since moved here from `lib/widgets/video_feed_item/actions/`)
- Modify: every caller of `canAddVideoToClips` (`share_action_button.dart`, `metadata_actions_section.dart`, `video_content_action_items.dart` if used)
- Modify: `mobile/packages/models/lib/src/video_event.dart:1153` (`allowVideoReuse` getter doc + semantics)
- Modify: `mobile/lib/models/video_editor/video_editor_provider_state.dart:35` and the draft model default (`allowVideoReuse` in `lib/models/divine_video_draft.dart`) → default `true`
- Modify: `mobile/docs/NOSTR_VIDEO_EVENTS.md` "Divine Reuse Markers"
- Test: `mobile/test/blocs/video_content_actions/video_content_action_rules_test.dart`, `mobile/packages/models/test/...video_event...` (the file covering `allowVideoReuse`), editor state default test

**Interfaces:**
- Produces: `bool canRemixVideo({required VideoEvent video, required bool isOwnContent})` — pure tag/ownership rule, no platform and no account check. `VideoEvent.allowVideoReuse` now means "the event does not decline": `_firstNostrTagValue('allow_video_reuse') != 'false'`.

- [ ] **Step 1: Tests** — `canRemixVideo` returns: true for no tag; true for `true`; false for `false`; true for `false` on a classic Vine (`platform=vine`); true for own video with `false`. `VideoEvent.allowVideoReuse` true when the tag is absent or malformed, false only for exact `false`. A fresh `VideoEditorProviderState().allowVideoReuse == true` and a draft created without the field restores `true`; a draft saved with `false` restores `false`.
- [ ] **Step 2: Run, expect FAIL** — `mise exec -- flutter test --no-pub test/blocs/video_content_actions/video_content_action_rules_test.dart` and the models test file.
- [ ] **Step 3: Implement.** Rename and rewrite the rule; callers keep their `!kIsWeb` gate only where the share sheet's Add to clips needs it (`canRemixVideo(...) && !kIsWeb`). Update the doc table to the consent table in Global Constraints.
- [ ] **Step 4: Run** the task's tests plus `test/widgets/video_feed_item/` and `test/widgets/video_metadata/` → PASS; `flutter analyze lib test`.
- [ ] **Step 5: Commit** — `feat(video-reuse): allow remixing unless the creator declines`.

### Task 2: Account-wide remix block

**Files:**
- Modify: `mobile/packages/profile_repository/lib/src/profile_repository.dart` — `saveProfileEvent` gains `bool? allowVideoReuse` (precedent: `monetizationLinks`, key constant like `divineMonetizationLinksKey`); include it in the pending-save payload the method already serializes.
- Modify: `mobile/packages/models/lib/src/user_profile.dart` — `bool get allowsVideoReuse` reading `rawData['divine_allow_video_reuse'] != false`.
- Create: `mobile/lib/repositories/remix_consent_repository.dart`
- Create: `mobile/lib/blocs/remix_settings/remix_settings_cubit.dart` (+ state); a `DivineSwitchTile` in `PrivacySettingsScreen` (or the closest existing settings screen per research §2)
- Modify: `VideoContentActionsBloc` — Add to clips consults the consent repository before importing (non-owner only)
- Modify: `docs/NOSTR_EVENT_TYPES.md` (kind 0 field)
- Test: package test for the new param/key; `test/repositories/remix_consent_repository_test.dart`; cubit test; bloc tests; settings widget test

**Interfaces:**
- Produces:
  - `const divineAllowVideoReuseKey = 'divine_allow_video_reuse'` (models).
  - `class RemixConsentRepository { RemixConsentRepository({required ProfileReader profileRepository, required String defaultRelayUrl}); Future<RemixConsent> consentFor(String authorPubkey); }` with `enum RemixConsent { allowed, blocked, unknown }`. It reads `readRawProfileFromRelays` from every connected relay and from `defaultRelayUrl` alone; `blocked` for the author's `false`, `allowed` for a kind 0 that does not block or a conclusive read finding none, and `unknown` only when no read settles it. Provided via a Riverpod provider beside `profileRepositoryProvider`.
  - `VideoContentActionsBloc` gains `RemixConsentRepository? remixConsentRepository` and `String? viewerPubkey`; new result `VideoContentRemixRefused({required RemixConsent consent})`.
- Consumes: Task 1 `canRemixVideo`.

- [ ] **Step 1: Tests** — `saveProfileEvent(allowVideoReuse: false)` publishes content containing `"divine_allow_video_reuse": false` and preserves other raw keys; omitting it preserves an existing value. `consentFor` → `blocked` for raw `false`, `allowed` for absent/true, `unknown` when the fetch throws. Bloc: Add to clips on a non-owned video with `blocked` emits `VideoContentRemixRefused(consent: blocked)` and never calls the importer; `unknown` emits `VideoContentRemixRefused(consent: unknown)`; own video skips the check. Settings: toggling off calls `saveProfileEvent(..., allowVideoReuse: false)`; a failed save reverts the switch and shows the existing profile-save failure copy.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Feedback: `VideoContentRemixRefused` maps to "This creator doesn't allow remixes." (blocked) or "Couldn't check whether this video can be remixed. Try again." (unknown) in `showVideoContentActionFeedback`. Cubit follows `MonetizationLinksSettingsCubit` (load, and a fresh read before every save, via `readFreshProfile(requireRawKind0: true)`; save via `saveProfileEvent`).
- [ ] **Step 4: Run** profile_repository package tests (`cd packages/profile_repository && mise exec -- flutter test --no-pub --coverage`; keep its coverage floor), models tests, and the app tests touched → PASS; guards `check_untested_services_floor`, `check_ui_service_boundary`.
- [ ] **Step 5: Commit** — `feat(video-reuse): let creators block remixing on their whole account`.

### Task 3: Import marker and the "From others" Library tab

**Files:**
- Modify: `mobile/lib/models/divine_video_clip.dart` — `final bool importedSource` (JSON key `importedSource`, default false) + `copyWith`; legacy fallback getter.
- Modify: `mobile/lib/services/video_clip_import_service.dart` — every import path (`importToLibrary`, received DM clip, received Vine) sets `importedSource: true`.
- Modify: `mobile/lib/services/clip_library_service.dart` — `Future<DivineVideoClip?> findImportedClipOf(VideoEvent video)`.
- Modify: `mobile/lib/blocs/clips_library/` — ownership scope.
- Modify: `mobile/lib/screens/library_screen.dart` — `_LibraryTab.fromOthers`; tab order Drafts, Clips, From others, Sounds; selection mode shows a two-tab bar (Clips, From others).
- Test: model JSON round-trip, import service, clip library service, bloc, library screen widget tests.

**Interfaces:**
- Produces:
  - `bool DivineVideoClip.isFromOthers(String? viewerPubkey)` — `importedSource && sourceAuthorPubkey != viewer` for new clips; for clips without the field (legacy): id starts with `video_`, `classic_vine_` or `dm_clip_` and `sourceAuthorPubkey != null && != viewer`. Derived prefixes (`merged_`, `clip_library_`, `split_layout_`, `clip_`) are never from others.
  - `ClipLibraryService.findImportedClipOf(VideoEvent video)` → newest non-trashed clip with `importedSource` (or legacy import prefix) whose first source credit matches `video.id` or `video.addressableId`; null otherwise.
  - `enum ClipOwnershipScope { own, fromOthers }`; `ClipsLibraryEvent` `ClipsLibraryScopeChanged(ClipOwnershipScope)`; state field `scope`; grid shows `filter.admits(clip) && scopeAdmits(clip)`; selection survives scope changes; bloc takes `viewerPubkey`.

- [ ] **Step 1: Tests** — round-trip keeps `importedSource`; legacy JSON without it reads false; `isFromOthers`: plain Vine import by someone else → true; same import credited to viewer → false; `split_layout_` clip carrying another's credit → false (Review Focus 4); `findImportedClipOf` returns the import, ignores a derived clip with the same credit and trashed clips; bloc: scope switch filters, selection preserved across scopes; Library screen shows four tabs in order with `withoutSounds` dropping Sounds, and selection mode shows Clips + From others tabs and can select across both.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** The From others tab reuses `ClipsTab` with the bloc scope set on tab change; viewer pubkey from `ref.read(authServiceProvider).currentPublicKeyHex`. All three selection-mode callers (`video_editor_screen.dart` add-clips and `_pickLayoutCellClips`, `conversation_view.dart` DM attach) get the tabs with no caller change if the screen owns them; otherwise update each.
- [ ] **Step 4: Run** `test/models test/services test/blocs/clips_library test/screens test/widgets/library` (paths that exist) → PASS; guards `check_hand_written_route_ceiling`, `check_l10n_delegates_ceiling`.
- [ ] **Step 5: Commit** — `feat(library): keep clips from other people in their own From others tab`.

### Task 4: Remix flow and the info sheet's Remix button

**Files:**
- Modify: `VideoContentActionsBloc` — new event/result.
- Create: `mobile/lib/widgets/video_feed_item/metadata/metadata_remix_button.dart`
- Create: `mobile/lib/widgets/video_feed_item/actions/remix_launcher.dart` (navigation side of a ready remix)
- Modify: `mobile/lib/widgets/video_feed_item/metadata/metadata_actions_section.dart` — items become Edit, Delete (own), Save only.
- Modify: `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart` — Remix button directly after `MetadataStatsRow`, above the action row.
- Test: bloc tests, button widget tests, launcher tests.

**Interfaces:**
- Consumes: Task 1 `canRemixVideo`; Task 2 consent check + `VideoContentRemixRefused`; Task 3 `findImportedClipOf`, `importedSource`.
- Produces:
  - Event `VideoContentRemixRequested()` (`droppable()`), state flag `isPreparingRemix`, result `VideoContentRemixReady({required DivineVideoClip clip})`. Flow: owner check → the per-video rule (`canRemixVideo`) and the account consent (non-owner) → `findImportedClipOf` → else `importToLibrary(video)` with the default title (no prompt) → `VideoContentRemixReady`. Import failure → existing `VideoContentClipImportResult(succeeded: false)`.
  - `Future<void> openRemixInEditor(BuildContext sheetContext, WidgetRef ref, DivineVideoClip clip)`: if `DraftStorageService.draftExists(autoSaveId)` and that draft has clips, save it as a new regular draft (`saveDraft` with a fresh id, then the Drafts tab lists it); `videoPublishProvider.notifier.clearAll(keepAutosavedDraft: false)`; `clipManagerProvider.notifier.insertClip(0, clip)`; dismiss the sheet; `VideoEditorRouteData(from: VideoEditorScreen.libraryOrigin).push<void>(hostContext)`. Back-out is the editor's existing save/discard prompt (a timeline with a credited clip counts as edited); no extra return handling.
  - `MetadataRemixButton({required VideoEvent video})` — `DivineButton(label: l10n.<remixThisVideo>, expanded: true, isLoading: isPreparingRemix)`; visible iff `canRemixVideo(video:, isOwnContent:)`; on web (`kIsWeb`) tap shows the app nudge snackbar with "Get the app" → `launchUrl(Uri.parse(AppConstants.downloadUrl), mode: LaunchMode.externalApplication)`.

- [ ] **Step 1: Tests** — bloc: remix on a non-owned allowed video imports and emits `VideoContentRemixReady`; a second request reuses `findImportedClipOf` (importer called once across two remixes — Review Focus 1); refused consent emits `VideoContentRemixRefused`; `isPreparingRemix` true while running, false on every refused or failed path, and still true with a ready result until `VideoContentRemixLaunchFinished`. Launcher: an autosave with clips is saved as a new draft before the clip manager is cleared, and the clip manager then holds exactly the remix clip (Review Focus 2); no autosave → no draft written. Widget: button label is the l10n string; hidden when `canRemixVideo` is false; loading state ignores taps; on web (inject a platform flag the widget reads, defaulting to `kIsWeb`) tap shows the nudge and does not dispatch the bloc event. Info sheet: order is Remix button, then Edit, Delete, Save; Add to list / Event JSON / Event ID absent with debug tools on.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** The section listens for `VideoContentRemixReady` (in the feedback listener or a dedicated `BlocListener`) and calls `openRemixInEditor`. Remove the info sheet's Add to list / debug / small Add to clips items; shared item factories stay for the share sheet.
- [ ] **Step 4: Run** `test/blocs/video_content_actions test/widgets/video_feed_item test/widgets/share_video_menu_comprehensive_test.dart` → PASS; `flutter analyze lib test`.
- [ ] **Step 5: Commit** — `feat(info-sheet): remix a video straight into the editor`.

### Task 5: Locked credit while posting, and credit on replies

**Files:**
- Modify: `mobile/lib/providers/video_editor_provider.dart` — public `List<ClipSourceCredit> get clipSourceCredits` (wraps `_clipSourceCreditsFromClips`).
- Create: `mobile/lib/widgets/video_metadata/video_metadata_clip_credits.dart`
- Modify: `mobile/lib/widgets/video_metadata/video_metadata_form_fields.dart` — insert after `VideoMetadataInspiredByInput` (~L193).
- Modify: `mobile/packages/models/lib/src/video_event.dart` `creditedInspiredByPubkeys` — include clip-source credits on replies too.
- Test: widget test for the row; models test; publish test.

**Interfaces:**
- Produces: `VideoMetadataClipCredits` — one row per credited author other than the viewer: "Uses a clip from {name}" (profile display name, falling back to the full npub rendered with ellipsis), no remove control, semantics label equal to the text.

- [ ] **Step 1: Tests** — row renders for a timeline with a reused clip and has no tappable remove; absent with no credits. Models: a reply event with a `clip-source` credit lists that author in `creditedInspiredByPubkeys`. Publish: `VideoEventPublisher` with `clipSourceCredits` set and inspired-by cleared still writes `["a", coord, relay, "clip-source"]` and the `p` tag; `VideoMetadataUpdateService` edit keeps them.
- [ ] **Step 2: Run, expect FAIL** (the publish/edit tests may already pass — then they are pinning tests; record that in the report).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the touched test files + `packages/models` tests → PASS.
- [ ] **Step 5: Commit** — `feat(video-metadata): show the clip credit while posting and keep it on replies`.

### Task 6: Remixes list and "Report this remix"

**Files:**
- Modify: the repository that owns video-by-tag reads (`mobile/packages/video_responses_repository` per research §4) — `Future<List<VideoEvent>> fetchRemixesOf(String addressableId, {int limit = 50})`.
- Create: `mobile/lib/widgets/video_feed_item/metadata/metadata_remixes_section.dart` (+ a small cubit under `lib/widgets/video_feed_item/metadata/` like `video_reposters_cubit.dart`)
- Modify: `metadata_expanded_sheet.dart` — section after Inspired by; "Report this remix" item.
- Modify: `mobile/lib/widgets/report_content_dialog.dart` only if needed to open from the info sheet (it already takes `video`).
- Test: repository test (package coverage floor), cubit test, widget tests.

**Interfaces:**
- Produces: `fetchRemixesOf` queries `Filter(kinds: [NIP71VideoKinds.addressableShortVideo], a: [addressableId], limit:)` and keeps only events whose `clipSourceCredits` include that coordinate, newest first, deduped by addressable id. `MetadataRemixesSection({required VideoEvent video})` — hidden when `video.addressableId` is null/empty or the list is empty; each row opens the remix like other video chips in the sheet. "Report this remix": a `VideoActionRowItem` shown in the info sheet's row when the video's `clipSourceCredits` include the viewer; tap → `ReportContentDialog.show(context, video: video)` after dismissing the sheet.

- [ ] **Step 1: Tests** — repository: returns only clip-source referencers (an event a-tagging the coordinate as inspired-by or reply parent is excluded), newest first; empty on no results. Section: hidden for null `addressableId` (Review Focus 5) and for zero results; lists rows otherwise. Report item: shown only when the viewer is credited; tap opens the report dialog.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** package tests with coverage, app tests touched → PASS.
- [ ] **Step 5: Commit** — `feat(info-sheet): list a video's remixes and let a credited creator report one`.

### Task 7: Verify, screenshots, PR update

- [ ] **Step 1:** `git fetch origin && git rebase origin/main`; confirm all branch commits survive (`git log --oneline origin/main..HEAD`).
- [ ] **Step 2:** `mise exec -- dart format` changed files; `mise exec -- flutter analyze lib test integration_test`; `cd mobile && bash scripts/ci/run_guards.sh` (lock lowered ceilings with `UPDATE_BASELINE=1`); `mise exec -- flutter test --no-pub test/l10n/arb_consistency_test.dart`; run every test directory the tasks touched.
- [ ] **Step 3:** Run the app on macOS (`mise exec -- flutter run -d macos` from `mobile/`, or the iOS simulator) and capture screenshots: classic Vine info sheet (Remix button + Save), own video info sheet (Edit, Delete, Save), the editor opened by Remix, the From others tab, the posting screen's locked credit row, the account setting. Web nudge: `flutter run -d chrome` or the PR preview. Save PNGs outside the repo; attach them to the PR description via `gh` (upload as a PR comment image) — state any screenshot that could not be captured and why.
- [ ] **Step 4:** Push (`git push --force-with-lease > /tmp/push.log 2>&1`), update the PR #11054 title/body (Conventional Commit title; describe revision 3, consent table, the 2026-11-15 data check, what was not verified), `gh pr checks 11054 --watch`, read the per-check table.
