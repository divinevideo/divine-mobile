# Testing

Tests reduce bugs, encourage clean code, and give confidence when shipping — but only when each test earns its place. Two ideas govern everything below: a test must be able to fail for a real reason (see [A test must be able to fail](#a-test-must-be-able-to-fail)), and coverage expectations differ by layer — packages carry hard percentage gates, while the app layer (`mobile/lib`) is behavior-first with ratchets rather than an absolute percentage (see [Coverage](#coverage)). There is deliberately no repo-wide 100% mandate; do not read the package gates as one.

---

## A Test Must Be Able to Fail

A passing test should be evidence that the feature works. If the test would still pass with the feature broken, it tests nothing — delete it rather than bank it as coverage.

Coverage percentage is a byproduct of good tests, never the goal. A green line that no meaningful assertion protects is worth less than an uncovered one, because it hides the gap instead of flagging it.

Before keeping a test, it must satisfy all of these:

- **It can catch a regression.** If you cannot describe a plausible code change that turns it red, it has no reason to exist.
- **It fails for the right reason.** Assert the user-visible outcome, not the mechanism that produces it (see [Test Behavior, Not Properties](#test-behavior-not-properties)).
- **It is not a tautology.** Never assert the value you just stubbed — `when(() => mock.x).thenReturn(1); expect(mock.x, 1)` tests Mockito, not your code.
- **It is not written to turn a line green.** A line only reachable through contorted setup with no real scenario is a signal of dead or over-defensive code — fix the code, don't manufacture a test for it.
- **It does not restate a sibling.** One test that pins the behavior beats three that reword the same assertion.

**The bar applies to tests that already exist, not just new ones.** When you're already editing a file whose tests fail the bar above, deleting them is the right call — removing a test that cannot fail is a net improvement, not a coverage loss, because the green line was hiding the gap instead of guarding it.

> **LLM-generated tests skew hard toward coverage theatre** — asserting constructor parameters, mock-then-verify-the-mock, one trivial test per line. Reject these on the "can it fail?" bar even when the coverage number looks fine.

### The two most literal shapes are frozen at zero

Judgement is needed for most of the bar above, but two shapes need none, so
they are enforced: `check_placeholder_tests.sh` (#3340) freezes at **zero**

1. a test whose every assertion is trivially satisfied —
   `expect(true, isTrue)`, `expect(1, 1)`, `expect(x, equals(x))` for a
   literal `x`; and
2. a `*_test.dart` that declares no `test` / `testWidgets` / `blocTest` /
   `patrolTest` / `group` at all.

#3340 removed all 93 sites — 38 of them one 602-line accessibility suite in
which every single test was `expect(true, isTrue)`, and 24 in seven ProofMode
suites waiting on services deliberately deleted a year earlier. So any hit is a
regression: fix the test, do not regenerate the baseline.

Assert the behaviour instead. A construction smoke test has
`expect(() => Foo(), returnsNormally)` or `expect(foo, isNotNull)`; a widget
lifecycle pump has `expect(tester.takeException(), isNull)` — which is a real
assertion, since a provider mutated during `initState`/`dispose` surfaces as a
framework exception. There is deliberately no inline ignore: a genuine
exception earns a reviewed baseline entry.

Two boundaries worth knowing, because they are the reason the guard is
trustworthy:

- **A tautology beside a real assertion is not flagged.** The test as a whole
  can still fail, so it is noise rather than a placeholder.
- **A test with NO assertion is not flagged at all.** Assertions arrive through
  routes one file cannot see: drift's `verifier.migrateAndValidate` throws on
  mismatch and *is* the assertion, and `expectMeetsAccessibilityGuidelines` is
  an imported helper. 91 such tests exist; most are good. That population needs
  helper-aware triage, not a gate, so the bar above still applies to it by
  judgement.

```bash
cd mobile && dart run scripts/lib/placeholder_test_detector.dart test integration_test packages --path-prefix . --detail
```

### An unchanged-assertion needs a pinned baseline

The third frozen shape is not literal, which is why the placeholder guard cannot
see it. Read a value into a local, act, and assert the same read still equals
the local:

```dart
service.markAuthShellReady();
final firstTime = service.authShellReadyTime;
service.markAuthShellReady();
expect(service.authShellReadyTime, equals(firstTime));   // null == null passes
```

Both operands come from the state under test. Replace `markAuthShellReady` with
a no-op and `authShellReadyTime` is null both times, so the test stays green
while claiming the value "did not change" without ever proving it existed. The
same holds for a counter that stays 0, a list that stays empty, or a notifier
whose value never landed. #8617 proved the first instance by mutation and the
sweep that closed it found sixteen more.

Pin the baseline before the act — `expect(firstTime, isNotNull)`,
`expect(count, greaterThan(0))`, `expect(rows, hasLength(2))` — or give the
test an in-body positive control that proves the mechanism ran. An expect on a
member of either side (`expect(cubit.state.status, ready)` before
`final last = cubit.state`), on the collection a `.length` came from, or a
`firstTime!` that would throw on null all count. A pin *after* the re-read is
fine too; the test fails either way.

Three of the swept tests needed more than a pin, and they are the shape to watch
for: when acting wrongly would leave the observable unchanged anyway — a second
`setRate(1.0)` on a player already at 1.0, a `jumpToPage(3)` while page 3 is
showing, or geometry measured on a parent-constrained row — no pin on the value
helps, and the test has to observe calls or unconstrained child geometry instead.

A read that cannot come back absent is its own pin and is not reported: the
single-result `tester` queries (`tester.state`, `tester.getSize`) throw on an
empty finder, and a provider read (`container.read(fooProvider)`,
`ref.watch(fooProvider)`, `context.read<FooBloc>()`) returns the provided value
or throws, so `same()` on two of them cannot pass on null == null. There is no
inline escape hatch, for the same reason the placeholder ratchet has none: an
assertion the scan cannot see is one line away from being one it can.

`check_unpinned_unchanged_assertions.sh` (#8617) freezes at **zero** every
pair that is the test's ONLY assertion, in
`mobile/scripts/baseline/unpinned_unchanged_assertions.txt`; a pair beside a
real assertion is listed by `--all` but not frozen, for the same reason a
tautology beside a real assertion is not a placeholder. Detector:
`scripts/lib/unpinned_unchanged_assertion_detector.dart`, a Dart AST because
`dart format` wraps the three parts onto different lines and pinning is a
property of the whole body.

```bash
cd mobile && dart run scripts/lib/unpinned_unchanged_assertion_detector.dart test integration_test packages --path-prefix . --detail
```

---

## New and Extracted Packages Must Ship with Tests

When extracting code into a new package (client, repository, utility), include test coverage in the same PR. Do not defer tests to a follow-up — the extraction PR is incomplete without them.

At minimum, cover:
- All public methods on the main class
- Error/edge cases for network or I/O operations
- Model serialization if the package defines models

### Preserving Test Behavior During Package Extraction

When extracting a package, keep the branch up to date with `main` during the work — merge from `main` frequently, and again just before requesting review. This surfaces recent edits to files you're moving (e.g. test fixes added to the original location while extraction was in progress) so they aren't silently dropped when the file is relocated.

Known precedent: PR #2985 (extract `follow_repository`) silently dropped a `fakeAsync` wrap added two days earlier by PR #2986; restored by PR #3210. See `tasks/lessons.md` → "CI & Chain Hygiene" → "Package extractions can silently regress sibling fixes".

---

## Test Organization

### File Structure
Test files should mirror the `lib/` folder structure:

```
lib/screens/login/login_page.dart
→ test/screens/login/login_page_test.dart

lib/services/user_service.dart
→ test/services/user_service_test.dart
```

**Note:** Barrel files (`models.dart`, `widgets.dart`) do not need tests.

**Do not add tests under `test/unit/` or loose at the `test/` root.** `test/unit/`
is a frozen legacy bucket that duplicates the `lib/` mirror one level down
(`test/unit/services/foo_test.dart` instead of `test/services/foo_test.dart`); a
CI ratchet blocks `test/unit/` from growing (see **Test-structure floor** below).
Root-loose tests (`test/foo_test.dart` with no `lib/foo.dart`) are only correct
when they mirror a root `lib/` file (e.g. `lib/main.dart` →
`test/main_*_test.dart`) or test a `test/` helper. Everything else mirrors its
`lib/` source path.

### Group Structure
Every test declaration lives inside a `group()` — a flat file gives the runner
nothing to nest, so failures print as an undifferentiated wall of descriptions
and you cannot run one slice of a file (`--plain-name 'FooRepository fetch'`).
This is enforced; see [Ungrouped-test ceiling](#ungrouped-test-ceiling) below.

- **Widget tests:** Group by "renders", "navigation", "interactions"
- **BLoC tests:** Group by event name
- **Repositories/Clients:** Group by method name

Wrap the declarations only. `setUp` / `tearDown`, helper functions, and
`late` variables stay at `main()` level — they already apply to nested
groups, and moving them into one group hides them from the others.

```dart
void main() {
  group(ShoppingCart, () {
    group('addItem', () {
      test('increases item count', () {});
      test('updates total price', () {});
    });

    group('calculateTotal', () {
      test('returns sum of all item prices', () {});
      test('returns zero when cart is empty', () {});
    });
  });
}
```

---

## Writing Tests

### Always Assert Results
Every test must have `expect` or `verify` statements:

**Good:**
```dart
testWidgets('calls [onTap] on tapping widget', (tester) async {
  var isTapped = false;
  await tester.pumpWidget(
    SomeTappableWidget(onTap: () => isTapped = true),
  );
  await tester.tap(find.byType(SomeTappableWidget));
  await tester.pumpAndSettle();

  expect(isTapped, isTrue);  // Actual assertion
});
```

**Bad:**
```dart
testWidgets('can tap widget', (tester) async {
  await tester.pumpWidget(SomeTappableWidget());
  await tester.tap(find.byType(SomeTappableWidget));
  // No assertion - test is useless!
});
```

### Use Matchers
Matchers provide better error messages:

```dart
// Good
expect(name, equals('Hank'));
expect(people, hasLength(3));
expect(valid, isTrue);

// Bad
expect(name, 'Hank');
expect(people.length, 3);
expect(valid, true);
```

### Single Purpose Tests
One scenario per test:

```dart
// Good
testWidgets('renders $WidgetA', (tester) async {});
testWidgets('renders $WidgetB', (tester) async {});

// Bad
testWidgets('renders $WidgetA and $WidgetB', (tester) async {});
```

### Test Behavior, Not Properties
Test what widgets DO, not how they're configured:

**Good - Testing behavior:**
```dart
testWidgets('navigates to settings when button is tapped', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byType(SettingsButton));
  await tester.pumpAndSettle();

  expect(find.byType(SettingsPage), findsOneWidget);
});

testWidgets('displays error message when login fails', (tester) async {
  await tester.pumpWidget(LoginPage());
  await tester.enterText(find.byType(TextField), 'invalid@email.com');
  await tester.tap(find.byType(LoginButton));
  await tester.pumpAndSettle();

  expect(find.text('Invalid credentials'), findsOneWidget);
});
```

**Bad - Testing static properties:**
```dart
testWidgets('button has correct padding', (tester) async {
  final button = tester.widget<Button>(find.byType(Button));
  expect(button.padding, EdgeInsets.all(16)); // Useless test
});
```

---

## Test Naming

### Descriptive Names
Be verbose - readability matters:

```dart
// Good
testWidgets('renders $YourView', (tester) async {});
testWidgets('renders $YourView for $YourState', (tester) async {});
test('given an [input] is returning the [output] expected', () async {});
blocTest<YourBloc, State>('emits $StateA when $EventB is added');

// Bad
testWidgets('renders', (tester) async {});
test('works', () async {});
```

### Use String Expressions for Types
Easier refactoring when types are renamed:

```dart
// Good
testWidgets('renders $YourView', (tester) async {});

// Bad
testWidgets('renders YourView', (tester) async {});

// For group names with only a type:
group(YourView, () {});  // Preferred
group('$YourView', () {}); // Avoid
```

---

## Test Isolation

### Initialize Shared Objects Per Test
Use `setUp` to avoid test interdependence:

```dart
// Good
group(_MySubject, () {
  late _MySubjectDependency myDependency;

  setUp(() {
    myDependency = _MySubjectDependency();  // Fresh instance each test
  });

  test('value starts at 0', () {
    final subject = _MySubject(myDependency);
    expect(subject.value, equals(0));
  });
});

// Bad
group(_MySubject, () {
  final myDependency = _MySubjectDependency();  // Shared - tests affect each other!
  // ...
});
```

### Keep Setup Inside Groups
Avoid side effects from test optimization:

```dart
// Good
void main() {
  group(UserRepository, () {
    late ApiClient apiClient;

    setUp(() {
      apiClient = _MockApiClient();
    });

    // Tests...
  });
}

// Bad
void main() {
  late ApiClient apiClient;

  setUp(() {  // Outside group - can cause issues!
    apiClient = _MockApiClient();
  });

  group(UserRepository, () {
    // Tests...
  });
}
```

### Use Private Mocks
Avoid shared mocks between files:

```dart
// Good - private mock, scoped to file
class _MockYourClass extends Mock implements YourClass {}

// Bad - public mock, can be accidentally shared
class MockYourClass extends Mock implements YourClass {}
```

---

## Finding Widgets

### Prefer Type Over Key
Keys are harder to maintain:

```dart
// Good
expect(find.byType(HomePage), findsOneWidget);

// Bad
expect(find.byKey(Key('homePageKey')), findsOneWidget);
```

---

## BLoC Testing

### Test with Event Order
Handle concurrent event processing:

```dart
blocTest<MyBloc, MyState>(
  'change value',
  build: () => MyBloc(),
  act: (bloc) async {
    bloc.add(ChangeValue(add: 1));
    await Future<void>.delayed(Duration.zero);  // Ensure order
    bloc.add(ChangeValue(remove: 1));
  },
  expect: () => const [
    MyState(value: 1),
    MyState(value: 0),
  ],
);
```

---

## Golden File Testing

Golden tests compare widget rendering against master images. Divine keeps a
deliberately small image-golden suite; the full contract lives in
[`mobile/docs/GOLDEN_TESTING_GUIDE.md`](../../mobile/docs/GOLDEN_TESTING_GUIDE.md)
and you should read it before adding one. The three rules that bite hardest:

1. **Drain google_fonts before asserting.** `VineTheme` resolves the bundled
   fonts asynchronously *per variant*, so without
   `await tester.runAsync(GoogleFonts.pendingFonts)` the first test in an
   isolate captures Ahem blocks. It still "passes" when regenerated — the
   failure mode is a wrong reference, not a red test.
2. **Never commit locally-generated references.** Skia antialiases
   differently per OS (2.7–3.7% of pixels here), so references are produced
   on the Ubuntu runner via the `update_goldens` workflow dispatch.
   `golden.sh verify` is therefore expected to show a pixel diff on macOS.
3. **Put `tags: ['golden']` on every test under `test/goldens/`.** An image
   golden cannot survive `very_good test --optimization`: the merged bundle's
   entrypoint moves the comparator basedir to `test/`, so `goldens/x.png`
   resolves to `test/goldens/x.png` and does not exist. Test-level `tags:`
   are ordinary Dart arguments, so unlike a file-level `@Tags` annotation
   they survive bundling — `mise run test` passes
   `--exclude-tags "integration || golden"` and the tests never run there.
   That is why no `skip_very_good_optimization` opt-out is needed.

Goldens live under `mobile/test/goldens/`, which the CI `Tests` shards (by
deleting the directory), `mise run test` (by tag), and the pre-push hook (by
path) all exclude; the dedicated `Goldens` job owns them and filters nothing.

Run and update them through the script, from `mobile/`:

```bash
bash scripts/golden.sh verify
bash scripts/golden.sh update test/goldens/widgets/design_system_gallery_golden_test.dart
```

See `mobile/docs/GOLDEN_TESTING_GUIDE.md` for the full workflow and the
cross-OS drift details.

---

## Random Test Ordering

Run tests in random order to catch flaky tests:

```bash
flutter test --test-randomize-ordering-seed random
dart test --test-randomize-ordering-seed random
```

---

## Coverage

Measure coverage locally with:

```bash
flutter test --coverage
```

### Coverage expectations by layer

The enforced bar differs by architectural layer. There is deliberately no repo-wide threshold on the app layer (`mobile/lib`) — the package gates are not a blanket 100% mandate.

| Layer | Bar |
|-------|-----|
| Client / Repository (`mobile/packages/*`) | Hard percentage gate. The VeryGood package workflow defaults to **100%** unless a package lowers `min_coverage` in its own `.github/workflows/<pkg>.yaml`. Keep it green; the value only ratchets down deliberately. |
| BLoC / Cubit | Held high. `blocTest` is cheap and the logic is pure — treat it close to package-grade, not UI-grade. |
| Widgets / UI (`mobile/lib`) | **Behavior + golden, not a line-percentage chase.** No absolute threshold; the floor is a meaningful test alongside every change, plus the untested-services ratchet below. |

Chasing line coverage on widgets pushes tests toward asserting properties (padding, widget config) just to reach branches, which contradicts [Test Behavior, Not Properties](#test-behavior-not-properties) and the [can-it-fail bar](#a-test-must-be-able-to-fail). On UI, a golden or an interaction test is the meaningful unit — a test asserting `padding == EdgeInsets.all(16)` is coverage, not evidence.

### Strict-coverage packages

Some packages enforce **100% line coverage as a CI gate** — not a
target, a gate. The PR fails with a very specific message:

> `Expected coverage >= 100.00% but actual is 99.xx%.`
> `Lines not covered: lib/…: N, M, …`

Current strict-coverage packages in this repo:

- `mobile/packages/divine_ui`

When adding a new public method / getter / constructor on a strict
package (e.g. a new `VineTheme.xxxFont()` helper, a new enum case
surfaced by a public method, a new widget variant), **add a matching
test in the same PR**. Mirror the style of neighbouring tests —
typically an assertion on the returned style / computed size.

If a line is genuinely unreachable, exclude it from coverage with a
justified `// coverage:ignore-line` (or block) comment rather than
leaving the gate red.

### Untested-services floor

Every service under `mobile/lib/services/` must have a same-named
`*_test.dart`. The set of untested services is frozen in
`mobile/scripts/baseline/untested_services.txt` and may only ever
**shrink** — adding a new `*_service.dart` without a test fails CI
(`check_untested_services_floor.sh`) and the pre-push hook. After adding
the test, ratchet the floor and commit the baseline:

```bash
UPDATE_BASELINE=1 bash mobile/scripts/check_untested_services_floor.sh
```

### Test-structure floor

The legacy non-mirroring `mobile/test/unit/` bucket is frozen in
`mobile/scripts/baseline/test_unit_files.txt` and may only ever **shrink**.
Adding any new `*_test.dart` under `test/unit/` fails CI
(`check_test_unit_structure.sh`) — write it at its `lib/` mirror path instead
(`lib/services/foo.dart` → `test/services/foo_test.dart`). When you intentionally
move a test out of `test/unit/` to its mirror (or delete it), shrink the baseline
and commit it:

```bash
UPDATE_BASELINE=1 bash mobile/scripts/check_test_unit_structure.sh
```

The guard freezes `test/unit/` only; it does not force draining it. Two sibling
non-mirroring buckets — `test/tdd` and `test/widget` (a split-brain vs the
282-file `test/widgets`) — are known and deferred as a fast-follow, not frozen here.

### Ungrouped-test ceiling

A `test` / `testWidgets` / `blocTest` / `patrolTest` declared outside any
`group()` is frozen per file in `mobile/scripts/baseline/ungrouped_tests.txt`
and may only ever **shrink** (`check_ungrouped_tests.sh`, #3615). A new flat
file, a new loose declaration in a baselined file, or a raised ceiling fails
CI. The audit behind #3615 counted 25 flat files in April 2026 and 108 by
August, so the shape re-accretes on its own.

Nothing in the baseline is a flat file — those were all grouped in #3615.
Each remaining entry is a file that *has* group structure and left a
declaration or two outside it; paydown is tracked in #7705. List them:

```bash
cd mobile && dart run scripts/lib/ungrouped_test_detector.dart test integration_test packages --path-prefix . --detail
```

After grouping the loose ones, lock the win and commit the baseline:

```bash
UPDATE_BASELINE=1 bash mobile/scripts/check_ungrouped_tests.sh
```

Runs in CI only, in the `generated-files` job; the pre-push hook does not
cover it.

### Skip ceiling

A test disabled with an unconditional `skip:`, or a whole file disabled with
`@Skip(...)`, is frozen per file in `mobile/scripts/baseline/skip_test_ceilings.txt`
(`check_skip_ceiling.sh`, #3340, epic #4337 WS-1 → #4836) — a per-file ceiling
that may only ever **decrease**, across `mobile/test`, `mobile/integration_test`
and `mobile/packages/*/test`.

**Never add `skip: true` to silence a failing test.** A failing test on your
branch is caused by your branch (`agent_workflow.md` rule #5). If it is not
worth fixing, delete it.

Every baseline entry carries a trailing `# <outcome>: <why> (#4836)` naming one
of #4836's four outcomes, so the file reads as a worklist rather than a set of
exemptions:

| Outcome | When |
|---|---|
| `delete` | dead or low-value — the route, screen, or symbol is gone |
| `recover` | the test is fine; the skip is stale |
| `quarantine` | genuinely needs hardware, a device, or a network — move it behind a tag or the integration lane, not an unconditional skip |
| `rewrite` | the behaviour is still wanted, the setup is not |

Reasons survive regeneration: `lib/numeric_ratchet.sh` carries them forward by
key, so a count that moves keeps its explanation.

Not counted: a platform gate (`skip: !kIsWeb`, `skip: !Platform.isX`), which
restricts a test to where it can run; and `bloc_test`'s `skip: N`, which is the
number of leading states to ignore before matching `expect` — excluded by
callee, so a named int constant stays safe. A bare identifier **is** counted:
`const _blockedOnCi = true` is an unconditional skip with a nicer name.

```bash
cd mobile && dart run scripts/lib/skipped_test_detector.dart test integration_test packages --path-prefix . --detail
UPDATE_BASELINE=1 bash mobile/scripts/check_skip_ceiling.sh
```

Runs in CI only, in the `Generated Files` job; the pre-push hook does not
cover it.

### Shared-setup stub ceiling

Mocktail `when` / `whenListen` registrations inherited from a file-level or
outermost-group `setUp` are frozen per file by
`mobile/scripts/check_shared_setup_stubs.sh` (#8399). The detector follows
direct calls and tear-offs of helpers declared in the same file: extracting a
shared setup body into a named helper improves readability, but does not reduce
the number of tests that inherit its decisions and therefore does not reduce
the count.

Move each decision stub—and a named helper invocation when useful—into the
groups whose tests depend on it. A leaf group's own setup is not counted because
the dependency is adjacent to the tests it governs. After reducing a file's
shared reach, lock in the lower ceiling and commit the baseline:

```bash
cd mobile
dart run scripts/lib/shared_setup_stub_detector.dart test integration_test packages --path-prefix . --detail
UPDATE_BASELINE=1 bash scripts/check_shared_setup_stubs.sh
```

Runs in CI only, in the `Generated Files` job; the pre-push hook does not cover
it.

---

## Widget tests that use `context.l10n`

Any widget test that pumps a widget which calls `context.l10n.xxx` (or
its generated getters) must include the localization delegates on the
test's `MaterialApp`, or the l10n lookup fails at runtime:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ...
)
```

Most tests should reach for `testMaterialApp(...)` from
`test/helpers/test_provider_overrides.dart` instead of hand-rolling one —
it already sets both, plus the common provider overrides.

A common symptom of the missing setup is an assertion that passes when
the string is hardcoded but fails after an l10n migration with
`Found 0 widgets with text "…"`. The widget tree built correctly; only
the text child failed to resolve. The other symptom is a hard
`Null check operator used on a null value`, because `context.l10n` is
`Localizations.of<AppLocalizations>(context, AppLocalizations)!` and the
framework's own fallbacks (`DefaultMaterialLocalizations` and friends)
never satisfy the app's delegate.

### Delegate ceiling ratchet

`scripts/check_l10n_delegates_ceiling.sh` freezes the per-file count of
`MaterialApp` / `CupertinoApp` / `WidgetsApp` constructions under
`mobile/test` that register no `AppLocalizations` delegate — passing
some other delegate list, such as `GlobalMaterialLocalizations.delegates`,
does not clear the count — in
`mobile/scripts/baseline/l10n_delegates.txt` — a ceiling that may only
shrink. It runs in CI (the `generated-files` job), not the pre-push hook.

```bash
cd mobile && dart run scripts/lib/l10n_delegate_detector.dart test --detail
UPDATE_BASELINE=1 bash mobile/scripts/check_l10n_delegates_ceiling.sh
```

The detector is a Dart AST, not a regex, and #3613 is why. That issue was
filed off `grep MaterialApp | grep -v localizationsDelegates`, which
reported 39 offending screen tests — **31 of them already correct**,
matched only because `testMaterialApp` *contains* the substring
`MaterialApp`. The same grep is blind in the other direction too: it
cannot see an unconfigured construction inside a file that mentions
`localizationsDelegates` somewhere else, which is where 6 of the real
ones were hiding.

---

## VGV merged isolate & process-global state

Under CI's `very_good test --optimization`, every untagged `mobile/test`
suite is bundled into **one isolate** (`test/.test_optimizer.dart` imports
each `*_test.dart` and wraps its `main()` in a `group(...)`), and
`flutter_test` **auto-restores nothing** between tests — mock channel
handlers, `HttpOverrides.global`, view config, and platform `.instance`
statics all persist for the whole bundle. (The SDK doc line "Registered
callbacks are cleared after each test" is true only at *file* granularity —
one isolate per file under plain `flutter test` — and false for the merged
run.) So a test that mutates a process-global without restoring it strands
every later suite in a seed-dependent way (#5713→#5725, #5159/#5163, #5340,
#5738).

`--exclude-tags integration` does **not** exclude a bundled file: package:test
reads suite-level `@Tags` only from the bundle entry point, which has none.
The only tag that changes bundling is `skip_very_good_optimization` (the
optimizer text-scans for it and runs those files separately). Adding a
file-level `@Tags(['integration'])` without `skip_very_good_optimization` is a
dead letter — the `vgv-tag-gate` CI job enforces this.

### Restore decision table

| Global you mutate | Correct pattern |
|---|---|
| One of the 5 shared MethodChannels (`flutter_secure_storage`, `openvine.secure_storage`, `device_info`, `path_provider`, `image_picker`) | `overrideSharedChannel(channel, handler)` from `test/helpers/shared_channel_override.dart` — installs a sanctioned override and auto-restores the canonical handler on teardown. For a full reset in a hand-rolled `remove()`, call `restoreSharedChannelDefaults()`. |
| A test-local MethodChannel (not one of the 5) | Install in `setUp`, clear (`setMockMethodCallHandler(ch, null)`) in `tearDown`. |
| A `<Platform>.instance` singleton (`PathProviderPlatform`, `WebViewPlatform`, …) | Snapshot in `setUp`/`setUpAll`, restore in the matching `tearDown`/`tearDownAll` (`check_process_global_mutations.sh` enforces). |
| An irreversible initializer (`loadAppFonts()`) | Not allowed in a suite. The root `flutter_test_config.dart` loads app fonts once before `testMain`, so every merged test measures the same glyphs. There is no inverse, so no teardown can undo a suite-local call — `test/goldens/` is the only other allowed home (`check_process_global_mutations.sh` enforces, hard zero). |
| `HttpOverrides.global` | Not allowed in a merged test — tag the file `['skip_very_good_optimization', 'integration']` (`check_http_overrides_isolation.sh` enforces). |
| View config (`tester.view.physicalSize` / `devicePixelRatio` / `setSurfaceSize`) | Pair every override with an `addTearDown` reset (`resetPhysicalSize`, `resetDevicePixelRatio`, `setSurfaceSize(null)`). |
| Any Hive box in `HiveBoxNames.all` (they are registered process-globally by name) | `await TestHelpers.cleanupHiveBox(name)` in **both** `setUp` and `tearDown`. Never `Hive.box(name).close()` — see the harness below. Enforced by a root `tearDown` that heals and blames. |
| A service you registered with `BackgroundActivityManager` (`AuthService`, `UploadManager`, `AnalyticsService`) | Dispose the service. All three unregister in `dispose()`. If a test drives a manager directly, keep that exact instance and call `addTearDown(manager.resetForTesting)`. Each provider container owns a separate manager, so constructing a new manager cannot reset the instance under test. |

### Heal-and-blame harness (the 5 shared channels)

`flutter_test_config.dart` registers a root `tearDown` that, after **every**
test, verifies each shared channel still carries its canonical handler
(`checkMockMessageHandler` identity compare). If a test replaced one without
going through `overrideSharedChannel`, the harness **heals** it (reinstalls
canonical so the next suite is safe) and, under the `DIVINE_STRICT_CHANNELS`
build flag (`--dart-define=DIVINE_STRICT_CHANNELS=true`), **fails** the
perpetrating test with a fix recipe. Compliant tests never trip it.
**Mobile CI and `mise run test` both set that flag**, so a leak fails your PR
rather than being healed into someone else's suite; a bare
`flutter test <file>` leaves it off and heals silently. A static
`check_shared_channel_overrides.sh` ratchet additionally freezes the set of
files that raw-install a shared channel, so new ones must use the helper.

### Heal-and-blame harness (shared Hive boxes)

Hive registers a box **process-globally by name**, so the box one suite leaves
open is the box the next suite gets back from `openBox` — rows and backing
directory included, regardless of the path it asked for. More than a dozen
suites open `pending_uploads`, which is why a curated-lists PR that touches no
upload code could fail on `upload_manager_get_by_path` seeing a row it never
wrote (#6748).

`flutter_test_config.dart` registers a root `tearDown` that closes and deletes
every box in `sharedHiveBoxNames` (`test/helpers/shared_hive_box_guard.dart`,
which is `HiveBoxNames.all`) that a test left open, then `fail()`s that test.
The hazard is a property of the name being process-global, not of which box it
is, so the guard covers every box the app owns rather than only the one that
surfaced it. Unlike the channel harness it blames **unconditionally** rather
than behind a build flag: a shared box open after a test is never intentional,
and a single-file run is exactly where the owning suite is still cheap to
identify.

**Clean up with `TestHelpers.cleanupHiveBox(name)`, never `Hive.box(name)`.**
`Hive.box(name)` is `Hive.box<dynamic>`, and hive_ce throws
``HiveError: The box "pending_uploads" is already open and of type
Box<PendingUpload>`` for any box opened with a concrete value type. Swallowed
by a bare `catch`, that throw made the shared cleanup helper a silent no-op on
every open typed box — both the close and the `deleteBoxFromDisk` after it were
skipped. Measured over the seventeen suites that touch `pending_uploads`, seven
of them were handing 64 rows forward to whichever suite ran next.
`cleanupHiveBox` routes through `deleteBoxFromDisk`, which resolves the box by
name with no type check, and asserts its own postcondition rather than
swallowing a failure.
