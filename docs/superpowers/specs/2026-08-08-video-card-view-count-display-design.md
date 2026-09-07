# Video card view-count display

**Date:** 2026-08-08
**Status:** Implemented
**Target:** Release before the ~2026-08-13 freeze

## Problem

A video card's secondary line renders an unconditional loop count. A freshly
posted video reads `0 loops`, and funnelcake is about to guarantee new
creators' first videos 100–200 impressions through an exploration budget. Those
videos would surface stamped with a discouraging number: we pay for the
distribution and simultaneously tell every viewer not to bother.

Supporting measurements:

- 80% of new creators never reach 100 views on any first-week video.
- Crossing ~100 views roughly doubles the chance they keep posting (31% → 61%).
- New-creator content out-performs established-creator content per impression
  (loops 1.143 vs 1.092, completion 1.147 vs 1.097), so it deserves a fair
  viewing that a low count denies it.

Creator-facing counts are the opposite case. Bernstein et al. (CHI 2013) found
people badly underestimate their audience, and that perceived audience drives
production. The exploration floor will create exactly that underestimate, so
the creator's own view of their numbers stays intact.

The date is more useful on Divine than on other platforms: ~2.2M archived vines
from 2013–16 sit alongside content posted minutes ago. "Apr 22, 2014" vs
"3h ago" reframes what the viewer is watching and turns a bare clip into an
artifact. It also partly addresses a recurring review complaint about confusing
archive content ("weird videos of old people", App Store, 2026-08-06, v0.1.17).

## What the code actually does today

The number on the card is a **loop** count, not a view count.

The live site is `mobile/lib/widgets/video_feed_item/video_feed_item.dart:394`,
inside `VideoOverlayActions.build`. It renders `videoFeedLoopCountLine` directly
under the author name, unconditionally — so `0 loops` on a fresh post is real.

`VideoEvent.totalLoops` (`mobile/packages/models/lib/src/video_event.dart:1187-1188`)
is:

```dart
int get totalLoops =>
    (originalLoops ?? 0) + (int.tryParse(rawTags['views'] ?? '') ?? 0);
```

Archive Vine loops **plus** live Divine views, summed into one number. The two
components are available separately, which is what lets a classic Vine report
its archival figure alone.

Other surfaces carrying the same line:

- `mobile/lib/widgets/video_feed_item/metadata/metadata_stats_row.dart` — the
  more-info sheet. Already shows Loops/Likes/Comments/Reposts plus a
  Vine-vs-Divine breakdown for classic vines.
- `mobile/lib/screens/inbox/conversation/widgets/message_bubble.dart:1161` — DM
  video previews. **Out of scope.**
- `video_author_info_section.dart` and `actions/video_description_overlay.dart`
  were dead code — instantiated only by their own tests, referenced in `lib`
  only from comments or a barrel export. The flag-removal follow-up deleted
  them so the old raw loop-count line cannot be reintroduced by wiring a stale
  widget back in.

## Decisions

### Scope: display change only

The spec that motivated this work asked for a randomized variant flag and a
`video_card_shown` impression event. Neither is cheap here:

- `mobile/lib/features/feature_flags/` is the wired flag system: enum-based,
  boolean only, local SharedPreferences plus build config. No user bucketing,
  no variants.
- `mobile/lib/services/feature_flag_service.dart` is HTTP-backed and *does*
  support variants and rollout hashing — but has zero imports anywhere in `lib`
  or `test`. Dead code.
- No impression event exists. `AnalyticsService` has a generic `track()`, but
  all view tracking is playback-side.

So randomized measurement is infrastructure work, not a flag toggle. It was cut
from this change and deferred to separate post-freeze work. **The hypothesis in
the originating spec therefore stays untested by this change** — that is a
deliberate trade, made because this was already the third client change queued
for the same four days and the designated one to slip.

### Display rule

The rule is about **size, not provenance**. A count appears publicly only
when it is large enough to read as a recommendation; below that it reads as a
warning and is replaced by the date. Archival Vine numbers usually clear the
bar and our current view volume usually does not, which is the whole effect —
but it falls out of one threshold rather than two source-specific branches.

