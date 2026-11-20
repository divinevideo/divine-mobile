# Highlight Invite Friends Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On days a creator posted, the daily highlight card in Inbox shows a "Bring your friends in →" row that opens the share sheet with the download link, at most 3 posting days a week per account.

**Architecture:** The repository decides eligibility (posted today, weekly limit) and exposes it as `CreatorHighlight.showInvite`; it also persists the weekly record. The cubit records the invite as seen when the card is presented. The card renders the row and opens the share sheet itself, anchored to the row.

**Tech Stack:** Flutter, flutter_bloc, SharedPreferences, share_plus via `showShareSheet`, ARB l10n.

**Spec:** `docs/superpowers/specs/2026-11-20-highlight-invite-friends-design.md`

## Global Constraints

- Link: `AppConstants.downloadUrl` (`https://divine.video/download`); no new constant.
- Share only through `showShareSheet` from `mobile/lib/utils/share_sheet.dart`.
- Row copy: "Bring your friends in" (arrow is the existing `DivineIconName.arrowRight`, as on "See your stats").
- Share message: "Come make loops with me on Divine. React, comment, and collab with me in the app: {url}"
- Weekly limit: 3 posting days per Monday-start week, per account, counted when the row is seen; the same day counts once.
- No new dependencies, permissions, or backend changes. No invite codes or gating.
- Colors through `context.vineColors` (same `accentPositive` as the stats link); text through `VineTheme.*Font()`.
- New ARB keys are read in the same change; new prefs key is classified for account cleanup.
- Run Flutter commands from `mobile/`. Tests mirror `lib/` under `mobile/test/` and live inside `group()`.

## Review Focus

1. Account switch: one account's weekly record must not suppress or enable another's row. (Task 1 test.)
2. A new Monday resets the count even if last week hit the limit. (Task 1 test.)
3. Several showings in one day (rotation advances, Inbox remounts) count as one day. (Task 1 and Task 2 tests.)
4. A storage failure while recording the invite must not hide the card or break the feed. (Task 2 test.)
5. Tapping the invite row must not also open stats. (Task 3 test.)

---

### Task 1: Eligibility and weekly record in the repository

**Files:**
- Modify: `mobile/lib/features/creator_highlights/creator_highlight.dart`
- Modify: `mobile/lib/features/creator_highlights/creator_highlights_repository.dart`
- Modify: `mobile/lib/services/user_data_cleanup_service.dart` (`identityChangePrefixes` ~line 316, and both `presentationKey(userPubkey)` removals ~lines 519 and 853)
- Test: `mobile/test/features/creator_highlights/creator_highlights_repository_test.dart`, `mobile/test/features/creator_highlights/creator_highlight_test.dart`

**Interfaces:**
- Produces:
  - `CreatorHighlight.showInvite` (`bool`, constructor `this.showInvite = false`), carried by `copyWith` unchanged and included in `props`.
  - `CreatorHighlightsRepository.markInviteShown(String owner, String localDate) → Future<void>`; throws `CreatorHighlightPresentationException` when storage rejects the write.
  - `FunnelcakeCreatorHighlightsRepository.invitePrefix = 'creator_highlight_invite_'`, `inviteKey(String owner)`, `maxInviteDaysPerWeek = 3`.

- [ ] **Step 1: Write failing tests** in the repository test, new `group('invite')`, using the file's existing fakes and a fixed `now`:
  - `'offers the invite on a day with a publication today'`: today's video → `card!.showInvite` is `true`.
  - `'withholds the invite when nothing was published today'`: only an earlier-this-week video → `showInvite` is `false`.
  - `'withholds the invite after three posting days this week'`: prefs `inviteKey(owner)` = `'<monday>|<mon>,<tue>,<wed>'`, now Thursday with a video today → `false`.
  - `'keeps the invite on a day already counted'`: same three dates, now Wednesday → `true`.
  - `'a new week resets the limit'`: marker for last week's Monday with three dates, now the following Monday → `true`.
  - `'another account's record does not apply'`: limit-reached marker under a different owner's key → `true` for `owner`.
  - `markInviteShown`: two calls with the same `localDate` store one date (`'<monday>|<date>'`); a call in a new week replaces the old record; a rejected write throws `CreatorHighlightPresentationException`.
  - In `creator_highlight_test.dart`: `copyWith(rotation: 1)` keeps `showInvite: true`, and two highlights differing only in `showInvite` are not equal.

