---
name: e2e-test
description: |
  Run and debug Flutter E2E integration tests that exercise the real
  app against a local Docker backend (no mocks). Use when running
  E2E tests, debugging failures, or working on the local harness.
author: Claude Code
version: 1.3.0
---

# E2E Integration Testing

Goal: run the real app against a real local backend, end-to-end.
OAuth, relay subscriptions, and media uploads all hit local Docker
services — no mocks anywhere. Tests live in
`mobile/integration_test/`, backend in `local_stack/`.

## Run a test

Two terminals, from `mobile/`:

```bash
# Terminal 1 — emulator
mise run emulator

# Terminal 2 — tests
mise run e2e_test                                              # All auth tests
mise run e2e_test integration_test/auth/auth_journey_test.dart # Single test
```

`e2e_test` brings up the Docker stack, runs the suite, captures a
merged docker+logcat+app timeline at `test_reports/*.jsonl`, and
prints the native test XML path + failure excerpts when the APK
fails to install. **For e2e targets, never call `patrol test` or
`flutter test` directly** — you'll lose the timeline and the diagnostics.

Not every suite is a patrol suite. `profile.sh` recursively greps the
target for `patrolTest` and dispatches: patrol suites go to
`patrol test`, plain `integration_test` suites go to
`flutter test --device-id`. Everything under `integration_test/e2e/`
is now the plain kind. The original four converted off patrol in #7005 because
none used the native automator for anything load-bearing, and new suites follow
that pattern. The plain path pre-grants `POST_NOTIFICATIONS`, since
without an automator nothing can dismiss that dialog.

## Version pair

`patrol` (the package) and `patrol_cli` (the binary) ship as a matched
pair, and `patrol_cli` enforces it at run time — a mismatch aborts the
run before any test executes.

| Half | Version | Declared in |
|---|---|---|
| `patrol` package | 4.9.0 | `mobile/pubspec.yaml` (`patrol: ">=4.9.0 <4.10.0"`) |
| `patrol_cli` binary | 4.7.0 | `local_stack/profile.sh` (`PATROL_CLI_VERSION`) |

`profile.sh` checks the installed CLI and runs
`dart pub global activate patrol_cli <version>` when it differs, so
`mise run e2e_test` self-heals. That activation is **machine-global**:
it switches the CLI for every checkout, including worktrees still on an
older `patrol`, which will then fail the same compatibility check until
they rebase. Change the two versions together — the compatibility table
is at https://patrol.leancode.co/documentation/compatibility-table.

The package constraint pins a single minor rather than using a caret,
because that table closes open-ended bands retroactively. A caret range
lets `flutter pub upgrade` walk into a `patrol` the pinned CLI rejects,
and the abort then surfaces at `patrol test` time, unrelated to whatever
the upgrade was actually for.

## Stack

| Service | Port | Purpose |
|---|---|---|
| Keycast | 43000 | OAuth + NIP-46 signer |
| FunnelCake Relay | 47777 | Nostr relay (WebSocket) |
| FunnelCake API | 47777 | REST API, under `/api/` on the same proxy |
| Blossom | 43003 | Media server |
| Postgres | 15432 | Keycast DB |
| Invite | 43004 | divine-invite-darshan (Viceroy) |

The app reaches these at `10.0.2.2` from the emulator. Cleartext to
loopback hosts is permitted in every build type on both platforms.

### Only start what your flow needs

Most services are irrelevant to any given test, and `local_up`
failing on one does not mean you are blocked. An invite-only flow
needs `invite` alone: a locally-generated nsec signs on-device, so
no Keycast, and `onboarding_mode=open` means no invite gate. Check
what is actually healthy before debugging a service you never call:

```bash
docker compose -f local_stack/docker-compose.yml ps
```

```bash
mise run local_up         # Start (auto-runs local_setup on fresh worktrees)
mise run local_up_cached  # Same, but reuse cached images (offline / rate-limited)
mise run local_down       # Stop
mise run local_reset      # Wipe data + restart
mise run local_status     # Health
```

