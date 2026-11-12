# Flutter and Dart lens

Facts here come from the SDK source pinned at the time (Flutter 3.47.2,
Dart 3.13.2; `mobile/mise.toml` now pins 3.47.9 with Dart 3.13.7, on which
the §3 and §4 recipes were re-run against an iOS 27.2 simulator on 2026-11-11),
`origin/main`, runs on a developer Mac in October 2026, and on 2026-11-02 a
headless `flutter-tester`, an iOS 27.0 simulator and a USB iPhone on iOS 27.0.1.
iOS build traps are
in `.claude/rules/ios_build_troubleshooting.md`; read it before the first build,
and use `mise exec -- flutter` from `mobile/`.

## 0. Before touching the device

A phone, the simulators, the pub cache and the local Docker stack may be shared
with other agent sessions on the same Mac.

- `xcrun devicectl list devices`: the phone is listed and available. A wireless-only iPhone may never attach the VM service; use USB.
- `pgrep -fl 'flutter_tools|xcodebuild|patrol'` and any other live agent sessions: nobody else is building for it or attached to it. If someone is, ask the user; never kill by pattern.
- Every `flutter` command that targets a device names it with `-d <id>`, using the id `flutter devices` prints: `run`, `drive`, `install`, `attach`, `logs`, `screenshot`, and `flutter test` on an `integration_test/` suite. On Android, the `e2e-test` skill's `mise run e2e_test` is the route for suites that need the local stack, such as those under `integration_test/auth/`; a direct `flutter test` cannot drive a patrol suite and gives up the merged timeline. Pass a simulator's UDID or an emulator's serial unless the `devicectl` and `pgrep` checks above show the phone is free and yours to use.
- Without `-d`, Flutter picks for itself: the only device it finds, or the only attached phone, simulator or emulator among several, so a USB phone beside the macOS target still wins. On macOS a wireless phone is picked only when it is the only device of any kind.
- `mise run e2e_test` and `local_stack/profile.sh` pick their own Android device: `ANDROID_SERIAL` if set, else the first emulator, else the first device `adb devices` lists. They then clear its logcat and install the app, and a patrol suite uninstalls it afterwards unless `PATROL_NO_UNINSTALL=true`. `mise run local_install` runs `adb install` with no serial at all. So with a phone attached, start an emulator first unless the phone is yours to use: `mise run emulator` in its own terminal (it does not return), then set `ANDROID_SERIAL` to the `emulator-<port>` serial `adb devices` shows.
- **Delegated agents** (reviewers, helpers) run only commands that stay on the host: analyze, format, `pub get`, code generation, the guards, `flutter devices`, `flutter test` or `dart test` on files under `test/` outside `test/manual/` and not tagged `integration`, the stubbed `mise run test_local_stack_scripts`, and read-only views of the stack: `mise run local_status`, `docker compose -f local_stack/docker-compose.yml ps` or `logs --tail=<n>`.
- **They never run** anything that selects, installs on, launches on, boots, erases or attaches to a device, simulator or emulator, or that starts, stops, resets or attaches to the local stack or a running app:
  - `integration_test/` suites, the acceptance tests in `test/manual/`, every `flutter` command that targets a device, and this skill's `scripts/flutter-machine.sh` (§3);
  - the dart MCP `vm_service`, `dtd`, `get_runtime_errors`, `hot_reload`, `hot_restart`, `widget_inspector` and `flutter_driver_command` tools, and `websocat` on a VM service;
  - `patrol`, `maestro`, `idb`, `xcodebuild test`, the `mise run e2e_test` and `emulator*` tasks, and every `local_*` task except `local_status` and `local_build`;
  - `test_local_name_server` (it starts its own Compose project), `local_stack/` scripts other than its stubbed `test_*_scripts.sh` checks, and `docker compose up` and `down`;
  - any `adb`, `devicectl` or `simctl` command other than listing devices.
- State this in every brief you write, and run device work yourself. Host commands can still lower the generated iOS Swift package floor (`.claude/rules/ios_build_troubleshooting.md`, Cause 3), so check it before your next device build.
- A debug run replaces the installed Divine Staging build, and its data may not survive. That is an ask-the-user item. On the iPhone the Keychain account survived and the app came back signed in as the existing account. Afterwards the phone holds a debug build, which Flutter says does not launch from the home screen on iOS 14 and later, so reinstall the TestFlight build to use the app on its own again.
- One simulator per session, named by UDID in every note.

