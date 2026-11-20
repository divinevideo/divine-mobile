# Highlight Invite Friends Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On days a creator posted, the daily highlight card in Inbox shows a "Bring your friends →" link that opens an editable invite page, which shares the message plus the download link, at most 3 posting days a week per account.

> **Revision (after the first simulator review):** Tasks 1-3 are done. Tasks 6 and 7 replace Task 3's in-card share with an invite page, and run before Tasks 4 and 5.

**Architecture:** The repository decides eligibility (posted today, weekly limit) and exposes it as `CreatorHighlight.showInvite`; it also persists the weekly record. The card reports the invite as seen after the invite's label and arrow paint on screen (measured separately from the card, the taller tap target, and spotlight presentation), and the cubit records that day. The card renders the link and hands the tap to Inbox, which pushes the invite page; the page shares through `showShareSheetAtOrigin`, anchored to its Share button.

> **As built (after review):** the page leaves (back to the previous screen, or to Inbox when opened directly by a link or reload) unless the share sheet was dismissed, so an unknown outcome is treated as shared; if another route arrived on top while the sheet was up, the page stays underneath it. One share runs at a time, owned by `InviteFriendsCubit`. A failed share (any ordinary exception) shows an error snackbar and keeps the page open. The route has its own `RouteType.inviteFriends` so tab history does not record it as Home. The field caps at 6 lines, and the link note is its own text under the field so it never truncates. Strings are translated in all locales, with ungendered wording where the first pass used a masculine plural.

**Tech Stack:** Flutter, flutter_bloc, SharedPreferences, share_plus via `showShareSheet`, ARB l10n.

**Spec:** `docs/superpowers/specs/2026-11-20-highlight-invite-friends-design.md`

## Global Constraints

- Link: `AppConstants.downloadUrl` (`https://divine.video/download`); no new constant.
- Share only through `showShareSheet` from `mobile/lib/utils/share_sheet.dart`.
- Link copy: "Bring your friends" (arrow is the existing `DivineIconName.arrowRight`, as on "See your stats"), on the same line as "See your stats".
- Default message: "I'm making loops on Divine. You can react and collaborate with me!" The link is always appended on its own line when shared; a cleared message shares only the link.
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
  - `'withholds the invite after three posting days this week'`: prefs `inviteKey(owner)` = `'<mon>,<tue>,<wed>'` (as built: sorted dates, no week prefix), now Thursday with a video today → `false`.
  - `'keeps the invite on a day already counted'`: same three dates, now Wednesday → `true`.
  - `'a new week resets the limit'`: three dates from last week, now the following Monday → `true`.
  - `'another account's record does not apply'`: limit-reached marker under a different owner's key → `true` for `owner`.
  - `markInviteShown`: two calls with the same `localDate` store one date (`'<date>'`); dates older than about two weeks are dropped while last week's stay, so a local date stepping back across a Monday still counts them; a rejected write throws `CreatorHighlightPresentationException`.
  - In `creator_highlight_test.dart`: `copyWith(rotation: 1)` keeps `showInvite: true`, and two highlights differing only in `showInvite` are not equal.

- [ ] **Step 2: Run them and confirm they fail**

Run: `cd mobile && flutter test test/features/creator_highlights/creator_highlights_repository_test.dart test/features/creator_highlights/creator_highlight_test.dart`
Expected: compile errors for `showInvite`, `inviteKey`, `markInviteShown`.

- [ ] **Step 3: Implement.** Record format (as built after review: sorted `yyyy-MM-dd` dates from about the last two weeks; originally `'<weekStart yyyy-MM-dd>|<date>,<date>'`), Monday-start like `load`'s `weekStart` (extract a small private date-formatting helper rather than duplicating the padding expression). In `load`, `showInvite = createdToday > 0 && (dates.contains(date) || dates.length < maxInviteDaysPerWeek)`, where a record for another week reads as empty. `markInviteShown` derives the week from `DateTime.parse(localDate)`. Add `invitePrefix` to `identityChangePrefixes` and remove `inviteKey(userPubkey)` beside both `presentationKey(userPubkey)` removals.