- [ ] **Step 2: Run them and confirm they fail**

Run: `cd mobile && flutter test test/features/creator_highlights/creator_highlights_repository_test.dart test/features/creator_highlights/creator_highlight_test.dart`
Expected: compile errors for `showInvite`, `inviteKey`, `markInviteShown`.

- [ ] **Step 3: Implement.** Record format `'<weekStart yyyy-MM-dd>|<date>,<date>'`, Monday-start like `load`'s `weekStart` (extract a small private date-formatting helper rather than duplicating the padding expression). In `load`, `showInvite = createdToday > 0 && (dates.contains(date) || dates.length < maxInviteDaysPerWeek)`, where a record for another week reads as empty. `markInviteShown` derives the week from `DateTime.parse(localDate)`. Add `invitePrefix` to `identityChangePrefixes` and remove `inviteKey(userPubkey)` beside both `presentationKey(userPubkey)` removals.

- [ ] **Step 4: Run tests and the prefs guard**

Run: `cd mobile && flutter test test/features/creator_highlights/ && bash scripts/check_prefs_key_classification.sh`
Expected: all pass; guard reports no unclassified key. The cubit test's `_Repository` fake (the only other implementer) needs `markInviteShown` to compile: add it now, recording calls into `final invites = <(String, String)>[]` and throwing `inviteError` when set. Task 2 uses it.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/creator_highlights mobile/lib/services/user_data_cleanup_service.dart mobile/test/features/creator_highlights
git commit -m "feat(creator-highlights): decide when to invite friends from the highlight"
```

### Task 2: Record the invite when the card is seen

**Files:**
- Modify: `mobile/lib/features/creator_highlights/creator_highlights_cubit.dart` (`presented`)
- Test: `mobile/test/features/creator_highlights/creator_highlights_cubit_test.dart` (and the `_Repository` fake there)

**Interfaces:**
- Consumes: `CreatorHighlight.showInvite`, `CreatorHighlightsRepository.markInviteShown` (Task 1).

- [ ] **Step 1: Write failing tests** in `group('presented')`, using the `invites` / `inviteError` fake from Task 1:
  - `'records the invite with each showing that offers it'`: present a `showInvite: true` card, refresh to the next rotation, present that card → `invites` equals `[(owner, today), (owner, today)]` (the repository counts the day once, Task 1).
  - `'does not record an invite the card did not offer'`: `showInvite: false` → `invites` is empty, `presented` still has one entry.
  - `'an invite storage failure keeps the card and reports'`: `inviteError = const CreatorHighlightPresentationException()` → `state.card` is still the card, `markPresented` still ran, and the cubit emitted the error (use the file's existing error-observation pattern from `'reports storage failure without replaying the celebration'`).

- [ ] **Step 2: Run and confirm failure**

Run: `cd mobile && flutter test test/features/creator_highlights/creator_highlights_cubit_test.dart`
Expected: the new tests fail.

- [ ] **Step 3: Implement.** In `presented`, after the existing guard and before or alongside `markPresented`, call `markInviteShown(owner, card.localDate)` when `card.showInvite`, in its own try/catch that reports with `asReportableError(error, context: 'CreatorHighlightsCubit.inviteShown') ?? error` and otherwise continues. A failure in one write must not skip the other.

- [ ] **Step 4: Run tests**

Run: `cd mobile && flutter test test/features/creator_highlights/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/creator_highlights/creator_highlights_cubit.dart mobile/test/features/creator_highlights/creator_highlights_cubit_test.dart
git commit -m "feat(creator-highlights): count an invite when the highlight is seen"
```

### Task 3: Invite row on the card and the share message

**Files:**
- Modify: `mobile/lib/features/creator_highlights/creator_highlight_card.dart`
- Modify: `mobile/lib/l10n/app_en.arb`, generated files under `mobile/lib/l10n/generated/`
- Modify: `mobile/test/l10n/arb_consistency_test.dart` (`_knownUntranslatedDebt`, until Task 5)
- Test: `mobile/test/features/creator_highlights/creator_highlight_card_test.dart`

**Interfaces:**
- Consumes: `CreatorHighlight.showInvite` (Task 1).
- Produces: ARB keys `creatorHighlightInvite` ("Bring your friends in") and `creatorHighlightInviteMessage` (the share message, `{url}` String placeholder, with a `description`).

- [ ] **Step 1: Write failing widget tests** in the card test, using the share-channel interception pattern from `test/screens/settings/settings_share_divine_test.dart` (handler on `MethodChannel('dev.fluttercommunity.plus/share')`, cleared in `tearDown`), strings resolved from `AppLocalizations`:
  - `'shows the invite row when the highlight offers it'` / `'hides the invite row otherwise'`.
  - `'tapping the invite row shares the download link and does not open stats'`: tap `find.text(l10n.creatorHighlightInvite)` → one share call whose text equals `l10n.creatorHighlightInviteMessage(AppConstants.downloadUrl)`; `onAnalytics` count stays 0.
  - `'the invite row is its own button for screen readers'`: `tester.getSemantics` on the row has the label `l10n.creatorHighlightInvite` and the button flag.

- [ ] **Step 2: Run and confirm failure**

Run: `cd mobile && flutter test test/features/creator_highlights/creator_highlight_card_test.dart`
Expected: the new tests fail.

- [ ] **Step 3: Implement.** Add the two ARB keys, run `flutter gen-l10n`, list both keys in `_knownUntranslatedDebt`. Add a private `_InviteAction` widget under the stats row, shown when `highlight.showInvite`: same layout and style as the stats row, wrapped in `Semantics(container: true, button: true, label: …)` and its own `InkWell` so the tap does not reach the card's `onTap`; on tap, `showShareSheet(context, ShareParams(text: l10n.creatorHighlightInviteMessage(AppConstants.downloadUrl)))` through `runDetached` (logName `CreatorHighlights`), using the row's own `context` so iPad anchors to it.

- [ ] **Step 4: Run tests, l10n checks, analyze, format**

Run: `cd mobile && flutter test test/features/creator_highlights/ test/l10n/arb_consistency_test.dart test/tools/share_sheet_entry_point_test.dart && bash scripts/check_orphaned_arb_key_floor.sh && bash scripts/check_divine_ui_semantic_label_defaults.sh && dart format lib/features/creator_highlights test/features/creator_highlights && flutter analyze lib test integration_test`
Expected: all pass, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/creator_highlights mobile/lib/l10n mobile/test
git commit -m "feat(creator-highlights): invite friends from the daily highlight"
```