The device steps below are written for iOS; §5b has Android, macOS and web.

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
- `$FM vmlog $RUN 5` prints the `Logging` stream for five seconds, backlog first, one `level<TAB>logger<TAB>message` line each. On `flutter-tester` (Dart 3.13.2) the history started when DDS subscribed: `developer.log` calls from the first moments of a cold-started `main()` were not in it, and a hot restart's were. The VM cuts a message at 128 characters and the command marks the cut. On the iPhone it returned on time (3 s and 6 s) and carried `nostr_sdk`'s relay-pool lines (`Connect begin`, OK responses, COUNT requests), none of which are in `$FM logs`.
- The relay layer rate-limits its own log lines per relay, site and level (`RelayDiagnosticsAdapter` in `nostr_client`): three a minute, then one `Further requestSettlement warning diagnostics suppressed until <time>`. How many were dropped shows only in a `Suppressed <n> repeated …` line, written when the next one arrives after that minute. A burst of refusals or timeouts leaves three lines, so count frames at the proxy (relay lens §6) before reading the log as a count.
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
$FM status $RUN                        # running / exited, started or not; exit 0, 1 (still starting), 3 (not running)
$FM ext $RUN ext.flutter.debugDumpApp  # any service extension, optional JSON params
$FM reload $RUN                        # hot reload; `restart` = hot restart
$FM logs $RUN                          # the app's log lines so far
$FM vmlog $RUN 5                       # the VM Logging stream (dart:developer logs), §2
$FM taint $RUN                         # exit 1 if the tree may be corrupted (§4)
$FM stop $RUN
```

Run on the headless `flutter-tester` device: start, wait, status, ext, reload,
restart, vmlog, taint, stop. Run on a USB iPhone on iOS 27.0.1: start, wait,
status, ext, vmlog, taint, stop, and on an earlier run logs and a second start
on the same install; `restart` crashed the app (below). On the phone the
first `app.started` took about four minutes, and the tool printed "The Dart VM
Service was not discovered after 60 seconds" on the way; it attached without
help, so keep waiting rather than restarting.

- `start` refuses a run directory whose tool is still alive. `stop` sends `app.stop`; a run that never reached `app.start` has no appId to name, so `stop` ends that run's own process tree instead, after checking the recorded pid is still its `flutter run --machine`.
- The run survives the shell call that started it, so separate calls can drive it. Stop it when you are done: a leftover run holds the device.

- `wsUri` goes to the dart MCP `vm_service` tool or `websocat`. `dtdUri` goes to its `dtd` tool, which unlocks `get_runtime_errors`, `widget_inspector`, `hot_reload` and `hot_restart`.
- One malformed line on stdin crashes the tool with a `FormatException`. Build messages with `jq`, as the helper does.
- Handing the tool the FIFO read-write (`0<>ctl`) makes the Dart VM ignore stdin on macOS. Keep a separate writer open instead.
- Hot restart is not a cold start: native plugin state and sockets survive it. Hot reload is weaker still: a running async closure (a `Timer.periodic` callback) kept its old body on `flutter-tester`; use `restart` for code that is already scheduled.
- Without `--machine`, SIGUSR1 / SIGUSR2 reload and restart only in a debug run that has already started; anywhere else the signal kills the tool.
- The dart MCP server is a convenience, not a dependency: if it shows as failed at session start, everything in this file works with `websocat` on `wsUri` (§4). `dart mcp-server` may recompile its package on launch and outlast the default connect timeout; in Claude Code the user can reconnect it with `/mcp` or raise `MCP_TIMEOUT`.
- The first `flutter run` on a phone can die with `App terminated due to signal 10` right after `Installing and launching`. Run it again; the second attaches.
- On the iPhone a hot restart of the Divine app ended the run both times it was tried (debug, iOS 27.0.1): `EXC_BAD_ACCESS` on the `com.apple.NSURLSession-delegate` queue at addresses ending in the same `…0258`, then `Lost connection to device`. It reads as a native `cupertino_http` callback reaching the torn-down isolate. Use `stop` and `start` for a fresh run, and do not report the crash as an app bug. The scratch app on `flutter-tester` has no `cupertino_http` and restarted fine.
- A device build can fail in `Building native assets` when the `sqlite3` hook cannot download `libsqlite3mc.arm64.ios.dylib` (`github.com` timed out here while `api.github.com` answered). Fetch the asset with `gh release download sqlite3-<ver> --repo simolus3/sqlite3.dart --pattern 'libsqlite3mc.arm64.ios.dylib'`, check its SHA-256 against `asset_hashes.dart` in the pub-cache `sqlite3` package, and copy it to `mobile/.dart_tool/hooks_runner/shared/sqlite3/build/download-<first 8 hex of that hash>/libsqlite3mc.dylib`. Nothing tracked changes.

## 4. Find the failing layer by reading state

Read each boundary at the moment of failure. The bug is at the first one where
expected and actual part ways.

| Boundary | Read it with |
|---|---|
| Screen | `ext.flutter.debugDumpApp`; `ext.flutter.debugDumpSemanticsTreeInTraversalOrder`; dart MCP `widget_inspector`; `devicectl device capture screenshot` |
| Bloc / provider state | VM `evaluate` in the owning library, deferred to post-frame. Match the instance (stale blocs linger behind the current route) |
| Cache | `evaluate` a Drift query, `Hive.isBoxOpen(…)`, the repository's cached value |
| Wire: REST | `ext.dart.io.httpEnableTimelineLogging` on, then `ext.dart.io.getHttpProfile` with the `isolateId`: each `dart:io` request lists method, `uri`, start and end time, request, response and events. Run on `flutter-tester`, and on the Divine app on an iOS 27.0 simulator and on an iPhone (iOS 27.0.1), debug: REST shows as plain ids, and a media download (`cupertino_http` in `media_cache`) as a `from_package/N` entry: a GET to the media host, status 200, request and response recorded. Switch the logging on right after launch: on the iPhone 30 s later the first media fetches had already passed (8 requests, none `from_package`), while from launch it caught 65, two of them `from_package`. On a Galaxy S23 (Android 17, debug, signed out) `cronet_http` shows the same way: a `from_package/N` GET to the media host, status 200, with response headers and content length and `connectionInfo` `package:cronet_http`, but no events and no response body (a `dart:io` entry keeps both). Which call decides it: `MediaCacheManager.cacheFileCancellable` uses the platform downloader, `cacheFile` uses flutter_cache_manager's file service on a `dart:io` client, so one thumbnail URL fetched with `cacheFile` was a plain id with user-agent `Dart/3.13 (dart:io)` and with `cacheFileCancellable` a `from_package/1`. Signed out no feed loads, so trigger a download by `evaluate` in `open_vine_image_cache.dart`: `openVineImageCache.cacheFileCancellable('<public media URL>', key: 'probe')`. Cronet came from Play Services (Cronet 149.0.7827.102). Without Play Services: on the Pixel_10_Pro_XL emulator (a Play Store image, booted `-read-only` so the AVD stays untouched) the same probe was `from_package/1` with Play Services and, after `pm disable-user --user 0 com.google.android.gms` and a fresh app process, a plain `dart:io` id with status 200. The app logged once `MediaCache: cronet_http init failed, using dart:io HttpClient for the rest of this process: … All available Cronet providers are disabled`, and a second download in that process was `dart:io` too. An AOSP image or a phone with no Play Services at all was not run; the factory catches any `Object`, so it should take the same path |
| Wire: relay sockets | `RELAY` log lines for content. For timing, direction and size of every frame without a proxy: turn on HTTP timeline logging (`$FM ext $RUN ext.dart.io.httpEnableTimelineLogging '{"enabled":"true"}'`; the value is a string), then `getVMTimeline` shows `WebSocket.Connect` (with the URI), `Send`, `Receive` and `Close`, each tagged `args.filterKey: "HTTP/websocket"` and carrying connection id, direction, opcode and byte count; the default recorded streams already include `Dart`. Relay sockets are `dart:io` (`IOWebSocketChannel`). Payloads need the log lines or the relay lens's proxy. Run on `flutter-tester` against a local `dart:io` socket; not yet run against the app |
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
its own bug: #10439 was filed from such a run. An `evaluate` that typed into a
field mid-frame left an `EditableText` batch edit open; popping the route then
dropped the rest of that frame's teardown, so the route's `Scaffold` stayed
registered with the app-level `ScaffoldMessenger`. From then on every root
snackbar threw and taps stopped arriving. None of it happens on a clean launch.
The signatures are the `taint_re` line of `scripts/flutter-machine.sh`.

- Before counting a run, and again before Gate B: `$FM taint $RUN`. It exits 1 on those signatures and names the first line, and 3 when the run has no log to read.
- A tainted run is over. Cold-start and redo everything observed after that line. If the signature is itself the bug under test, report it as its own finding.
- A clean `taint` proves only that the app logged none of them, not that the tree is sound.

## 5. Touch on a physical iPhone

1. **VM-service pointer events** on a debug build. `handlePointerEvent(PointerDownEvent…)` then `PointerUpEvent` at a live widget's centre (`localToGlobal(size.center(Offset.zero))`, read at tap time: the keyboard and sliding sheets move targets), with a fresh `pointer` id per tap, dispatched from a post-frame callback with a frame requested, like every other write (§4). Type with `EditableTextState.userUpdateTextEditingValue` the same way. Wait for the target to be on screen and still; poll transient UI such as snackbars every 200 ms rather than sleeping a fixed time. The default for an ad-hoc validation run; cannot reach native dialogs.
2. **`devicectl`.** Launch or foreground the app, screenshot, screen recording, pasteboard, appearance, location. No touch.
3. **Patrol (XCUITest).** Real taps, system dialogs included, but on a physical iPhone the CLI runs release mode only (`patrol_cli` `ios_test_backend.dart`). That means the production bundle id, no VM service, and live logs from `idevicesyslog`, which Xcode 26 and later no longer feed. On the phone it is an ask-the-user item. When the flow is worth keeping as a regression test, write it for the repo's E2E harness instead (`e2e-test` skill, `local_stack/profile.sh`): Android emulator, plain `integration_test` suites, and new suites avoid Patrol.
4. **The user's hand**, for camera, biometrics and anything else hardware.

`idb` taps simulators only.

Traps that make a probe lie:

- Confirm the account from the log before you call a run signed-out: `Auth state:` (`auth_service.dart`) and `Signing kind` (`signer_factory.dart`). A Keychain entry can survive an uninstall, so a reinstall may come back signed in and publish for real (a debug install over Divine Staging on the iPhone did); the log of a write-blocking proxy (`--reject-event`, relay lens §6) is the proof that nothing got through.
- One tap, one look: screenshot after every tap that can change state. A blind batch can land on a destructive row once a layout shifts.
- Navigate as the app does. `go()` straight to a page the app `push`es leaves `pop` with nothing to return to, and the bugs that follow belong to the probe.

## 5b. Android, macOS and web

**Android.** Debug builds are `co.openvine.app.staging` and release is `co.openvine.app` (`mobile/android/app/build.gradle.kts`); setup is in `mobile/docs/ANDROID_LOCAL_SETUP.md`.

- Name the device: `adb devices`, then `ANDROID_SERIAL=<serial>` for `adb` and the `mise run` tasks, and `-d <serial>` for every `flutter` command (§0 says why a phone beside an emulator gets picked).
- The helper works unchanged: `$FM start $RUN <repo>/mobile <serial> --dart-define=DEFAULT_ENV=STAGING …`. `flutter run` forwards the VM service port to the host, so the `wsUri` from `wait` works with `websocat` as in §4.
- `flutter run` can stop before it builds: "The Java version used for the build is 25.0.4, which is incompatible with Gradle 8.14". Flutter takes Android Studio's bundled JDK before `JAVA_HOME` (`flutter doctor -v` names it), and the repo builds on 17 (`mobile/mise.toml`). `flutter config --jdk-dir=<JDK 17>` fixes it but is a global setting, so ask first. Without it, build with Gradle and let the helper install the result: in `mobile/android`, `JAVA_HOME=<mise JDK 17> FLUTTER_ROOT=<flutter sdk> ./gradlew assembleDebug -Ptarget=lib/main.dart -Ptarget-platform=android-arm64 -Pdart-defines=$(printf 'DEFAULT_ENV=STAGING' | base64)` (1 m 52 s in a worktree that had never built Android), then `$FM start … --use-application-binary=<repo>/mobile/build/app/outputs/flutter-apk/app-debug.apk`. The app then talked to staging.
- `evaluate` compiles through that `flutter run`. Once it has ended, `evaluate` answers "No compilation service available; cannot evaluate from source" while the VM service is still up behind its `adb forward` (`adb logcat -d | grep 'Dart VM service is listening'` prints the port and token). Start the run again.
- Keep the screen on. On the S23 one run ended with "Lost connection to device." about 70 s after the screen went off and the app went to `paused`. With `adb shell input keyevent KEYCODE_WAKEUP` every 15 s (it changes no setting) the next run was still up after three minutes. That is two runs, not a controlled test. The phone woke straight into the app; a lock screen would need the user.
- A first `flutter run` once ended with "Error connecting to the service protocol … DDS shut down too early" while the app was running. The same command worked on the second try.
- Logs: `Log.*` and `debugPrint` reach `adb logcat` under the tag `flutter` (the `e2e-test` skill greps `flutter.*\[AUTH\]`). Logcat's buffer rotates: the same skill sets it with `adb logcat -G 16M`, and `adb logcat -c` starts clean. `dart:developer` logs are on the VM `Logging` stream (`$FM vmlog`), not in logcat (the `[RelayManager]` lines on the S23 were in `vmlog` and absent from logcat). A native crash: `adb logcat -b crash -d`.
- Look and touch: `adb exec-out screencap -p > shot.png`. `adb shell input tap <x> <y>` takes device pixels (on the S23, 1080 x 2340 at 480 dpi, `input tap 538 2024` hit a button), where the VM-service pointer events of §5 take logical ones; divide by `devicePixelRatio`.
- The emulator reaches the host's local stack at `10.0.2.2`; a physical phone cannot (`AGENTS.md`, Local Stack Development). A USB phone can still use a Mac-side service on loopback: `adb reverse tcp:<port> tcp:<port>` plus a scratch `localHost` change, as the relay proxy did on the S23 (relay lens §6, the app behind the proxy). The emulator booted with `-dns-server <the Mac's resolver>` (`scutil --dns`) and resolved the media host.

