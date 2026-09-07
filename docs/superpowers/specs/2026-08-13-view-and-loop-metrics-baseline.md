# View and loop metrics: pre-change baseline

**Date:** 2026-08-13, measured 08:30–09:15 UTC
**Status:** Snapshot — read-only measurement, no code change
**Companion to:** [View and loop metrics design](2026-08-13-view-and-loop-metrics-design.md)

## Why this exists

The design's open risk section: the redefinition and the #7210 outage recovery
land close together, and without a recorded pre-change state their effects
become unattributable. This is that record. Every number here was measured
read-only against production ClickHouse Cloud on the date above, with the exact
SQL in the appendix so any figure can be re-derived or extended.

**Reader's key for the client tag.** Mobile view reporters appear in
`view_interactions.client` as `Divine`, emitted by
`mobile/packages/nostr_client/lib/src/nip89_client_tag.dart:11`. A second
stream, `divine-mobile/1.0`, carries 1-6 viewers/day and is a legacy or dev
build, not the shipping app. The divinevideo/divine-funnelcake#917 detector's
"mobile" series is the `Divine` bucket alone — its backtest figures (578 on
2026-08-05, 263 on 2026-08-12) match `Divine` exactly. **§1's Mobile columns
are the union `client IN ('Divine', 'divine-mobile/1.0')`, so they run 0-6
viewers/day above the detector's series** (2026-08-05: 582 union vs 578
`Divine`). Reconcile a divinevideo/divine-funnelcake#917 alert against
`Divine` only.

One caveat is load-bearing: the mobile client tag is user-disablable from
Nostr settings (`mobile/lib/screens/settings/nostr_settings_screen.dart:241`),
and `Nip89ClientTag.applyToEvent` returns without adding the tag when disabled
(`mobile/packages/nostr_client/lib/src/nip89_client_tag.dart:75-82`). Kind
22236 is not excluded from tagging, so a user who opts out still publishes view
events, but they land with a null or non-Divine client. That means §1's mobile
columns and divinevideo/divine-funnelcake#917's detector series are biased low
by an unmeasured opt-out population; a large opt-out wave can present as a
mobile reporting collapse. Any change to what the shipping app sends as its
client tag silently re-keys the detector; the redefined playback-start event
must keep the same tag when attribution is enabled.

## 1. The outage, as a series

Signed-in reporting per day, UTC. `views_today_def` reconstructs the server's
current definition per event: `ceil(loops)` clamped to ≥1 (see §3).