### Task 4: Demo in the iOS simulator on the local stack (Matt's gate)

No code. Nothing is pushed or opened as a PR before Matt has seen this.

- [ ] **Step 1: Start the stack.** `export BLOSSOM_PUBLIC_URL=http://localhost:43003 && local_stack/up.sh`. Expected: services healthy per `local_stack/preflight.sh`.
- [ ] **Step 2: Build and run** from `mobile/`: `flutter run -d <iPhone simulator> --dart-define=DEFAULT_ENV=LOCAL` (if the Swift package floor error appears, see `.claude/rules/ios_build_troubleshooting.md` Cause 3). Simulator UI is in Xcode's DeviceHub app.
- [ ] **Step 3: Walk the path with Matt.** Sign in to a local account, post a loop, open Inbox: the card shows "Bring your friends in →"; tapping it opens the share sheet with the message and link; tapping the card body still opens stats.
- [ ] **Step 4: Show the hidden cases.** An account with no post today shows no row. Seed `creator_highlight_invite_<pubkey>` with three other dates this week (developer tooling or a debug prefs write, reverted afterward) and confirm the row is hidden.
- [ ] **Step 5: Capture screenshots** (light and dark) for the PR, and note any copy or timing changes Matt asks for; apply them as a follow-up commit through Task 3's tests.

### Task 5: Translations, then PR (after Matt approves the copy)

- [ ] **Step 1:** Translate both keys into every `app_*.arb` per `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`, keep `{url}` intact, remove them from `_knownUntranslatedDebt`, run `flutter gen-l10n` and `flutter test test/l10n/`. Expected: PASS.
- [ ] **Step 2:** Commit: `feat(l10n): translate the highlight invite`.
- [ ] **Step 3:** Rebase on `origin/main`, run `bash scripts/ci/run_guards.sh` and the creator-highlights tests, then ask Matt draft vs ready per his PR rules (reviewers: rabble for the card, plus the mapped team). Title: `feat(creator-highlights): invite friends on days you post`.
