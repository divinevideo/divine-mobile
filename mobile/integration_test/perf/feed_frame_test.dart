// ABOUTME: #9045 — captures real UI (build) and raster frame times while the
// ABOUTME: pooled feed player plays and transitions between pages on the device
// ABOUTME: under test, so budget-Android jank can be measured before any fix.
//
// Scope: this measures `InfiniteVideoFeed` — the player page, its loading
// placeholder, and the page transition. The app's item builders are supplied by
// `mobile/lib/widgets/video_feed_item/feed_videos.dart` (`videoBuilder` at
// :398, `overlayBuilder` at :507) and carry the app-layer overlay tree — the
// `ScrollFadeOverlay` group Opacity, the blurred backdrop, the action rail. It
// does NOT render that overlay tree, so a raster reading here cannot confirm or
// exonerate a change inside it; measuring those needs the full screen
// composition, not this harness.
//
// Run it against a budget Android device (the class #9045 reports) with:
//
//   python3 scripts/ci/serve_ttff_fixtures.py \
//     --directory assets/seed_media/videos --rate 625000 &
//   adb reverse tcp:8765 tcp:8765
//   flutter test integration_test/perf/feed_frame_test.dart -d <device-id> \
//     --dart-define=FEED_TTFF_BASE_URL=http://127.0.0.1:8765 --machine \
//     | tee feed_frame.jsonl
//
// Read the `FEED_FRAME window=...` lines. Build time is the UI-thread half and
// is CPU-bound; raster time is the GPU half the report's rendering path lives
// in. The Impeller backend is not queryable from Dart — read the `## impeller`
// section of this lane's emulator dump
// (`test_reports/feed_frame_emulator.txt`), or `adb logcat -s flutter` on the
// device.

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'feed_percentile.dart';
import 'feed_perf_fixtures.dart';

/// Minimum frames the playback window must render for its statistics to mean
/// anything. The window is a fixed 4 s of playback plus a ~2 s flush drain, so
/// this only catches a window that fell silent.
const int _minPlaybackFrames = 30;

/// Minimum frames each page transition must render, enforced as
/// [_pageTransitions] × this value across the whole window. The window is
/// bounded by real animation time ([_pageTransitions] × `_pageJumpDuration`
/// 300 ms), and the point of the report is the frame distribution on the
/// device under test — a device rendering the transition at 10 fps is a
/// finding, not a harness failure. Two frames per transition is enough to
/// prove the filter is keyed to the right clock; a genuinely frozen window
/// produces none. The effective floor is ~7 fps over the 1.5 s window, below
/// which the window is too sparse to report.
const int _minFramesPerTransition = 2;

/// Ceiling for the p90 UI-thread (build) frame time. Build is CPU-bound and
/// device-relative; this is a catastrophic-regression guard, not the budget
/// under investigation. Raster is reported, not gated: on an emulator it is
/// software-rendered and not comparable to the budget hardware the report
/// ([#9045]) is about.
const double _maxBuildP90Ms = 50;

/// Page transitions in the transition window. Five keeps the animating frames
/// a large share of the window when the engine flushes timings about a second
/// after they render; the window's stats are filtered to the animation
/// intervals regardless.
const int _pageTransitions = 5;

class _WindowStats {
  _WindowStats._({
    required this.label,
    required this.frames,
    required this.buildP50Ms,
    required this.buildP90Ms,
    required this.rasterP50Ms,
    required this.rasterP90Ms,
    required this.buildOverBudget,
    required this.rasterOverBudget,
  });

  factory _WindowStats.from(
    String label,
    List<FrameTiming> timings,
    double frameBudgetMs,
  ) {
    double ms(Duration d) => d.inMicroseconds / 1000.0;
    final build = timings.map((t) => ms(t.buildDuration)).toList();
    final raster = timings.map((t) => ms(t.rasterDuration)).toList();
    double p(List<double> xs, int percentile) =>
        xs.isEmpty ? 0 : feedPercentile(xs, percentile);

    return _WindowStats._(
      label: label,
      frames: timings.length,
      buildP50Ms: p(build, 50),
      buildP90Ms: p(build, 90),
      rasterP50Ms: p(raster, 50),
      rasterP90Ms: p(raster, 90),
      buildOverBudget: build.where((d) => d > frameBudgetMs).length,
      rasterOverBudget: raster.where((d) => d > frameBudgetMs).length,
    );
  }

  final String label;
  final int frames;
  final double buildP50Ms;
  final double buildP90Ms;
  final double rasterP50Ms;
  final double rasterP90Ms;
  final int buildOverBudget;
  final int rasterOverBudget;

  /// Machine-readable one-liner, mirrored by the TTFF lane's format so a budget
  /// device run can be pasted into the issue.
  String get reportLine =>
      'FEED_FRAME window=$label frames=$frames '
      'build_p50=${buildP50Ms.toStringAsFixed(2)} '
      'build_p90=${buildP90Ms.toStringAsFixed(2)} '
      'raster_p50=${rasterP50Ms.toStringAsFixed(2)} '
      'raster_p90=${rasterP90Ms.toStringAsFixed(2)} '
      'build_over=$buildOverBudget raster_over=$rasterOverBudget';