If `local_up` fails only at `e2e-seed` and the services your test
actually needs are healthy (auth tests don't need the indexer),
bypass the seed:

```bash
bash ../local_stack/profile.sh integration_test/<your_test>.dart
```

Any `local_up` failure prints the per-service status, the logs of
whatever is down, and that same bypass command. Set `E2E_TEST_PATH`
before the run and it prints the command for *your* test:

```bash
E2E_TEST_PATH=integration_test/auth/auth_journey_test.dart mise run local_up
```

### Port conflicts

`up.sh` pre-flights every host port in `docker-compose.yml` before
starting anything. This machine runs several compose projects, and
stale test containers days old are the normal case, so collisions
are routine. The check names the service, the port, and the holder:

```
  port 43000  wanted by service "keycast"
            held by container "funnelcake-test-clickhouse-sim" — compose project "funnelcake-test"
            remedy: docker rm -f funnelcake-test-clickhouse-sim

  port 45173  wanted by service "keycast"
            held by a host process (not a container), listening on: 127.0.0.1:45173
            find it: sudo lsof -nP -iTCP:45173 -sTCP:LISTEN
```

Ports already published by our own containers are not conflicts —
`up.sh` is idempotent. The raw daemon error it replaces (`Bind for
0.0.0.0:16380 failed: port is already allocated`) named neither the
service nor the holder.

Listening sockets come from `ss` on Linux and `lsof` on macOS, and
the `find it:` line names whichever of the two the machine has. With
neither installed the run says so and falls back to container-held
ports alone, which `docker ps` reports without either tool — and a
stale container is the usual culprit anyway.

`bash local_stack/test_stack_scripts.sh` covers these paths against a
stubbed docker/ss/lsof, so it needs no daemon and no free ports.

### Startup races

Containers sometimes start before Docker's embedded DNS knows a
dependency's alias: `funnelcake-migrate` dies with `dial tcp: lookup
funnelcake-clickhouse on 127.0.0.11:53: no such host`, or `keycast`
burns its DB connection attempts on `Temporary failure in name
resolution`. Both succeed on an unchanged retry. `up.sh` re-runs the
whole `up` (idempotent — it restarts whatever died) up to 3 attempts,
5s apart, **only** when it sees a name-resolution signature in the
compose output or in the failed containers' logs. A port clash or a
bad image fails straight through rather than retrying pointlessly.

### Running a locally built backend

Compose pulls `ghcr.io/divinevideo/divine-invite-darshan:e2e`. To
test an unmerged backend branch, build it and tag it as that name so
compose uses the local image without pulling:

```bash
docker build -f Dockerfile.local -t divine-invite-darshan:local .
docker tag divine-invite-darshan:local ghcr.io/divinevideo/divine-invite-darshan:e2e
```

The published image is amd64-only, and Compose selects `linux/amd64`
explicitly so Apple Silicon can run it through emulation. A local build
on Apple Silicon is arm64-native, so select that platform before starting
the stack:

```bash
export INVITE_PLATFORM=linux/arm64
```

`invite` is one of the few services without `pull_policy: always`, so
a plain `mise run local_up` keeps your tag. Use `local_up_cached` if
you have overridden a service that *does* pull on every start.

### Cross-repo gotcha: `kv-store-data.json`

The invite service (`divine-invite-darshan`) reads a gitignored
`kv-store-data.json`. A **fresh worktree of that repo does not have
it**, and without it the entire invite-service suite fails. Seed it:

```bash
printf '{}' > kv-store-data.json
```

## Emulator

```bash
mise run emulator           # Normal launch (auto-detects DISPLAY)
mise run emulator_headless  # Offscreen, no window
mise run emulator_wipe      # -wipe-data (storage exhausted)
```

Override AVD: `AVD_NAME=<name> mise run emulator`. Always uses
`-gpu host` — swiftshader can't render media_kit frames.

Skip the per-run reinstall with `PATROL_NO_UNINSTALL=true mise run
e2e_test ...` when iterating fast and the APK hasn't changed.
Stale-state debugging cost is yours.

Buffer auth-flow logs: `adb logcat -G 16M` (default 256 KB rotates
mid-flow).

### Storage exhaustion

Not just a Patrol problem — `flutter run` hits it too, and the error
is on the install, not the build:

```
java.io.IOException: Requested internal only, but not enough space
```

A debug APK is ~289 MB and needs real headroom on top of that.
`adb shell pm trim-caches 1G` often does not free enough; `mise run
emulator_wipe` (`emulator.sh --wipe`) is usually the faster fix.

## Patterns

### Launching the app

`pumpAndSettle` hangs because of persistent polling timers — the app
polls email verification every 3s, so the tree never reaches a
quiescent frame and the call blocks until its 10-minute timeout. Use
`launchAppGuarded` (from `test_setup.dart`) with error suppression and
a bounded pump instead of `pumpAndSettle`:

```dart
final originalOnError = suppressSetStateErrors();
final originalErrorBuilder = saveErrorWidgetBuilder();
launchAppGuarded(app.main);

await pumpUntilSettled(tester, maxSeconds: 3);

restoreErrorWidgetBuilder(originalErrorBuilder);
restoreErrorHandler(originalOnError);
drainAsyncErrors(tester);
```

When you need to stop as soon as something appears rather than pump a
fixed budget, use `waitForText` / `waitForWidget` from
`navigation_helpers.dart` — both poll and return early.

The tell that a suite has this bug: patrol logs
`PATROL_LOG {"type":"test",…,"status":"start"}` and then **no terminal
status at all**, while the app keeps logging. It reads like a crash;
it is a hang.

### Async publish → relay query

UI navigates before publish/upload completes. Poll the relay:

```dart
for (var i = 0; i < 120; i++) {
  await tester.pump(const Duration(milliseconds: 500));
  events = await queryRelay(filter);
  if (events.isNotEmpty) break;
}
```

### Onboarding sheets blocking UI

New bottom sheets may cover the target widget:

```dart
for (var i = 0; i < 20; i++) {
  await tester.pump(const Duration(milliseconds: 250));
  final gotIt = find.text('Got it!');
  if (gotIt.evaluate().isNotEmpty) {
    await tester.tap(gotIt);
    break;
  }
}
```

### Patrol false positives

Patrol bundles every file in a target dir into one APK. When file B
runs, file A shows up as "not requested" `[E]` markers in logcat.
Trust only the final `✅`/`❌` lines.

### Never put `/` in a patrol test name

Patrol names each JUnit case `MainActivityTest#runDartTest[<dart test
name>]`, and the AndroidX orchestrator writes a per-test output file
named after it. Android's `ContextImpl.makeFilename` rejects any
filename containing a path separator, so a test called e.g. `'strips
metadata via separate input/output paths'` crashes the orchestrator:

```
FATAL EXCEPTION: AndroidTestOrchestrator
java.lang.IllegalArgumentException: File …input/output paths].txt
contains a path separator
```

The tell is a **green summary with a non-zero exit**: Gradle reports
`Instrumentation run failed due to Process crashed` and exits 1, while
patrol prints `Failed: 0` — because the offending test never started
and so was never counted. Compare `Total:` against the number of tests
in the file when the exit code disagrees with the summary.

Write `input and output`, not `input/output`.

### NIP-98 URL binding

The invite service rejects a signed request whose `u` tag does not
match the URL the server saw: `auth_invalid_binding`, HTTP 401. The
client must sign the **same base URL it calls**. Signing
`http://10.0.2.2:43004` while calling `http://localhost:43004` fails;
signing and calling the same host works. If you switch the emulator
between `10.0.2.2` and a forwarded `localhost`, switch the signing
base URL with it.

### Provider error caching

Providers using `requireIdentity` (or similar non-nullable getters)
crash during cold start and Riverpod caches the error forever. Use
the nullable accessor (`currentIdentity`) and handle null.

### Material ancestor

`TextField` in an overlay/transition without `Scaffold` needs:

```dart
Material(color: Colors.transparent, child: TextField(...))
```

## Helpers

`integration_test/helpers/`:

- `test_setup.dart` — `launchAppGuarded`, error suppression, async-error drain
- `navigation_helpers.dart` — register, login, tap tabs, wait for widgets
- `relay_helpers.dart` — publish/query Nostr events
- `db_helpers.dart` — Postgres (verification tokens, refresh tokens)
- `http_helpers.dart` — Keycast API (verify email, forgot password)
- `constants.dart` — ports + `appPackage`

## Debugging

### Never pipe a long-running command through `tail`/`head`

```bash
flutter run ... | tail -40      # WRONG
flutter run ... > /tmp/run.log 2>&1   # then read/grep the file
```

Two separate failures. The pipe buffers until the command exits, so
you watch a blank screen and lose everything if you kill it. And the
pipeline's exit status is `tail`'s, so a failed run reports success.
Redirect to a file and read that instead.

```bash
# Service logs
docker compose -f local_stack/docker-compose.yml logs keycast --tail=50
docker compose -f local_stack/docker-compose.yml logs blossom | grep -v 'path=/'

# Auth trace
adb logcat -d | grep 'flutter.*\[AUTH\]' | grep -v 'Router redirect'

# Last merged timeline
ls mobile/test_reports/*.jsonl
```

The timeline is where cross-service failures actually show up. A test
can fail in **teardown** from an unhandled async error against a service
that is down — Patrol's summary only says the test failed, while the
timeline names the URL that was refused. Read it before writing a
failure off as flaky.

```bash
rg -o '.{0,60}logout.{0,50}' mobile/test_reports/<run>.jsonl
```

If patrol reports `Total: 0` with Gradle exit 1, the runner
auto-prints the native test XML path + failure excerpts — that's
an APK install failure, not a missing test. Free space with
`adb shell pm trim-caches 1G` or `mise run emulator_wipe`.