| Case | Date | Count | Renders |
|---|---|---|---|
| Own video | post date | `totalLoops`, always | `3h ago · 12 loops` |
| Count at or above the floor | post date | public count | `Apr 22, 2014 · 2.1M loops` |
| Count below the floor | post date | none | `3h ago` |
| Preview mode (`video == null`) | none | none | line omitted |

`publicLoopCountFloor` is **1000**. That number is a product call, not a
technical one, and it is the single value to change if the bar sits wrong. It
is deliberately a named constant so moving it is a one-line diff.

Cases are evaluated in the order listed, so `isOwnVideo` wins: a creator sees
their own number however small, because correcting a creator's underestimate
of their audience is what keeps them posting (Bernstein et al., CHI 2013).
A claimed classic Vine shows the creator `totalLoops` — performance data, not
the public archival figure.

The public count is `originalLoops` for classic Vines and `totalLoops`
otherwise. **Classic Vines never fold in live diVine views**: doing so would
misreport how popular the Vine actually was, and our current view volume is
too small to move the number meaningfully anyway.

**Preview mode currently renders a bogus `0 loops`** — `video?.totalLoops ?? 0`
with a null video. The rule drops the line instead. This is a behavior change
on share previews that was not requested; it is small and an improvement, but
it is a change.

### Date format: age-adaptive

Relative under 7 days (`3h ago`), absolute with the year beyond it
(`Apr 22, 2014`). This produces the fresh-vs-archive contrast the change is
for. Always-absolute reads cold on a ten-minute-old post; always-relative turns
a classic vine into `12y ago`, which reads as neglect rather than history and
works against the App Store complaint above.

### Card copy: reuse the shipped key

The card keeps `videoFeedLoopCountLine` ("12 loops"). No new ARB key, so no
16-locale mirroring for the card. The warmer "12 people watched this" framing
goes to the creator analytics screen instead, where the line is not width-
constrained.

### More-info sheet: reorder, don't restyle

Move the Loops `_StatColumn` from first to last position in
`MetadataStatsRow`. The count stays available per the originating spec's
"de-emphasised, not removed", de-emphasised by reading order. Restyling it
smaller in place was considered and rejected — a visually downgraded first
column reads as broken rather than intentional.

## Design

### 1. Pure resolver

New file `mobile/lib/widgets/video_feed_item/video_card_meta.dart`:

```dart
@immutable
class VideoCardMeta {
  const VideoCardMeta({this.timestamp, this.loopCount});
  final int? timestamp;   // unix seconds; null when the date is unknown
  final int? loopCount;   // null when the count stays hidden
  bool get isEmpty => timestamp == null && loopCount == null;
}

VideoCardMeta resolveVideoCardMeta({
  required VideoEvent? video,
  required bool isOwnVideo,
});
```

No Flutter dependency, so the whole truth table above is unit-testable without
pumping a widget.

Date source matches the more-info sheet:
`int.tryParse(video.publishedAt ?? '') ?? video.createdAt`, suppressed when
`video.hasUnknownOriginalDate` — classic vines whose original date is not
recoverable. A classic vine with neither a usable date nor an archive count
yields `isEmpty`, and the line is omitted.

### 2. Date formatting

Extend `mobile/lib/l10n/localized_time_formatter.dart`. It already wraps the
l10n-free `TimeFormatter` package with ARB strings and uses `package:clock`, so
tests pin time with `withClock`:

```dart
/// Recent posts read as elapsed time; a week or older falls back to an
/// absolute date with the year, so archives read as artifacts.
static String formatPostAge(
  AppLocalizations l10n,
  int unixSeconds, {
  String? locale,
});
```

Under 7 days delegates to the existing localized `formatRelativeVerbose`.
Beyond, `TimeFormatter.formatAbsoluteDate` — `DateFormat.yMMMd(locale)`, whose
doc comment already notes that Vine archives need their year visible.

### 3. Feature flag

None. The rule ships on for everyone.

