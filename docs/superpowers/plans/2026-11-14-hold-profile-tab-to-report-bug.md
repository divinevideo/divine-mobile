# Hold the Profile Tab to Report a Bug Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pressing and holding the Profile tab opens Report a Bug from any screen with the bottom bar. On iOS the form slides up; Android is unchanged. TalkBack and VoiceOver can reach the shortcut, and the dead shake detector is deleted.

**Architecture:** Two PRs to `main`.

- **PR 1** deletes `ShakeDetectorService`, its test and `sensors_plus`.
- **PR 2** adds four things on the existing `/support-center/report-bug` route:
  - a hold handler and semantics on the Profile tab in `VineBottomNav`;
  - a `?entry=profile-hold` marker on the route URL;
  - an `iosModalPage` helper that makes the route a full-screen dialog on iOS only;
  - a tip line in `BugReportScreen` that the marker hides.

No new state, providers, packages or native code.

**Tech Stack:** Flutter 3.47.9 (pinned by mise), go_router 18, flutter_riverpod (legacy DI), `material_ui`, flutter_test + mocktail, gen-l10n ARB in 23 locales.

**Spec:** `docs/superpowers/specs/2026-11-14-hold-profile-tab-to-report-bug-design.md`

## Global Constraints

- Supported range: Android 9 (API 28, `minSdk = 28`) through Android 17 (API 37); iOS 16 (deployment target 16.0) through iOS 27. No OS-version-specific code.
- No new dependencies. PR 1 only removes `sensors_plus: ^7.0.0`.
- Import `package:material_ui/material_ui.dart` or `package:flutter/widgets.dart`, never `package:flutter/material.dart`.
- Navigate with `RoutePaths` members, never a literal path (`check_literal_navigation_paths.sh`). Edit the existing typed `BugReportRouteData`; add no hand-written route (`check_hand_written_route_ceiling.sh`). `route_paths.dart` stays import-free.
- Every new ARB key is read through `context.l10n` in the same commit, exists in all 23 `mobile/lib/l10n/app_*.arb` files, and is translated per `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`.
  - Every file uses 2-space indentation.
  - Key order and `@` blocks follow each file's own existing shape: insert next to the neighbouring key and match it.
  - Insert each key by hand, file by file; never round-trip the JSON.
- Fire-and-forget work goes through `runDetached`. Logs go through `Log.*`.
- Widget tests use `appLocalizationsDelegates` and read copy through `AppLocalizations`, never hardcoded English. Every test sits in a `group`. No `Future.delayed`.
- New Dart files start with two `// ABOUTME:` lines.
- Commit subjects are `type(scope): summary`. Run `/verify` before every commit that changes production code (not for docs-only or tests-only commits).
- Run Flutter and Dart from `mobile/` through `mise exec --`. In a fresh worktree, run `mise exec -- flutter pub get` before any `dart format`; otherwise format rewrites every file.
- Never press Send Report on a device, emulator or simulator run: it files a real, public GitHub issue.
- Never take screenshots of the user's physical phones. Screenshots come from simulators and emulators only.
- Tasks 6 and 7 need the user, for the phones and for approving published text. Run them in the main session, not in a subagent.

## Review Focus

1. **Holding Profile while already on the Profile tab** must open the form, not retry the profile load. Test: Task 5.
2. **Two holds in quick succession** must open one form, not two stacked ones. Check: Task 6, Galaxy.
3. **Closing the form** with Cancel, the arrow, or Android back and predictive back must return to the same screen and scroll position. A video paused while the form was open must resume. Check: Task 6, every target.
4. **At the largest text size** the tip must wrap and nothing may overflow. Check: Task 6, iOS 27 simulator.
5. **A hold while a sheet or dialog covers the bottom bar** must do nothing. Check: Task 6, Galaxy.

---

### Task 1: Remove the dead shake detector (PR 1)

**Files:**
- Delete: `mobile/lib/services/shake_detector_service.dart`
- Delete: `mobile/test/services/shake_detector_service_test.dart`
- Modify: `mobile/pubspec.yaml:435` (remove `  sensors_plus: ^7.0.0`)
- Modify: `mobile/pubspec.lock` (regenerated)

**Interfaces:** none. This is independent of Tasks 2–7 and lives in its own worktree and PR.

- [ ] **Step 1: Create the worktree from fresh `main`** (from the repo root)

