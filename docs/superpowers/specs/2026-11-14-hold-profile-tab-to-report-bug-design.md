# Hold the Profile tab to report a bug

Issue: #8955 (filed by Liz, assigned to Meylis, labelled `needs design`).

## Why

Reporting a bug today is four taps and a full navigation away from whatever
broke: Profile tab → Settings → Support Center → Report a Bug. By the time the
form opens, the broken screen is out of sight. Zendesk → GitHub is one-way with
no reply channel, so whatever context the report fails to carry is gone for
good. A shortcut that opens the form from the screen with the problem makes
reporting cheaper and keeps that screen recorded in the report.

The trigger was originally requested as "shake the phone". #8955 ruled shake
out on accessibility grounds: people with a tremor set it off by accident,
people with a mounted phone or weak grip cannot set it off, iOS already binds
shake to Undo while typing, and recording or editing produces the same motion.
This design builds the alternative #8955 recommends: press and hold a tab in
the bottom bar.

## What we are building

1. **Press and hold the Profile tab** (the avatar at the right of the bottom
   bar) on any screen that shows the bottom bar. After the standard hold
   (500 ms) the phone gives a light haptic tap and the Report a Bug form opens.
   A quick tap on the Profile tab keeps doing what it does today.
2. **The form is the existing Report a Bug screen**, full screen, with the
   public-post notice, the same fields, attachments and the same submission
   path. Nothing about what a report contains or where it goes changes.
