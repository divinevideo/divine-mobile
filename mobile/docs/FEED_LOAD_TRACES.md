# Feed-load performance traces

The `feed_load_*` custom traces measure how long a newly created feed load
takes to reach its first terminal milestone. They cover the cache lookup and
the relay subscription as one operation. They do not measure only relay
latency, and they do not necessarily measure time until a video is visible.

Use this reference when interpreting these traces in Firebase Performance.
The implementation lives in
[`VideoEventService`](../lib/services/video_event_service.dart), while
[`FeedLoadTrace`](../lib/services/feed_load_trace.dart) owns the first-wins
completion behavior.

## Trace names

`VideoEventService` starts one trace for each new subscription load that gets
past duplicate-subscription detection. The name is
`feed_load_${subscriptionType.name}`:

- `feed_load_homeFeed`
- `feed_load_discovery`
- `feed_load_profile`
- `feed_load_editorial`
- `feed_load_popularNow`
- `feed_load_trending`
- `feed_load_hashtag`
- `feed_load_search`

Each load owns its own trace handle, even when concurrent loads have the same
trace name. Reusing an identical subscription does not start another trace.

## Completion values

Every trace records a `completion` attribute and an `event_count` metric. The
first completion call wins; all later completion calls are no-ops.

| `completion` | What the duration ends at | Winning `event_count` |
| --- | --- | ---: |
| `cache` | A nonempty cache result has been processed and listeners have been notified | Number of events returned by the cache query |
| `first_relay_event` | The first raw relay event reaches the stream listener | `1` |
| `eose_empty` | EOSE arrives before any relay event reaches the listener | `0` |
| `timeout` | The 30-second no-event, no-EOSE fuse fires | `0` |
| `error` | The relay stream errors before another completion wins | `0` |
| `done` | The relay stream closes before another completion wins | `0` |
| `cancelled` | The load is unsubscribed or replaced before another completion wins | `0` |
| `disposed` | The service is torn down while the load is still pending | `0` |
| `setup_error` | Creating the relay subscription throws before another completion wins | `0` |
| `eose` | EOSE arrives after one or more relay events | Not currently observable as the winning value |

The `eose` call site remains in the implementation, but the first relay event
completes the same trace as `first_relay_event`. By the time EOSE can report a
positive relay count, that earlier completion has already won. An EOSE with no
listener-delivered events reports `eose_empty` instead.

## Durations are not interchangeable

The trace starts immediately before the cache lookup. This has two important
consequences:

- `cache` measures the cache lookup plus synchronous cache processing through
  listener notification.
- Relay outcomes include the cache lookup and relay subscription setup before
  the named relay milestone.

A warm-cache load normally completes as `cache`; later relay milestones for
that load do not replace it. Samples such as `first_relay_event` and
`eose_empty` are therefore biased toward loads without a nonempty cache result.

Do not interpret a percentile across every `completion` value as one latency
measure. Filter to a single completion value first. In particular, `cache` and
`first_relay_event` describe different work and are not directly comparable.

Treat `cancelled` and `disposed` as abandonment outcomes. Treat `error`,
`done`, and `setup_error` as unsuccessful terminal outcomes. Their durations
are useful for diagnosing and counting incomplete loads, but should not be
mixed into successful-load latency percentiles.

## What `event_count` counts

`event_count` is not the number of videos a person saw.

For `cache`, it is the number of events returned by the local cache query. The
events are then passed through normal ingestion, which can reject duplicates,
blocked content, hidden content, and other events that should not enter the
feed. The count can therefore be greater than the number added to the feed.

For relay processing, the counter increments as soon as each raw event reaches
the stream listener, before kind checks, duplicate detection, block filtering,
content filtering, or parsing. In current first-wins behavior, the only
successful relay value that retains a nonzero count is `first_relay_event`,
which reports `1`.

Do not use `event_count` as an impression, rendered-video, accepted-video, or
unique-video metric.

## Contract tests

The behavior is pinned in:

- [`feed_load_trace_test.dart`](../test/services/feed_load_trace_test.dart) for
  first-wins completion and metric assignment.
- [`video_event_service_startup_contract_test.dart`](../test/services/video_event_service_startup_contract_test.dart)
  for the completion paths and lifecycle cleanup.
