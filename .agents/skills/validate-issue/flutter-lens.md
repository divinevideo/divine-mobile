# Flutter and Dart lens

Facts here come from the pinned SDK source (Flutter 3.47.2, Dart 3.13.2),
`origin/main`, and runs on a developer Mac in October 2026. iOS build traps are
in `.claude/rules/ios_build_troubleshooting.md`; read it before the first build,
and use `mise exec -- flutter` from `mobile/`.

## 0. Before touching the device

A phone, the simulators, the pub cache and the local Docker stack may be shared
with other agent sessions on the same Mac.

- `xcrun devicectl list devices`: the phone is listed and available. A wireless-only iPhone may never attach the VM service; use USB.
- `pgrep -fl 'flutter_tools|xcodebuild|patrol'` and any other live agent sessions: nobody else is building for it or attached to it. If someone is, ask the user; never kill by pattern.
- Every `flutter` command that targets a device names it with `-d <id>`, using the id `flutter devices` prints: `run`, `drive`, `install`, `attach`, `logs`, `screenshot`, and `flutter test` on an `integration_test/` suite. On Android, the `e2e-test` skill's `mise run e2e_test` is the route for suites that need the local stack, such as those under `integration_test/auth/`; a direct `flutter test` cannot drive a patrol suite and gives up the merged timeline. Pass a simulator's UDID or an emulator's serial unless the `devicectl` and `pgrep` checks above show the phone is free and yours to use.
- Without `-d`, Flutter picks for itself: the only device it finds, or the only attached phone, simulator or emulator among several, so a USB phone beside the macOS target still wins. On macOS a wireless phone is picked only when it is the only device of any kind. During the review of #10534 a review agent ran an `integration_test/e2e/` suite with no `-d` while a shared USB phone was attached; the review posted there records the run.
- `mise run e2e_test` and `local_stack/profile.sh` pick their own Android device: `ANDROID_SERIAL` if set, else the first emulator, else the first device `adb devices` lists. They then clear its logcat and install the app, and a patrol suite uninstalls it afterwards unless `PATROL_NO_UNINSTALL=true`. `mise run local_install` runs `adb install` with no serial at all. So with a phone attached, start an emulator first unless the phone is yours to use: `mise run emulator` in its own terminal (it does not return), then set `ANDROID_SERIAL` to the `emulator-<port>` serial `adb devices` shows.
- Delegated agents (reviewers, helpers) run only commands that stay on the host: for example analyze, format, `pub get`, code generation, the guards, `flutter devices`, `flutter test` or `dart test` on files under `test/` outside `test/manual/` and not tagged `integration`, and the stubbed `mise run test_local_stack_scripts`.
- They run nothing that selects, installs on, launches on, boots, erases or attaches to a device, simulator or emulator, and nothing that starts, stops, resets or attaches to the local stack or a running app. That covers `integration_test/` suites and the acceptance tests in `test/manual/`, every `flutter` command that targets a device, this skill's `scripts/flutter-machine.sh` (§3), the dart MCP `vm_service`, `dtd`, `get_runtime_errors`, `hot_reload`, `hot_restart`, `widget_inspector` and `flutter_driver_command` tools, `websocat` on a VM service, `patrol`, `maestro`, `idb`, `xcodebuild test`, the `mise run e2e_test` and `emulator*` tasks, every `local_*` task except `local_status` and `local_build`; also `test_local_name_server`, which starts its own Compose project, `local_stack/` scripts other than its stubbed `test_*_scripts.sh` checks, `docker compose up` and `down`, and any `adb`, `devicectl` or `simctl` command other than listing devices. Reading the stack is fine: `mise run local_status`, and `docker compose -f local_stack/docker-compose.yml ps` or `logs --tail=<n>`.
- State this restriction in every brief you write, and run device work yourself. Host commands can still lower the generated iOS Swift package floor (`.claude/rules/ios_build_troubleshooting.md`, Cause 3), so check it before your next device build.
- A debug run replaces the installed Divine Staging build, and its data may not survive. That is an ask-the-user item.
- One simulator per session, named by UDID in every note.

