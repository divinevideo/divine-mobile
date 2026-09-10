# Build Speed Checklist

Status: Current

Use this checklist when builds slow down before reaching for `flutter clean`.

Run these commands from `mobile/`.

## Start With Fast Defaults

`./build_ios.sh debug` and `./build_macos.sh debug` are the fast defaults.

1) Open a simulator/device run with `./run_dev.sh`.

2) If the app compiles and runs, do not clean pods or run `flutter clean`.

3) If codegen changed, run one explicit rebuild command, then return to `run_dev`.

### Why repeat builds are quick

The build scripts hash `pubspec.yaml` + `pubspec.lock` after a successful
resolve and store it under `.dart_tool/.last_pub_get_hash`. On the next
run the script compares hashes and skips `flutter pub get` entirely if
nothing changed — no re-download, no re-resolve. Editing `pubspec.yaml`
or pulling a branch with a new `pubspec.lock` invalidates the hash and
triggers a single `pub get`. `flutter clean` wipes `.dart_tool/`, so the
first build after a clean will resolve once.

When `--codegen` is in effect, the standalone `flutter pub get` is
skipped because `dart run build_runner` runs its own resolve — that
removes the duplicate "Resolving dependencies / Downloading packages"
pass that older versions of these scripts produced.

Codegen itself is also short-circuited when none of the codegen inputs
under `lib/` (excluding `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) and
`pubspec.lock` have been modified since the last successful run. The
marker is `.dart_tool/.last_codegen_marker`. Touching any input file —
or `flutter clean` — re-arms the next codegen pass.

## Active Development: build_runner watch

The biggest local-build cost is `dart run build_runner build` (a few
hundred seconds on a cold analyzer). For active development on
`@riverpod` / `@JsonSerializable` / `drift` inputs, run the
watcher in a separate terminal once and leave it running:

```bash
cd mobile && ./watch_codegen.sh
```

Subsequent edits regenerate in seconds because the analyzer stays
warm. The build scripts' codegen short-circuit (above) means
`./build_ios.sh debug --codegen` will see fresh outputs and skip the
expensive re-run.

## Test Speed

`flutter test` defaults to a single isolate. On a multi-core machine you
can parallelize:

```bash
flutter test --concurrency=$(sysctl -n hw.ncpu)
flutter test --reporter=compact   # less verbose than the default
```

For TDD-style iteration on a focused area, scope the path:

```bash
flutter test test/path/to/feature
./watch_tests.sh test/path/to/feature
```

Generated mocks (`*.mocks.dart`) are excluded by `dart_test.yaml` —
don't try to run them as tests. If a test file imports a missing mock,
you need a codegen pass, not a test fix.

## When You See Build Errors

### `pod install` or dependency lock issues

1) Run the platform debug script with pod reset once:

```bash
# iOS
./build_ios.sh debug --pod-reset
# macOS
./build_macos.sh debug --pod-reset
```

2) Re-run app:

```bash
# iOS
./run_dev.sh ios debug
# macOS
./run_dev.sh macos debug
```

3) If still broken:

```bash
./clear_cache.sh --full
```

### `generated code` or `build_runner` related errors

1) Regenerate before running:

```bash
# iOS
./build_ios.sh debug --codegen
# macOS
./build_macos.sh debug --codegen
```

2) Retry your run target:

```bash
# iOS
./run_dev.sh ios debug
# macOS
./run_dev.sh macos debug
```

### Reproducible bad local state or flaky startup

1) Fast reset first:

```bash
./clear_cache.sh
```

2) If startup is still corrupted, do full reset:

```bash
./clear_cache.sh --full
```

## Release Builds

1) Use full platform sync path:

```bash
./build_ios.sh release
```

2) For macOS store artifacts:

```bash
./build_macos.sh release
```

3) Archive and upload with your normal CI/CD flow after the build passes.

## Team Default Rule

Avoid `flutter clean` unless you are already in the full reset branch above.
