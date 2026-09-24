# Golden Testing Guide for Divine

Status: A small image-comparison golden suite ships and runs in CI. Broader
component coverage for `divine_ui` is still tracked in **#6235**.

## Overview

Golden tests (screenshot tests) compare a rendered widget against a
committed reference image to catch visual regressions. Divine runs a
deliberately small suite — a handful of high-value, deterministic images —
through `scripts/golden.sh` and the `Goldens` CI job.

## Current State

`test/goldens/` holds two files:

- `widgets/design_system_gallery_golden_test.dart` — three image goldens
  (`divine_button_types`, `divine_button_sizes`, `divine_snackbars`)
  rendering `divine_ui` components on the dark app surface. They render from
  the *app's* test context because `divine_ui` bundles no fonts of its own —
  it has no `flutter:` assets section — so `VineTheme` typography cannot
  resolve inside the package's own tests. Package-local goldens are #6235.
- `widgets/notification_rows_golden_test.dart` — a layout/geometry test
  (`tester.getTopLeft`), **not** an image comparison. It lives here because
  the `Goldens` job owns the directory, not because it diffs pixels. Note
  that moving the directory to that job also moved this file from Ahem to
  real fonts; its assertions are relative, so the change is
  behaviour-neutral, but it is why the file no longer runs in the sharded
  suite.

Mechanics:

- Golden setup (`AlchemistConfig`) runs only under
  `-D DIVINE_GOLDEN_TESTS=true` (see `test/flutter_test_config.dart`); a
  plain `flutter test` skips it. Real fonts are **not** part of that
  opt-in — the harness loads them before every non-web test (#8649).
  `scripts/golden.sh` sets that dart-define for you.
- CI runs `scripts/golden.sh verify` in a dedicated **`Goldens`** job.
  `scripts/ci/select_test_shard.sh` removes `test/goldens/` from every shard
  of the `Tests` job, so goldens never run inside the merged
  `very_good test --optimization` isolate and never run twice.
- Files under `test/goldens/` are tagged `golden` so the local `mise run test`
  path can exclude the same directory from the merged optimizer run without
  adding another `skip_very_good_optimization` opt-out.
- **Reference images are generated on the Ubuntu runner**, not on a
  developer machine — see [Regenerating references](#regenerating-references).

What these goldens do *not* cover: light mode, and any component whose
render is time- or network-dependent. Adding a light-mode counterpart to the
button gallery is the cheapest next win.

## The font-determinism rule

**Every image golden must drain google_fonts before it asserts.** This is
the single thing that makes a Divine golden reproducible, and getting it
wrong produces a reference that looks plausible and is wrong.

`VineTheme` renders through `google_fonts`, which resolves the bundled
`assets/fonts/` files **asynchronously and per variant**. `loadAppFonts()`
in `flutter_test_config.dart` does not cover it, and neither does warming
the theme's own text styles — a widget can be the first to ask for a weight
the theme never uses. Left alone, the first test in an isolate captures Ahem
blocks and a later one captures real glyphs. Both "pass" when regenerated;
they simply disagree about what the component looks like.

```dart
await tester.pumpWidget(...);
// runAsync is required — this is real file I/O that the widget tester's
// fake async would otherwise never complete.
await tester.runAsync(GoogleFonts.pendingFonts);
await tester.pumpAndSettle();
```

Two related traps:

- **Put the surface inside the captured boundary.** A `Scaffold`
  `backgroundColor` outside the `RepaintBoundary` you match against leaves
  the golden transparent, which renders as white and makes dark-theme
  foregrounds look broken.
- **Pin `tester.view.physicalSize` and `devicePixelRatio`** (with
  `addTearDown` resets), so the image does not depend on whose machine ran
  it.

## Quick Start

### Running Golden Tests

```bash
# Update all golden images
./scripts/golden.sh update

# Verify golden tests pass
./scripts/golden.sh verify

# Update a specific image golden test file
./scripts/golden.sh update test/goldens/widgets/design_system_gallery_golden_test.dart

# List all golden test files
./scripts/golden.sh list

# Show changes to golden images
./scripts/golden.sh diff

# Clean all golden images
./scripts/golden.sh clean
```

`update` is for iterating locally. It refuses to be quiet about it: off
Linux it prints a warning that its output must not be committed, because
the `Goldens` job compares against Linux-rendered references.

### `golden.sh verify` on a non-Linux machine

**Expect a pixel diff, and don't chase it.** References are committed as the
Ubuntu runner produced them, and Skia antialiases differently per OS —
measured on macOS at **2.7% / 2.8% / 3.7% of pixels** for
`divine_button_sizes` / `divine_button_types` / `divine_snackbars`,
entirely on glyph edges. `golden.sh verify` prints a notice saying so when
the host isn't Linux. Note the spread: the number is per golden, not one
suite-wide constant, so treat ~4% as the ceiling rather than assuming
anything above 3% is a regression.

That run is still worth doing: it catches structural breakage — image
*size* mismatches, thrown exceptions, layout overflow — which is what most
real regressions look like. A 1px padding change on `DivineButton`, for
instance, fails as a size mismatch on any OS. What it cannot tell you is
whether a sub-4% pixel difference is drift or a genuine change; the
`Goldens` CI job answers that.

A tolerance-based comparator was considered and rejected: the tolerance
would have to exceed ~4%, which is wide enough to hide a colour tweak or an
icon swap — exactly the regressions the suite exists to catch.

### Regenerating references

Reference PNGs are compared byte-for-byte, and Skia does not render
identically across operating systems — so a reference generated on macOS
will not match the Ubuntu runner that checks it. **Always regenerate on
CI:**

1. Push the branch.
2. Run the `Mobile CI` workflow via `workflow_dispatch` against it with
   **`update_goldens: true`** (`gh workflow run "Mobile CI" --ref <branch>
   -f update_goldens=true`).
3. Download the `goldens` artifact from that run.
4. Unpack it over `mobile/test/goldens/` (the archive is rooted there, so it
   restores `widgets/goldens/*.png`), inspect the images, and commit.

That dispatch run reports **`Mobile CI` red on purpose**: it skipped
verification, so it is not a merge verdict, and the aggregate fails closed
rather than publish a green check that compared no pixels over the PR's real
one. Pushing the regenerated references produces the genuine verdict.

`./scripts/golden.sh update` locally is still useful for *iterating* on a
new golden — just don't commit what it produces.

When the job fails, it uploads a `golden-failures` artifact containing the
master / test / diff images, which is how you tell a real regression from
rendering drift without an Ubuntu machine.

## Project Structure

```
test/
├── flutter_test_config.dart        # app fonts for every non-web test;
│                                    # Alchemist setup is opt-in via
│                                    # -D DIVINE_GOLDEN_TESTS=true
└── goldens/                        # owned by the `Goldens` CI job; excluded
    └── widgets/                    # from every shard of the `Tests` job
        ├── design_system_gallery_golden_test.dart
        ├── notification_rows_golden_test.dart   # layout test, not an
        │                                          # image-comparison golden
        └── goldens/                # committed references, generated on CI
            ├── divine_button_sizes.png
            ├── divine_button_types.png
            └── divine_snackbars.png
```

Failure diffs land in `test/goldens/**/failures/`, which is gitignored
(`test/**/failures/`). They are debug output from a red run — never commit
them.

## Writing Golden Tests

**Start from `design_system_gallery_golden_test.dart`** — it is the shipped
example and already handles the font drain, the captured surface, and the
pinned view config. The `golden_toolkit` / `alchemist` APIs below are
reference material; no test currently uses them for image diffing.

### Basic Widget Golden Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  group('MyWidget Golden Tests', () {
    testGoldens('MyWidget renders correctly', (tester) async {
      await tester.pumpWidgetBuilder(
        const MyWidget(),
        wrapper: materialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'my_widget_default');
    });
  });
}
```

### Using GoldenBuilder for Multiple States

```dart
testGoldens('Widget states', (tester) async {
  final builder = GoldenBuilder.grid(columns: 3)
    ..addScenario('Loading', MyWidget(state: WidgetState.loading))
    ..addScenario('Success', MyWidget(state: WidgetState.success))
    ..addScenario('Error', MyWidget(state: WidgetState.error));

  await tester.pumpWidgetBuilder(builder.build());
  await screenMatchesGolden(tester, 'widget_states');
});
```

## Best Practices

### When to Use Golden Tests
- **Critical UI components** that must maintain visual consistency
- **Complex layouts** that could break with changes
- **Theme-dependent widgets** to verify dark/light mode
- **Multi-state components** (loading, error, success states)

### When NOT to Use Golden Tests
- Components with **dynamic content** that changes frequently
- **Animated widgets** (use widget tests instead)
- Simple widgets with minimal visual complexity

### Tips for Stable Golden Tests
1. **Use fixed timestamps** - Don't use `DateTime.now()` directly; use
   `package:clock`'s `withClock` (see `notification_rows_golden_test.dart`
   for the current pattern)
2. **Mock network images** - Use local assets or placeholders
3. **Control text content** - Use consistent test data
4. **Test multiple states** - Cover all visual states in one test
5. **Name tests clearly** - Use descriptive golden file names
6. **Drain async font loading** - mandatory, and the most common way to
   produce a wrong-but-passing reference. See
   [The font-determinism rule](#the-font-determinism-rule).

## Troubleshooting

### Common Issues

**Tests fail on CI but pass locally**
- Almost always means the reference was generated locally. Skia renders
  differently per OS; regenerate on the runner
  ([Regenerating references](#regenerating-references)).

**Text renders as solid blocks instead of glyphs**
- The google_fonts drain is missing or ran too early. See
  [The font-determinism rule](#the-font-determinism-rule). Note that
  `loadAppFonts()` alone does **not** fix this: the root harness runs it
  before every non-web test (#8649), and it still leaves the `google_fonts`
  variants that `VineTheme` resolves lazily undrained.

**A golden is transparent / the background is white**
- The surface is outside the `RepaintBoundary` being matched. Move it in.

**Image loading errors**
- Mock image providers or use test assets
- Avoid network-dependent images in tests

## Performance Considerations

- Golden tests are slower than unit/widget tests
- Run targeted golden tests during development

### How image goldens are kept out of every other suite

An image golden cannot run inside `very_good test --optimization`: the
merged bundle's entrypoint is `test/.test_optimizer.dart`, so the golden
comparator's basedir becomes `test/` and `goldens/x.png` resolves to
`test/goldens/x.png`, which does not exist. Three mechanisms keep it out,
and a new image golden needs all three:

| Where | Mechanism |
|---|---|
| CI `Tests` job | `scripts/ci/select_test_shard.sh` deletes `test/goldens/` from every shard |
| `mise run test` | `tags: ['golden']` on every test in the file + `--exclude-tags "integration \|\| golden"` in the mise task |
| pre-push hook | `scripts/hooks/pre-push` skips changed files under `test/goldens/` |

Hooks are generated copies, so that last one only takes effect after
`cd mobile && mise run setup_hooks`. Until you re-run it, a stale pre-push
hook still runs the image goldens against Ubuntu references and a golden
change is unpushable on macOS.

Use a **test-level** `tags:` argument, not a file-level `@Tags` annotation.
File-level annotations are dropped inside the merged bundle, so `@Tags` there
is a dead letter that only `skip_very_good_optimization` can rescue —
test-level `tags:` are ordinary Dart arguments and survive, which is what lets
this work without spending a `vgv_tag_baseline.txt` opt-out. Verified: bundled
without the exclude the suite fails on the basedir; with it, package:test
reports "No tests match the requested tag selectors".

`golden.sh verify` and the `Goldens` job filter nothing, so the goldens do
run there — which is the point.

## Resources

- [golden_toolkit documentation](https://pub.dev/packages/golden_toolkit)
- [alchemist documentation](https://pub.dev/packages/alchemist)
- [Flutter golden testing guide](https://flutter.dev/docs/cookbook/testing/widget/introduction#golden-tests)

## divine_ui package goldens (deferred — #6235)

Goldens that live *inside* the `divine_ui` package are still **not in
place**. Two package-isolation limits block them, neither of which is the
font race solved above: `DivineIcon` loads `assets/icon/*.svg` by root path
so icons render empty in package tests, and Material `Slider`'s
`OverlayPortal` asserts under alchemist's grid layout. Both are tracked in
**#6235**.

The gallery goldens described in [Current State](#current-state) are the
interim answer — they render the same components from the app, where the
assets and fonts exist. Beyond that, `divine_ui` relies on widget-behaviour
and `meetsGuideline` accessibility tests.
