# Tag Limit Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the tags picker turns a tag away because the video already has 10, say so in warning colour, say how to make room, and keep the typed text.

**Architecture:** Extend the design lead's `TagsPickerNotice` (#10053) with a `tagLimitReached` reason set by `TagsPickerBloc._withAddedTags`. `_TagInputHint` renders a new string in `accentWarning` for that notice and keeps the existing muted line for the plain at-limit state. `_addTag` keeps the field text when `TagsPickerState.turnsAwayAtLimit(raw)` is true, and both submit paths announce repeat rejections with `announceDetached`.

**Tech Stack:** Flutter, flutter_bloc, bloc_test, gen-l10n (ARB).

**Spec:** `docs/superpowers/specs/2026-11-18-tag-limit-feedback-design.md`

All paths below are relative to `mobile/` unless they start with `docs/`.

## Global Constraints

- The 10-tag limit (`HashtagExtractor.maxHashtagsPerVideo`) and its enforcement do not change.
- New ARB key `videoMetadataTagsPickerTagLimitRemoveToAdd`, English: `{max, plural, one{You can add up to {max} hashtag. Remove it to make room.} other{You can add up to {max} hashtags. Remove one to make room.}}`, with `{max}` an `int` placeholder.
- The existing `videoMetadataTagsPickerTagLimitReached` string is not edited (translations stay valid); the social sticker sheet keeps using it.
- Warning colour is `context.vineColors.accentWarning`; muted stays `context.vineColors.onSurfaceMuted`. No green for a rejection.
- Mirror the new key into all 22 non-English `app_*.arb` files following `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`, and read it through `context.l10n` in the same commit (orphan ratchet).
- Widget tests use `appLocalizationsDelegates` via the existing `_buildTestApp`; assertions resolve strings with `lookupAppLocalizations(const Locale('en'))`, never hardcoded English.

## Review Focus

1. **Typing a tag then a space at 10** (the separator path, not return): the warning must appear. The typed text is cleared on this path, a known limit the design accepts; Task 2 pins the warning.
2. **Re-submitting a tag the video already has, while at 10**: not a rejection: no new notice, no announcement, and a warning already showing stays. Tasks 1 and 2 pin it.
3. **A sticker hashtag filling the 10th slot**: sticker tags count toward the limit, so a new tag is turned away with the warning. Task 1 pins it.
4. **Submitting an empty field at 10**: must not announce or warn. Task 2 pins it.
5. **Removing a tag after a rejection, then pressing return again**: warning clears and the kept text is added. Task 2 pins it.

---

### Task 1: Bloc reports a limit rejection

**Files:**
- Modify: `lib/blocs/tags_picker/tags_picker_state.dart` (`TagsPickerNotice`, `turnsAwayAtLimit`)
- Modify: `lib/blocs/tags_picker/tags_picker_bloc.dart` (`_withAddedTags`, its doc comment, `_onQueryChanged`)
- Test: `test/blocs/tags_picker/tags_picker_bloc_test.dart`, group `'$TagsPickerBloc hashtag limits'`

**Interfaces:**
- Produces: `TagsPickerNotice.tagLimitReached` — doc: a valid tag not already on the video was dropped because the video carries `HashtagExtractor.maxHashtagsPerVideo` tags.
- Produces: `TagsPickerState.turnsAwayAtLimit(String raw)` — whether committing `raw` would be turned away for the limit.

- [ ] **Step 1: Write the failing tests** in the existing `'$TagsPickerBloc hashtag limits'` → `TagsPickerTagsAdded` group, reusing its `createBloc`, `ten`, `tooLong`:
  - Replace `'ignores further tags once the limit is reached'` (expects no emit today) with `'flags a tag turned away at the limit'`: seed `ten`, add `['eleven']`, expect one state with `selectedTags == ten.toSet()` and `notice == TagsPickerNotice.tagLimitReached`.
  - `'flags the overflow of a pasted list'`: initial = first 9 of `ten`, add `['a', 'b']`, expect `selectedTags` = 9 + `'a'`, notice `tagLimitReached`.
  - `'does not flag a tag the video already has'`: seed `ten`, add `['tag3']`, expect `const <TagsPickerState>[]`.
  - `'limit notice wins over a too-long tag in the same paste'`: initial = first 9, add `[tooLong, 'x', 'y']`, expect `'x'` added and notice `tagLimitReached`.
  - In the `TagsPickerTagRemoved` group: `'clears a limit notice'` mirroring the existing too-long one with `notice: TagsPickerNotice.tagLimitReached`.
  - In the `TagsPickerQueryChanged` group: `'keeps a limit notice when the cleared field sends an empty query'` and `'keeps a limit notice while typing at the limit'`, both seeded with ten tags and `notice: TagsPickerNotice.tagLimitReached`, `wait` past the debounce as the neighbouring debounce tests do, and the notice stays `tagLimitReached`.
  - `'keeps a limit notice when a tag the video already has is committed'`: seed ten tags and the limit notice, add `['tag3']`, expect no emit.
  - In the `sticker tags` group: `'flags a tag turned away when a sticker fills the last slot'`: bloc with 9 initial tags and one sticker tag (construct as that group does), add `['new']`, expect notice `tagLimitReached`; and `'does not flag a sticker hashtag at the limit'` adding the sticker's own tag, expect no emit.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/blocs/tags_picker/tags_picker_bloc_test.dart`
