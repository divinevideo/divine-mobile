# User experience performance monitoring

Use this with [network coverage](NETWORK_PERFORMANCE_MONITORING.md) and
[feed trace semantics](FEED_LOAD_TRACES.md). A slow response and a failed user
operation are separate signals. Compare both, by platform and app build, before
choosing an optimization.

## Measurements

| User experience | Trace | Measurement and boundary |
| --- | --- | --- |
| API responsiveness | `http_operation` | `headers_ms` until response headers, `total_ms` through body completion/error/cancellation, `response_bytes`; fixed `operation`, HTTP `method`, `status`, and terminal `outcome` |
| Creator media cleanup | `creator_delete_enforcement` | Entire enabled enforcement call; `total_ms`, cumulative `signing_ms` and `http_ms`, `request_count`, `poll_count`; final `outcome` and `reason` |
| Startup bottlenecks | `startup_phase` | Custom **`elapsed_ms`**, filtered by fixed `phase`; completed phases only |
| Startup readiness | `startup_milestone` | Custom **`elapsed_ms`** from startup monitor initialization to `first_frame`, `auth_shell_ready`, `ui_ready`, or `video_ready`. `video_ready` is the first rendered native frame of any fullscreen-feed video after launch, and it also ends `startup_phase` `total` |
| Fullscreen video playback | `video_first_frame` | Custom **`ttff_ms`**, activation to rendered native first frame; `cache=hit/miss`, `position=initial/subsequent`; optional controller/source/playback milestones measured from activation |
| Feed retrieval (existing) | `feed_load_*` | First raw feed event/cache result, timeout, cancellation, and result counts; does not measure first rendered video |
| Opening the video editor | `editor_ready` | Live trace from entering the editor route until the editor is usable: it shows its clips (at once from the recorder or the Library; a draft once restored with its thumbnails and fonts) and, for video clips, the preview player loaded them and showed its first frame. `total_ms`, plus `clips_loaded_ms`, `player_ready_ms`, and `first_frame_ms` for the phases reached, and `pre_route_ms` for an editor opened with the recorder's "Next" (the wait from the tap to the route); `entry=recording/clips/draft`, `clips=0/1/2-3/4-6/7+/unknown`, `preview=video/stop_motion/none/unknown`, `outcome=ready/failed/left` |
| Opening the recorder's camera | `camera_startup` | Live trace from the recorder asking the camera to open until it is fitted to the recorder mode. `init_ms` until the camera opened (on iOS its first preview frame, on Android the attached preview surface), `mode_apply_ms` for dual-camera capture and stabilization, `total_ms`; `lens`, `quality`, `outcome=success/failed/error`, and `dual_camera=on/off` on success. A camera that does not open ends the trace at `init_ms` |
| Video preparation (existing) | `video_generation` | Video generation duration and outcome, with step `*_ms`, output and feature metrics (see below) |
| Flipping the camera or changing the lens | `camera_switch` | Live trace from the tap until the recorder shows the new camera. `switch_ms` for the native switch (on both platforms it completes on the incoming camera's first frame), `total_ms` until the frozen preview lifts; `kind=flip/lens`, `outcome=success/failed/error`, `dual_camera=on/off`, `lens` live afterwards |
| Processing a recorded take | `clip_postprocess` | Live trace per take, from the stop handing it over until its detached background work ends. `copy_ms`, `duration_ms`, `thumbnail_ms`, `ghost_frame_ms`, `library_save_ms`, and `chroma_key_bake_ms` (from the end of the enrichment until the keyed take is saved) for the steps reached, `total_ms`; `outcome=success/save_failed/superseded/error`, `chroma_key=yes/no` |
| Finishing a stop-motion session | `stop_motion_assemble` | Live trace of turning the session's stills into a clip before the editor opens. `total_ms`, `frames` (stills in the session); `outcome=success/failed`, `append=yes/no` |
| Publishing and uploads (existing) | `video_publish`, `video_upload`, `video_upload_enqueue` | Publish phase metrics and outcome; in-process transfer and OS enqueue have different populations and boundaries |
| Starting and stopping a take | `recording_start`, `recording_stop` | Live traces, one per take. `recording_start` runs from the shutter until the camera writes the take and the recorder shows it running; a countdown is excluded and reported as `countdown_ms`. `start_ms`, `sound_prep_ms`, `native_start_ms`, `wakelock_ms`; `outcome=success/failed/aborted/error`, `sound=on/off`. `recording_stop` runs from the stop until the camera handed over the file: `stop_ms`, `native_stop_ms`, `sound_stop_ms`, `wakelock_ms`, `take_ms`, `secondary_file`; `outcome=success/no_file/error`, `trigger=user/auto/teardown`. Both carry `mode`, `stabilization` and `dual_camera=on/off`, plus the 0/1 metrics `chroma_key` and `reaction` |
| Sound picker search | `sound_search` | **Trace duration** from the debounced query the sound picker's Newest tab sends until its relay results arrive; `outcome` = `results` or `empty` when the relays answered, `fallback` when they did not and the picker showed its cached matches instead (`reason` = `timed_out`, `no_relays` or `relay_error`), `failure`, or `abandoned` when the query, the tab or the picker changed first; `result_bucket` (`0`, `1_10`, `11_50`, `over_50`) and a `result_count` metric when it answered. Never the query text |
| Drawing smoothness per screen | `screen_frames` | One sample per visit to a traced screen: from when it shows until it closes, an opaque route covers it, another tab of the bottom navigation is selected, or the app goes to the background. `frames`, `slow_frames` (over the display's frame budget, 16.7 ms at 60 Hz and 8.3 ms at 120 Hz, on the UI or raster thread), `frozen_frames` (over 700 ms), `slow_per_mille`, `visible_ms`, `build_p90_us` (vsync to build end) and `raster_p90_us`; `screen=recorder/editor/home_feed/fullscreen_feed/explore/search/profile`, `refresh=60/90/120/other`, `end=closed/covered/tab_switch/background`. Visits under 1 s or 10 frames are dropped |

`sound_search` is a live trace, so read its duration. It runs once per query the
Newest tab sends — at most one per pause in typing — and never for the other
tabs, which search the lists they already hold. Only a relay answer counts as
`results` or `empty`. When the relay query times out, reaches no relay or
throws, the picker still lists the matches it had cached, and the trace ends
as `fallback` with the reason, so those waits stay out of the relay result
times; `result_bucket` then counts the cached matches the user saw. A
`timed_out` fallback can hold relay sounds that arrived before the deadline.
The picker's tab loads and picks are Analytics events, not traces; see
[Analytics observability](../../docs/ANALYTICS_OBSERVABILITY.md#sound-picker).

**`screen_frames` replaces Firebase's automatic frame metrics for the screens it
traces.** Those are kept per native screen, and the whole Flutter app is one
native screen, so they cannot tell the editor from the feed. They also count
every frame over 16 ms as slow, which on a 120 Hz iPhone is every frame at 60
fps. `screen_frames` judges each frame by the display's refresh rate and reports
`refresh`, so compare within it. Read its custom metrics, never the trace
duration: the trace is created when the visit ends, and `visible_ms` is the
visit's length. Dialogs and sheets are not opaque routes, so their frames count
towards the screen beneath them, as do transitions to and from it. A visit that
ends because the app went to the background reports at once and misses up to a
second of its last frames, which the engine had not reported yet.

The traced screens are fixed: `recorder` and `editor`; `home_feed`, the home
tab's feed; `fullscreen_feed`, the fullscreen player, wherever it opens: from a
grid, Classics, replies or a video link;
`explore`, Explore's tabs and grids; `search`, search and its results; and
`profile`, a profile's header and grids, the account's own or someone else's.
Tapping a video in a grid opens the fullscreen feed on top of the whole app, so
the grid's visit ends as `covered` and a new one starts when the feed closes.
Explore and the own profile can also show their feed in place of the grid when
their URL carries a video index, as a link can; then the grid's visit ends as
`closed`, and the feed starts a `fullscreen_feed` visit. The bottom navigation
keeps every tab it has shown mounted, so selecting another tab ends the visit
as `tab_switch` and coming back starts a new one; the
cross-fade between the two counts for the tab being selected. `covered` is a
route on top, pushed over the whole shell or inside the tab. The inbox,
notifications, settings and the hashtag, list and sound grids are not traced.
Frames are drawn for the whole app, so one scope never sits inside another's
trace; a debug assertion holds that. A push or pop between two traced screens
is the exception: both visits run during the transition, so its frames count
for both.

A visit has to last a second to report, so a device sends about one sample a
second at most (two visits overlap only during a transition) and in practice
one per change of screen: someone who changes screen
every 10 seconds sends 60 in 10 minutes, a fifth of the shared budget described
below. Tab hops shorter than a second send nothing.

**Startup and first-frame traces are snapshots of already measured intervals.**
Select their custom millisecond metric, never the default trace duration. Early
startup measurements are buffered by the existing startup service and exported
once after Firebase initialization. The playback observer subscribes once at the
app root and cancels with its provider container. It emits once per completed
video activation, not once per rendered frame.

**The recorder traces are live traces, emitted once per user action.** Read
their duration or `total_ms`, the same span measured in Dart. Until this
release `camera_startup` ended when the camera opened; it now ends once the
recorder has fitted the camera to its mode, so compare `init_ms` across that
boundary, not the trace duration. Startups that fail or throw still end when
the camera returns. `clip_postprocess` measures work that is detached from the
stop, so a slow sample never held up the next take, and its
`chroma_key_bake_ms` includes any time the bake was held back while the next
take recorded. Picking the lens that is already live emits no `camera_switch`.
One sample per startup, switch, take or assemble adds little to the shared
event budget described below.

**`editor_ready` is a live trace, emitted once per editor open.** It starts in
the editor screen's first build and stops at the first terminal outcome, so its
duration is the wait; `total_ms` is the same span measured in Dart, without the
trace start's platform round-trip, and the phase metrics share that start. By
the boundary the play button works, the timeline has started loading its
thumbnails, and the preview no longer shows a still poster. A stop-motion
composition has no preview player and is ready once its clips show, so compare
within `preview`. `failed` is a draft that could not be restored or a first clip
load the player rejected; `left` is a close before either, including during a
draft load, when `clips` is still `unknown`. Reloads after the editor is ready (trim,
reorder, speed) are not measured.

**`video_generation` is a live trace, emitted once per final render from the
editor.** It runs from the start of the render until its outcome is known and
the draft is saved. `outcome` is `success`, `stale` (the render finished but the
edit changed while it ran, so the editor threw the video away and, while Post
details still waits, rendered again under its own trace), `incomplete` (a newer render
replaced it, or it was cancelled, for example because the user left Post
details), `failed` or `error`, with
`failure_reason`, `clip_count` and `aspect_ratio`. Each step that ran
reports its milliseconds, so an absent step metric means the step did not
happen: `chroma_bake_ms` (keying takes recorded with the color mask),
`assembly_ms` (stop-motion stills to video, summed over clips), `render_ms`
(preparing the render, such as fetching sounds, and every native pass),
`metadata_ms`, `proof_ms` (C2PA and ProofMode signing of the recordings left
unsigned at capture, then of the output) and `cover_ms`. A
render that reached its end also reports `output_duration_ms`, `output_width`,
`output_height` and `output_bytes` (read after signing), so render time per
second of video can be compared across devices. The features it used are 0/1
metrics rather than attributes, since a trace takes five attributes:
`has_text`, `has_filter`, `has_adjustment`, `has_effect`, `has_audio_track`,
`has_speed_change`, `has_reverse`, `has_chroma_key` and `has_stop_motion`, plus
`layer_count`. The renders of a draft published from the Library and of a
background publish retry are not measured.

The HTTP classifier has a finite vocabulary. It separates `creator_delete`,
`creator_delete_status`, and `moderation_lookup`, plus feed/video, profiles,
notifications, search, comments, discovery, login/signing, names, and media.
Unknown paths fall into `other` or a known service's `*_other` group. No new
custom field contains an event ID, pubkey, username, URL, search term, token,
response body, or exception message. Existing network metrics retain their URL
normalization policy. Third-party hosts remain excluded.

HTTP `outcome` is `success` for 2xx/3xx with a completely consumed body,
`http_error` for other statuses, `transport_error` before headers, `body_error`
for a failed response stream, or `cancelled` for a cancelled subscription.
A 202 is HTTP success; it does not prove deletion completed.

Deletion `outcome` is `confirmed`, `delayed`, or `failed`. Disabled enforcement
makes no request and emits no trace. `reason` distinguishes observed HTTP errors,
missing signing capability, signing or HTTP timeout/transport failure, exhausted
polling, and unexpected exceptions. `response` means a response was received;
interpret it alongside `outcome`. Signing time includes any human approval wait.
`http_ms` is cumulative time after signing across requests, including response
reading; polling backoff contributes to `total_ms`. This does not change timeout,
retry, signing, deletion, or UI behavior. Telemetry completion is not awaited by
the user operation, and new trace failures are contained.

## Reports and release comparisons

The SQL in `scripts/performance/` reads the existing iOS and Android Firebase
Performance export. It returns aggregated rows and accepts inclusive named DATE
parameters. From `mobile/`, for example:

```bash
bq query --use_legacy_sql=false --dry_run \
  --maximum_bytes_billed=2000000000 \
  --parameter=start_date:DATE:2026-09-08 \
  --parameter=end_date:DATE:2026-09-14 \
  < scripts/performance/freshness.sql
```

Remove `--dry_run` to execute. Substitute the report filename and dates. Keep
query results in credentialed tooling; do not commit/export production rows to
public issues or PRs.

1. **`freshness.sql` first:** shows the latest exported event/partition for each
   platform, age, and whether any event reaches the requested final day. Reaching
   that day does not prove that day is complete. Exports are daily; use the live
   Firebase console and server logs for a current incident.
2. **`network.sql`:** separates deletion POST, deletion status polling, and
   moderation lookup for existing builds. Shows sample counts, status classes,
   success ratio, p50/p90/p99, and separate successful/404 p90. A historical
   catch-all URL cannot be reconstructed into a specific endpoint.
3. **`outcomes.sql`:** one `DURATION_TRACE` row per recorded operation, grouped
   by build, operation, editor entry and preview, outcome, and deletion reason.
   Outcome shares use the completed trace population, not the number of custom
   metric rows.
4. **`custom-metrics.sql`:** measured startup/playback/HTTP/deletion/publishing/
   editor metrics, with sample counts and p50/p90/p99. Millisecond metric names
   end in `_ms`; count and byte metrics retain their own units.

Compare candidate and previous builds over the same complete date range, within
platform, operation, outcome, startup phase/milestone, and cache state. Do not
average percentiles. Investigate regressions using the console's device, OS, and
network filters to distinguish changed user populations from code regressions.
The reports flag groups below 100 samples as insufficient for a routine release
comparison; rare deletion failures still warrant investigation individually in
credentialed server tooling. A useful initial review trigger is a 25% p90 timing
regression in adequately sampled comparable cohorts or an increased delayed/
failed share. This is a review heuristic, not an established service objective.

Queries prune ingestion partitions to the requested dates plus seven days for
late uploads and also filter event dates in `America/Los_Angeles` to match the
console. Data arriving more than seven days late is excluded. Firebase sampling,
rate limits, incomplete exports, and operations interrupted by process death
mean these are observed samples, not exact request counts or completion rates.
See [Emission rate, shared limits, and release decision](#emission-rate-shared-limits-and-release-decision)
for what volume these traces add and how the two new populations are bounded.

## Emission rate, shared limits, and release decision

The two new custom traces are emitted at a fixed, bounded rate:

- **`http_operation`** — exactly one `DURATION_TRACE` per instrumented request,
  and only when the matching `NETWORK_REQUEST` metric was accepted
  (`PerformanceHttpClient` returns the inner response untouched when the
  recorder's `start` returns null). The population is therefore the same one
  the app already sends through `FirebaseHttpMetricRecorder`; the custom trace
  adds a sibling code trace per network request, not a new request event.
- **`video_first_frame`** — exactly one `DURATION_TRACE` per completed
  fullscreen-feed activation, i.e. per distinct active video that reached a
  rendered native first frame. It is not per rendered frame, per buffering
  event, or per cached byte.

Neither trace is emitted per frame, per chunk, or per video byte, and
third-party hosts stay excluded (see
[Network performance monitoring](NETWORK_PERFORMANCE_MONITORING.md)).

### Absolute emission rate is not recorded in this repository

There is no checked-in measurement of instrumented requests per user or per
session, so this document does not state one. The inputs exist and can be
measured before or after rollout:

- The pre-rollout request rate is the `NETWORK_REQUEST` count for the
  instrumented hosts over a build and date range. `scripts/performance/network.sql`
  reports it for the moderation host today; the same query extended to the
  other hosts in `NETWORK_PERFORMANCE_MONITORING.md` gives the full population.
- The activation rate is the completed `FeedFirstFrameMetric` count, observable
  locally from the `FeedFirstFrame` logger and the feed TTFF harness
  ([Network performance monitoring](NETWORK_PERFORMANCE_MONITORING.md)).
- After rollout, `outcomes.sql` reports the `http_operation` sample count per
  build and operation. Comparing that with the matching `NETWORK_REQUEST` count
  is how to tell whether Firebase retained the population or sampled it down.

### Effect on the existing performance traces

Firebase sets no per-trace quota. Custom code traces and network request traces
share one per-device budget — currently 300 events every 10 minutes — and one
app-wide daily dynamic-sampling rate delivered through Remote Config; projects
with the BigQuery export get a higher limit for network request traces. Firebase
may also drop events server-side. The `http_operation` trace therefore draws
from the same budget the existing `feed_load_*`, `video_publish`,
`camera_startup`, and network metrics already use. Trace names cannot collide,
but a device that reaches the shared cap has its excess dropped across trace
names, so the busiest devices can see lower sample counts for existing traces
once this ships. This is a sample-count cost, not a latency or behavior cost:
nothing on the user path waits for these traces, and `PerformanceOperation`
contains monitor failures and is never awaited.

### Release decision

Ship enabled, under the same gates as every other performance trace: release
mode only and distributed builds only (Shorebird engine or a Zapstore
installer), with debug and profile excluded both natively and in Dart. No
separate sampler is added. The `http_operation` trace is 1:1 with a network
metric that already ships unsampled; Firebase's on-device rate limit and
dynamic sampling already bound the volume; and a second sample rate would
decouple the custom trace from the network metric the reports compare it
against.

The safeguard is the comparison above plus a rollback that needs no store
release: the per-request trace lives entirely in
`mobile/lib/observability/network/performance_http_client.dart`, so sampling or
removing it is a Dart-only change that Shorebird can push
([Shorebird code push](SHOREBIRD_CODE_PUSH.md)). If `outcomes.sql` shows
`http_operation` samples collapsing against the matching `NETWORK_REQUEST`
count on a platform, or an existing trace's sample count falling after this
ships, that is the signal to push the gate.

## Firebase dashboard and alerts

New traces appear after a distributed release is installed and sends samples.
Debug/profile and non-distributed local builds retain the current collection
exclusions. Add `creator_delete_enforcement` to the custom trace dashboard and
filter outcome/reason. For `http_operation`, filter operation, method, status,
and outcome before interpreting latency. Add the startup `elapsed_ms` and video
`ttff_ms` custom metrics to the dashboard.

For stable Network Requests rows, configure these custom URL patterns for both
apps in Firebase Performance:

```text
moderation-api.divine.video/api/delete/*
moderation-api.divine.video/api/delete-status/*
moderation-api.divine.video/check-result/*
```

Verify actual matching after rollout. Add response-time and success-rate alerts
on each URL pattern, using a representative baseline for that operation. Never
combine deletion and moderation lookup into one latency target. Keep 404s visible
as failures; do not redefine success to hide delayed enforcement. The custom
operation traces remain useful even before URL patterns are configured.

Firebase's documented custom trace alerts evaluate **trace duration**; they must
not be used as startup/TTFF alerts on the snapshot traces. Use the custom metrics
report for those measurements. Firebase alert sample requirements can suppress
alerts for rare deletion traffic, so inspect delayed outcomes and server retry
logs even if no Firebase alert fires.

The repository change does not install console URL patterns, alerts, scheduled
queries, or deploy code. The available Firebase MCP exposes project/Crashlytics
tools but no Performance configuration or reporting tools. The report SQL can
be validated/run with authenticated `bq`; console settings require console
access. Production server diagnostics live in `divine-moderation-service`;
its deletion monitoring runbook describes the corresponding stage/retry logs.

## Validation and known gaps

Exercise a confirmed deletion, missing-event 404, accepted deletion with polling,
signing timeout, HTTP failure, response stream cancellation, cold launch, and
cached/uncached video activation. Verify unchanged user-facing outcomes and one
terminal sample per completed operation. Compare emitted startup/playback custom
metrics with the existing local measurements, not with snapshot trace duration.

Playback samples only cover successfully rendered first frames from the existing
fullscreen-feed event bus. They do not establish playback success rate, rebuffer
frequency, abandoned activations, background playback, or native image latency.
Feed/search/profile HTTP metrics measure retrieval, not every screen's time to
usable content. Native screen frame ratios cover the
whole Flutter app, so they are not per-route jank measurements; `screen_frames`
is, for the screens listed above only. Existing
publish phase metrics cover the wider publish flow; `video_upload_enqueue`
measures OS handoff, not transfer completion. WebSocket relay traffic is outside
Dart HTTP instrumentation.

References: [custom trace metrics and limits](https://firebase.google.com/docs/perf-mon/custom-code-traces),
[alert behavior and configuration](https://firebase.google.com/docs/perf-mon/alerts),
[BigQuery export and console timezone](https://firebase.google.com/docs/perf-mon/bigquery-export),
[custom URL patterns](https://firebase.google.com/docs/perf-mon/custom-url-patterns).