```bash
git fetch origin
git worktree add .worktrees/8955-remove-shake-detector -b chore/8955-remove-shake-detector origin/main
```

- [ ] **Step 2: Prove nothing else uses it**

Run: `git grep -n "shake_detector_service\|ShakeDetectorService\|sensors_plus" -- . ':!mobile/pubspec.lock'`
Expected: only the two files being deleted and `mobile/pubspec.yaml:435`. No baseline under `mobile/scripts/baseline/` names them (checked 2026-11-14).

- [ ] **Step 3: Delete both files and the pubspec line**

- [ ] **Step 4: Regenerate the lockfile**

Run: `cd mobile && mise exec -- flutter pub get && git status --short && git diff mobile/pubspec.lock`
Expected:
- The lock diff removes only the `sensors_plus` and `sensors_plus_platform_interface` entries.
- No other package changes version.
- No file under `lib/l10n/generated/` changes (pub get runs gen-l10n).

Any other churn comes from an SDK mismatch: restore the lock and investigate before going on.

- [ ] **Step 5: Verify**

Run from `mobile/`:
- `mise exec -- flutter analyze lib test integration_test` → `No issues found!`
- `bash scripts/check_untested_services_floor.sh` → pass
- `bash scripts/check_dependency_provenance.sh` → pass

Then run `/verify`.

- [ ] **Step 6: Commit**

```
chore(app): remove the unused shake detector and sensors_plus

Nothing constructs ShakeDetectorService outside its own test, and it was the
only importer of sensors_plus. #8955 ruled out shake-to-report, so the
detector and the dependency go.
```

- [ ] **Step 7: Publish PR 1**
  - Rebase on fresh `origin/main` and push with `-u`.
  - Draft the PR body and show it to the user before creating. It contains:
    - a summary and why;
    - `Part of #8955` (not `Closes`: PR 2 closes the issue);
    - the test plan, noting that the lockfile change runs the `iOS Native Tests` job;
    - the Agent identity block (format in Task 7, Step 3).
  - After approval, run `gh pr create --base main --title "chore(app): remove the unused shake detector and sensors_plus" --assignee @me --body-file <file>`, not as a draft. CODEOWNERS requests `divinevideo/reviewers` on its own, so do not pass `--reviewer`.
  - Confirm with `gh pr view <n> --json reviewRequests`.
  - Watch the checks as described in Task 7, Step 6.

---

### Task 2: `iosModalPage` page helper

**Files:**
- Create: `mobile/lib/router/ios_modal_page.dart`
- Test: `mobile/test/router/ios_modal_page_test.dart`

**Interfaces:**
- Produces: `MaterialPage<void> iosModalPage({required GoRouterState state, required Widget child, TargetPlatform? platform})`
  - `fullscreenDialog` is `(platform ?? defaultTargetPlatform) == TargetPlatform.iOS`.
  - The metadata mirrors `fadeUpwardsPage` in `mobile/lib/router/fade_upwards_page.dart`:
    - `key: state.pageKey`
    - `name: goRouterPageName(state)`
    - `arguments: {...state.pathParameters, ...state.uri.queryParameters}`
    - `restorationId: state.pageKey.value`

- [ ] **Step 1: Write the failing tests**

Use `group('iosModalPage', ...)`. Copy the `_FakeGoRouterState` fake from `mobile/test/router/fade_upwards_page_test.dart`, and define a `_state({Uri? uri})` helper that builds it with `pageKey: const ValueKey('support-report-bug')`, `name: 'support-report-bug'` and `path: '/support-center/report-bug'`.

```dart
test('is a full-screen dialog on iOS, so it slides up with no back swipe', () {
  final page = iosModalPage(
    state: _state(),
    child: const SizedBox.shrink(),
    platform: TargetPlatform.iOS,
  );
  expect(page.fullscreenDialog, isTrue);
});

test('is a regular page on Android, so its transition stays as it is', () {
  final page = iosModalPage(
    state: _state(),
    child: const SizedBox.shrink(),
    platform: TargetPlatform.android,
  );
  expect(page.fullscreenDialog, isFalse);
});

test('carries go_router page metadata so observers see a real route name', () {
  final page = iosModalPage(
    state: _state(uri: Uri.parse('/support-center/report-bug?from=test')),
    child: const SizedBox.shrink(),
  );
  expect(page.key, const ValueKey('support-report-bug'));
  expect(page.name, 'support-report-bug');
  expect(page.arguments, {'from': 'test'});
  expect(page.restorationId, 'support-report-bug');
});
```