Expected: FAIL — `tagLimitReached` undefined (compile error).

- [ ] **Step 3: Add `TagsPickerNotice.tagLimitReached` and rewrite `_withAddedTags`**

Order matters: normalize and dedupe before the limit check, and `continue` (not `break`) so later tokens are still classified.

```dart
var droppedForLimit = false;
var droppedForLength = false;
for (final raw in rawTokens) {
  final tag = HashtagExtractor.normalizeVideoHashtag(raw);
  if (tag == null) {
    if (raw.length > HashtagExtractor.maxHashtagLength) droppedForLength = true;
    continue;
  }
  if (state.stickerTags.contains(tag) || updated.contains(tag)) continue;
  if ({...state.stickerTags, ...updated}.length >=
      HashtagExtractor.maxHashtagsPerVideo) {
    droppedForLimit = true;
    continue;
  }
  updated.add(tag);
}
```

Notice: `tagLimitReached` if `droppedForLimit`, else `tagTooLong` if `droppedForLength`, else `none`. Keep `_onTagsAdded`'s `if (next != state) emit(next)`. Update the method doc to mention the new notice.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/blocs/tags_picker/tags_picker_bloc_test.dart`
Expected: all pass, including every pre-existing test.

- [ ] **Step 5: Mutation check** — temporarily make `_withAddedTags` never set `tagLimitReached`; confirm the new limit tests go red; restore.

- [ ] **Step 6: Commit**

```bash
git add lib/blocs/tags_picker test/blocs/tags_picker
git commit -m "fix(hashtags): report when a tag is turned away at the 10-tag limit"
```

---

### Task 2: Picker shows the warning, keeps the text, announces repeats

**Files:**
- Modify: `lib/l10n/app_en.arb` and all 22 other `lib/l10n/app_*.arb`
- Regenerate: `lib/l10n/generated/*` via `flutter gen-l10n`
- Modify: `lib/widgets/video_metadata/video_metadata_tags_selector.dart` (`_TagsPickerViewState._addTag`, `_onSearchChanged`, `_TagInputHint`)
- Test: `test/widgets/video_metadata/video_metadata_tags_selector_test.dart`, group `'hashtag limits'`

**Interfaces:**
- Consumes: `TagsPickerNotice.tagLimitReached`, `TagsPickerState.isAtTagLimit`, `TagsPickerState.notice`, `TagsPickerState.turnsAwayAtLimit` (Task 1).
- Produces: `AppLocalizations.videoMetadataTagsPickerTagLimitRemoveToAdd(int max)`.

