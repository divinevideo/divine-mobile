# Investigating idle memory and native playback

The existing RSS sampler also requests a versioned, process-wide Apple snapshot
from `divine_video_player`. It runs on the existing 30-second cadence, at startup,
on Flutter lifecycle changes, and after OS memory-pressure notifications. This
does not change playback, caching, scheduling, or resource disposal.

## Measurements

- `mem_footprint_mb`: current `TASK_VM_INFO.phys_footprint`. Compare this with
  Activity Monitor's physical footprint, not with Dart heap usage.
- `mem_footprint_sampled_peak_mb`: maximum **sampled** footprint since this
  observer started. It can miss between-sample spikes; it is not an OS peak.
- Existing `mem_rss_mb` and `mem_peak_mb`: resident memory and OS RSS high-water
  mark. Footprint includes compressed memory that RSS does not.
- `mem_native`: JSON containing status, platform (`ios`, `ios_on_mac`, `macos`),
  native app state, registered players, weakly tracked live instances, owned
  AVQueuePlayers, playing players, attached textures, pending clip loads,
  disposed instances still owning players, and cumulative texture frames.
  Counts cover all engines, not just the Dart isolate. They measure ownership,
  not every retained AVFoundation allocation. Platform-view frames are excluded.
- `mem_lifecycle`: Flutter state, foreground gate, time in that state, observer
  age, trigger, memory-pressure count, and frame delta/sample interval when
  comparable. Observer age is not OS process uptime and resets when the root
  app is recreated. Native `inactive` is not synonymous with hidden.

`Memory native:` local logs pair these with Dart RSS, controller, image-cache,
and ingestion gauges. The old `vc_native` key is the **Dart-side** controller
count. Compare it with independent native counts, but do not assume equality
across multiple engines. Lifecycle breadcrumbs are immediate; a sample that
straddles a Flutter lifecycle transition is discarded. The next tick provides
a fresh reading. Frame deltas indicate work between observations, not proof
that all those frames occurred in the background.

## Crashlytics behavior and limits

Four new fixed keys limit consumption of the reporter's key budget. Aggregate scalars
are allow-listed; account IDs, media URLs, labels, raw exceptions, and exported
logs never enter these fields. Failed/unsupported/timed-out readings overwrite
current gauges with `unavailable`, never zero; the sampled peak remains
historical. Waiting times out after two seconds, but no more native reads start
until the original request settles. There are no new periodic timers or sample
queues.

`PlaybackResourceInvariantException`, reason
`native_player_resources_after_dispose`, is recorded at most once per observer
lifetime, after at least two observations spanning 30 seconds show disposed
instances owning AVQueuePlayers with no pending clip loads. A healthy,
unavailable, or loading sample resets the grace period. Keys are written before
the non-fatal. Its stack identifies the detector, not the allocation site.

High memory alone is not reported as a leak. Crashlytics is not a continuous
memory dashboard: keys/breadcrumbs attach to reports, and OS memory kills may
not produce one. Use local logs and Instruments too. Existing crash-reporting
collection policy is unchanged.

## Reproduce and diagnose

1. Use a native build containing this change. A Dart-only patch cannot add Apple
   gauges to an older binary; it reports `unavailable`. Reproduce on the same
   runtime: iOS-on-Mac and native macOS are not interchangeable.
2. Record app/build/OS versions. After a fresh launch, browse a fixed number of
   videos, then leave the window visible but unfocused, hide it, and minimize
   it as separate cases. Note transition times and wait several sampling
   intervals. Do not foreground the app to collect a background CPU sample.
3. Export logs and compare footprint, RSS, native counts, pending loads, OS and
   Flutter state, foreground gate, and frame deltas. A plateau differs from
   growth after repeated identical browse/hide cycles.
4. If footprint grows while Dart/image gauges stay flat, use Instruments
   Allocations and VM Tracker to distinguish heap growth from IOSurface/decoder
   buffers. Compare memory graphs before/after the same action. For a disposal
   invariant, inspect clip-load completion versus native disposal.
5. Validate a behavioral fix with the same sequence and regression tests. One
   footprint measurement or CPU sample cannot establish the memory's owner.

## Verification

From `mobile/`, run the memory telemetry/pressure and app lifecycle tests.
From `mobile/packages/divine_video_player`, run `flutter test --coverage`.
From the repository root on macOS, with `FLUTTER_ROOT` set and
`flutter precache --ios --macos` complete:

```sh
bash mobile/packages/divine_video_player/darwin/test_diagnostics.sh
```

The package's Apple CI job executes weak-lifetime/ownership/footprint tests and
typechecks the complete plugin for macOS and the iOS simulator. Instruments
captures on the affected runtime remain necessary to attribute memory growth.

References: [Apple memory analysis](https://developer.apple.com/documentation/xcode/analyzing-the-memory-usage-of-your-metal-app)
and [Crashlytics reporting limits](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports).