**macOS.** `-d macos`, debug only; the local stack is `localhost` there (`AGENTS.md`, Local Stack Development). **Web.** Nothing wires a LOCAL web run, so reproduce against a STAGING or PRODUCTION build or the PR preview and say so. The VM-service recipes in §4 were written for native builds.

## 6. Adversarial rows for the adjacent sweep

| Row | What it catches |
|---|---|
| Cold start, act before the first relay connects | signer not ready, empty-cache paths, a lazy `BlocProvider` whose `create` never ran |
| Background for 2+ minutes, then foreground (proxy: `--stall-after-ms`, or end it; relay lens §6) | sockets the SDK idle policy dropped, a suspended isolate, subscriptions nobody reopened, double fetch on resume |
| Offline → act → online | "unanswered" rendered as "empty"; a retry that never fires |
| Account switch, sign-out, sign-in | dependencies captured at first build, cross-account cache or prefs leak |
| Relay slow or refusing (see relay lens §6) | timeout shown as empty, `OK false` counted as success |
| Leave the screen mid-await | emit after close, `setState` after dispose, `BuildContext` across an async gap |
| Double tap, rapid repeat | missing `droppable` / `sequential`, duplicate publishes |
| Same account on a second device | replaceable read-modify-write, self-addressed DM copies |
| Upgrade from the previous build over its existing data | a Drift or prefs migration that never ran, a key renamed without its cleanup |
| Feature flag on, then off, in one session | a gate read once at build; UI that outlives the flag |
| Cold start from a push or a deep link | a route built without its `extra` (`routing.md`: it is a warm-start cache only), a signer that is not ready yet |
| Light / dark, largest text, RTL, reduce motion, a non-English locale | wrong colour token, clipped text, animation that never settles, English left in a widget, a plural form the locale lacks |

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
- A filter built from a list that can be empty (`authors: followingPubkeys`) and sent without a guard: nostr lens §5, "Empty filter list".

## 8. Proof design

- Put the regression test at the lowest layer that shows the bug. If production code catches the error, a stubbed collaborator hides it: use the real repository or DAO over a fake client.
- Time with `fakeAsync` and `elapse`, streams with `pumpEventQueue`. Never `Future.delayed`.
- Bound every positive wait (`.timeout(const Duration(seconds: 5))`), or a mutant hangs for ten minutes instead of failing.
- Mutation: commit first, remove the fix, watch the named test go red, restore. A mutation that reddens a different test than its own means the harness skipped the guard.
- Dispose and leak claims: instance counts before and after over the VM service (`getInstances`; `getAllocationProfile` with `gc: true` only attempts a collection). `leak_tracker` (`LeakTesting.enable()`, `experimentalLeakTesting:`) covers `testWidgets` only and only instrumented classes: Flutter disposables yes, a Bloc no.
- Races: a scratch `registerExtension` that dispatches the events milliseconds apart. Never committed.
- "It used to work": `git bisect run` with the failing test, and name the introducing change.
