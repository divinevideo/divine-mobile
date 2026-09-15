# Maestro E2E tests

End-to-end UI tests written with **Maestro**, driving a real build against
**STAGING**.

They exist for fast, high-signal regression detection on critical user flows.
They are not a replacement for unit or widget tests.

## Supported entry points and execution tiers

[`tiers.txt`](tiers.txt) is the source of truth for supported Maestro entry
points. An entry point is either a test, flow, or suite nothing else invokes,
or a file an automation runner invokes directly. Assertions, utilities, and
nested journey files inherit the tier of the entry point that reaches them.

| Tier | Runs | Requirements and cost |
|---|---|---|
| `pr` | Codemagic's shared iOS/Android smoke command | iOS uses `mac_mini_m2` with a 25-minute cap; manually dispatched Android uses `linux_x2` with a 60-minute cap; promotion target is p95 below 15 minutes over at least 30 comparable iOS runs |
| `manual-regression` | Operator invokes `smoke.yaml` or `fullRegression.yaml` | Simulator and staging fixture variables; runtime is not yet measured |
| `manual-hardware` | Operator invokes one recorder flow | Camera-capable Android emulator or physical device with an English system UI; runtime is not yet measured |
| `scheduled` | No entry points currently | Reserved for a journey connected to a real scheduled runner |

The registry records the runner, prerequisites, and reason for every supported
entry point. `maestro_pr_smoke_contract_test.dart` checks that the registry
covers the live flow graph, paths resolve with exact case, PR rows match the
Codemagic command in order, and manual rows cannot drift into CI. Add or remove
the registry row in the same change that adds, nests, retires, or automates an
entry point.

There is currently no scheduled Maestro device regression. The daily workflow
described in `docs/AUTOMATED_QA.md` runs deterministic headless service tests;
it does not run these Maestro suites.

## Pull-request smoke

The intended automatic PR lane is limited to three deterministic signals:

1. `prLaunchReady` proves a clean install reaches interactive onboarding.
2. `prAuthenticateHome` creates a throwaway local identity and proves the
   authenticated shell can open Home.
3. `prSeededVideoPlayback` opens one immutable public Nostr event directly and
   proves the video route resolves to playback chrome.

`removeKeys` is a teardown case, not another journey. Codemagic passes every
file separately so JUnit preserves its name and timing. The PR suite neither
searches mutable content nor signs into a shared account, and it does not need
credentials. A public `QA_VIDEO_EVENT_ID` variable identifies the immutable
fixture; changing it is a reviewed CI configuration change.