- [ ] **Step 2: Run and see it fail**

Run: `mise exec -- flutter test test/router/ios_modal_page_test.dart`
Expected: compile error, `iosModalPage` not found.

- [ ] **Step 3: Implement `iosModalPage` in `mobile/lib/router/ios_modal_page.dart`**

Write the doc comment on the function, covering:
- On iOS, the full-screen-dialog flag selects Cupertino's slide-up transition. That also disables the edge back-swipe and holds the screen behind still.
- It stays `false` on Android, where Material would freeze the screen behind during the transition.

- [ ] **Step 4: Run and see it pass**

Run: `mise exec -- flutter test test/router/ios_modal_page_test.dart`
Expected: all 3 pass.

- [ ] **Step 5: Commit** (after `/verify`)

`feat(router): add a page that presents as a modal on iOS only`

---

### Task 3: Shortcut tip in the Report a Bug form

**Files:**
- Modify: `mobile/lib/widgets/bug_report_dialog.dart` (`BugReportScreen`, `_BugReportScreenState.build`, `_BugReportView`)
- Modify: all 23 `mobile/lib/l10n/app_*.arb` files, plus the regenerated `mobile/lib/l10n/generated/*`
- Test: `mobile/test/widgets/bug_report_dialog_test.dart`

**Interfaces:**
- Produces: `BugReportScreen({..., bool showProfileHoldTip = true})` with the field `final bool showProfileHoldTip`.
- Produces: the ARB key `bugReportProfileHoldTip`.

- [ ] **Step 1: Add the string**

In `app_en.arb`, insert directly after `bugReportDiagnosticsNotice`:

```json
"bugReportProfileHoldTip": "Shortcut: when the bottom bar is showing, press and hold your profile picture to report a bug from any screen.",
"@bugReportProfileHoldTip": {
  "description": "Muted line at the bottom of the Report a Bug form, shown unless the form was opened by holding the Profile tab. The tab shows the user's profile picture, not a word. Some people reach this form while the bottom bar is hidden, so keep the 'when the bottom bar is showing' condition. Avoid left/right wording (RTL locales)."
},
```

Mirror it into the other 22 locales with real translations, following each file's indentation (see Global Constraints). Then run `mise exec -- flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Work in `group('bug report flow')`. Give `openFlow` a `bool showProfileHoldTip = true` parameter and forward it to the `BugReportScreen` it builds.

```dart
testWidgets('teaches the Profile-tab shortcut when opened another way', (
  tester,
) async {
  await openFlow(tester);
  final l10n = lookupAppLocalizations(const Locale('en'));
  expect(find.text(l10n.bugReportProfileHoldTip), findsOneWidget);
});

testWidgets('skips the tip when the hold opened the form', (tester) async {
  await openFlow(tester, showProfileHoldTip: false);
  final l10n = lookupAppLocalizations(const Locale('en'));
  expect(find.text(l10n.bugReportProfileHoldTip), findsNothing);
  expect(find.text(l10n.bugReportDiagnosticsNotice), findsOneWidget);
});
```

- [ ] **Step 3: Run and see it fail**

Run: `mise exec -- flutter test test/widgets/bug_report_dialog_test.dart`
Expected: compile error, no named parameter `showProfileHoldTip`.

- [ ] **Step 4: Implement**

- Add `this.showProfileHoldTip = true` to `BugReportScreen`, with a doc comment: false when the Profile-tab hold opened the form, since the tip would only repeat what the user just did.
- Pass it through to `_BugReportView`.
- In the scroll `Column`, directly after the `bugReportDiagnosticsNotice` `Text`, add:
  `if (showProfileHoldTip) Text(l10n.bugReportProfileHoldTip, style: VineTheme.bodySmallFont(color: context.vineColors.mutedText))`

- [ ] **Step 5: Run and see it pass**

Run from `mobile/`:
- `mise exec -- flutter test test/widgets/bug_report_dialog_test.dart test/l10n/arb_consistency_test.dart` → all pass
- `bash scripts/check_orphaned_arb_key_floor.sh` → pass

- [ ] **Step 6: Commit** (after `/verify`)

`feat(support): teach the Profile-tab shortcut in the bug report form`

---

### Task 4: Mark the hold in the report URL and present the form as an iOS modal