- [ ] **Step 1: Add the ARB key** to `app_en.arb` after `videoMetadataTagsPickerTagLimitReached`, with an `@` entry: description "Warning under the tags field when a tag was not added because the video already has the maximum number of hashtags.", placeholder `max` type `int`. Translate into every other locale, starting from that locale's existing `videoMetadataTagsPickerTagLimitReached` and adding the remedy in the register `LOCALIZATION_STYLE_GUIDE.md` sets for it, with every plural category the locale's existing string uses. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget tests** in `'hashtag limits'`, using its `openPicker`, with `final tenTags = {for (var i = 0; i < 10; i++) 'tag$i'};` and `warning = l10n.videoMetadataTagsPickerTagLimitRemoveToAdd(HashtagExtractor.maxHashtagsPerVideo)`, `standing = l10n.videoMetadataTagsPickerTagLimitReached(...)`. Submit with `await tester.testTextInput.receiveAction(TextInputAction.done)`, then `pump` and `pump(400ms)` like the neighbours.
  - `'pressing return at the limit keeps the tag and explains why'`: open with `tenTags`, `enterText(field, 'news')`, submit. Expect `find.text(warning)` one, `find.text(standing)` nothing, the field's `TextField.controller!.text == 'news'`, and no chip `'news'` (`find.bySemanticsLabel(l10n.videoMetadataDeleteTagHint('news'))` finds nothing).
  - `'removing a tag after a rejection clears the warning and lets the tag in'`: as above, then tap `find.bySemanticsLabel(l10n.videoMetadataDeleteTagHint('tag0'))` (`warnIfMissed: false`), pump; expect `warning` gone; submit again; expect a `'news'` delete-hint chip and the controller empty.
  - `'pressing return below the limit still clears the field'`: open with 9 tags, enter `'news'`, submit; expect controller empty and the `'news'` chip present.
  - Extend `'explains the tag limit once a video has 10 tags'`: after `'eleven '`, expect `find.text(warning)` one and `find.text(standing)` nothing.
  - `'announces a repeat rejection'`: capture `SystemChannels.accessibility` announcements exactly as `test/widgets/support_capped_text_field_test.dart` `'announces every rejection'` does (mock handler + `addTearDown` nulling it). Open with `tenTags`, enter `'news'`, submit twice. Expect `announcements.where((m) => m == warning)` has length 1 (the first is carried by the hint's live region).
  - `'submitting an empty field at the limit says nothing new'`: open with `tenTags`, submit with empty field; expect `find.text(standing)` one, `find.text(warning)` nothing, and zero captured announcements.

- [ ] **Step 3: Run to verify they fail**

Run: `flutter test test/widgets/video_metadata/video_metadata_tags_selector_test.dart`
Expected: the new tests FAIL (warning not found / controller cleared).

- [ ] **Step 4: Implement**
  - `_TagInputHint`: helper selection becomes notice `tagLimitReached` → `l10n.videoMetadataTagsPickerTagLimitRemoveToAdd(max)` in `accentWarning`; else `isAtTagLimit` → existing standing string, muted; else the existing too-long/counter logic unchanged. Keep the `Semantics(liveRegion: true)` wrapper. Update its doc comment.
  - `_addTag(String raw)`: read `final bloc = context.read<TagsPickerBloc>()`. If `bloc.state.turnsAwayAtLimit(raw)`: call `_announceRepeatLimitRejection(bloc.state, [raw])`, dispatch `TagsPickerTagsAdded([raw])` and return without clearing the field or dispatching `TagsPickerSearchCleared`. Else if `bloc.state.isAtTagLimit` (an empty return or a tag the video already has): clear the field and dispatch nothing, which leaves any notice in place. Otherwise behave as today. One-line comment on why the text stays (the creator can add it once a tag is removed).
  - `_announceRepeatLimitRejection(state, tokens)`: when `state.notice` is already `tagLimitReached` and any token `turnsAwayAtLimit`, call `announceDetached` (import `package:openvine/utils/semantics_announcement.dart`) as `announceDetached(context, context.l10n.videoMetadataTagsPickerTagLimitRemoveToAdd(HashtagExtractor.maxHashtagsPerVideo), description: 'announce repeated tag limit rejection', logName: 'VideoMetadataTagsSelector')`.
  - `_onSearchChanged` calls the same `_announceRepeatLimitRejection` before dispatching, so a repeat rejection ended with a space, or pasted in a list, is announced too.

- [ ] **Step 5: Run to verify they pass, plus the l10n and selector suites**

Run: `flutter test test/widgets/video_metadata test/blocs/tags_picker test/l10n/arb_consistency_test.dart`
Expected: all pass.

- [ ] **Step 6: Mutation checks** — (a) make `_addTag` clear unconditionally: the keep-text tests go red; (b) drop the `announceDetached` call: the repeat test goes red; (c) render the warning with the standing string: the warning tests go red. Restore each.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n lib/widgets/video_metadata test/widgets/video_metadata
git commit -m "fix(hashtags): explain why a tag isn't added once a video has 10"
```

---

### Task 3: Verify, review, and hand Matt a local build

**Files:**
- Commit: `docs/superpowers/specs/2026-11-18-tag-limit-feedback-design.md`, this plan.
- Modify only if a guard requires it: `mobile/scripts/baseline/*`.

- [ ] **Step 1: Static checks** — from `mobile/`: `dart format` on changed Dart files; `flutter analyze lib test integration_test` → no issues; `bash scripts/ci/run_guards.sh` → all pass (orphan ARB, plural-category floor, raw-colors, l10n delegates in particular).
- [ ] **Step 2: l10n check** — run the `check-l10n` skill; resolve or justify every finding.
- [ ] **Step 3: Commit the docs** — `git add docs/superpowers && git commit -m "docs(hashtags): design and plan for tag limit feedback"`.
- [ ] **Step 4: Adversarial review** — `superpowers:requesting-code-review` on `origin/main...HEAD`, briefed with #11226 and the spec, not my conclusions; resolve every clear finding; re-review until clean.
- [ ] **Step 5: Local build for Matt** — boot an iPhone simulator, `flutter build ios --config-only --simulator`, check the Swift package floor (`.claude/rules/ios_build_troubleshooting.md`, Cause 3), `flutter run` against staging. Screenshot the picker at 10 tags in dark and light: the standing line, the warning after a rejected tag with the text still in the field, and the cleared state after removing a tag. Hand Matt the screenshots and the running simulator for his own check.
- [ ] **Step 6: Stop.** No push or PR until Matt confirms the build. Then `superpowers:finishing-a-development-branch` and his "Opening my PRs" flow (ask draft vs ready, with a fit-and-size review verdict).