| Day | Mobile events | Mobile viewers | Mobile loops | Mobile views (today's def) | Web events | Web viewers |
|---|---|---|---|---|---|---|
| 2026-07-24 | 28,022 | 621 | 28,323.1 | 44,027 | 11,967 | 39 |
| 2026-07-25 | 27,967 | 656 | 28,303.4 | 44,117 | 7,415 | 37 |
| 2026-07-26 | 27,710 | 630 | 27,869.1 | 43,628 | 196 | 26 |
| 2026-07-27 | 28,823 | 666 | 26,927.2 | 43,409 | 2,436 | 56 |
| 2026-07-28 | 30,269 | 641 | 33,278.1 | 50,483 | 2,126 | 46 |
| 2026-07-29 | 30,144 | 591 | 32,376.2 | 49,541 | 3,514 | 40 |
| 2026-07-30 | 23,788 | 597 | 27,753.4 | 40,753 | 2,069 | 42 |
| 2026-07-31 | 26,558 | 566 | 28,895.8 | 43,554 | 1,098 | 45 |
| 2026-08-01 | 27,351 | 680 | 27,476.4 | 42,672 | 10,739 | 42 |
| 2026-08-02 | 28,301 | 625 | 27,736.6 | 43,762 | 3,557 | 50 |
| 2026-08-03 | 28,523 | 628 | 28,488.8 | 44,582 | 484 | 41 |
| 2026-08-04 | 29,067 | 612 | 27,448.8 | 44,089 | 1,345 | 56 |
| 2026-08-05 | 25,043 | 582 | 26,140.5 | 40,202 | 925 | 51 |
| 2026-08-06 | 28,252 | 580 | 28,995.7 | 44,907 | 903 | 36 |
| 2026-08-07 | 24,062 | 572 | 26,286.7 | 39,702 | 758 | 42 |
| 2026-08-08 | 21,083 | 499 | 22,249.3 | 34,456 | 2,265 | 39 |
| 2026-08-09 | 21,653 | 415 | 22,838.2 | 34,962 | 3,999 | 46 |
| 2026-08-10 | 16,870 | 366 | 17,931.6 | 27,300 | 1,287 | 51 |
| 2026-08-11 | 15,050 | 350 | 14,439.2 | 23,147 | 1,545 | 42 |
| 2026-08-12 | 8,833 | 263 | 9,197.5 | 14,182 | 2,517 | 40 |
| 2026-08-13 (partial, to 09:15 UTC) | 2,861 | 116 | 3,544.6 | 5,141 | 2,253 | 24 |

What to hold onto:

- **Mobile reporters fell 676 → 263 (–61%) over twelve days; events fell
  28.5k → 8.8k (–69%).** Stated on the `Divine` bucket so it matches the
  two merged specs and the divinevideo/divine-funnelcake#917 detector; the
  union column above reads 680 → 263 for the same span. Re-run the client
  breakdown query in the appendix to derive the 676 detector peak; the platform
  rollup query derives the table.
- **Web was flat throughout** (36–56 viewers every day, no trend). The
  regression is mobile-only — the property the divinevideo/divine-funnelcake#917
  detector keys on.
- **The #7210 recovery is not yet visible at capture time.** 2026-08-13 is a
  partial day but tracks below 2026-08-12's full day. The client fix
  (#7182, persist the addressable d tag on queued view events) is merged but
  its reporters have not arrived in production numbers. When they do, this
  table is the "before".
- Loops-per-event sits at ~1.0–1.1 for mobile throughout, outage or not —
  the outage removed *reporters*, not engagement depth per reporter.

## 2. Anonymous coverage: the CDN side

`cdn_view_counts` holds one row per media delivery (sha256, viewed_at, pop,
bytes_sent). Daily, UTC:

| Day | Deliveries | Distinct videos | GB served |
|---|---|---|---|
| 2026-07-24 | 62,939 | 44,239 | 82.97 |
| 2026-07-25 | 46,165 | 25,690 | 68.50 |
| 2026-07-26 | 28,514 | 15,580 | 47.95 |
| 2026-07-27 | 37,149 | 22,470 | 53.05 |
| 2026-07-28 | 98,027 | 67,253 | 126.66 |
| 2026-07-29 | 115,191 | 78,120 | 150.03 |
| 2026-07-30 | 78,905 | 55,092 | 103.90 |
| 2026-07-31 | 54,012 | 36,279 | 73.41 |
| 2026-08-01 | 21,523 | 8,601 | 33.43 |
| 2026-08-02 | 32,802 | 19,734 | 48.59 |
| 2026-08-03 | 28,398 | 14,325 | 44.20 |
| 2026-08-04 | 25,383 | 12,299 | 38.04 |
| 2026-08-05 | 55,444 | 39,299 | 68.69 |
| 2026-08-06 | 49,968 | 35,327 | 65.41 |
| 2026-08-07 | 34,529 | 23,071 | 50.28 |
| 2026-08-08 | 35,932 | 25,314 | 54.13 |
| 2026-08-09 | 27,276 | 13,198 | 42.62 |
| 2026-08-10 | 35,480 | 24,929 | 54.67 |
| 2026-08-11 | 39,609 | 18,781 | 63.96 |
| 2026-08-12 | 110,791 | 68,035 | 150.15 |
| 2026-08-13 (partial) | 32,666 | 22,034 | 48.86 |

- **Daily deliveries swing 21.5k–115.2k with no weekly pattern** — cache
  behaviour and range requests, not audience. The design doc's noise warning
  (21k–110k) reproduces. Ranking must not treat a CDN-derived loop as
  equivalent in confidence to an observed one.
- **CDN deliveries do not visibly dip during the outage window** (the dip
  2026-08-01..04 and the spike 2026-08-12 both sit inside ordinary variance).
  Anonymous demand kept flowing while signed-in reporting collapsed — the
  two channels measure different things and only one was broken.

Totals across the catalogue (`video_total_views_data`, refreshed
2026-08-13 08:30 UTC):

| Measure | Value |
|---|---|
| Videos | 2,201,986 |
| CDN views | 4,709,947 |
| Auth views | 6,441,545 |
| Total views | 11,151,492 |
| CDN share | **42.24%** |
| Rows where `total ≠ cdn + auth` | **0** |

The design doc's identity holds exactly on all 2.2M rows. CDN-derived
viewing is already 42% of reported views and contributes **zero** loops
today — that gap is the single largest correction the design makes.
This denominator comes from `video_total_views_data`, the aggregate table
behind the CDN/auth split; §5 uses `nostr.videos`, which has a slightly larger
catalogue row count because it is the source table for the public-count gate.

## 3. Today's definitional conflation, measured

The server computes, per kind-22236 event
(`divinevideo/divine-funnelcake/crates/relay/src/view_handler.rs:62-82`):

```
duration   = video_duration_seconds, else 6.3s when missing/non-finite/<=0
loops      = max(watched_seconds, 1) / duration   (Float)
view_count = ceil(loops) clamped to ≥ 1
```

So today's "views" are not playback starts and not sessions — they are
**loops rounded up**. A 30-second watch of a 6-second video is 5 "views"
from one session; a 0.75-pass watch is 1. The client-sent `loops` tag is
never parsed (`ViewEventData`, same file) — every fractional loop in the
database is server-derived. Unknown or invalid durations use the 6.3-second
fallback, so the 0.733 aggregate ratio includes fallback-derived loops rather
than treating those rows as undefined. Aggregate state:

| Measure | Value |
|---|---|
| `view_counts` rows (per-video aggregates) | 2,106,714 |
| Σ view_count | 6,542,283 |
| Σ total_loops | 4,796,635.2 |
| Loops per view, aggregate | **0.733** |
| Rows with loops < views | **91%** |

The design doc's 0.63–0.71 ratio and 91% row share reproduce. This is the
ratio measured on the broken pipeline — the argument for deferring the
"which metric leads" call until both are measured properly.

## 4. Ground truth: interactors who never registered a view

Method: a like, repost, or comment is proof of viewing. For each sampled
video, the set of distinct pubkeys interacting in the last 4 days (kinds
6, 7, 16, 1111 via `event_tags_flat`, plus `comments`) is compared against
the set of distinct pubkeys in `view_interactions` for that video (full
90-day TTL window). Candidates were restricted to events present in
`videos` — an earlier unrestricted pass returned kind-1 text notes from the
wider relay network, which trivially have no view rows.

Ten most-reacted videos, 2026-08-09..13. Sample labels stand in for the real
event ids so this public doc keeps the aggregate result without publishing
content-level internal measurement rows.

| Sample | Interactors | Registered viewers | Interactors with a view | Missing |
|---|---|---|---|---|
| sample_01 | 46 | 55 | 17 | 63.0% |
| sample_02 | 42 | 53 | 22 | 47.6% |
| sample_03 | 42 | 29 | 11 | 73.8% |
| sample_04 | 39 | 77 | 27 | 30.8% |
| sample_05 | 38 | 52 | 20 | 47.4% |
| sample_06 | 35 | 35 | 16 | 54.3% |
| sample_07 | 33 | 55 | 14 | 57.6% |
| sample_08 | 31 | 41 | 11 | 64.5% |
| sample_09 | 30 | 41 | 14 | 53.3% |
| sample_10 | 30 | 49 | 22 | 26.7% |

**Weighted: 174 of 366 provable watchers registered a view — 52.5% are
absent.** Median across videos 53.8%, range 26.7–73.8%. The design doc's
single-video measurement reproduces as `sample_03` at 11-of-42 — same video,
more interactions accrued since, same direction. The 73% figure was the high
end of a real distribution, not an outlier.

Caveats, stated so the number is not over-read:

- An interactor who watched >90 days ago and reacted late would be falsely
  counted as missing. For videos interacted with this month this is rare —
  reaction follows viewing closely — and the 4-day-window variant of the
  query produced near-identical overlap.
- This samples *signed-in* viewing only, by construction: anonymous viewers
  sign no events, so they appear in neither set. It is a floor on the
  signed-in loss, not a measure of the anonymous share.

## 5. The display floor, restated on current numbers

**This section is the measurement record behind the design doc's corrected
display-floor section.** `mobile/lib/widgets/video_feed_item/video_card_meta.dart:70`
defines the gated quantity as `video.isOriginalVine ? video.originalLoops ?? 0 :
video.totalLoops` — i.e. the archival `loops` tag for classic Vines (about 98%
of the `nostr.videos` catalogue; derived by the appendix query), and
`originalLoops + views` for native ones. The design doc's table originally
measured `video_total_views_data.total_views`, which the floor is never applied
to, and landed three orders of magnitude off; #7471 replaced it with the figures
below.

`publicLoopCountFloor` = 1000, measured against the quantity the code
actually gates:

| Threshold | Videos at or above | Share of 2,203,822 |
|---|---|---|
| 1000 (today's floor) | 1,152,593 | **52.30%** |
| 333 | 1,375,711 | 62.42% |
| 100 | 1,621,923 | 73.60% |

Median public count across the catalogue: **1,417**.

A public count renders on about **half** the catalogue, not on 0.044% of it.
The design doc's prior conclusion — "the public count is effectively never
shown; 9,996 videos in 10,000 render a date" — does not hold.

This is live for everyone, not feature-gated. `FeatureFlag.videoCardPostDate`
originally gated the rule as a kill switch, but it defaulted off and nothing
ever set `FF_VIDEO_CARD_POST_DATE`, so it never reached a normal build. #7452
(merged 2026-08-15 04:31 UTC) deleted the dead flag; `_resolveLoopCount` now
applies the floor unconditionally to any viewer who is not the video's owner.
An earlier revision of this paragraph introduced the stale
"production unchanged while the flag stayed off" framing after #7452 had
already removed that flag.

Scope: this is the Flutter-client card rule. Divine Web currently diverges: its
card renders any positive playback count and `formatLoopCount` applies only K/M
abbreviation, not a display floor.

**The floor decision survives the correction; only its stated rationale
changes.** The design doc argued the floor was harmless because almost
nobody ever sees a count. The real argument is the one on the constant
itself (`mobile/lib/widgets/video_feed_item/video_card_meta.dart:9`): a number
below the floor "tells a viewer not to bother", and a wall of small counts on
*other people's* videos discourages posting. On the real distribution, the
floor shows visitors a count on ~52% of videos, every one of them ≥1000, and a
date on the rest instead of a discouraging 47. Creators are never gated:
`_resolveLoopCount` returns
`video.totalLoops` unconditionally when `isOwnVideo`, and `totalLoops` is
additive (`mobile/packages/models/lib/src/video_event.dart:1181-1183`), so a
creator sees the larger number.

One unreconciled discrepancy, stated rather than smoothed over: the
constant's own doc comment reports "roughly 64% of the archive" hidden
with "p50 is 298 loops", measured against a 1,000-Vine sample. The
full-catalogue measurement above gives 47.7% hidden at p50 1,417. Both are
the same order of magnitude and both contradict the withdrawn 0.044%,
but the sample and the census disagree by enough that the sample was
probably not representative. Re-tuning the floor should use the census.

## 6. Context figures

- `daily_active_users` was still accruing when this snapshot was taken, so the
  same day read changed between 2026-08-13 and 2026-08-14. Signed-in view
  reporters were only a low-single-digit percentage of that daily active user
  row. Treat that as directional context, not a settled KPI. The table has no
  auth split, so the "anonymous are roughly half of daily users" claim cannot
  be checked here; the CDN channel (§2) is the only anonymous evidence.
- The API's trending surface reads `trending_videos_snapshot`
  (`divinevideo/divine-funnelcake/crates/clickhouse/src/client.rs`); a second,
  separate path queries `trending_videos` in the same repo. Both are live code
  at capture time — the duplicate-formula situation the design removes.

## 7. How to use this document

When each change from the design lands, re-run the appendix queries and
compare against the matching section:

| Change | Status at capture | Watch |
|---|---|---|
| #7210 client fix rollout | merged, not yet visible | §1 mobile reporters returning toward ~600/day; expect a one-day backlog-replay spike at publish-time timestamps — recovered history, not growth |
| View = playback start | **landed — #7217, merged 2026-08-13 10:08 UTC** | §1 events rising toward sessions; `views_today_def` decoupling from loops |
| Same-video session restart | **landed — #7231, merged 2026-08-14 04:20 UTC** | §1 events rising for re-watches without §1 viewers rising |
| CDN-derived loops | not started | §2's zero-loop gap closing; §3 aggregate loops/view rising past 1.0 for the first time |
| Ranking unification | not started | §6's duplicate trending paths reduced to one |

**Changes since capture.** #7217 and #7231 both merged between this
snapshot and this document landing, so the first two rows are already
"after" rather than "before". #7217 implements the design's single
kind-22236 event per session — there is no two-phase start/end event in
either merged spec, and #7231 documents one-event-per-session as the
current mobile-emitted contract.

**Most** figures here are floors measured on a pipeline whose known errors
run downward — but not all of them, so do not apply that blanket:

- **View counts are floors.** Every known error drops views.
- **Loop figures are not.** The findings doc §3.4 records a `_handleState`
  early-return defect that *inflates* watch time when a route is pushed,
  and stored `loops` is `watched_seconds / duration`, so §1's loop sums and
  §3's 0.733 loops/view ratio are inflated by it.
- **§4's missing share is not.** Its own caveat admits the 90-day window
  falsely counts a late-reacting interactor as missing.

Compare like for like: same UTC day boundaries, same client buckets, same
TTL windows.

## Appendix: exact queries

All run read-only against production ClickHouse, database `nostr`, on
2026-08-13. `CH()` is the HTTPS endpoint with the readonly credential.

<details>
<summary>§1 — daily signed-in series</summary>

```sql
SELECT toDate(created_at,'UTC') AS day,
       multiIf(client IN ('Divine','divine-mobile/1.0'),'mobile',
               client='divine-web/1.0','web','other') AS platform,
       count() AS events,
       uniqExact(viewer_pubkey) AS viewers,
       round(sum(view_interactions.loops),1) AS loops_sum,
       sum(greatest(ceiling(view_interactions.loops),1)) AS views_today_def
FROM nostr.view_interactions
WHERE created_at >= toDate('2026-07-24','UTC')
GROUP BY day, platform
ORDER BY day, platform;
```
(The `view_interactions.` qualifier on `loops` is load-bearing: an unqualified
`sum(loops) AS loops` alias shadows the column and ClickHouse 26 rejects the
later `ceiling(loops)` as a nested aggregate.)

Client breakdown for reconciling §1's `mobile` union with the
divinevideo/divine-funnelcake#917 detector's `Divine` bucket:

```sql
SELECT toDate(created_at,'UTC') AS day,
       client,
       count() AS events,
       uniqExact(viewer_pubkey) AS viewers
FROM nostr.view_interactions
WHERE created_at >= toDate('2026-07-24','UTC')
  AND client IN ('Divine','divine-mobile/1.0','divine-web/1.0')
GROUP BY day, client
ORDER BY day, client;
```
</details>

<details>
<summary>§2 — CDN deliveries and totals split</summary>

```sql
SELECT toDate(viewed_at,'UTC') AS day, count() AS deliveries,
       uniqExact(sha256) AS videos, round(sum(bytes_sent)/1e9,2) AS GB
FROM nostr.cdn_view_counts
WHERE viewed_at >= toDate('2026-07-24','UTC')
GROUP BY day ORDER BY day;

SELECT count() AS videos, sum(cdn_views) AS cdn, sum(auth_views) AS auth,
       sum(total_views) AS total,
       round(sum(cdn_views)/sum(total_views)*100,2) AS cdn_pct,
       countIf(total_views != cdn_views + auth_views) AS sum_breaks,
       max(refreshed_at) AS last_refresh
FROM nostr.video_total_views_data;
```
</details>

<details>
<summary>§3 — loops vs views aggregate</summary>

```sql
SELECT count() AS rows, sum(view_count) AS views,
       round(sum(total_loops),1) AS loops,
       round(sum(total_loops)/sum(view_count),3) AS loops_per_view,
       round(countIf(total_loops < view_count)/count()*100,1) AS pct_rows_loops_lt_views
FROM nostr.view_counts;
```
</details>

<details>
<summary>§4 — ground-truth interactor overlap</summary>

Candidates (must be restricted to catalogue videos, or relay-network text
notes dominate the reaction sample):

```sql
SELECT f.tag_value_primary AS vid, uniqExact(f.pubkey) AS reactors
FROM nostr.event_tags_flat f
INNER JOIN (SELECT toString(id) AS id FROM nostr.videos) v
  ON f.tag_value_primary = v.id
WHERE f.kind = 7 AND f.tag_name = 'e'
  AND f.created_at >= now() - INTERVAL 4 DAY
GROUP BY vid HAVING reactors >= 10
ORDER BY reactors DESC LIMIT 10;
```

Overlap per candidate set:

```sql
WITH videos AS (SELECT arrayJoin([ '<event id>', ... ]) AS vid),
interactors AS (
  SELECT DISTINCT vid, toString(pubkey) AS pk FROM (
    SELECT tag_value_primary AS vid, pubkey FROM nostr.event_tags_flat
    WHERE kind IN (6,7,16,1111) AND tag_name = 'e'
      AND tag_value_primary IN (SELECT vid FROM videos)
      AND created_at >= now() - INTERVAL 4 DAY
    UNION ALL
    SELECT root_event_id AS vid, pubkey FROM nostr.comments
    WHERE root_event_id IN (SELECT vid FROM videos)
      AND created_at >= now() - INTERVAL 4 DAY
  )
),
viewersall AS (
  SELECT DISTINCT target_event_id AS vid, toString(viewer_pubkey) AS pk
  FROM nostr.view_interactions
  WHERE target_event_id IN (SELECT vid FROM videos)
)
SELECT ia.vid, ia.interactors, va.viewers_90d, oa.interactors_with_view,
       round(100 - oa.interactors_with_view / ia.interactors * 100, 1)
         AS pct_interactors_missing
FROM (SELECT vid, uniqExact(pk) AS interactors FROM interactors GROUP BY vid) ia
LEFT JOIN (SELECT vid, uniqExact(pk) AS viewers_90d
           FROM viewersall GROUP BY vid) va ON ia.vid = va.vid
LEFT JOIN (SELECT i.vid, uniqExact(i.pk) AS interactors_with_view
           FROM interactors i
           INNER JOIN viewersall v ON i.vid = v.vid AND i.pk = v.pk
           GROUP BY i.vid) oa ON ia.vid = oa.vid
ORDER BY ia.interactors DESC;
```
</details>

<details>
<summary>§5 — display floor distribution</summary>

Mirrors `_publicCount` in `video_card_meta.dart`: the archival `loops` tag
for classic Vines, `originalLoops + views` otherwise. Do **not** measure
this against `video_total_views_data.total_views` — the floor is never
applied to that column, and doing so is the error this section corrects.

```sql
WITH
  arrayExists(t -> t[1] = 'platform' AND t[2] = 'vine', tags) AS is_vine,
  toUInt64OrZero(arrayFirst(t -> t[1] = 'views', tags)[2])    AS views_tag,
  if(is_vine, loops, loops + views_tag)                       AS public_count
SELECT count()                       AS catalogue,
       countIf(is_vine)              AS vine_catalogue,
       round(countIf(is_vine) / count() * 100, 1) AS vine_catalogue_pct,
       countIf(public_count >= 1000) AS ge_1000,
       countIf(public_count >= 333)  AS ge_333,
       countIf(public_count >= 100)  AS ge_100,
       median(public_count)          AS p50
FROM nostr.videos;
```

`nostr.videos.loops` is the `loops` tag, verified over a 200,000-row Vine
sample: 198,061 rows carry the tag and the column equals it in all 198,061,
with zero mismatches.
</details>

<details>
<summary>§6 — daily active users</summary>

`daily_active_users` accrues after the day closes, so a same-day or
next-morning read is partial. Record the read time alongside the value.

```sql
SELECT date, active_users
FROM nostr.daily_active_users
WHERE date >= toDate('2026-08-08')
ORDER BY date;
```
</details>