**Files:**
- Modify: `mobile/lib/router/route_paths.dart` (after `supportReportBug`, line 112)
- Modify: `mobile/lib/router/routes/settings_routes.dart` (`BugReportRouteData`: an `entry` query parameter, `build` → `buildPage`) and the regenerated `settings_routes.g.dart`
- Modify: `mobile/test/router/route_locations_resolve_test.dart` (`_locations` and `_notLocations`)
- Modify: `mobile/test/router/providers/support_route_trail_provider_test.dart`
- Modify: `mobile/test/router/routes/settings_routes_test.dart`

**Interfaces:**
- Consumes: `iosModalPage` (Task 2) and `BugReportScreen.showProfileHoldTip` (Task 3).
- Produces, on `RoutePaths`:
  - `static const supportReportBugEntryParameter = 'entry';`
  - `static const supportReportBugProfileHoldEntry = 'profile-hold';`
  - `static const supportReportBugFromProfileHold = '$supportReportBug?$supportReportBugEntryParameter=$supportReportBugProfileHoldEntry';`, which is `/support-center/report-bug?entry=profile-hold`

- [ ] **Step 1: Add the three constants**

Add them to `RoutePaths` with a doc comment: the query marks a Report a Bug opened by holding the Profile tab, and the form then skips its shortcut tip.

- [ ] **Step 2: Register them in the resolve test**

- Add `'supportReportBugFromProfileHold': [RoutePaths.supportReportBugFromProfileHold],` to `_locations`.
- Add `'supportReportBugEntryParameter'` and `'supportReportBugProfileHoldEntry'` to `_notLocations`.

Run: `mise exec -- flutter test test/router/route_locations_resolve_test.dart`
Expected: pass.

- [ ] **Step 3: Pin the trail behaviour**

Add this to `group('SupportRouteTrail')`. It passes immediately, because `_isSupportPath` reads `uri.path`; it guards that a report opened by the hold still names the screen it was held from.

```dart
test('treats the hold-marked report location as support', () async {
  final snapshot = await visit([
    '/home/0',
    RoutePaths.supportReportBugFromProfileHold,
  ]);
  expect(snapshot.currentScreen, 'home');
  expect(snapshot.recentScreens, ['home']);
});
```

- [ ] **Step 4: Write the failing route tests**

Add `group('bug report page')` to `test/router/routes/settings_routes_test.dart`, after `group('support forms')`, reusing the file's harness:
- `overrides()` returns `authServiceProvider` and `bugReportServiceProvider` mocks with nothing stubbed, and `supportRouteTrailProvider.overrideWith(_FixedTrail.new)`.
- `_page(location, context)` resolves `location` in the settings table and calls the route's `pageBuilder` with a context from `_scopedContext(tester, overrides())`. `formAt(location, context)` returns the `BugReportScreen` that page holds.
- In `group('locations')`, add `BugReportRouteData(entry: RoutePaths.supportReportBugProfileHoldEntry)` with the expected location `RoutePaths.supportReportBugFromProfileHold`, the constant the bottom bar pushes.
- `group('support forms')` reads the bug report through `_page`, since the route no longer implements `build`.

The first test checks the iOS behaviour, not the flag. On a regular Cupertino
page, a drag from the left edge pops the route; on the modal page it must not.
Use the real route in a minimal `GoRouter` under a `ProviderScope`:

```dart
testWidgets('on iOS an edge swipe does not close the report', (tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      _routeNamed(BugReportScreen.routeName),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(),
    child: MaterialApp.router(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  unawaited(router.push(RoutePaths.supportReportBug));
  await tester.pumpAndSettle();
  expect(find.byType(BugReportScreen), findsOneWidget);

  await tester.dragFrom(const Offset(2, 300), const Offset(600, 0));
  await tester.pumpAndSettle();

  expect(find.byType(BugReportScreen), findsOneWidget);
}, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

testWidgets('keeps the regular page transition on Android', (tester) async {
  final context = await _scopedContext(tester, overrides());
  expect(_page(BugReportScreen.path, context), isA<MaterialPage<void>>().having(
    (p) => p.fullscreenDialog, 'fullscreenDialog', isFalse));
}, variant: TargetPlatformVariant.only(TargetPlatform.android));

testWidgets('keeps its route name for page observers', (tester) async {
  final context = await _scopedContext(tester, overrides());
  expect(_page(BugReportScreen.path, context).name, BugReportScreen.routeName);
});

testWidgets('hides the shortcut tip when the Profile-tab hold opened it', (
  tester,
) async {
  final context = await _scopedContext(tester, overrides());
  expect(
    formAt(RoutePaths.supportReportBugFromProfileHold, context)
        .showProfileHoldTip,
    isFalse,
  );
});

testWidgets('shows the shortcut tip for every other way in', (tester) async {
  final context = await _scopedContext(tester, overrides());
  expect(formAt(BugReportScreen.path, context).showProfileHoldTip, isTrue);
});
```