  @override
  String toString() =>
      '$label: frames=$frames build p50=${buildP50Ms.toStringAsFixed(2)}ms '
      'p90=${buildP90Ms.toStringAsFixed(2)}ms | raster '
      'p50=${rasterP50Ms.toStringAsFixed(2)}ms '
      'p90=${rasterP90Ms.toStringAsFixed(2)}ms | over-budget '
      'build=$buildOverBudget raster=$rasterOverBudget';
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('feed frame timing', () {
    testWidgets(
      '#9045 playback and page-transition frame times',
      (tester) async {
        final view = PlatformDispatcher.instance.views.first;
        final refreshHz = view.display.refreshRate;
        final frameBudgetMs = refreshHz > 0 ? 1000.0 / refreshHz : 16.67;

        // Free-run frames in real time so the native video texture keeps
        // rendering while each window is collected; a paused test clock would
        // measure nothing.
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

        final cache = installFeedPerfMediaCacheMock();
        final firstFrame = StreamIterator(FeedFirstFrameMetrics.events);
        addTearDown(firstFrame.cancel);
        final feedKey = GlobalKey<InfiniteVideoFeedState>();

        // Production defaults for the player window and prefetch: the point is
        // to measure the package's real playback work, not an isolated page.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InfiniteVideoFeed(
                key: feedKey,
                videos: feedPerfVideos(_pageTransitions + 1),
                cache: cache,
              ),
            ),
          ),
        );

        final started = await firstFrame.moveNext().timeout(
          const Duration(seconds: 15),
          onTimeout: () => false,
        );
        expect(
          started,
          isTrue,
          reason: 'no native first frame before the frame windows started',
        );

        Future<List<FrameTiming>> record(Future<void> Function() action) async {
          final raw = <FrameTiming>[];
          void callback(List<FrameTiming> timings) => raw.addAll(timings);
          binding.addTimingsCallback(callback);
          await action();
          // FrameTimings are flushed by the engine about once a second; drain
          // the tail before detaching the callback.
          await Future<void>.delayed(const Duration(seconds: 2));
          binding.removeTimingsCallback(callback);
          return raw;
        }

        // Watching the active video, the "just watch a video" half of #9045.
        final playback = await record(
          () => Future<void>.delayed(const Duration(seconds: 4)),
        );

        // Page transitions. Each interval is bounded by the frame clock the
        // engine timestamps `FrameTiming`s with, so the transition window's
        // stats cover animating frames only — the flush drain is not idle
        // playback diluted into the percentiles. The two clocks are not
        // contractually documented to share a base (`currentSystemFrameTimeStamp`
        // is "more or less arbitrary" in the SDK docs), but both derive from
        // the engine's frame timestamps on Android and the emulator run matched
        // 42 of the captured frames; if they ever diverge the filter matches
        // nothing and the frame floor below fails loudly.
        final intervals = <(int, int)>[];
        final transitionRaw = await record(() async {
          for (var index = 1; index <= _pageTransitions; index++) {
            final start = binding.currentSystemFrameTimeStamp.inMicroseconds;
            await feedKey.currentState!.animateToPage(index);
            intervals.add((
              start,
              binding.currentSystemFrameTimeStamp.inMicroseconds,
            ));
          }
        });
        final transition = transitionRaw.where((timing) {
          final at = timing.timestampInMicroseconds(FramePhase.vsyncStart);
          return intervals.any((i) => at >= i.$1 && at <= i.$2);
        }).toList();

        final playbackStats = _WindowStats.from(
          'playback',
          playback,
          frameBudgetMs,
        );
        final transitionStats = _WindowStats.from(
          'page_transition',
          transition,
          frameBudgetMs,
        );
        final stats = <_WindowStats>[playbackStats, transitionStats];

        final report = StringBuffer()
          ..writeln(
            '================ #9045 FEED FRAME TIMING ================',
          )
          ..writeln(
            'device refreshRate=${refreshHz.toStringAsFixed(1)}Hz '
            'frameBudget=${frameBudgetMs.toStringAsFixed(2)}ms '
            'backend=not queryable from Dart (read logcat for the Impeller '
            'line on the device under test)',
          )
          ..writeln(
            'scope=InfiniteVideoFeed player page and page transitions; the '
            'app-layer video/overlay builders (feed_videos.dart) are not part '
            'of this tree. Transitions run back-to-back like a fast swipe, so '
            'a late transition may composite its loading placeholder rather '
            'than video.',
          );
        for (final window in stats) {
          // Machine-readable for the retained Codemagic log artifact.
          debugPrint(window.reportLine);
          report.writeln('  $window');
        }
        report.writeln(
          '=========================================================',
        );
        // This benchmark's result is a human-readable console report.
        // ignore: avoid_print
        print(report);

        expect(
          playbackStats.frames,
          greaterThanOrEqualTo(_minPlaybackFrames),
          reason:
              'playback rendered only ${playbackStats.frames} frames; the '
              'window measured nothing',
        );
        const minTransitionFrames = _pageTransitions * _minFramesPerTransition;
        final transitionFrames = transitionStats.frames;
        expect(
          transitionFrames,
          greaterThanOrEqualTo(minTransitionFrames),
          reason: transitionFrames == 0
              ? 'page_transition matched no frames; the frame-clock filter did '
                    'not line up with the engine timings'
              : 'page_transition rendered only $transitionFrames frames across '
                    '$_pageTransitions transitions, below the '
                    '$minTransitionFrames-frame floor; the sample is too sparse '
                    'to report',
        );
        for (final window in stats) {
          expect(
            window.buildP90Ms,
            lessThanOrEqualTo(_maxBuildP90Ms),
            reason:
                '${window.label} p90 build '
                '${window.buildP90Ms.toStringAsFixed(2)}ms exceeds the '
                '$_maxBuildP90Ms ms ceiling',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
