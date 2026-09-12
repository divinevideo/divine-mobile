# Localization

All user-facing strings must use the l10n system. Never hardcode English strings in widgets.

This file covers the **mechanics**: where strings live, how to add a key, how
to wire tests. For what a translation should *sound* like — which register
each locale uses, the Spanish dialect decision, which terms never get
translated, and who signs off — see
[`mobile/docs/LOCALIZATION_STYLE_GUIDE.md`](../../mobile/docs/LOCALIZATION_STYLE_GUIDE.md).

---

## Using Localized Strings

Access strings via the `context.l10n` extension:

```dart
import 'package:openvine/l10n/l10n.dart';

// In a widget build method
Text(context.l10n.settingsTitle)
```

## Adding New Strings

When creating new UI, add strings to the ARB file first:

1. Add the key and English value to `mobile/lib/l10n/app_en.arb`
2. Use feature-prefixed keys: `profileFollowButton`, `feedEmptyState`, `authLoginTitle`
3. Add `@` metadata for parameterized strings with placeholders
4. Run `flutter gen-l10n` from `mobile/`
5. Use `context.l10n.keyName` in the widget
6. Mirror the key into every other `app_*.arb` locale, or add it to
   `_knownUntranslatedDebt` in `test/l10n/arb_consistency_test.dart` when
   translations are deferred to a later pass. Then run
   `flutter test test/l10n/arb_consistency_test.dart` (or the check-l10n
   skill). Adding a key to `app_en.arb` only — without mirroring it or
   marking it as known debt — fails that test in CI.
7. Ship steps 1 and 5 **in the same change**. A key that lands ahead of its
   call site is an orphan, and the orphan ratchet below will fail CI on it.

```json
{
  "feedEmptyState": "No videos yet",
  "feedVideoCount": "{count} videos",
  "@feedVideoCount": {
    "placeholders": { "count": { "type": "int" } }
  }
}
```

## Orphaned keys: never add a key ahead of its call site

An ARB key that no Dart file reads is not harmless dead weight. It is picked up
by the next translation pass, paid for in 21 locales, mirrored into every
`app_*.arb`, and compiled into `AppLocalizations` — and meanwhile the string it
was written for is normally still sitting hardcoded in a widget, so non-English
users see English. The waste and the bug travel together.

Nothing in the ordinary toolchain notices:

| Guard | Why it stays green on an orphan |
|---|---|
| `arb_consistency_test` | Proves a key exists in **every** locale. An orphan passes trivially, in all 23. |
| `flutter gen-l10n` | Has no notion of an unused message; it emits the getter regardless. |
| `flutter analyze` | Cannot report an unused public getter on a generated class. |

The scan is `mobile/lib` **only**. A test cannot render a string, so a test
reference is not evidence a key is live — and taking it as evidence hid 9
product-orphans, four of them propped up by a `find.text(l10n.x), findsNothing`
assertion, which is a test *proving* the string is not on screen.