- [ ] **Step 5: Run and see it fail**

Run: `mise exec -- flutter test test/router/routes/settings_routes_test.dart`
Expected:
- the file does not compile until `BugReportRouteData` takes `entry`; with only that added, the page tests fail because the route still implements `build`, so its `buildPage` returns go_router's `NoOpPage`;
- the edge-swipe test fails because the swipe pops the form (`BugReportScreen` not found).

- [ ] **Step 6: Implement**

- Give `BugReportRouteData` the constructor parameter `{@TypedQueryParameter(name: RoutePaths.supportReportBugEntryParameter) this.entry}` and `final String? entry;`.
- Override `buildPage` instead of `build`, returning `iosModalPage(state: state, child: BugReportScreen(...))`.
- Keep the existing trail snapshot, service and pubkey reads through `ProviderScope.containerOf`.
- Add `showProfileHoldTip: entry != RoutePaths.supportReportBugProfileHoldEntry`.
- Regenerate with the full `mise exec -- dart run build_runner build --delete-conflicting-outputs` and commit `settings_routes.g.dart`.

- [ ] **Step 7: Run the route-adjacent suites**

Run from `mobile/`:
- `mise exec -- flutter test test/router/routes/settings_routes_test.dart test/router/route_locations_resolve_test.dart test/router/providers/support_route_trail_provider_test.dart test/router/flat_route_cold_entry_back_test.dart test/router/app_router_redirect_test.dart test/widgets/bug_report_dialog_test.dart test/widgets/delete_account_dialog_test.dart test/screens/settings/support_center_screen_test.dart` → all pass
- `bash scripts/check_literal_navigation_paths.sh && bash scripts/check_hand_written_route_ceiling.sh` → pass

- [ ] **Step 8: Commit** (after `/verify`)

`feat(support): open the report form as a modal on iOS and mark the hold entry`

---

### Task 5: Hold the Profile tab

**Files:**
- Modify: `mobile/lib/widgets/vine_bottom_nav.dart` (`VineBottomNav`, `_TabSlot`, `_ProfileTabButton`)
- Modify: all 23 `mobile/lib/l10n/app_*.arb` files, plus the regenerated `mobile/lib/l10n/generated/*`
- Test: `mobile/test/widgets/vine_bottom_nav_test.dart`

**Interfaces:**
- Consumes: `RoutePaths.supportReportBugFromProfileHold` (Task 4) and the existing ARB key `supportReportBug`. `RoutePaths` is not exported by `router.dart`, so import `package:openvine/router/route_paths.dart`.
- Produces:
  - `_TabSlot({..., String? onLongPressHint, Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions})`, forwarded to its `Semantics`;
  - `_ProfileTabButton({..., required VoidCallback onLongPress})`;
  - `VineBottomNav._handleProfileHold(BuildContext context)`;
  - the ARB key `navProfileLongPressHint`.

- [ ] **Step 1: Add the string**

In `app_en.arb`, insert directly after `navProfile`:

```json
"navProfileLongPressHint": "Report a bug",
"@navProfileLongPressHint": {
  "description": "TalkBack hint on the Profile tab of the bottom bar. Holding the tab opens the bug report form. Write a verb phrase completing Android's 'Double-tap and hold to …', in the register mobile/docs/LOCALIZATION_STYLE_GUIDE.md sets for the locale."
},
```

Mirror it into the other 22 locales, in the register `mobile/docs/LOCALIZATION_STYLE_GUIDE.md` sets for each locale rather than another key's form (`inboxConversationTileLongPressHint` is familiar in `am` and `te`, where the guide asks for the polite form). Then run `mise exec -- flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Create a new `group('profile tab hold')` inside `group('VineBottomNav interaction targets')`, with this `setUp`:

```dart
router = MockGoRouter();
when(() => router.push<Object?>(any(), extra: any(named: 'extra')))
    .thenAnswer((_) async => null);
```