The broader `suites/smoke.yaml` remains a manual regression target. It includes
account-management and social flows that depend on credentials or mutable
staging state. `likeFlow` and `commentFlow` remain unsuitable for the PR gate:
after the reduced-motion fix they still fail on Codemagic with a blocked main
thread, as documented in
[#7204](https://github.com/divinevideo/divine-mobile/issues/7204). Restoring
those flows is tracked by
[#7619](https://github.com/divinevideo/divine-mobile/issues/7619) and
[#7620](https://github.com/divinevideo/divine-mobile/issues/7620). The iOS
simulator is still set to reduced motion so XCUITest can settle on the flows
that do run.

Nothing is held back from `smoke.yaml`. The last two were restored by
[#6952](https://github.com/divinevideo/divine-mobile/issues/6952) —
`commentFlow` had an `env`-vs-`output` bug and a disabled cleanup step, and
`searchUserFlow` needed a rewrite for the current search layout. Their
credentials (`SEARCH_USER` for `searchUserFlow`) must be present on the
runners.

### `likeFlow` was an app bug, not test data

`videoUnlike` used to hang, and the failure was filed as a test-data problem.
It was not. Unliking the only video in your own Liked feed makes the liked
grid's bloc re-emit an empty list into the still-open fullscreen route, and
the fullscreen screen rendered its loading placeholder for *any* empty list —
no timeout, no empty state, no error. Every action button left the tree, so
the flow's 15-second wait for the "Like video" label could never succeed.
Reproduced on device and fixed in
[#6949](https://github.com/divinevideo/divine-mobile/issues/6949); the feed
now settles on an explicit drained state carrying
`fullscreen_feed_empty`, which `assertVideoFeedDrained.yaml` asserts.

The lesson generalises: **before filing a Maestro failure as flaky data,
check whether the screen is stuck in a state the app has no exit from.**
A permanent loading placeholder looks exactly like slow live content.

The `e2e-smoke-ios` Codemagic workflow is configured to run on pull requests
that touch mobile code, excluding Markdown-only changes — but no build can fire
until the Codemagic webhook subscription is restored under
[#7504](https://github.com/divinevideo/divine-mobile/issues/7504), which is an
external integration setting this repository cannot change. Once builds do
fire, the check remains non-blocking for an observation window of at least 30
runs. Promote it to a required check only if
at least 95% of runs are infrastructure-clean and the p95 end-to-end duration
stays below 15 minutes; reset the observation window after a flow, runner image,
or Maestro version change. The `e2e-smoke-android` workflow is manual.

## The recorder flows

Four of the recorder's five modes are covered, one flow each:

| Flow | Mode | Covers |
|---|---|---|
| `flows/captureModeFlow.yaml` | capture | open, drive the control rail, record a clip, delete it, close |
| `flows/lipSyncModeFlow.yaml` | lip-sync | open, drive the control rail, prove the shutter refuses without a sound and records with one, delete the clip, close |
| `flows/stopMotionModeFlow.yaml` | stop-motion | open, drive the control rail, shoot two stills, undo them, close |
| `flows/classicModeFlow.yaml` | classic | open, drive the action row, record a clip off the preview, prove a second recording stops itself at the duration limit, delete both, close |

Upload is not covered yet.

The gate is lip-sync's own behaviour and it takes **both** shutter tests to
cover it. `lipSyncModeAudioGate` proves the shutter refuses with no sound
picked, which on its own is also what a permanently broken shutter does;
`lipSyncModeRecordClip` picks one and records against it. They run in that
order and cannot be swapped — the gate test needs the editor to hold no sound,
and the record test is what puts one there.

Picking a sound stays deterministic because the flow only ever touches the
picker's **Divine** tab, whose entries come from
`assets/sounds/sounds_manifest.json` and ship with the app. The Community tab
is the relay-backed one, and it is the live-content dependency this file names
elsewhere as the suite's main source of flakiness — no flow goes near it.

Every file in all four flows has been run green on a Galaxy SM-S942B. The
lip-sync, stop-motion and classic tests were driven test-by-test against an
already-signed-in app rather than through their flow end to end, because the
device runs a German system locale and `loginFreshInstall`'s `clearState` drops
the per-app English override mid-run (see step 0b). The login and `removeKeys`
bookends of those three flows are the same ones `captureModeFlow` already runs.

The classic run settled the two things only hardware could, both of which had
been flagged as unknowns while it was written: the native auto-stop reaches the
Flutter side as a clip, so `classicModeRecordingLimit` sees the session hold it,
and the ghost-frame snackbar does not cover the action row `classicModeControls`
drives above it.

None of them is in **`smoke.yaml`**, and all four are deliberately off the iOS
lane:

- **They need real camera hardware.** Without a camera the bloc never reports
  `isCameraInitialized`, the record button stays disabled, and the recording
  and shutter tests hang on their first wait. The lens switch in the shared
  rail needs one too. The iOS Simulator has no camera at all; an Android
  emulator's virtual scene camera is enough, and a device is best.
- **The `…Open` tests alone** — the chrome assertions — do pass without a
  camera, because the viewfinder falls back to a placeholder and every control
  still renders. So does `lipSyncModeAudioGate`: the blocked shutter is
  rendered from the audio selection, not from the camera being ready.

Run one against a booted Android emulator or a connected device:

```bash
maestro --device <serial> test e2e/maestro/flows/captureModeFlow.yaml
maestro --device <serial> test e2e/maestro/flows/lipSyncModeFlow.yaml
maestro --device <serial> test e2e/maestro/flows/stopMotionModeFlow.yaml
maestro --device <serial> test e2e/maestro/flows/classicModeFlow.yaml
```

### Reading state off an icon-only control

The cycling rail controls are asserted by their Semantics `value`
(`.*Square.*`, `.*3 seconds.*`, `.*Front camera.*`). That works: Flutter folds
`value` into the Android content description, and Maestro matches against it —
confirmed on device. Three things follow, all worth knowing before writing more
recorder selectors:

- **A selector may combine `id` with `text`**, and here it must: "Off" is the
  value of the flash control *and* the timer control — and, once its sheet is
  open, of the stabilization menu's own first row.
- **`selected: true` is readable too**, which is what all four `assert…Mode`
  files use to prove the right mode is armed. The mode wheel renders an entry
  for every mode in every mode, so a bare `id: camera_mode_capture` would pass
  on the Upload tab just as happily.
- **`enabled:` is readable, and sometimes it is the only signal.**
  `driveCaptureRail` uses it as a *guard* on hardware-dependent controls, but
  `assertClassicMode` and `assertClassicClipRecorded` assert on it directly:
  classic's next button stays mounted and goes disabled on an empty session
  rather than fading out of the tree, so `enabled` is the only thing that moves
  when a clip lands.
- **`checked:` is how an on/off control reads.** The ghost-frame and grid
  toggles carry a Semantics `toggled` flag rather than a `value`, and Flutter
  maps that to the accessibility node's checked state, so
  `stopMotionModeControls` and `classicModeControls` drive them with
  `checked: true` / `checked: false`.
  **Maestro does not print the flag in its run log** — the line reads
  `Assert that id: camera_ghost_frame_button is visible`, exactly as it would
  if the flag had been dropped, unlike `text:` and `enabled:` which both show
  up. It is genuinely applied: asserting `checked: true` against the toggle in
  its off state fails on device. Don't "fix" a `checked:` selector because the
  log looks bare; prove it with a deliberately-wrong assertion instead.

### What the four viewfinders share, and what tells them apart

Three of them *are* the capture stack: same close, next, delete, library button
and record button. Between those three, only the top bar's center slot and the
control rail differ. Classic is the odd one out — its own stack, its own top
bar, its own action rows, and no record button at all.

| | capture | lip-sync | stop-motion | classic |
|---|---|---|---|---|
| `camera_record_button` | ✅ | ✅ | ✅ | — |
| `camera_classic_shutter` (the preview) | — | — | — | ✅ |
| `audio_chip` (center slot) | — | ✅ | — | — |
| `camera_stop_motion_budget` (center slot) | — | — | ✅ | — |
| `camera_flash_button` | ✅ | ✅ | ✅ | — |
| `camera_aspect_ratio_button` | ✅ | ✅ | ✅ | — |
| `camera_switch_camera_button` | ✅ | ✅ | ✅ | ✅ |
| `camera_timer_button` | ✅ | ✅ | — | — |
| `camera_stabilization_button` | ✅ | ✅ | — | — |
| `camera_ghost_frame_button` | — | — | ✅ | ✅ |
| `camera_grid_button` | — | — | ✅ | ✅ |

Lip-sync and capture are the subset trap. Their rails are identical, so assert
only what each mode renders and `assertCaptureMode` passes on the Lip Sync tab,
because everything it checks is there. It asserts `audio_chip` *absent*, and
that one line is what keeps it honest. `video_editor_audio_chip_test.dart` pins
the anchor itself at the widget level.

Stop-motion is not that case, and its `assertNotVisible` block is there for a
different reason. Its rail and capture's are **disjoint**, not nested — capture
has timer and stabilization, stop-motion has ghost frame and grid — so each
assert already fails on the other's viewfinder on the rail alone. What settles
which viewfinder is up before either gets that far is the mode wheel's
`selected` state, asserted on the first line of all four files.

So the pairs those two asserts carry — `assertStopMotionMode` pinning timer and
stabilization absent, `assertCaptureMode` pinning ghost frame, grid and the
budget absent — are **leak guards**, not mode separators: they fail when a
control starts rendering in a mode that does not declare it, which nothing else
in the suite would catch. `camera_classic_shutter`, pinned absent by all three
capture-stack asserts, is the same kind of line: the record button is already
enough to tell classic apart, and `assertClassicMode` pins that one absent from
its side. `video_recorder_capture_actions_test.dart` pins the
same split at the widget level.

Because flash, aspect ratio and the lens switch are unconditional *on that
rail*, the three capture-stack modes drive them with the same three files —
`utils/driveAspectRatioControl`, `utils/driveLensControl`,
`utils/driveFlashControl`. Capture and lip-sync wrap those in
`utils/driveCaptureRail.yaml`, which adds the timer and stabilization controls
they alone render. The two `supportGridLines` / ghost toggles are shared by
stop-motion and classic, so they are per-control utils on the same rule —
`utils/driveGridControl`, `utils/driveGhostFrameControl`. Each mode's
`…Controls` test is a sequence of those utils plus its own mode assert, and
what it owns is the **order**, not the sequences. `classicModeControls` is the
worked example: the same three utils stop-motion runs, in the order classic's
horizontal action row needs them — ghost last, then the banner wait.

Classic is the case none of the above covers, because it is a different stack
rather than the same one with a different rail. Two consequences for its
selectors:

- **It has no record button.** The square preview is the shutter, wrapped in
  its own `Semantics` node carrying `camera_classic_shutter`. It keeps that
  identifier in both recording states while its *label* flips between "tap to
  start" and "tap to stop", which is what makes it a usable anchor.
- **Next is disabled, not hidden.** The capture stack fades next and delete out
  of the semantics tree when the session is empty; classic's top bar keeps next
  mounted and passes `onPressed: null`. So `assertClassicMode` reads an empty
  session off `enabled: false` there, and `assertClassicClipRecorded` waits on
  `enabled: true` rather than on visibility — a visibility wait would pass
  instantly and prove nothing. Delete does still drop out of the tree, so it is
  asserted the usual way. `video_recorder_classic_top_bar_test.dart` pins both
  halves of that contract.

### Things the flows depend on that are easy to break by accident

Shared:

- **Camera and mic pre-granted.** Each flow relaunches with
  `permissions: all: allow` rather than tapping through the native dialog,
  whose buttons are OS-localized copy. Note the relaunch deliberately does
  *not* clear state: on Android `pm clear` wipes the encrypted preferences the
  Nostr key lives in and would sign the account back out mid-flow.
- **Hardware for the guarded rail controls.** Flash (the three capture-stack
  modes — classic renders no rail at all) and stabilization (capture and
  lip-sync) are driven behind an `enabled: true`
  guard, because both are disabled outright when the active lens has no flash
  unit or reports a single stabilization mode. Where the feature is missing the
  block prints `SKIPPED` rather than failing — check the run output before
  reading a green run as full rail coverage. Both were exercised for real on
  the SM-S942B's back lens.
- **Everything the recorder persists, which is more than the mode.** Four
  preferences survive a run and every one of them is asserted as a default
  somewhere: `camera_last_used_recorder_mode` (absent ⇒ Capture),
  `camera_last_used_lens` (absent ⇒ back, which the rail asserts first),
  `camera_last_used_stabilization` and `camera_grid_lines_enabled` (absent ⇒
  on, which `stopMotionModeControls` and `classicModeControls` both assert
  first). Run from the top this is handled — `loginFreshInstall`'s `clearState`
  wipes all four — but a standalone run inherits whatever the last session left.
  A phone whose last session used the front lens fails the rail on its first
  `.*Back camera.*`, and the four flows leave the mode key on different values,
  so a `captureModeFlow` run straight after a lip-sync, stop-motion or classic
  one, skipping the login step, opens on the wrong mode. When iterating
  standalone, either reset the keys or start from a flow that clears state.
- **An empty session when the rail is driven.** The aspect-ratio control is
  disabled once the session holds a clip, because clips of mixed ratios cannot
  share an editor timeline. `captureModeControls` therefore runs before the
  recording tests; lip-sync gets this for free, since nothing in that flow
  records. Stop-motion stills are not clips until the assemble, so its rail
  stays live mid-session — but `stopMotionModeControls` closes on its mode
  assert, which pins next and undo absent, so it needs the empty session
  anyway and the flow keeps the same order. Classic renders no aspect-ratio
  control at all (it is square by definition), so nothing there is gated on
  clips either — but `classicModeControls` closes on the same kind of mode
  assert and keeps the same order for the same reason.

Capture only:

- **The recorder opening on Capture.** `openCaptureMode` asserts the mode
  rather than selecting it, so a standalone run against a device whose last
  session used another mode dies on `id: camera_mode_capture, selected` with no
  hint why. Reproduced on the iOS Simulator with the key left on `classic`.
  Selecting it there is not a one-liner: the wheel is a lazy `ListView`, so
  from Classic the Capture entry is not rendered at all.
- **Tap-to-toggle recording.** `HoldToRecordPreferenceService` defaults to
  false. On a device where a previous session turned hold-to-record on, the
  first tap does nothing and `captureModeRecordClip` fails on its wait.
  Stop-motion is immune: the record button disables long-press outright for any
  mode that captures stills.

Lip-sync only:

- **Reaching the mode at all.** `openLipSyncMode` selects rather than asserts,
  because the recorder falls back to Capture whenever the persisted key is
  absent and so never opens here on its own. It walks the wheel one entry at a
  time: Lip Sync sits two places from Capture, and the wheel is a lazy
  `ListView` that only builds entries near the armed one.
- **No sound picked before the gate test.** The selection lives in the editor
  provider rather than a preference, so a relaunch clears it — but an iterating
  run that already reached `lipSyncModeRecordClip`, or picked a sound by hand,
  has to relaunch before `lipSyncModeAudioGate` means anything again. Same for
  the rail: the aspect-ratio control is disabled once a clip exists, so
  `lipSyncModeControls` runs ahead of both.
- **The keyboard hides the confirm bar.** The picker's done button is anchored
  to the bottom of the sheet, so with the search keyboard up it is pushed off
  screen entirely. `lipSyncModeRecordClip` types its query and then calls
  `hideKeyboard` before touching the list. Skip that and the failure is a
  nasty one to read: the sound selects correctly, the tile turns green in the
  failure screenshot, and the run dies waiting on a button that is simply not
  in the hierarchy.
- **The sound is picked by title, from the manifest.** The test searches
  "Bruh Sound Effect" and asserts the title back off the first result, so a
  reordered or renamed manifest fails there rather than silently recording
  against a different sound. That title comes from the asset manifest, not
  l10n, so unlike the rest of the copy in this suite it reads the same in every
  locale. It is chosen for being 864ms — under the 6.3s maximum clip length, so
  confirming pops straight back instead of routing through the trim screen a
  longer sound would need.
- **The "add audio" snackbar is asserted by copy.** `DivineSnackbarContainer`
  takes no identifier, and adding one is a `divine_ui` change that drags that
  package's 100% coverage gate along with it — the same call `openRecorder`
  makes for the education sheet. It earns the copy dependency: without it the
  test only proves nothing happened, which is also what a dead button looks
  like. The two assertions in that test catch different failures and both are
  needed: the snackbar proves the gate *fired*, the still-visible
  `camera_close_button` proves no recording started behind it.

Stop-motion only:

- **Reaching the mode at all.** `openStopMotionMode` selects rather than
  asserts, for the same reason `openLipSyncMode` does. It taps the entry
  directly instead of hopping: Stop Motion sits next to Capture, so the lazy
  `ListView` has it built in both states this flow can arrive in. From Classic
  or Upload it would not be, same trap as everywhere else on this wheel.
- **The ghost-frame snackbar.** Each toggle raises a 4-second confirmation
  banner that floats over the bottom of the screen — the record and undo
  buttons included — so the controls test waits it out before handing over to
  the shutter test.
- **Undo leaving nothing behind.** Stills are written to the clip library as
  they are shot (the session is upserted on every frame, not on the assemble),
  so `stopMotionModeUndoFrame` is load-bearing teardown: undoing the last still
  is what drops the session's library row again.
- **Two stills, not one.** `stopMotionModeCaptureFrame` shoots twice and
  `stopMotionModeUndoFrame` undoes twice, with the first undo asserting the
  chrome is *still* up. That pairing is the only evidence the session
  accumulates rather than overwriting — shortening either test to one tap
  silently removes it. Verified the other way round on device: shoot once, undo
  once, and that assertion goes red.

Classic only:

- **Reaching the mode at all.** Classic is the last entry on the wheel, three
  places from Capture — further than any other mode has to travel on a lazy
  `ListView` that only builds entries near the armed one. `openClassicMode`
  therefore hops one entry at a time, and guards the hops on Classic not
  already being on screen: on a rerun the recorder opens straight on Classic
  (selecting a mode persists it), and from there Stop Motion is two entries
  away and may not be built at all.
- **The shutter is the preview.** There is no `camera_record_button` here, so
  `utils/recordCaptureClip.yaml` is not reusable and classic gets its own
  `utils/recordClassicClip.yaml`. Both wait on the close button leaving and
  coming back, because classic fades its whole top-bar row out while recording.
- **One 6.3s budget for the whole session, and Maestro's own overhead eats
  most of it.** Classic is the only mode that declares `hasRecordingLimit`, so
  every clip comes out of one budget and the bloc refuses to start a recording
  below 30ms remaining. Maestro dumps the view hierarchy around every command,
  which on the SM-S942B makes a tap cost 2-3.5s of wall-clock; the two taps in
  `recordClassicClip` span ~4.1s of the budget on their own. So that util has
  no accumulate-footage wait where the capture one records for three seconds —
  a `waitForAnimationToEnd: 2000` there measured 3.7s (the live preview never
  settles, so it runs its timeout out and then some) and pushed the pair to
  ~7.9s, past the limit. The first device run failed exactly there, and it cost
  both shutter tests at once: the recording was ended by the native auto-stop
  rather than the stop tap, so `classicModeRecordClip` stopped proving what it
  is named for, and `classicModeRecordingLimit` could not start at all against
  a spent budget. Anything added between those two taps comes out of the ~2.1s
  the limit test runs on.
- **The limit test asserts a fact, not a duration.** It starts a recording,
  never stops it, and waits for the top bar to come back — which only the
  native auto-stop can do. It deliberately does not assert *when*, because the
  budget left depends on what the previous test spent.
- **The ghost-frame snackbar, over a horizontal row.** Each toggle raises the
  same 4-second banner stop-motion has, but classic's controls are a row above
  the mode wheel rather than a vertical rail on the right. The banner sits
  below that row, so the two taps that restore the toggle are not covered —
  but `classicModeControls` still drives ghost *last*, so if that turns out to
  be wrong on some screen size the failure lands on that control alone rather
  than taking the lens and grid blocks with it.

Account creation is a precondition, not part of what is tested. The recorder
route itself is public (`appRouterRedirect` exempts it), but the only way in is
the feed's camera button and the feed is not public.

The stop-motion assemble step — "next", which collects the stills into a clip
and opens the editor — is out of scope on purpose: it leaves the recorder, and
the editor has no coverage to hand off to yet. So is classic's "next", which
skips the editor entirely (classic is the one mode declaring no
`hasVideoEditor`) and pushes the metadata screen with a render already started.

---

## Running them

Everything below runs from `mobile/`.

### 0. Install the CLI

```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
export PATH="$PATH:$HOME/.maestro/bin"
```

Not `brew install maestro`. That name resolves to an unrelated cask — "Maestro,
AI agent command center", ~680 MB — that installs a macOS app and no CLI, so
the next command still fails with `maestro: command not found`.

### 0b. Put the device's app UI in English

**The suite only runs against an English UI.** Not every selector is an id yet:
`loginFreshInstall` taps "Use Divine with no backup", `removeKeys` taps
"Cancel" / "Remove from device", `assertLogin` pins the three legal links. On a
German phone the app renders "Nutzungsbedingungen" and the run dies in the
first assert — which reads like a regression and isn't one.

CI runners are English, so this only bites locally — and locally it is
awkward, because the per-app override does not survive the suite:

```bash
# Android 13+, per app, without touching the system language:
adb shell cmd locale set-app-locales co.openvine.app.staging --locales en-US
```

**`launchApp: clearState` wipes that again.** It runs `pm clear`, which drops
the package's locale override along with its data, so any flow that starts
from `loginFreshInstall` is back in the system language by its first assert.
On a non-English phone the options are a scratch flow that skips `clearState`,
or setting the system language. This is not a problem worth engineering around
— it disappears once the remaining copy selectors become identifiers.

### 1. Build the app

The environment is not optional: a PRODUCTION run would write test data to the
live relay. `fullRegression` additionally fails outright on a PRODUCTION build,
because `searchTags` asserts the `STG` badge.

```bash
# iOS Simulator
flutter build ios --simulator \
  --dart-define=DEFAULT_ENV=STAGING

# Android emulator
flutter build apk --debug \
  --dart-define=DEFAULT_ENV=STAGING
```

### 2. Supply credentials

Nothing is committed. The current PR gate does not use credentials. Full local
suite runs and any future full-suite CI restore must supply these at run time:

| Variable | Used by |
|---|---|
| `USER_EMAIL`, `USER_PWD` | `flows/loginEmailPwd.yaml` |
| `SEARCH_USER` | `flows/searchUserFlow.yaml` — an account that ranks in People results for its own name |
| `USER_KEYS`, `SEARCH_USER_ID`, `VIDEO_USER`, `VIDEO_DESCRIPTION`, `VIDEO_DATA`, `EXISTING_USERNAME` | `suites/fullRegression.yaml` |

Every entry point guards its own variables with `assertTrue`. A missing `-e`
resolves to the JavaScript value `undefined` rather than erroring, so without
that guard the suite would run against garbage and fail somewhere unrelated.

If CI is restored to run `suites/smoke.yaml`, recreate the
`maestro_e2e_credentials` Codemagic group, pass the variables with `-e`, and
restore a runner-level preflight that fails fast when any required variable is
missing. The per-flow `assertTrue` guards catch direct entry-point runs, but the
runner guard keeps CI failures from looking like unrelated selector breakage.

### 3. Run

```bash
# The credential-free PR gate, as CI runs it
maestro test \
  --format junit \
  --output report.xml \
  -e QA_VIDEO_EVENT_ID=<immutable-public-event-id> \
  e2e/maestro/tests/prLaunchReady.yaml \
  e2e/maestro/tests/prAuthenticateHome.yaml \
  e2e/maestro/tests/prSeededVideoPlayback.yaml \
  e2e/maestro/tests/removeKeys.yaml

# The full smoke suite
maestro test \
  -e USER_EMAIL=... -e USER_PWD=... -e SEARCH_USER=... \
  e2e/maestro/suites/smoke.yaml

# Or run the full suite via the iOS helper, which boots a simulator and installs for you
MAESTRO_USER_EMAIL=... MAESTRO_USER_PWD=... MAESTRO_SEARCH_USER=... \
  bash e2e/maestro/scripts/ui_smoke_ios.sh
```

Pass `--device <udid>` when more than one simulator or emulator is running,
or Maestro may target a different one from the one you installed onto.

Failure artifacts — a screenshot and the command log — land in
`~/.maestro/tests/<timestamp>/`. Read the screenshot first; it is usually
faster than reasoning about the selector.

If CI reports a selector failure that does not match the screenshot, confirm
that Maestro targeted the simulator containing the current app build before
debugging the selector. A stale build on another booted simulator can produce
the same symptom.

### Iterating

Most files under `tests/` and all of `asserts/` contain no `launchApp`, so
they run against whatever is already on screen. Get the app into position
once, then re-run a single assert in about three seconds instead of a
ten-minute flow. Please keep it that way — adding `launchApp` to an assert
breaks it for everyone.

---

## Layout

```
e2e/maestro
├── suites/    entry points (smoke, fullRegression)
├── flows/     multi-test journeys
├── tests/     single scenarios
├── asserts/   reusable screen assertions
├── utils/     navigation helpers
├── scripts/   runners and checks
└── tiers.txt  supported entry points and execution policy
```

`scripts/check_refs.sh` verifies every `runFlow:` path resolves,
case-sensitively. macOS is case-insensitive by default and the Android CI
runner is Linux, so a wrong-case reference passes locally and fails only in
CI. Run it after moving or renaming anything.

---

## Writing selectors

**Target `Semantics(identifier:)`, not copy.** The suite spent six months
broken because it asserted English strings that product and l10n moved on
from. Identifiers are snake_case and defined in
`mobile/lib/constants/semantic_ids.dart`; `divine_ui` components take a
`semanticIdentifier`.

If the element you need has no identifier, add one — that is a smaller change
than the assertion you would otherwise write, and it survives translation.

Four traps worth knowing:

- **Opacity 0 is invisible to Maestro, `IgnorePointer` is not.**
  `RenderOpacity`/`RenderAnimatedOpacity` drop their child from the semantics
  tree at `alpha == 0` (unless `alwaysIncludeSemantics`), so a faded-out
  control genuinely fails `assertVisible` — that is what the recorder's
  next/delete assertions rely on. A control that is only wrapped in
  `IgnorePointer` stays in the tree and will happily satisfy `assertVisible`
  while being untappable.
- **`TabBar` composes a compound label.** A tab reads as `"New\nTab 2 of 6"`,
  and Maestro matches the whole label, so a bare `New` does not match. Use a
  prefix (`New.*`) or the tab's identifier — never the `Tab N of M` count,
  which varies with feature flags and with whose profile you are on.
- **`env` is read-only inside `evalScript`.** Write to `output.*` and read it
  back as `${output.NAME}`; `${NAME}` still resolves to the `env` default.
  An empty default is worse than a wrong one: an empty pattern matches an
  empty-text node, so the assertion passes and proves nothing.
- **Matching is whole-label, case-insensitive, and `.` crosses newlines.**
  A row that merges several `Text`s exposes one label
  (`"Now\n • \nYou\nGreat vine"`), so `assertVisible: Great vine` fails
  where `text: ".*Great vine"` passes. Measured on Maestro 2.1.0.

---

## Environments and test data

The flows run against shared STAGING infrastructure. What each one actually
depends on, and how much of that is real:

| Dependency | Where | Still a risk? |
|---|---|---|
| "whichever video is newest in the New grid" | `videoLike`, `commentVideo` | Yes, but only that it is **playable**. Nothing asserts which video it is. |
| "the account has exactly one liked video" | `videoUnlike` | No. `loginFreshInstall` creates the account, so it starts at zero likes and `videoLike` adds exactly one. |
| a specific account existing and ranking first in search | `searchUserFlow` | Yes — and it also taps a hardcoded `point: 50%,32%`, which is the more fragile half. [#6952](https://github.com/divinevideo/divine-mobile/issues/6952) |
| a real comment left on a stranger's video | `commentFlow` | Yes — its `deleteComment` cleanup is commented out, so every run leaves one behind. [#6952](https://github.com/divinevideo/divine-mobile/issues/6952) |

Accounts and likes are self-owned: each run creates its own account and
`removeKeys` tears it down, so those are not shared-state coupling.

Treat an unexplained failure as possibly-data *after* ruling out a stuck
screen, not before — and check the screenshot either way.

`commentFlow` deletes the comment it posts, but that only cleans the
poster's view: measured on 2026-08-10, the app publishes a valid kind 5,
the STAGING relay stores it, and the relay keeps serving the deleted
kind 1111 to everyone else. Each run therefore still leaves a visible
comment on whichever video is first in the New grid.

`tests/removeKeys.yaml` is the teardown of every smoke flow and is what makes
runs repeatable: the Nostr key lives in the iOS keychain and survives both
`launchApp: clearState` and a full app uninstall, so if teardown does not run,
the next run starts already signed in.

---

## Ownership

Owned by QA. Developers are encouraged to run them locally, report failures,
and propose improvements. Because they act as release alarms, change flows
deliberately — and when navigation changes intentionally, update the affected
flows in the same PR.