`FeatureFlag.videoCardPostDate` originally gated this as a kill switch. It
defaulted off and nothing in CI, Codemagic, build scripts, or dart-defines ever
set `FF_VIDEO_CARD_POST_DATE`, so the rule never reached normal builds from the
day it merged. Developer-mode devices could preview the internal flag locally,
but there is no bucketing or impression event behind it to justify keeping a
toggle, and the behaviour reverts in a single commit.

### 4. Widget changes

**`video_feed_item.dart:394`** — replace the unconditional `Text` with the
resolved line. `VideoOverlayActions.build` is already a `ConsumerWidget` with
`ref`, so `isOwnVideo` comes from
`ref.watch(authServiceProvider).currentPublicKeyHex`, the same read
`VideoOverlayActionColumn` already performs at line 673.

Date and count join with `' · '` at the widget layer. That is the established
idiom in this codebase (`sound_tile.dart`, `audio_attribution_row.dart`,
`metadata_sounds_section.dart`, and five other call sites), and it avoids a new
ARB key. The separator is bidi-neutral, so RTL locales order the whole string
correctly.

**`metadata_stats_row.dart`** — move the Loops `_StatColumn` to last.

The product line is surface-specific. Feed cards are first-impression
recommendation surfaces, so they hide stranger-facing counts below
`publicLoopCountFloor = 1000`; own-video cards always show the creator their
count. Profile summaries keep their stronger `profileLoopsVisibilityFloor =
10000` because they communicate account-level momentum, while detail surfaces
such as the metadata sheet remain factual and keep exact counts visible after a
viewer asks for more information.

### 5. Analytics wording

`creator_analytics_screen.dart:718` and `:930` both used `analyticsViewsCount`
= `"{count} views"`. Reaching "12 people watched this" required a **new** key
(`analyticsWatchedCount`), not an edit of the existing value: editing in place
would leave 16 locales holding translations of "views" while English said
something else, which `.claude/rules/localization.md` explicitly warns against.
The new key is registered in `_knownUntranslatedDebt`, deferring translation to
the next analytics localization pass.

**Only the `:718` highlight row was changed.** `:930` is a dense per-video row
rendering `12 views • 3 interactions`; "12 people watched this • 3
interactions" does not fit that line. The result is that one screen names the
same quantity two ways — "people watched this" in the headline, "views" in the
data rows. That is a deliberate call (headline gets the human framing, data
rows stay compact) but it is a real inconsistency a reviewer may want reversed
in either direction.

## Testing

| File | Covers | Tests |
|---|---|---|
| `test/widgets/video_feed_item/video_card_meta_test.dart` (new) | Every row of the truth table; the floor boundary either side; `originalLoops` vs `totalLoops` for classic Vines; `hasUnknownOriginalDate`; the empty case | 15 |
| `test/widgets/video_feed_item/video_feed_item_meta_line_test.dart` (new) | Hides a small count from a stranger but shows a large one; creator sees their own small count; classic Vine shows archival count plus its date; auth changes reveal the creator count | 6 |
| `test/widgets/video_feed_item/metadata/metadata_stats_row_test.dart` (new) | Loops trailing every interaction stat; the count still rendering; classic-Vine breakdown. This file had no test before. | 5 |
| `test/l10n/localized_time_formatter_test.dart` (extend) | `formatPostAge` either side of the 7-day boundary under `withClock`; year retained on an archive date; German localization of both forms | 5 |

The floor-boundary pair is what makes these able to fail: each side asserts a
behaviour its sibling contradicts.

Widget tests need `AppLocalizations.localizationsDelegates` and
`supportedLocales` on their `MaterialApp`, and must resolve expected strings
from `AppLocalizations` rather than hardcoding English.

No goldens cover these widgets, so there is no golden churn.

## Out of scope

- DM video previews (`message_bubble.dart:1161`) keep the old line.
- `video_card_shown` impression event and variant bucketing — separate
  post-freeze work. Without them this change ships unmeasured.
- Any further de-emphasis of the more-info sheet beyond column order.

## Open risk

This is the third client change queued for the same pre-freeze window, and the
one already designated to slip if something must. Nothing here depends on the
other two, so it can be dropped late without unpicking them.