`l10n` below is `lookupAppLocalizations(const Locale('en'))`.

```dart
testWidgets('a press-and-hold opens Report a Bug, marked as the hold', (
  tester,
) async {
  await pumpSubjectWithRouter(tester, router);
  await tester.longPress(find.bySemanticsIdentifier('profile_tab'));
  await tester.pump();
  verify(() => router.push<Object?>(
    RoutePaths.supportReportBugFromProfileHold,
    extra: any(named: 'extra'),
  )).called(1);
  verifyNever(() => router.go(any(), extra: any(named: 'extra')));
});

testWidgets('a tap does not open the report', (tester) async {
  await pumpSubjectWithRouter(tester, router);
  await tester.tap(find.bySemanticsIdentifier('profile_tab'));
  await tester.pump();
  verifyNever(() => router.push<Object?>(
    RoutePaths.supportReportBugFromProfileHold,
    extra: any(named: 'extra'),
  ));
});

// Review Focus 1
testWidgets('holding while already on Profile opens the report and does '
    'not retry the profile', (tester) async {
  await pumpSubjectWithRouter(tester, router, currentIndex: 3);
  await tester.longPress(find.bySemanticsIdentifier('profile_tab'));
  await tester.pump();
  verify(() => router.push<Object?>(
    RoutePaths.supportReportBugFromProfileHold,
    extra: any(named: 'extra'),
  )).called(1);
  expect(profileRetapCubit.state, isZero);
});

testWidgets('gives a light haptic when the hold registers', (tester) async {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add(call);
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  await pumpSubjectWithRouter(tester, router);
  await tester.longPress(find.bySemanticsIdentifier('profile_tab'));
  await tester.pump();
  expect(calls, contains(isMethodCall(
    'HapticFeedback.vibrate',
    arguments: 'HapticFeedbackType.lightImpact',
  )));
});

testWidgets('tells TalkBack the hold reports a bug, listed once', (
  tester,
) async {
  final handle = tester.ensureSemantics();
  await pumpSubjectWithRouter(tester, router);
  final data = tester
      .getSemantics(find.bySemanticsIdentifier('profile_tab'))
      .getSemanticsData();
  final actions =
      data.customSemanticsActionIds!.map(CustomSemanticsAction.getAction);
  expect(data.hasAction(SemanticsAction.longPress), isTrue);
  expect(
    actions.singleWhere((a) => a!.action == SemanticsAction.longPress)!.hint,
    l10n.navProfileLongPressHint,
  );
  expect(actions.where((a) => a!.label == l10n.supportReportBug), isEmpty);
  handle.dispose();
}, variant: TargetPlatformVariant.only(TargetPlatform.android));

testWidgets('offers VoiceOver a Report a Bug action that opens the report', (
  tester,
) async {
  final handle = tester.ensureSemantics();
  await pumpSubjectWithRouter(tester, router);
  final node = tester.getSemantics(find.bySemanticsIdentifier('profile_tab'));
  final id = CustomSemanticsAction.getIdentifier(
    CustomSemanticsAction(label: l10n.supportReportBug),
  );
  expect(node.getSemanticsData().customSemanticsActionIds, contains(id));
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
  await tester.pump();
  verify(() => router.push<Object?>(
    RoutePaths.supportReportBugFromProfileHold,
    extra: any(named: 'extra'),
  )).called(1);
  handle.dispose();
}, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
```

Add one more test in a nested `group('when opening the report fails')`. Mirror the `setUp`/`tearDown` of the camera group's `group('when opening the camera fails')` in its own group. Do not lift that setup to a shared level: it would add shared-setUp stubs.
- Test name: `'a press-and-hold logs and reports the failure'`.
- Push stub throws `StateError('push failed')`.
- Expect exactly one `Navigation` error log with the message `'Failed to open the bug report from bottom navigation: Bad state: push failed'`, in `LogCategory.ui`.
- Expect the recorded crash report to be a `Reportable<Object>` wrapping a `StateError`.

- [ ] **Step 3: Run and see it fail**

Run: `mise exec -- flutter test test/widgets/vine_bottom_nav_test.dart`
Expected: the new tests fail: nothing is pushed on hold, no hint, no custom action.

- [ ] **Step 4: Implement**

