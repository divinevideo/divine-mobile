# View and loop metrics

**Date:** 2026-08-13
**Status:** Approved — fractional loops (settled 2026-08-13)
**Target:** No freeze applies; ships on the normal release path

## Problem

Divine has no shared definition of a view, and three discovery surfaces that
each rank on a different theory of merit. None of it was decided — it accreted
as data became available, and old formulas were carried forward by refactors
rather than revisited.

| Date | Event |
|---|---|
| 2026-01-05 | Trending formula written: `engagement × decay`, **no views term** |
| 2026-01-16 | Kind-22236 view ingestion ships — 11 days *later* |
| 2026-04-13 | Leaderboard rebuilt, uses `views + unique_viewers × 2` |
| 2026-06-15 | A **second** trending formula added, view-velocity |
| 2026-08-05 | Popular rebuilt, uses views as a linear term |

Two contradictory trending formulas are live simultaneously on
near-identically-named objects. The one the API serves
(`trending_videos_snapshot`, via `client.rs:3541`) is the view-velocity one —
not the one the object naming suggests.

The kind-22236 outage (#7210) exposed this. When mobile view reporting stopped,
`views`, `unique_viewers` and `loops` all fell ~60–69% in six days, which moved
Trending, Popular and the creator Leaderboard while Divine had no way to notice.
Detection is being added separately (divinevideo/divine-funnelcake#917).

Underneath the outage sits a permanent undercount, and it is measurable
directly rather than by inference.

### Ground truth: anyone who interacts provably watched

A like, comment, or repost is proof of viewing. Comparing the set of people who
interacted with a video against the set who registered a view gives a floor on
the loss, per video, with no benchmarks or assumptions.

Worked example — event
`a3092dfc8d36d15583d0866ae4312fd32b96a8eb59d79a7f23028c1ffc6d5503`, posted
2026-08-13:

| Measure | Count |
|---|---|
| Distinct people who liked / commented / reposted | 37 |
| Distinct people who registered a view | 26 |
| **Interactors who registered a view** | **10 of 37** |

**27 of 37 people who provably watched are absent from the view count** — 73%
missing. The card showed 108; the implied floor is above 400. It is a floor
twice over: it counts only people who bothered to interact, and silent viewers
are missing on top of them.

The same method shows engagement tracks looping, as expected for the format.
Interactors returned 4.5 times each against 1.06 for non-interactors, giving
~4.8 loops per interactor versus ~1.7. But the largest single interactor
session recorded **3.3 loops** — nobody writes a comment on a six-second video
in 3.3 passes, which suggests loop accumulation stops when the comment sheet
opens while the video keeps playing behind it. Unconfirmed, and worth finding.

Two weaker estimates agree in direction: recorded views imply an 8–18% per-user
interaction rate against a 1–5% short-form norm, and run at ~1.0 per CDN
download for a format where one download serves many playthroughs.

### Every known error runs the same way

Every cause identified so far *subtracts*:

- A view requires ≥1s of playback, excluding the scroll-past and the
  still-buffering.
- Anonymous viewers contribute no loops at all.
- Loop accumulation appears to stop during interaction.
- The queue regression dropped signed-in reporting entirely for six days.

None of them inflate. **So this is not a choice between accurate and
flattering — it is a choice between wrong-low and less-wrong.** Where a
definition is a genuine judgment call, this design takes the inclusive reading,
because every measured error is in one direction and adding caution on top of a
fourfold undercount compounds it rather than correcting it.

The constraint that remains is honesty, not conservatism: publish nothing that
could not be explained if audited. That rules out fabrication. It does not rule
out counting what is actually being watched.

Anonymous coverage is split, which is the confusing part. Because view events
are Nostr-signed, anonymous viewers reach `total_views` through CDN delivery —
42% of all views — but are absent from everything derived from
`view_interactions`: `unique_viewers`, `loops`, and the daily stats feeding the
leaderboard.

Numbers are not cosmetic here.
[The video-card view-count spec](2026-08-08-video-card-view-count-display-design.md)
measured that crossing ~100 views roughly doubles the chance a new creator keeps
posting (31% → 61%), and that 80% of new creators never reach it. Understated
counts suppress the behaviour the product depends on.

## Decisions

**1. Two metrics, not one.** Views and loops answer different questions and
must stop being conflated.

- **Loops** — every playthrough. Depth. Unbounded by nature.
- **Views** — one per playback start, per session. Reach. Bounded per person.

**2. A view is a playback start.** Not ≥1s, not a completed loop. This matches
TikTok and Reels, so a creator arriving from either reads Divine's numbers in
familiar units. It is also the largest defensible definition.

Rejected: *completed loop* (strictest option; 60.3% of current view events never
complete one, so it would cut recorded views to ~40%) and *≥1s* (today's rule,
comparable to nothing).

**3. Both metrics count everyone.** Signed-in and anonymous alike. Anonymous
viewers are roughly half of daily users and are currently invisible. This is the
single largest correction available and every other platform already does it.

**4. Loops stays the signature metric. Which number is larger is not yet
known.**

Loops currently measures 0.63–0.71 per view, and an earlier draft concluded
from that that views should be the headline. **That conclusion does not
survive, because the ratio is measured on a broken pipeline.** Anonymous
viewers are 42% of all views and contribute *zero* loops; the signed-in half
was dropping data for six days; and loop accumulation appears to stop during
interaction. Every one of those depresses loops specifically.

Loops is the *worse-measured* of the two metrics, not the smaller one. Counting
anonymous loops alone moves it close to parity, and if real looping runs above
what today's pipeline captures — which the 3.3-loop ceiling on commenter
sessions suggests — it passes views.

So loops keeps its claim on the video card and stays the metric no competitor
can quote. **Which metric leads is deferred until both are measured properly**,
rather than settled now on an instrument known to be broken in exactly the
direction that decides it.

**The card does not render this metric today, despite the label.**
`VideoEvent.totalLoops`
(`mobile/packages/models/lib/src/video_event.dart:1187-1188`) is:

```dart
int get totalLoops =>
    (originalLoops ?? 0) + (int.tryParse(rawTags['views'] ?? '') ?? 0);
```

Archival Vine loops plus the Divine **`views`** tag. For a Divine-native video
the number under the label "loops" is the *view* count. Pointing the card at
the real loop metric therefore cuts every Divine-native card by roughly a
third — which decision 5 forbids. Reconciling the label with the metric is a
prerequisite for this work, not a follow-up, and it is tracked as an open risk
below.

**5. A displayed number is never reduced — but it may be withheld.** These are
different acts and only one of them is a lie.

- **Never reduce.** No damping, capping, or silent dedup on any number that is
  shown. A creator can count their own loops; a shaved number is a trust
  violation and a discoverable one.
- **Withholding is legitimate.** Showing nothing is an editorial choice, not a
  false statement.
  [The video-card spec](2026-08-08-video-card-view-count-display-design.md)
  already establishes this: a public count renders only at or above
  `publicLoopCountFloor` (1000), because below that it reads as a warning rather
  than a recommendation, and small numbers were themselves suppressing adoption.
- **A creator always sees their own true number**, however small — correcting a
  creator's underestimate of their audience is what keeps them posting
  (Bernstein et al., CHI 2013).

The three rules compose: raw counts everywhere they appear, a floor governing
whether a *public* count appears at all, and no floor on a creator's own view of
their own work.

**6. Anti-spam lives entirely in ranking.** Nobody is owed a slot on Popular, so
ranking can be as aggressive as it needs to be. Because public counts never
move, aggressive filtering produces no creator-facing complaint — which makes it
easier to be strict, not harder.

**7. Each surface gets one stated job and one formula.** The duplicate and
contradictory ranking objects are removed, not left alongside.

| Surface | Job, in words a user could repeat |
|---|---|
| Trending | Rising fastest right now |
| Popular | Most-watched over a window |
| Leaderboard | Best creators over a period |

## Design

### Metric definitions

```
loop   := one playthrough fraction of the video (completed + partial)
view   := one playback start, deduplicated per viewing session
session:= a continuous period of engagement with one video by one viewer
```

One session reports one view and N loops, where **N is frequently zero** — a
viewer who starts playback and leaves before the video completes produces a
view and no loop. `loops >= views` does **not** hold, at either the row or the
aggregate level: 91% of current `view_counts` rows carry fewer loops than
views, and the aggregate ratio sits at 0.63–0.71 loops per view.

**Settled: loops are fractional.** `view_counts.total_loops` is `Float64` and
`view_interactions.loops` is `Float32` (observed range 0 to 218.2, mean 0.99).
A partial pass contributes a fraction; flooring would drop the reported figure —
the median view event sits at 0.75 of a pass and would round to zero. Keeping
the fractional value matches what already ships, is strictly larger, and
"2.4 loops" is defensible for a format where partial replays are real viewing.
The word "loop" therefore means *playthrough fraction*, not *completed
playthrough*.

### Display versus ranking

Two pipelines from one event stream, and they must not be collapsed:

- **Display path** — raw sums. What a viewer or creator sees on a video, a
  profile, or in analytics. No filtering of any kind. Whether a public count is
  *shown* is governed separately by `publicLoopCountFloor`; that gate decides
  visibility, never magnitude.
- **Ranking path** — the same events, then anti-spam, then damping. Feeds
  Trending, Popular, Leaderboard, and recommendations.

A single event contributes fully to display and conditionally to ranking. The
divergence is intentional and should be documented wherever both appear, so a
creator asking "why am I not on Popular with 50k loops" gets a real answer.

### Ranking inputs

Ranking damps loops and trusts views, because views are bounded per person and
loops are not — one observed session already carries 218 loops, which under raw
weighting outranks 218 distinct viewers.

Retained from current behaviour: `log1p(loops) × 0.5`, already used by
`popular_score` and the leaderboard. This is not a new brake; it is the existing
one, kept deliberately rather than by accident.

Anonymous events carry weaker identity guarantees than signed ones and should
therefore weigh less in ranking than signed-in events. They still count fully
for display. The exact weighting is a tuning question, not an architectural one.

### Anonymous signal: CDN-derived, one loop assumed

**Decision: each CDN delivery without a matching signed view event counts as one
view and one loop.**

This is not new machinery — it is already how the platform reports. Every
`video_total_views_data` row satisfies `total_views = cdn_views + auth_views`
exactly, with zero exceptions across 2,201,983 videos, and CDN accounts for 42%
of all views (4.70M of 11.14M). The decision is to make the existing behaviour
the stated definition rather than an undocumented accident, and to extend the
same treatment to loops.

It needs no client work, no new ingest endpoint, no unsigned-write abuse
surface, and no privacy decision on a device identifier. An unsigned client
beacon was considered and rejected on that basis: it would measure anonymous
loop depth accurately, but every one of those costs is real and the accuracy
gain does not carry them.

Two limits, stated so nobody later mistakes them for defects:

- **Anonymous loop depth is assumed, not measured.** One delivery serves many
  playthroughs, so an anonymous viewer who loops a video twenty times reports
  one loop. Anonymous engagement depth is therefore systematically conservative
  against signed-in depth. This understates the loop count rather than
  inflating it, which is the safe direction to be wrong in.
- **CDN counts are noisy.** Observed daily totals swing between 21k and 110k,
  driven by cache behaviour and range requests rather than by audience. Ranking
  should not treat a CDN-derived loop as equivalent in confidence to an observed
  one.

If anonymous loop depth later proves worth measuring properly, the beacon
remains available as an additive change; nothing in this design forecloses it.

### Expected movement

Stacked against today's reported numbers:

| Change | Effect on views | Effect on loops |
|---|---|---|
| #7210 view-event fix (merged) | ×2.6 ceiling, actual unmeasured | same ceiling |
| View = playback start | ×2–3 on the signed-in share | — |
| Anonymous counted | already counted (42% of views) | **new — CDN deliveries begin contributing** |
| Loop accumulation during interaction | — | unquantified; suspected undercount |

The #7210 ceiling is the full reporter population coming back: daily mobile
view reporters fell 676 → 263 over the window, so restoring all of them is
×2.6. The realised figure is lower and not yet measured, because that fix only
restores queued rows carrying a real `d` tag — rows where `videoVineId ==
videoId` still drop as `missingAddressableDTag`. Treat ×2.6 as a bound, not a
forecast, and read the actual number off the post-rollout baseline.

Views grow mostly from the redefinition, since anonymous views already flow into
`total_views`. Loops grow mostly from anonymous, since loops are currently
signed-in only and CDN deliveries have never contributed one.

Both remain floors. The interaction-overlap measurement puts real views for a
sampled video above 400 against a displayed 108, which is a larger correction
than this table accounts for, and it counts only viewers who interacted.
Treat every figure here as the least the number should move, not the most.

### The display floor

`publicLoopCountFloor` is 1000. It gates `_publicCount` in `mobile/lib/widgets/video_feed_item/video_card_meta.dart` — the archival `loops` tag for classic Vines (about 98% of the catalogue), and `originalLoops + views` for everything else. It is never applied to `video_total_views_data.total_views`, which is the column an earlier revision of this section measured; that mistake put the section three orders of magnitude off.

Measured against the quantity the code actually gates:

| Threshold | Videos at or above | Share of 2,203,822 |
|---|---|---|
| 1000 (today's floor) | 1,152,593 | **52.30%** |
| 333 (floor reached at ×3) | 1,375,711 | 62.42% |
| 100 (floor reached at ×10) | 1,621,923 | 73.60% |

Median public count: 1,417. A public count renders on about half the catalogue, not on 0.044% of it.

Every figure above comes from one query over `nostr.videos` that reproduces `_publicCount`'s branch in SQL: [the pre-change baseline](2026-08-13-view-and-loop-metrics-baseline.md#appendix-exact-queries), appendix block **§5 — display floor distribution**. The column mapping the whole correction rests on was checked rather than assumed: `nostr.videos.loops` is the client's `loops` tag, verified over a 200,000-row Vine sample in which 198,061 rows carry the tag and the column equals it in all 198,061, with zero mismatches. §5 of that document is the measurement record; this section states what it means for the design.

**This is live for everyone.** `FeatureFlag.videoCardPostDate` originally gated the rule as a kill switch, but it defaulted off and nothing ever set `FF_VIDEO_CARD_POST_DATE`, so it never reached a normal build. #7452 (merged 2026-08-15) deleted the dead flag, and `_resolveLoopCount` now applies the floor unconditionally for anyone who is not the video's owner. Earlier drafts of this section — including the one this replaces — describe the floor as feature-gated; that stopped being true before those words merged.

This is Flutter-client behavior. Divine Web currently diverges: its card renders any positive playback count and `formatLoopCount` applies only K/M abbreviation, not a display floor.

**The floor decision survives the correction. Two of the arguments this document made for it do not, and are withdrawn.** Both were artifacts of the wrong column:

- "The public count is effectively never shown — 9,996 videos in 10,000 render a date instead." It is shown on roughly half of them.
- "A date is the better default for this catalogue." The archival-artifact reading — that "Apr 22, 2014" reframes a clip as an artifact — assumed a date is what almost every card renders. It is not, so the argument no longer reaches the conclusion it was offered for. Whether a date reads better than a count on a given card is untested in either direction; nothing here settles it, and no decision in this document should be read as resting on it.

What holds the floor up instead is the argument the constant's own doc comment gives: a number below the floor tells a viewer not to bother, and a wall of small counts on *other people's* videos discourages a visitor from posting. On the real distribution the floor does exactly that — a count on ~52% of videos, every one of them at or above 1000, and a date on the rest instead of a discouraging two-digit count.

Creator retention is untouched by any of this and was never gated by the floor. `_resolveLoopCount` returns `video.totalLoops` unconditionally when `isOwnVideo`, and `totalLoops` is additive, so a creator who claimed a Vine account sees archival loops plus live views. The retention effect the video-card spec cites — crossing ~100 views roughly doubling the chance a new creator keeps posting — operates on the creator's own number, which has no floor.

**Open, not resolved: the constant's doc comment disagrees with the census.** The doc comment on `publicLoopCountFloor` reports "roughly 64% of the archive" hidden at "p50 is 298 loops", measured against a 1,000-Vine sample; the full-catalogue census above gives 47.70% hidden at p50 1,417. Both are the same order of magnitude and both contradict the withdrawn 0.044%, but they disagree with each other by more than sampling noise allows, and the sample's provenance is unexplained. The census is the better basis and this section uses it; the comment is deliberately left standing rather than overwritten by assertion. Reconciling the two is open work.

Re-tuning the floor value stays out of scope here. The constant is deliberately one line and the number is a product call, to be made on the census rather than as a side effect of correcting the evidence behind it.

## Testing

- Unit tests pinning `view`/`loop`/`session` boundaries: a scroll-past with no
  playback start emits nothing; one session with N playthroughs emits one view
  and N loops, including the N=0 case where playback starts and never
  completes a pass. Do **not** assert `loops >= views`; it is false in
  production data and the test should pin that a view with zero loops is
  valid.
- A test asserting the display path applies no filtering — the property most
  likely to be broken later by someone adding a well-meant cap.
- Ranking-path tests over adversarial input: a single session with hundreds of
  loops must not outrank many distinct viewers.
- Parity test between the signed and anonymous paths, so the two cannot drift to
  different definitions of the same word.
- The divinevideo/divine-funnelcake#917 detector already covers per-client reporting
  collapse and should stay green through the rollout.

## Out of scope

- Recomputing historical rankings for 2026-08-08 onward. The events were never
  sent and cannot be recovered; the on-device backlog replays with publish-time
  timestamps, so it lands on rollout day rather than the days it happened.
  Historical daily leaderboards for that window stay wrong permanently.
- Gorse recommendation retraining. Recommendations consumed the biased sample
  during the outage; the extent is unmeasured and is its own piece of work.
- The sybil-shaped reaction traffic since 2026-08-06. It inflates engagement
  terms rather than view terms and is tracked separately.

## Open risk

**Rollout-day spike.** The #7210 fix replays every stranded on-device backlog at
publish time. Expect a one-day artificial peak that is recovered history, not
growth, and do not read any view metric on that day without accounting for it.

**Numbers move for two reasons at once.** The redefinition and the outage
recovery land close together, so a jump will be hard to attribute. Ship the
detector and record a pre-change baseline first, or the effect of each becomes
unrecoverable.

**The card's "loops" label does not name the loop metric.** `totalLoops` sums
archival Vine loops with the Divine `views` tag, so a Divine-native card shows
a view count under a loop label. Because loops run at ~0.65x views, correcting
the card reduces a displayed number, which decision 5 forbids. The two rules
cannot both be satisfied by pointing the existing card at the new metric;
which one gives — the label, the floor, or a one-time restatement — is
unresolved and blocks the client half of this work.

**Anonymous loop depth is assumed rather than measured.** One CDN delivery
counts as one loop, so anonymous viewers who rewatch report a single loop. The
loop count is therefore conservative for 42% of the audience. That is the safe
direction to be wrong in, but it should be stated wherever the number is
published rather than discovered later by someone reconciling it.

**CDN delivery is inflatable without an account.** Repeated media requests raise
displayed counts, and decision 5 says displayed numbers are never reduced, so
the only remedy is at ingest — deduplication and rate limiting on delivery
logging. Decision 6 keeps the blast radius out of ranking, but it does not
protect the public number.