The device steps below are written for iOS. On Android the equivalents are
`adb devices`, `adb logcat`, `adb exec-out screencap -p` and
`adb shell input tap`; the repo's E2E harness (`e2e-test` skill) is
Android-first and captures logcat for you.

## 1. Which build can show the bug

| | Debug | Profile | Release |
|---|---|---|---|
| Compiled | JIT, asserts on | AOT, asserts off | AOT, asserts off |
| VM service | yes, with `evaluate` | yes, no `evaluate` (AOT) | none |
| iOS bundle id | `co.openvine.app.staging` | `co.openvine.app` | `co.openvine.app` |
| Runs on | simulator and phone | phone only | phone only |
| Use it for | logic, state, protocol | jank, startup, memory, timing | what TestFlight users run |

- A TestFlight or App Store report is a release report. A debug repro proves the logic; say so, and name what differs: asserts that throw in debug and are skipped in release, `kDebugMode` branches, JIT timing, default log level.
- Performance claims are measured in profile, median of several runs. Debug numbers are not evidence.
- Profile and release install over the user's production app. Ask first.
- Debug needs `--dart-define=DEFAULT_ENV=STAGING` (or `LOCAL`), otherwise the staging bundle talks to production.

## 2. See every log, not two categories of seven

The console prints only `SYSTEM` and `AUTH` by default
(`unified_logger.dart`, `_getDefaultCategories`). "I watched the logs" on a
default build means relay, API, storage, video and UI lines were never shown.

- Launch with `--dart-define=LOG_CATEGORIES=RELAY,VIDEO,UI,AUTH,STORAGE,API,SYSTEM --dart-define=LOG_LEVEL=verbose`.
- A build already running with defaults still holds everything: the in-memory capture ignores the filter. Read it over the VM service: `LogCaptureService().getRecentLogs(limit: 500)`.
- Profile and release print no `Log.*` lines anywhere: console output sits behind `kDebugMode`. The in-memory capture still runs, and with no `evaluate` there the way to read it is the app's own export, Support Center → Save Logs.

| Written with | Reaches |
|---|---|
| `Log.*`, category enabled, debug build | console (`debugPrint`, the VM `Stdout` stream), in-memory capture; on web also the VM `Logging` stream |
| `Log.*`, category disabled, or a profile / release build | in-memory capture only |
| `dart:developer` `log` (packages) | VM `Logging` stream only |
| Swift `os_log` / `NSLog` | device unified log; the `flutter run` console filter drops most of it |
| Crash | a `.ips` on the device: `xcrun devicectl device info files --device <id> --domain-type systemCrashLogs`, then `devicectl device copy from … --domain-type systemCrashLogs` |

How the tool gets phone logs on this toolchain (Xcode ≥ 26, CoreDevice), from
`flutter_tools/lib/src/ios/devices.dart` and `core_devices.dart`:

- Debug launches through `lldb` and reads the console from it; the Dart VM streams are the fallback. `idevicesyslog` is no longer used. When the debugger connection drops, so do the logs.
- Profile launches with `devicectl … --console`, which carries native output only, since `Log.*` is compiled out. Release launches with no console at all.
- `flutter logs` is given neither source for a physical iPhone (read from source, not run). Do not wait on it.
- DDS, on by default, keeps history for the `Logging`, `Stdout` and `Stderr` streams and replays it to a late subscriber, so attaching after the fact still shows what happened (10,000 entries by default). `--no-dds` loses this, and DTD with it.
- If `flutter run` stalls at launch on the phone, see flutter/flutter#179496 (open; LLDB debugging on recent iOS). The workaround changes global Flutter config, so it is an ask-the-user item.

## 3. Drive `flutter run` as a program

`flutter run --machine` speaks one JSON message per line on stdin and stdout
(`packages/flutter_tools/doc/daemon.md`). No PTY, no quit on stdin EOF, no
signals, and the URIs the other tools need arrive as events. The helper in the
`scripts/` directory beside this file keeps a run alive across separate shell
calls. `<skill dir>` is the directory holding this file
(`.claude/skills/validate-issue`, or `.agents/skills/validate-issue` for Codex);
`<scratch>` is a directory outside the repo, such as your session's scratch
directory. In a fresh worktree run `mise trust` in `mobile/` once first, or
`mise exec` refuses to start:

```bash
FM="bash <skill dir>/scripts/flutter-machine.sh"; RUN=<scratch>/run1
$FM start $RUN <repo>/mobile <device-id> --dart-define=DEFAULT_ENV=STAGING \
    --dart-define=LOG_CATEGORIES=RELAY,VIDEO,UI,AUTH,STORAGE,API,SYSTEM \
    --dart-define=LOG_LEVEL=verbose
$FM wait $RUN                          # prints appId, wsUri (VM service), dtdUri
$FM ext $RUN ext.flutter.debugDumpApp  # any service extension, optional JSON params
$FM reload $RUN                        # hot reload; `restart` = hot restart
$FM logs $RUN                          # the app's log lines so far
$FM taint $RUN                         # exit 1 if the tree may be corrupted (§4)
$FM stop $RUN
```

Tested on the headless `flutter-tester` device (start, two extension calls,
reload, restart, stop, clean exit), and on a USB iPhone on iOS 27.0.1 (start,
wait, logs, taint, stop, then a second start on the same install). On the
phone the first `app.started` took about four minutes, and the tool printed
"The Dart VM Service was not discovered after 60 seconds" on the way; it
attached without help, so keep waiting rather than restarting.

- `wsUri` goes to the dart MCP `vm_service` tool or `websocat`. `dtdUri` goes to its `dtd` tool, which unlocks `get_runtime_errors`, `widget_inspector`, `hot_reload` and `hot_restart`.
- One malformed line on stdin crashes the tool with a `FormatException`. Build messages with `jq`, as the helper does.
- Handing the tool the FIFO read-write (`0<>ctl`) makes the Dart VM ignore stdin on macOS. Keep a separate writer open instead.
- Hot restart is not a cold start: native plugin state and sockets survive it.
- Without `--machine`, SIGUSR1 / SIGUSR2 reload and restart only in a debug run that has already started; anywhere else the signal kills the tool.
- The dart MCP server is a convenience, not a dependency. If it shows as failed at session start, everything in this file works with `websocat` on `wsUri` (§4). It answered `initialize` in 5 s in testing when warm; `dart mcp-server` resolves and may recompile its package on launch, which can outlast the default connect timeout. In Claude Code the user can reconnect it with `/mcp` or raise `MCP_TIMEOUT`.
- The first `flutter run` on a phone can die with `App terminated due to signal 10` right after `Installing and launching`. Run it again; the second attaches.

## 4. Find the failing layer by reading state

Read each boundary at the moment of failure. The bug is at the first one where
expected and actual part ways.

| Boundary | Read it with |
|---|---|
| Screen | `ext.flutter.debugDumpApp`; `ext.flutter.debugDumpSemanticsTreeInTraversalOrder`; dart MCP `widget_inspector`; `devicectl device capture screenshot` |
| Bloc / provider state | VM `evaluate` in the owning library, deferred to post-frame. Match the instance (stale blocs linger behind the current route) |
| Cache | `evaluate` a Drift query, `Hive.isBoxOpen(…)`, the repository's cached value |
| Wire: REST | `ext.dart.io.httpEnableTimelineLogging` on, then `ext.dart.io.getHttpProfile`. NSURLSession traffic (`cupertino_http`) reports through `http_profile` and shows as `from_package/N` entries. Not yet run against the app |
| Wire: relay sockets | `RELAY` log lines for content. For timing, direction and size of every frame without a proxy: with HTTP timeline logging on, Dart 3.13 emits `WebSocket.Send` / `Receive` / `Close` timeline events (category `HTTP/websocket`); relay sockets are `dart:io` (`IOWebSocketChannel`). Payloads need the log lines or the relay lens's proxy. Not yet run against the app |
| Relay | `nostr-lens.md` §3 |
| Errors nobody mentioned | dart MCP `get_runtime_errors`; the whole capture buffer at `warning` and above |

Profile builds keep `debugDumpApp`, `debugDumpRenderTree`,
`debugDumpSemanticsTreeInTraversalOrder`, `timeDilation` and the `profile*`
extensions. `platformOverride`, `brightnessOverride` and every `inspector.*`
extension exist in debug only.

