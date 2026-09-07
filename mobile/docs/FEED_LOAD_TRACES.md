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

Only **release** builds report them. `PerformanceMonitoringService`
gates on `kReleaseMode` in Dart and debug/profile builds are additionally
deactivated natively, so a local run produces no samples at all and that is not
a bug. Opting one run back in takes both halves of the recipe in
[Network performance monitoring](NETWORK_PERFORMANCE_MONITORING.md#verifying-a-change) —
either alone leaves collection off.

One sampling gap is worth knowing about, because it is silent.
`startOperationTrace` hands back a no-op handle until
`PerformanceMonitoringService.initialize()` completes, and a load that starts
before that reports nothing at all rather than reporting a failure. #7118
closed the common case by registering the service in the **critical** startup
phase, ahead of the loads that mount during later phases. It is registered
`optional: true` though, so an initialization that fails or runs slowly still
removes cold-start samples without leaving a trace of its own.

## Trace names

`VideoEventService` starts one trace for each new subscription load that gets
past duplicate-subscription detection. The name is
`feed_load_${subscriptionType.name}`, and production subscribes only four of
the eight `SubscriptionType` values:

- `feed_load_homeFeed`
- `feed_load_discovery`
- `feed_load_profile`
- `feed_load_hashtag`

`editorial`, `popularNow`, `trending` and `search` exist on the enum and own
event lists, but nothing under `mobile/lib` or `mobile/packages` passes them to
`subscribeToVideoFeed`. Search in particular runs its own path,
`VideoEventService.searchVideos`, which registers a subscription without
starting a trace at all. So do not expect `feed_load_editorial`,
`feed_load_popularNow`, `feed_load_trending` or `feed_load_search` samples in
Firebase — zero of them is the correct reading, not missing instrumentation. If
one does appear, a new call site added it and this list needs updating.

Each load owns its own trace handle, even when concurrent loads have the same
trace name. Reusing an identical subscription does not start another trace.

### The `feed_load_*` glob is shared with Analytics

Firebase **Analytics** already emits three events matching the same glob, from
`mobile/packages/analytics`: `feed_load_complete` and `feed_load_more` from
`FeedPerformanceTracker`, and `feed_load_error` from `ErrorAnalyticsTracker`.
They are a separate dataset in a separate product area, keyed on `feed_type`
and carrying their own parameters — `total_load_time_ms`, `total_videos`,
`first_batch_count` — rather than `completion` and `event_count`.

Filtering Performance traces on `completion` excludes all three, which is what
you want. The trap is reading across the two datasets: `feed_load_complete`
reports `total_videos`, the count its caller passes as the videos displayed,
which is not the quantity [`event_count`](#what-event_count-counts) measures
below.

## Which loads produce a sample

### The worst failures produce no sample at all

The trace is created after `subscribeToVideoFeed` has already cleared several
preconditions, and each of them returns or throws first:

| Precondition | Outcome |
| --- | --- |
| `NostrService` not initialized | returns early, retries when it becomes ready |
| Device offline | throws `VideoEventServiceException` |
| No connected relays | throws `RelayNotReadyException` |
| `NostrService` still not initialized at subscription time | throws |

None of these reaches `startOperationTrace`, so they are absent from Firebase
rather than counted as `error` or `setup_error`. A relay outage therefore shows
up as **fewer** `feed_load_*` traces, not more failed ones — the chart looks
healthier during the outage than outside it. Read a drop in sample volume as a
failure signal, and do not read `error` + `done` + `setup_error` + `timeout` as
the total count of feed loads that failed.

### Not every sample is a load someone was waiting for

`subscribeToVideoFeed` is also the app's re-subscribe entry point, so several
callers with no user in front of them start traces under the same names:

- `resetAndResubscribeAll()` when the relay set changes, from the relay
  providers and the relay-settings cubit.
- `_scheduleReconnection`, five seconds after a relay stream closes.
- `_scheduleRetryWhenRelayReady`, once relays reconnect.
- `FeedRetryScheduler`, which re-issues a failed subscribe up to
  `maxAttempts` (3) times at `retryDelay` (10 seconds) apart.

Each attempt forces past duplicate-subscription detection and starts its own
trace, so one user-visible failed load can leave several samples behind. Treat
a `feed_load_*` percentile as latency of *a subscribe*, not as time a person
spent waiting — the background traffic is in there too, and it is the traffic
most likely to be slow.

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

It also has one consequence in the other direction: **two awaited steps finish
before the trace starts and are outside every duration on this page.**

- Tearing down the subscription being replaced. `replace` defaults to `true`,
  so a normal reload awaits `_cancelSubscription` first.
- Building a sorted filter. When `sortBy` is set, the filter builder makes a
  relay-capability round trip before the filter exists.

A sorted `feed_load_discovery` can therefore report a fast p95 while the person
is blocked on the capability probe. "The feed feels slow but the trace says
200 ms" is that gap, not a broken report.

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