So the set is frozen by a shrink-only ratchet (#3630),
`mobile/scripts/check_orphaned_arb_key_floor.sh`, baseline
`mobile/scripts/baseline/orphaned_arb_keys.txt`. It runs in CI in the
`generated-files` job. Left unguarded the set grew 94 → 276 in four months,
which is the argument for the ratchet rather than a one-off sweep.

The detector (`mobile/scripts/lib/orphaned_arb_key_detector.dart`) is an
analyzer AST pass, not a grep, because four things look like a reference to
`grep` and render nothing:

```dart
// TODO wire up feedSkip            <- comment
Log.info('feedSkip');               <- string literal body
/// Renders [feedSkip].             <- dartdoc reference
enum NotificationType { uploadFailed }   <- unrelated declaration, never read
```

The last one is real: `uploadFailed` in `lib/services/notification_service.dart`
is an enum constant that nothing reads, and it kept the identically-named ARB
key looking live. Interpolation is the opposite case — `'${l10n.feedSkip}'` *is*
a render and does count.

### Baseline entries are a worklist, not exemptions

Every entry carries a trailing reason in one of two shapes:

- `# wire: <path>:<line>` — a live widget renders this string hardcoded. The
  key is right and the call site is wrong; fixing it is a real localization fix
  for 21 locales, not a cleanup.
- `# staged: <why>` — deliberately ahead of its call site.
- `# test-only: <where>` — nothing in `lib/` renders it and only a test names
  it. Resolving one means editing that test too, so they are tracked in #7968.

A key in none of those categories: **delete it** from `app_en.arb` and every
`app_*.arb` locale rather than baselining it.

```bash
cd mobile && dart run scripts/lib/orphaned_arb_key_detector.dart --detail
UPDATE_BASELINE=1 bash mobile/scripts/check_orphaned_arb_key_floor.sh
```

## Localized semantic labels for `divine_ui`

`divine_ui` stays independent of app localizations, so its public controls keep
English semantic-label fallbacks. App callers must pass localized labels when
the corresponding control can render.

Omissions under `mobile/lib` are frozen at zero by
`mobile/scripts/check_divine_ui_semantic_label_defaults.sh` (#7901), with
baseline `mobile/scripts/baseline/divine_ui_semantic_labels.txt`. The AST
detector follows conditional controls; do not pass meaningless labels when a
control is proven absent.

List omissions and run the guard from `mobile/`:

```bash
dart run scripts/lib/divine_ui_semantic_label_detector.dart lib --detail
bash scripts/check_divine_ui_semantic_label_defaults.sh
```

The baseline is empty and the ratchet rejects a baseline that adds a key, so
pass the app's localized label at the call site rather than regenerating the
baseline.

## Rules

- **Strings stay in the UI layer** — BLoCs emit status enums, the UI maps them to `context.l10n.xxx`
- **No error strings in BLoC state** — use status enums + `addError()`
- **`divine_ui` package stays l10n-free** — its widgets accept string params with English defaults
- **Plurals use ICU syntax** in ARB files, not conditional logic in Dart
- **Translated copy follows the per-locale register and terminology decisions** in [`mobile/docs/LOCALIZATION_STYLE_GUIDE.md`](../../mobile/docs/LOCALIZATION_STYLE_GUIDE.md) — the ARB parity guard proves a key exists, not that it is written in the locale's voice
- **Every `MaterialApp` in tests needs delegates** — use `localizationsDelegates: appLocalizationsDelegates` (from `package:openvine/l10n/l10n.dart`) and `supportedLocales: AppLocalizations.supportedLocales`. The generated `AppLocalizations.localizationsDelegates` is not enough on its own: gen-l10n emits `flutter_localizations`' delegates, which satisfy the framework's `MaterialLocalizations` and not `material_ui`'s (#8916), and a `MaterialApp` given a non-English locale without them reports a delegate-coverage error
- **Never hardcode English strings in widget test assertions** — resolve the key from `AppLocalizations` instead, so the test survives copy changes and breaks loudly if the widget stops reading from l10n. Pick whichever lookup fits the test:

```dart
// Option A — direct lookup by locale (no BuildContext needed)
final l10n = lookupAppLocalizations(const Locale('en'));
expect(find.text(l10n.videoEditorAudioSegmentInstruction), findsOneWidget);

// Option B — via the pumped widget's BuildContext
final l10n = AppLocalizations.of(
  tester.element(find.byType(VideoAudioEditorTimingScreen)),
);
expect(find.text(l10n.videoEditorAudioSegmentInstruction), findsOneWidget);

// Optional but recommended — prove the widget actually reads from l10n
expect(
  find.text(lookupAppLocalizations(const Locale('de')).videoEditorAudioSegmentInstruction),
  findsNothing,
);

// Bad — hardcoded string breaks when copy changes and hides missing l10n
expect(find.text('Select the audio segment for your video'), findsOneWidget);
```

## Key Files

| File | Purpose |
|------|---------|
| `mobile/lib/l10n/app_en.arb` | English string definitions (source of truth) |
| `mobile/lib/l10n/app_es.arb` | Spanish translations |
| `mobile/lib/l10n/l10n.dart` | `context.l10n` extension |
| `mobile/lib/l10n/generated/` | Generated code (do not edit manually) |
| `mobile/l10n.yaml` | gen-l10n configuration |

---

## Running an l10n pass over existing code

When migrating a feature that was prototyped with hardcoded strings
(or when addressing review comments that flag l10n gaps), work in
this order:

1. **Inventory** — scan the target files for hardcoded user-facing
   strings. Exclude: log messages, asset paths, error messages passed
   to `addError`, test fixtures, debug `assert` messages.
2. **Check `app_en.arb` first.** Keys are often scaffolded in
   anticipation of a migration and sit unused. `grep -n "profileXxx"
   lib/l10n/app_en.arb` and `grep -rn "context.l10n.profileXxx" lib
   test | grep -v l10n/generated` to see what's defined-but-unused
   vs already-in-use.
3. **Prefer reuse.** If an existing key has the right copy, use it —
   even if its current callsite count is zero. Only add a new key
   when the copy genuinely differs (e.g. "Library" vs "My Library").
4. **Add missing keys** with `@keyName` metadata when the key takes
   placeholders or when the meaning isn't obvious from the key name:
   ```json
   "profileUserFallback": "user",
   "@profileUserFallback": {
     "description": "Generic fallback noun for a user whose display name is unknown. Used in sentences like 'Unfollow {user}?'."
   }
   ```
5. **Regenerate** via `flutter gen-l10n` from `mobile/`. Commit the
   regenerated files under `lib/l10n/generated/` with the migration.
6. **Swap call sites** to `context.l10n.xxx`. Add the l10n import
   (`package:openvine/l10n/l10n.dart`) if the file doesn't have it.
   For helpers that don't take `BuildContext`, thread it through — do
   not fetch l10n through `navigatorKey.currentContext` or similar
   workarounds.
7. **Update tests** that pump these widgets: add
   `appLocalizationsDelegates` / `AppLocalizations.supportedLocales`
   to the test's `MaterialApp` (see `testing.md`). Any existing
   assertion on the hardcoded English string now needs to match the
   ARB value verbatim.

### Copy-alignment policy

If the code's hardcoded string differs slightly from the existing ARB
value (trailing period, capitalization, punctuation), **align the code
to the ARB value** rather than changing the ARB:

- ARB values are already translated into 16+ locales. Changing an
  English value silently drifts the English source from every
  translation.
- The design / product team owns copy; a silent translation churn in
  a review comment is not the place to ship copy changes.
- If the copy really needs to change, do it as a separate,
  clearly-scoped commit with a product note, not as an l10n-migration
  side effect.