Bloc transitions are not written to the log: the observer keeps only the last
event and state for error reports. Read `bloc.state` with `evaluate`. The
recipe, run against a debug app (VM service protocol 4.21):

```bash
WS=<wsUri>
rpc() { jq -nc --arg m "$1" --argjson p "$2" '{jsonrpc: "2.0", id: 1, method: $m, params: $p}' \
  | perl -e 'alarm 20; exec @ARGV' websocat -n1 -B 50000000 "$WS"; }
ISO=$(rpc getVM '{}' | jq -r '.result.isolates[0].id')
LIB=$(rpc getIsolate "$(jq -nc --arg i "$ISO" '{isolateId: $i}')" \
  | jq -r '.result.libraries[] | select(.uri | test("like_action_button.dart$")) | .id')
ev() { rpc evaluate "$(jq -nc --arg i "$ISO" --arg t "$LIB" --arg e "$1" '{isolateId: $i, targetId: $t, expression: $e}')" \
  | jq -c 'if .error then {error: .error.message} else .result | {kind, valueAsString} end'; }
ev 'WidgetsBinding.instance.rootElement?.widget.runtimeType.toString()'
```

- The expression is compiled in the library you name, so pick one that already imports what you call. Library ids change on every build: look them up, never reuse. Private classes of a `part` file are in scope from the owning library.
- `evaluate` needs the WebSocket. Over the HTTP form of the same URI it fails with `No compilation service available`; read-only calls (`getVM`, `getIsolate`) work either way.
- The expression must be one line: a newline anywhere is a compile error however balanced the braces. Write multi-statement probes as a one-line `(() { ... })()`.
- It cannot await: a `Future` comes back as `Instance of 'Future<…>'`. Use `.then((v) => Log.info('PROBE $v'))` and read the log.
- A returned string is cut at about 135 characters. Log long values instead of returning them.
- Object ids from one `evaluate` expire quickly; do the whole probe in one call rather than chaining ids.
- `evaluate` can land mid-frame: the VM services it as an interrupt, even inside `drawFrame`. Run every probe that reads layout or hit-testing, and every one that changes anything (typing, taps, focus, navigation, `emit`), inside a post-frame callback, and report through `Log.info`. `addPostFrameCallback` does not request a frame, so follow it with `WidgetsBinding.instance.ensureVisualUpdate()`: a still screen draws none, and the probe would wait for whatever draws next. A write that lands mid-frame can corrupt the rest of the run (below).
- The call hangs while the app is backgrounded or the phone is locked (hence the `alarm`). Foreground the app with `devicectl device process launch` first. A backgrounded app also tears down its route subtree, so a widget walk finds nothing.

### A run you can no longer trust

The probe driving the app can break it, and the app then reports the damage as
its own bug. #10439 was filed from such a run (checked on a phone, October
2026). An `evaluate` typed into a field mid-frame: `EditableText`'s `setState`
threw "Build scheduled during frame" with a batch edit open, and when the
screen was popped its `dispose` asserted `unfinished batch edits: 1`. The
framework then drops the rest of that frame's teardown, so the route's
`Scaffold` is never disposed and stays registered with the app-level
`ScaffoldMessenger`. From then on every root snackbar throws "Looking up a
deactivated widget's ancestor is unsafe", a live `Scaffold` can keep a stale
snackbar, and taps stop arriving (`_debugMouseTrackerUpdateScheduled`). None of
it happens on a clean launch.

- Before counting a run, and again before Gate B: `$FM taint $RUN`. It exits 1 on those signatures and names the first line, and 3 when the run has no log to read.
- A tainted run is over. Cold-start and redo everything observed after that line. If the signature is itself the bug under test, report it as its own finding.
- A clean `taint` proves only that the app logged none of them, not that the tree is sound.

## 5. Touch on a physical iPhone