- `_TabSlot`: add `onLongPressHint` and `customSemanticsActions`, and pass both to its `Semantics`.
- `_ProfileTabButton`: add `required this.onLongPress` and pass it to `_TabSlot` with:
  - `onLongPressHint: context.l10n.navProfileLongPressHint`;
  - `customSemanticsActions: defaultTargetPlatform == TargetPlatform.iOS ? {CustomSemanticsAction(label: context.l10n.supportReportBug): onLongPress} : null`.

  Add a one-line comment on why the custom action is iOS-only: TalkBack would list it twice, and iOS ignores hint overrides.
- `VineBottomNav._handleProfileHold(context)`, following the camera hold:
  1. `Log.info('👆 User held profile tab — opening bug report', name: 'Navigation', category: LogCategory.ui)`
  2. `unawaited(HapticFeedback.lightImpact())`
  3. `runDetached(context.push(RoutePaths.supportReportBugFromProfileHold), 'open the bug report from bottom navigation', logName: 'Navigation', category: LogCategory.ui)`

  Wire it as `onLongPress: () => _handleProfileHold(context)`.

- [ ] **Step 5: Run and see it pass**

Run from `mobile/`:
- `mise exec -- flutter test test/widgets/vine_bottom_nav_test.dart test/l10n/arb_consistency_test.dart` → all pass, including the camera tests
- `bash scripts/check_orphaned_arb_key_floor.sh` → pass

- [ ] **Step 6: Commit** (after `/verify`)

`feat(nav): hold the Profile tab to report a bug`

---

### Task 6: Full verification and device checks

**Files:** none, unless a check fails; fix the cause in the owning task's files.

- [ ] **Step 1: Rebase and regenerate**
  - `git fetch origin && git rebase origin/main`
  - `cd mobile && mise exec -- flutter pub get`
  - `git status --short` → clean

- [ ] **Step 2: Run `/verify` in pre-push mode**
  - Format, analyze and l10n, plus every test file named in Tasks 2–5.
  - Guards: `bash scripts/ci/run_guards.sh` from `mobile/`. Read FAIL rows only for files this branch touches. A FAIL that names only untouched files after a fresh fetch means a stale baseline; the cure is a rebase, never a baseline edit.
  - No goldens cover these widgets (checked 2026-11-14).

- [ ] **Step 3: Ask the user before using the phones**
  - The phones are shared with other sessions.
  - Agree which staging test account to sign in with.

- [ ] **Step 4: Galaxy S23, Android 17 (adb serial `RFCX70Z29TB`)**