3. **On iOS the form slides up from the bottom** like a modal (Mail's compose
   screen), instead of in from the right. Because it is a full-screen modal,
   the left-edge swipe no longer closes it; Cancel and the top-left arrow do.
   This applies to every way into the form (Support Center, the account
   deletion dialog's link, the new hold). **Android is unchanged**: same
   entrance, same system back and predictive back behaviour.
4. **The report records the screen the user was on.** This already works:
   `supportRouteTrailProvider` ignores support paths, so a report opened from
   the home feed names the home feed. The new entry must keep that true.
5. **Screen readers get the shortcut by name**, so nobody has to perform the
   physical hold:
   - TalkBack (Android): the Profile tab announces "Double-tap and hold to
     report a bug".
   - VoiceOver (iOS): the Profile tab offers a "Report a Bug" item in its
     Actions list.
6. **The form teaches the shortcut.** When the form is opened any way other
   than the hold, it shows one short line telling people they can hold their
   profile picture in the bottom bar to report from any screen. When opened by
   the hold, the line is hidden.
7. **Delete the dead shake detector.** `mobile/lib/services/shake_detector_service.dart`
   and its test have no production callers, and they are the only importers of
   `sensors_plus`, so the dependency goes too. This ships as its own PR.

## Goals

- Reach Report a Bug in one gesture from the four bottom-bar tabs and every
  screen that shows the bar.
- Keep the public-post disclosure in front of every report.
- Work the same on every OS version the app supports: Android 9 (API 28,
  `minSdk = 28`) through Android 17 (API 37), and iOS 16 (deployment target
  16.0) through iOS 27.
- Equal access for TalkBack and VoiceOver users.
- Remove the unused shake detector and the `sensors_plus` dependency.

## Non-goals

- Shake to report, in any form.
- An entry point on screens without the bottom bar: camera, video editor,
  fullscreen video and other routes pushed onto the root navigator. They have
  no bar to hold.
- A chooser between bug report, feature request and contact support. The hold
  goes straight to the bug form.
- Any change to the report payload, Zendesk fields, attachments or the GitHub
  mirroring.
- A "discard this report?" confirmation. Cancel, the arrow and Android's back
  gesture still close the form without asking, exactly as they do today.
- Changing Request a Feature's presentation. It keeps sliding in from the right.
- Recording how a report was opened, including usage analytics. Product
  analytics do not fire in production, and the hold's log line is not a
  reliable record either: a report carries only errors, warnings and the last
  50 log entries (`bug_report_log_summary.dart`), so an info line written at
  hold time has usually scrolled out by the time the report is sent. Neither
  the PR nor the #8955 comment may describe the log line as a record.
- Web and desktop.

## Anti-goals (it fails even if it works)

- Any path into the form that skips the public-post notice.
- A gesture-only shortcut that screen-reader users cannot reach.
- Any change to what a tap on the Profile tab does, including the retap that
  retries a failed profile load.
- Any change to the camera button's hold (it starts recording).
- The shortcut appearing twice in TalkBack's actions menu, or not at all in
  VoiceOver.

## Constraints

- Android 9 → 17 and iOS 16 → 27. Everything here is drawn by Flutter
  (bar, gesture, page, transition) and uses no OS-version-specific API. Haptics
  use `HapticFeedback.lightImpact()`, which needs no permission on Android and
  works on every iPhone that runs iOS 16 (iPhone 8 and later).
- Signed-out people never see the bottom bar: the shell routes are protected
  and the router sends unauthenticated users to Welcome. The report route is
  protected too, so even a hold in the frame before a sign-out redirect lands
  on Welcome. No signed-out branch is needed.
- Some signed-in people can open the form but never see the bar: anyone held
  at the account-deletion recovery gate, and restricted minor accounts. Both
  redirects exempt support routes (`isSupportRoute` in
  `app_router_redirect.dart`), so they reach Report a Bug through Support
  Center. The tip still shows for them (decided here: hiding it would repeat
  the redirect's gate logic in the route builder), so its copy must stay true
  when the bar is not on screen.
- Repo guards that apply: literal navigation paths are frozen at zero (use a
  `RoutePaths` member or builder), hand-written routes may not grow (this edits
  the typed `BugReportRouteData`, it adds none), orphaned ARB keys fail CI, every ARB key
  is mirrored into all 23 locales or listed as known debt, and widget tests
  that render `context.l10n` use `appLocalizationsDelegates`.

## Approaches considered

| Approach | Trade-off | Outcome |
|---|---|---|
| Shake the phone | Fails people with tremors (accidental) and people with mounted phones or weak grip (unreachable); fights iOS Shake to Undo; recording looks like shaking; always-on sensor | Ruled out in #8955 |
| Hold a tab → existing form, slides in from the right | Smallest change; iOS edge swipe can discard a draft | Considered |
| **Hold a tab → existing form, slides up from the bottom on iOS** | Small change; modal feel the original request wanted; no accidental edge-swipe dismissal on iOS; the Support Center path slides up too | **Picked by Meylis** |
| Hold a tab → form in a bottom sheet | Lightest feel, but a long form (four fields, photos, notice) is cramped with the keyboard up, a swipe while scrolling can lose a draft, and it means two layouts of one form | Rejected |
| Hold a tab → chooser (bug / feature / contact) | One more step on the fast path | Rejected (Meylis, #8955 comment of 2026-09-10) |
| App's existing `fadeUpwardsPage` transition | Already used by the camera, library and announcement flows, but only fades up the last quarter and changes Android too | Not used; keeps Android unchanged as agreed |

**Which tab.** Profile, as Meylis proposed on #8955: the form already lives
under that tab (Profile → Settings → Support Center), which makes the shortcut
easier to teach. Home is the alternative (the Threads precedent). Known cost:
the app now has account switching, and Instagram uses holding the Profile tab
to switch accounts; if Divine ever wants that convention, this shortcut would
have to move.

## How it works

### Bottom bar (`mobile/lib/widgets/vine_bottom_nav.dart`)

- `_ProfileTabButton` passes an `onLongPress` to its `_TabSlot`, following the
  camera button's hold (`_CameraButton`): log the hold, fire
  `HapticFeedback.lightImpact()` (called directly, as the camera does, because
  widgets may not import the service layer), then
  `runDetached(context.push(<report location with the hold marker>), ...)`.
  The log line is `Log.info` under `name: 'Navigation'`,
  `category: LogCategory.ui`, like the camera's. It helps local debugging;
  it is not a record of how the report was opened (see Non-goals).
- `_TabSlot` gains two optional semantics inputs and forwards them to its
  `Semantics` widget:
  - `onLongPressHint` → TalkBack reads "Double-tap and hold to <hint>". Flutter
    ignores hint overrides on iOS (`SemanticsHintOverrides`: "On iOS, these
    values are always ignored").
  - `customSemanticsActions` → VoiceOver's Actions list. Supplied **on iOS
    only**: on Android a plain custom action would be listed in TalkBack's
    actions menu next to the long press, naming the shortcut twice. Flutter's
    iOS bridge drops `CustomSemanticsAction.overridingAction`, so the iOS
    action has to be a plain `CustomSemanticsAction(label: ...)`.
- The hold, the hint and the action are attached unconditionally: the bar only
  exists for signed-in people (see Constraints).

### Route (`mobile/lib/router/routes/settings_routes.dart`)

- The typed `BugReportRouteData` overrides `buildPage` instead of `build` and
  returns a `MaterialPage` with
  `fullscreenDialog: true` on iOS only. On iOS that selects Cupertino's
  full-screen-dialog transition (slides up from the bottom, no back-swipe, the
  screen behind stays put). It stays `false` on Android, where Material would
  otherwise freeze the screen behind during the transition.
- The page must carry go_router's default metadata so root-navigator observers
  such as `PageLoadObserver` keep resolving a real route name instead of
  `unknown_route`: `key: state.pageKey`, `name: goRouterPageName(state)`,
  `arguments` (path and query parameters), `restorationId: state.pageKey.value`.
  `fadeUpwardsPage` in `mobile/lib/router/fade_upwards_page.dart` is the
  in-repo model.
- `buildPage` reads the hold marker, a typed query parameter, and passes
  `showProfileHoldTip` to `BugReportScreen` (true unless the marker is
  present). It keeps snapshotting `supportRouteTrailProvider` as today.
- The marker is a query parameter, not `extra`: `extra` is a warm-start cache
  only in this repo. The redirect compares `state.matchedLocation` (path only),
  and the trail tests `uri.path`, so a query string changes neither.
- The location comes from `RoutePaths` (a constant or builder), never a literal.
  A new `RoutePaths` member must also be listed in
  `mobile/test/router/route_locations_resolve_test.dart`.

### Form (`mobile/lib/widgets/bug_report_dialog.dart`)

- `BugReportScreen` gains `showProfileHoldTip` (default `true`) and renders one
  short muted line when it is set, styled like the existing
  `bugReportDiagnosticsNotice` (`VineTheme.bodySmallFont`,
  `context.vineColors.mutedText`).
- Nothing else in the form changes. The public-post notice stays first.

### Strings (`mobile/lib/l10n/app_*.arb`, 23 locales)

- New: the TalkBack hint fragment that completes "Double-tap and hold to …"
  (a sentence-case verb phrase, e.g. "Report a bug", capitalised like
  `inboxConversationTileLongPressHint`).
- New: the tip line. The Profile tab shows the user's avatar and no word, so
  the copy must describe it ("your profile picture in the bottom bar"), not
  "the Profile tab". It must also stay true for people who cannot see the bar
  right now (see Constraints), e.g. by framing it as "when the bottom bar is
  showing".
- Reused: `supportReportBug` ("Report a Bug") as the VoiceOver action label.
- Both new keys are read through `context.l10n` in the same change, mirrored
  into every `app_*.arb`, and translated following
  `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`. Every ARB file uses 2-space
  indentation; key order and `@` blocks follow each file's own shape, so
  insert next to the neighbouring key and match it.

### Deleting the shake detector (separate PR)

- Delete `mobile/lib/services/shake_detector_service.dart` and
  `mobile/test/services/shake_detector_service_test.dart`.
- Remove `sensors_plus: ^7.0.0` from `mobile/pubspec.yaml`, run
  `flutter pub get`, and commit the `pubspec.lock` change (it drops
  `sensors_plus` and `sensors_plus_platform_interface`).
- Nothing else references either: no docs, no other Dart, and the generated
  plugin registrants are not tracked.
- The lockfile change makes Mobile CI run the iOS Native Tests job, which is
  expected. Removing a native plugin cannot ship as a Shorebird patch; it rides
  the next store release, like any feature.

## Behaviour by platform

| | Android 9 → 17 | iOS 16 → 27 |
|---|---|---|
| Hold the Profile tab | 500 ms, light vibration | 500 ms, light haptic |
| Form opens | Same transition as today | Slides up from the bottom; screen behind stays still |
| Closing | Cancel, top-left arrow, system back (predictive back on Android 14+) | Cancel, top-left arrow; left-edge swipe does nothing |
| Keyboard | Form shrinks above the keyboard, Cancel / Send pinned above it (as today) | Same |
| Screen reader | TalkBack: "Double-tap and hold to report a bug" | VoiceOver: "Report a Bug" in the Actions list |
| Video behind | Pauses (root-navigator push) | Pauses |

## Verification

Automated:

- `mobile/test/widgets/vine_bottom_nav_test.dart`: holding Profile pushes the
  report location with the hold marker and does not navigate to the profile;
  a tap still navigates to the profile; the Profile tab exposes a long-press
  semantics action whose performance pushes the report; on Android the hint
  is set and no custom action is present; on iOS (platform override) the
  custom action is present, labelled from `supportReportBug`, and performing it
  pushes the report. The camera hold tests stay green.
- Route: on iOS the report route builds a full-screen-dialog page and on
  Android a regular one; its page name resolves to the route's name; the hold
  marker turns the tip off and its absence leaves it on.
- `mobile/test/widgets/bug_report_dialog_test.dart`: the tip renders by
  default and not when `showProfileHoldTip` is false, asserted through
  `AppLocalizations`, not hardcoded English.
- `support_route_trail_provider_test.dart`: a report location carrying the hold
  marker is still treated as a support path, so the current screen stays the
  screen the user held from.
- `test/l10n/arb_consistency_test.dart`, `flutter analyze lib test
  integration_test`, and the Guards (`bash scripts/ci/run_guards.sh` from
  `mobile/`).

On devices, because the request is explicit about the oldest and newest OS
versions. Test targets:

| Target | Covers | Source |
|---|---|---|
| Samsung Galaxy S23, Android 17 (API 37) | newest Android | physical, USB |
| iPhone 17 Pro Max, iOS 27.0.1 (developer mode on) | newest iOS | physical, USB |
| Android 9 (API 28) emulator | oldest Android | `system-images;android-28;google_apis;arm64-v8a`, to download |
| iOS 16 simulator | oldest iOS | only if Xcode 27.2 still offers an iOS 16 runtime; otherwise a borrowed phone that tops out at iOS 16 (iPhone 8 or X) |

| Check | Android 9 emulator | Galaxy S23 | iOS 16 | iPhone 17 Pro Max |
|---|---|---|---|---|
| Hold opens the form; a tap still opens the profile | ✓ | ✓ | ✓ | ✓ |
| Haptic on hold | — | ✓ (`dumpsys vibrator_manager`) | — | ✓ (by hand) |
| Form transition and closing behaviour as in the table above | ✓ | ✓ (incl. predictive back) | ✓ | ✓ |
| Keyboard up: Cancel and Send Report stay reachable | ✓ | ✓ | ✓ (smallest simulator) | ✓ |
| Screen reader reaches the shortcut once, by name | TalkBack, if the image has it | TalkBack | — | VoiceOver (by hand) |

- Never press Send Report on these runs: a production build files a real,
  public GitHub issue. The screen a report records is covered by the trail
  provider test instead.
- The agent installs the builds and drives the emulator, the simulators and
  the Galaxy (adb: long-press, TalkBack on and off, the vibration log).
  Meylis does what needs a hand on the iPhone: feeling the haptic, and finding
  "Report a Bug" in VoiceOver's Actions list. The iOS Simulator has no
  VoiceOver, so VoiceOver is checked on the iPhone only.
- All of this happens before PR 2 leaves draft.

## Delivery

- Two PRs, both targeting `main`, self-assigned, reviewers requested from
  `divinevideo/reviewers`:
  1. `chore(app): remove the unused shake detector and sensors_plus` —
     references #8955.
  2. `feat(support): open Report a Bug by holding the Profile tab` — carries
     this design doc, `Closes #8955`.
- The product choices here (Profile tab, slide-up presentation, the tip line)
  answer open questions on Liz's issue. They are posted to #8955 for the team
  before PR 2 is marked ready; the comment is drafted and shown to Meylis
  before posting. PR 2 stays a draft until the team agrees and the device
  checks above have passed.

## Left to the builder

- Final wording of the two new strings and their translations.
- The name of the hold marker and of the `RoutePaths` member or builder.
- Where the tip line sits in the form (suggested: under the diagnostics notice,
  so it does not push the fields down).
- How the page builder detects iOS (`Theme.of(context).platform` or
  `defaultTargetPlatform`), as long as tests can override it.
- Test file layout, within the repo's mirror-`lib/` rule.