1. **VM-service pointer events** on a debug build. `handlePointerEvent(PointerDownEvent…)` then `PointerUpEvent` at a live widget's centre (`localToGlobal(size.center(Offset.zero))`, read at tap time: the keyboard and sliding sheets move targets), with a fresh `pointer` id per tap, dispatched from a post-frame callback with a frame requested, like every other write (§4). Type with `EditableTextState.userUpdateTextEditingValue` the same way. Wait for the target to be on screen and still; poll transient UI such as snackbars every 200 ms rather than sleeping a fixed time. The default for an ad-hoc validation run; cannot reach native dialogs.
2. **`devicectl`.** Launch or foreground the app, screenshot, screen recording, pasteboard, appearance, location. No touch.
3. **Patrol (XCUITest).** Real taps, system dialogs included, but on a physical iPhone the CLI runs release mode only (`patrol_cli` `ios_test_backend.dart`). That means the production bundle id, no VM service, and live logs from `idevicesyslog`, which Xcode 26 and later no longer feed. On the phone it is an ask-the-user item. When the flow is worth keeping as a regression test, write it for the repo's E2E harness instead (`e2e-test` skill, `local_stack/profile.sh`): Android emulator, plain `integration_test` suites, and new suites avoid Patrol.
4. **The user's hand**, for camera, biometrics and anything else hardware.

`idb` taps simulators only.

## 6. Adversarial rows for the adjacent sweep

| Row | What it catches |
|---|---|
| Cold start, act before the first relay connects | signer not ready, empty-cache paths, a lazy `BlocProvider` whose `create` never ran |
| Background for 2+ minutes, then foreground | sockets the SDK idle policy dropped, a suspended isolate, subscriptions nobody reopened, double fetch on resume |
| Offline → act → online | "unanswered" rendered as "empty"; a retry that never fires |
| Account switch, sign-out, sign-in | dependencies captured at first build, cross-account cache or prefs leak |
| Relay slow or refusing (see relay lens §6) | timeout shown as empty, `OK false` counted as success |
| Leave the screen mid-await | emit after close, `setState` after dispose, `BuildContext` across an async gap |
| Double tap, rapid repeat | missing `droppable` / `sequential`, duplicate publishes |
| Same account on a second device | replaceable read-modify-write, self-addressed DM copies |
| Light / dark, largest text, RTL, reduce motion | wrong colour token, clipped text, animation that never settles |

## 7. Dart signatures to grep before theorising

- `emit` / `add` after an `await`, a stream callback or a timer with no `isClosed` check: "Cannot emit new states after calling close".
- `ref.read` inside `BlocProvider.create`, or `late final` bloc built in `initState`: stale after an auth flip.
- `BlocProvider` with no consumer below it: `create` never runs.
- A discarded `Future` whose error disappears; `.catchError((_) => null)` on a `Future<T?>`, which throws at runtime.
- `Timer`, `StreamSubscription` or controller not cancelled in `dispose`; `Future.delayed` used as synchronisation.
- `Equatable` `props` missing a field, or a mutated collection reused in state: the change is never emitted.
- `stream.listen` with no `onError`; `await for` over a stream that never closes.
- Seconds versus milliseconds in `created_at`; `DateTime.now()` where the test needs a clock.
- `!`, `int.parse` or `.first` on a tag that came from a relay.

## 8. Proof design

- Put the regression test at the lowest layer that shows the bug. If production code catches the error, a stubbed collaborator hides it: use the real repository or DAO over a fake client.
- Time with `fakeAsync` and `elapse`, streams with `pumpEventQueue`. Never `Future.delayed`.
- Bound every positive wait (`.timeout(const Duration(seconds: 5))`), or a mutant hangs for ten minutes instead of failing.
- Mutation: commit first, remove the fix, watch the named test go red, restore. A mutation that reddens a different test than its own means the harness skipped the guard.
- Dispose and leak claims: instance counts before and after over the VM service (`getInstances`; `getAllocationProfile` with `gc: true` only attempts a collection). `leak_tracker` (`LeakTesting.enable()`, `experimentalLeakTesting:`) covers `testWidgets` only and only instrumented classes: Flutter disposables yes, a Bloc no.
- Races: a scratch `registerExtension` that dispatches the events milliseconds apart. Never committed.
- "It used to work": `git bisect run` with the failing test, and name the introducing change.
