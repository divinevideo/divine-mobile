# Feed-load performance traces

Status: Current
Validated against: `mobile/lib/services/video_event_service.dart`,
`mobile/lib/services/feed_load_trace.dart`, and
`mobile/lib/services/performance_monitoring_service.dart` on 2026-09-14.

The `feed_load_*` custom traces measure how long a newly created feed load
takes to reach its first terminal milestone. They cover the cache lookup and
the relay subscription as one operation. They do not measure only relay
latency, and they do not necessarily measure time until a video is visible.

For end-to-end cache, first-visible, and fresh-result phases, use
[FEED_INTERACTIVE_LATENCY.md](FEED_INTERACTIVE_LATENCY.md).

Use this reference when interpreting these traces in Firebase Performance.
The implementation lives in
[`VideoEventService`](../lib/services/video_event_service.dart), while
[`FeedLoadTrace`](../lib/services/feed_load_trace.dart) owns the first-wins
completion behavior.

Only **distributed release** builds report them. `PerformanceMonitoringService`
gates on `kReleaseMode` in Dart, debug/profile builds are additionally
deactivated natively, and since #7302 a release build must also carry the
Shorebird engine (`shorebird release`) or a Zapstore installer — so a local
run, `flutter run --release` included, produces no samples at all and that is
not a bug. Opting one run back in takes every half of the recipe in
[Network performance monitoring](NETWORK_PERFORMANCE_MONITORING.md#verifying-a-change) —
any one alone leaves collection off.

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

`timeout` also undercounts, because the 30-second fuse is keyed by
`SubscriptionType` rather than by load: starting a load of a given type cancels
the previous load's fuse, and the handler additionally does nothing if the
subscription it belongs to is no longer the active one. That is normally
harmless, since a replacing load completes the one it replaced as `cancelled`.
It is not harmless where loads of one type run concurrently —
`HashtagService.subscribeToHashtagVideos` passes `replace: false` so several
hashtag subscriptions can be live at once. The earlier load loses its fuse and
stays pending until unsubscribe or teardown, reporting `cancelled` or
`disposed`. So `timeout` is a floor on 30-second stalls, not a count of them.

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
`done`, and `setup_error` as unsuccessful terminal outcomes. Count all five;
none of them belongs in successful-load latency percentiles.

Their *durations* split, though. `cancelled`, `error`, `done` and `setup_error`
are reported where the load ends, so the duration is the load's own and is
worth reading. `disposed` is reported by `dispose()` sweeping whatever is still
pending, and its provider is `keepAlive`, so that fires at container
teardown — the duration is "from this load's start until the app tore down",
bounded by session length rather than by anything about the load. Chart
`disposed` as a count, never as a latency.

## Separating cache work from relay waiting

The existing `feed_load_*` traces now carry consecutive phase metrics. Their
start, first-wins completion, and `event_count` semantics are unchanged.

| Metric | Work measured |
| --- | --- |
| `cache_read_ms` | Trace start through the cached-event read returning, including database availability, query, and row-to-event conversion |
| `cache_ingest_ms` | Processing returned events and notifying listeners, or advancing to relay setup when the cache is empty |
| `relay_wait_ms` | Relay subscription setup through the first terminal milestone, only when cache completion has not already won |

`terminal_phase` names the metric active when the load ended. Cancellation,
disposal, timeout, and errors record the unfinished phase's elapsed time too.
Missing metrics mean a phase was never reached, not zero duration. Work after
completion cannot add metrics to a stopped trace.

In Firebase Performance, select the build and a single `completion` first.
For a slow `cache` sample, compare `cache_read_ms` with `cache_ingest_ms`. For a
slow `first_relay_event` or `eose_empty` sample, also inspect `relay_wait_ms`.
Inspect abandonment counts separately; their partial phases are not successful
load latencies. Relay waiting includes client setup, transport, server work,
and delivery back to Dart; it is not a server query timer.

## Watch-history initialization and feed waits

For You and other repository paths that order videos by freshness wait for
`SeenVideosService` through `SeenVideoLookup`. Two additional Performance traces
separate initializing history from the wait experienced by a feed caller.

### `seen_videos_initialize`

One trace per actual initialization attempt. Concurrent callers share that
attempt, and already-initialized calls do not emit another initialization trace.

| Metric | Work measured |
| --- | --- |
| `preferences_ms` | Obtaining SharedPreferences |
| `preferences_decode_ms` | Reading and decoding saved metrics or legacy IDs and building their in-memory maps |
| `legacy_migration_ms` | Saving the legacy ID list as metrics and removing the old key, when needed |
| `database_read_ms` | Awaiting all stored seen rows, including database opening, queueing, query execution, and row materialization |
| `database_merge_ms` | Merging returned rows into the in-memory history |
| `database_migration_ms` | Copying preference metrics into the database and recording the migration marker, when needed |
| `migration_marker_ms` | Writing only the migration marker when database rows already exist |

`database_rows`, `seen_count`, `metrics_count`, and `preferences_json_chars`
provide size context without recording IDs or history contents. The last metric
counts string code units, not UTF-8 bytes. Background pruning is unawaited and
excluded from the phase breakdown.

Filter `storage` to `database` or `preferences`. `completion=success` means the
restore completed without a caught error; `partial` means the existing fallback
continued after a decode/read/migration failure; `error` means initialization
did not finish normally. `failed_phase` classifies caught failures without
including exception text. Partial restore still preserves the service's existing
ready/fallback behavior; this instrumentation does not change recovery policy.

### `feed_wait_seen_history`

One trace for each caller that reaches freshness ordering before history is
initialized. `wait_ms` measures that caller's wait, which may overlap the
initialization trace and other callers' waits. Do not add those durations.
Already-ready callers emit no wait trace, so these samples cannot establish the
percentage of all feed loads that waited. `initialization_state` is `not_started`
or `in_progress`; `completion` is `ready` or `not_ready` on return. A partial
restore can still be ready: consult the initialization trace for restore errors.

If wait times are high, compare initialization's database-read, decode, merge,
and migration metrics within the same build and device cohort. A large
`database_read_ms` identifies the database boundary, but cannot distinguish SQL
execution from opening or queueing without an on-device database profile.
A large decode/merge phase points toward processing local history. These traces
do not carry a per-feed correlation ID and do not time the recommendation HTTP
request; use the existing HTTP metrics and first-visible/fresh-result Analytics
events for those boundaries.

All phase durations use a monotonic stopwatch and include elapsed async waits;
they are neither CPU-time nor foreground-only measurements. The existing
distributed-release collection gate and Firebase sampling still apply. No
native reporting future is awaited by history initialization or feed completion.
No new account identifiers, video IDs, request URLs, or history contents are
included in these traces.

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