Run `mise exec -- flutter run --debug -d RFCX70Z29TB --dart-define=DEFAULT_ENV=STAGING`, which installs `co.openvine.app.staging`, and sign in. With `ADB=$ANDROID_HOME/platform-tools/adb`, check each of these:
  - **Hold opens the form.** Find the Profile tab bounds with `$ADB -s RFCX70Z29TB exec-out uiautomator dump /dev/tty`. Hold with `$ADB -s RFCX70Z29TB shell input swipe X Y X Y 1000`. A new dump shows the Report a Bug title and the public-post notice.
  - **The hold vibrates.** `$ADB -s RFCX70Z29TB shell dumpsys vibrator_manager` lists a vibration from `co.openvine.app.staging` at the hold time.
  - **Back closes it.** `$ADB -s RFCX70Z29TB shell input keyevent KEYCODE_BACK` closes the form and returns to the same screen (Review Focus 3).
  - **A tap still opens the profile**, with no form.
  - **Two quick holds open one form** (Review Focus 2): two swipes back to back, then one back press returns to the feed.
  - **A covered bar does nothing** (Review Focus 5): open a share sheet, then hold where the tab is.
  - **Keyboard:** with the Subject field focused, Cancel and Send Report stay above the keyboard (dump bounds).
  - **TalkBack** (with the user's go-ahead). Turn it on:

    ```
    $ADB -s RFCX70Z29TB shell settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
    $ADB -s RFCX70Z29TB shell settings put secure accessibility_enabled 1
    ```

    The user touches the Profile tab, hears "double-tap and hold to report a bug", double-taps and holds, and sees the form. TalkBack's actions menu lists the shortcut once. Then restore the phone's previous state (both were off):

    ```
    $ADB -s RFCX70Z29TB shell settings delete secure enabled_accessibility_services
    $ADB -s RFCX70Z29TB shell settings put secure accessibility_enabled 0
    ```

- [ ] **Step 5: iPhone 17 Pro Max, iOS 27.0.1, over USB (UDID `00008150-00195C563AB9401C`)**

Before the first iOS build of the session, read the iOS build-cache memory: seed SourcePackages and Pods from a sibling worktree if GitHub is slow. Run `mise exec -- flutter run --debug -d 00008150-00195C563AB9401C --dart-define=DEFAULT_ENV=STAGING`, which installs `co.openvine.app.staging`. The user checks by hand:
  - Holding the Profile tab gives a light tap, and the form slides up from the bottom.
  - Swiping in from the left edge does nothing.
  - Cancel and the arrow each close the form and return to the same screen (Review Focus 3).
  - With the keyboard up, Cancel and Send Report stay visible.
  - With VoiceOver on and focus on the Profile tab, swiping up or down reaches "Report a Bug" once, and a double-tap opens the form.

Take no screenshots of this phone.

- [ ] **Step 6: Android 9 emulator**

```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-28;google_apis;arm64-v8a"
$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n divine_api28 -k "system-images;android-28;google_apis;arm64-v8a" -d pixel_5
$ANDROID_HOME/emulator/emulator -avd divine_api28
```

Run the app on it and repeat Step 4's hold, back, tap and keyboard checks. Check TalkBack only if `pm list packages | grep -i talkback` finds it on the image.

- [ ] **Step 7: iOS 16 simulator**

Try `xcodebuild -downloadPlatform iOS -buildVersion 16.4`.
  - If Xcode 27.2 refuses or has no such runtime, stop and tell the user. iOS 16 then needs a borrowed phone that tops out at iOS 16, such as an iPhone 8 or iPhone X.
  - Otherwise, create a simulator from a device type the runtime supports (read its `supportedDeviceTypes`; prefer the smallest iPhone). Repeat the hold, slide-up, no-edge-swipe and keyboard checks.

- [ ] **Step 8: iOS 27 simulator**
  - Confirm the slide-up.
  - At the largest Dynamic Type size, the tip wraps and no overflow stripes appear (Review Focus 4).
  - Capture the PR screenshots or recording here.

- [ ] **Step 9: Record the results**

Write a pass/fail checklist, by target and check, for the PR body. Any fail goes back to its owning task.

---

### Task 7: Deliver PR 2

**Files:** none (PR, issue comment).

- [ ] **Step 1: Rebase and push**

Rebase on fresh `origin/main` if Task 6 ended more than a few hours ago, then run `git push -u origin feat/8955-hold-profile-to-report-bug`.

- [ ] **Step 2: Draft the PR body and show it to the user before creating the PR**

It contains:
- a summary and why (#8955);
- what changed: the hold, screen readers, the iOS slide-up, the tip, the URL marker;
- the platform behaviour table from the spec;
- the tests;
- the Task 6 results;
- simulator screenshots;
- `Closes #8955`;
- the identity block (Step 3).

- [ ] **Step 3: Fill in the identity block**

Use one block per run whose changes remain in the diff; read-only reviewer runs add none. Take the values from the session jsonl and put the block inside a code fence:

```
Agent-Model: anthropic/<model-id>[1m]
Agent-Effort: <effort>
Agent-Harness: claude-code/<version>
Agent-Context: fresh
Initiated-By: @realmeylisdev
```

- [ ] **Step 4: Create the PR as a draft**

After approval, run `gh pr create --draft --base main --title "feat(support): open Report a Bug by holding the Profile tab" --assignee @me --body-file <file>`. A draft gets no review request.

- [ ] **Step 5: Draft the #8955 comment and show it to the user before posting**

It covers:
- the direction: Profile-tab hold, the existing form, slide-up on iOS, TalkBack and VoiceOver, the tip;
- that the camera and editor are out of scope;
- the link to PR 1;
- a request for Liz to confirm.

Don't call the hold's log line a record of how a report was opened. After approval, run `gh issue comment 8955 --body-file <file>` and return the comment URL.

- [ ] **Step 6: Watch the checks**

Run `gh pr checks <n> --watch`, then re-list and confirm the row count is at least the number of distinct check names from the previous head; `--watch` can exit 0 on a network error or before any rows exist. Fix anything red; this branch is the suspect.

- [ ] **Step 7: Mark the PR ready**

Only once Liz has agreed on #8955 and Task 6 has passed: run `gh pr ready <n>`, then confirm with `gh pr view <n> --json reviewRequests` that CODEOWNERS requested `divinevideo/reviewers`. Never add reviewers by hand.
