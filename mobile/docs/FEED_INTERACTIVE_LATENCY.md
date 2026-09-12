# Feed interactive-latency telemetry

Status: Current

The `feed_load_*` Firebase Analytics events measure the user-visible home-feed
load owned by `VideoFeedBloc`. They complement the relay-subscription Firebase
Performance traces documented in [FEED_LOAD_TRACES.md](FEED_LOAD_TRACES.md).

## Event contract

Every accepted load emits `feed_load_started` with:

- `feed_type`: the stable feed-source tag;
- `load_reason`: `appStart`, `sourceSwitch`, `refresh`, or `pagination`.

The first nonempty list that can be rendered emits
`feed_first_content_visible`. It records `time_to_first_visible_ms`, video
count, and `served_from_cache`. A cache milestone does not finish the session.

The repository result emits `feed_fresh_result_complete`, even when it is
empty. It records `fresh_result_time_ms`, the earlier visible-content duration
when one exists, cache usage, and these bounded counters:

- `recommendation_page_count` for recommendation top-up pages;
- `following_page_count` for REST or relay following-feed pages.

These events contain no account, content, IP, locale, country, or precise
location identifiers. Regional analysis must use Firebase Analytics' derived
country/region dimensions and group them into `North America`, `Europe`,
`APAC`, and `Other/unknown` in the reporting query. Do not add client-derived
location fields to this event contract.

`feed_load_complete` remains emitted for dashboard compatibility. Its duration
now ends at the fresh result; new analysis should use the phase-specific event.

Each accepted load owns an independent telemetry session, including concurrent
loads for the same feed type. A superseded, cancelled, failed, or disposed load
is abandoned without a completion event, so `feed_load_started` and completion
counts are deliberately not one-to-one. Compare phase latency only across
completed loads, and monitor the completion ratio separately.

## Initial service target

For each feed type, initiation reason, cache state, platform, and coarse region:

- p75 time to first visible content: under 1 second;
- p95 time to first visible content: under 2.5 seconds;
- p75 fresh-result completion: under 3 seconds.

Evaluate a region only after at least 100 completed loads over a rolling
14-day window. Revisit these thresholds after the first complete window rather
than tuning them from individual reports.

## Deadline placement

Use the phase data before adding deadlines:

- High first-visible time with no cache points to cache lookup or the first
  upstream request. Bound the end-to-end BLoC load and return the best partial
  result available.
- Normal first-visible time but high fresh completion, correlated with page
  counts, points to repository page walks. Stop starting another page when the
  remaining load budget is exhausted; do not try to interrupt an in-flight
  HTTP or relay request with an elapsed-time check between awaits.
- High latency without elevated page counts points to transport or origin
  latency. A client page cap will not address it.

Cancellation belongs at the BLoC operation boundary when a load is superseded
by a source switch. Partial-result deadlines belong in the repository only
after the first page has produced usable content.