- [ ] **Step 4: Run tests and the prefs guard**

Run: `cd mobile && flutter test test/features/creator_highlights/ && bash scripts/check_prefs_key_classification.sh`
Expected: all pass; guard reports no unclassified key. The cubit test's `_Repository` fake (the only other implementer) needs `markInviteShown` to compile: add it now, recording calls into `final invites = <(String, String)>[]` and throwing `inviteError` when set. Task 2 uses it.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/creator_highlights mobile/lib/services/user_data_cleanup_service.dart mobile/test/features/creator_highlights
git commit -m "feat(creator-highlights): decide when to invite friends from the highlight"
```

### Task 2: Record the invite when the card is seen

> **Superseded by review:** counting no longer rides `presented()`. The card measures the invite link's own visibility and calls `onInviteSeen`, which the Inbox wires to `CreatorHighlightsCubit.inviteSeen`; see "As built" above. The steps below record the original approach.

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

### Task 6: One-line links, shorter copy, card hands the tap up

**Files:**
- Modify: `mobile/lib/features/creator_highlights/creator_highlight_card.dart`, `mobile/lib/features/creator_highlights/creator_highlights_inbox_view.dart`
- Modify: `mobile/lib/l10n/app_en.arb` (`creatorHighlightInvite` → "Bring your friends"; remove `creatorHighlightInviteMessage`), generated l10n, `_knownUntranslatedDebt`
- Test: `mobile/test/features/creator_highlights/creator_highlight_card_test.dart`

**Interfaces:**
- Produces: `CreatorHighlightCard({..., required VoidCallback onInvite})`; the inbox view wires it to `const InviteFriendsRouteData().push<void>(context)` through its existing `_open` (Task 7 defines the route; until then, wire a temporary no-op only if Task 7 lands in the same commit series before any commit that would not compile).

- [ ] **Step 1: Rewrite the invite tests** in the card test: tapping the row calls `onInvite` once and `onAnalytics` zero times; the share-channel interception and message assertion are removed from this file (sharing moves to the page). Keep the visibility, semantics and no-double-announcement tests. Add: `'both links share a line when they fit'`: at the default test width, `tester.getTopLeft` of the stats text and the invite text have equal `dy`.
- [ ] **Step 2: Run and confirm failure** (`onInvite` undefined; same-line test fails).
- [ ] **Step 3: Implement.** Put the stats row and `_InviteAction` in a `Wrap(spacing: 20, crossAxisAlignment: WrapCrossAlignment.center)`; `_InviteAction` takes the callback instead of sharing. Drop the share-sheet import from the card. Update the ARB key value and remove the message key.
- [ ] **Step 4: Run** `flutter test test/features/creator_highlights/ test/l10n/arb_consistency_test.dart`, orphaned-ARB and semantic-label guards, analyze. Expected: PASS.
- [ ] **Step 5: Commit** with Task 7 if the route is needed to compile (see Interfaces); message `feat(creator-highlights): put both highlight links on one line`.

### Task 7: The invite page

**Files:**
- Create: `mobile/lib/features/creator_highlights/invite_friends_screen.dart`
- Modify: `mobile/lib/router/route_paths.dart` (`inviteFriends = '/invite-friends'`), `mobile/lib/router/routes/video_routes.dart` (+ regenerated `video_routes.g.dart`)
- Modify: `mobile/lib/l10n/app_en.arb` (`inviteFriendsTitle` "Bring your friends", `inviteFriendsMessageLabel` "Your message" for the field's label/semantics, `inviteFriendsDefaultMessage`, `inviteFriendsShare` "Share"), generated l10n, `_knownUntranslatedDebt`
- Test: `mobile/test/features/creator_highlights/invite_friends_screen_test.dart`

**Interfaces:**
- Produces: `InviteFriendsScreen` (`routeName = 'invite-friends'`, `path = RoutePaths.inviteFriends`), `InviteFriendsRouteData` (root navigator, like `CreatorAnalyticsRouteData`), and a top-level `String inviteShareText(String message, String url)` returning `url` when `message.trim()` is empty, else `'${message.trim()}\n$url'`.

- [ ] **Step 1: Write failing tests** (share-channel interception as in `settings_share_divine_test.dart`):
  - `inviteShareText`: message + newline + url; whitespace-only message → url alone.
  - `'starts with the default message and shows the link'`.
  - `'shares the edited message and the link'`: `enterText` a new message, tap Share → one share call whose text is `inviteShareText(edited, AppConstants.downloadUrl)`.
  - `'a cleared message shares only the link'`.
  - `'a completed share returns'` / `'a dismissed share stays'`: channel returns a success activity vs `''` (share_plus's dismissed result); assert the page pops or stays (pump it under a `MaterialApp` with a home that pushes it).
- [ ] **Step 2: Run and confirm failure.**
- [ ] **Step 3: Implement.** A `StatefulWidget` owning a `TextEditingController` seeded from `inviteFriendsDefaultMessage` (as built after review, the share status, duplicate suppression and outcome decisions moved into `InviteFriendsCubit`, per the repo's rule that a Cubit owns loading/error/success state). App-bar title from `inviteFriendsTitle`. Multiline field per `ui_theming.md` (`.multiline`, `newline`, `.sentences`, `maxLines: 6` as built, `minLines: 3`), the link as secondary text below, a `DivineButton` labelled `inviteFriendsShare`. On tap: capture `shareAnchorForContext` of the button before awaiting, `showShareSheetAtOrigin`, then leave unless the result is `dismissed` (see "As built" above). Add the route and run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4: Run** the new test, highlight tests, `test/l10n/`, routing guards (`check_literal_navigation_paths.sh`, `check_hand_written_route_ceiling.sh`, `check_layer_direction.sh`), analyze, format. Expected: PASS.
- [ ] **Step 5: Commit** `feat(creator-highlights): let people edit the invite before sharing`.

### Task 4: Demo in the iOS simulator on the local stack (product review gate)

No code. Nothing is pushed or opened as a PR before the product owner has seen it.

- [ ] **Step 1-2 (revised):** the simulator cannot post, so build with the throwaway demo patch (highlight always reports a post today; scratchpad `apply_demo.py`) against `DEFAULT_ENV=PRODUCTION`, then revert the patch before any commit. Simulator UI is in Xcode's DeviceHub app.
- [ ] **Step 3: Walk the path with the product owner.** Sign in, open Inbox: the card shows "See your stats →" and "Bring your friends →" on one line; tapping the invite opens the invite page; editing the message and sharing hands the share sheet the message and link; tapping the card body still opens stats.
- [ ] **Step 4: Show the hidden cases.** An account with no post today shows no row. Seed `creator_highlight_invite_<pubkey>` with three other dates this week (developer tooling or a debug prefs write, reverted afterward) and confirm the row is hidden.
- [ ] **Step 5: Capture screenshots** (light and dark) for the PR, and note any copy or timing changes requested; apply them as a follow-up commit through Task 3's tests.

### Task 5: Translations, then PR (after the copy is approved)

- [ ] **Step 1:** Translate the seven current keys (`creatorHighlightInvite`, `inviteFriendsTitle`, `inviteFriendsMessageLabel`, `inviteFriendsDefaultMessage`, `inviteFriendsLinkNote`, `inviteFriendsShare`, `inviteFriendsShareFailed`; the original `creatorHighlightInviteMessage` was removed in Task 6) into every `app_*.arb` per `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`, keep `{url}` intact, remove them from `_knownUntranslatedDebt`, run `flutter gen-l10n` and `flutter test test/l10n/`. Expected: PASS.
- [ ] **Step 2:** Commit: `feat(l10n): translate the highlight invite`.
- [ ] **Step 3:** Rebase on `origin/main`, run `bash scripts/ci/run_guards.sh` and the creator-highlights tests, then decide draft vs ready (reviewers: the card's author, plus the mapped team). Title: `feat(creator-highlights): invite friends on days you post`.
