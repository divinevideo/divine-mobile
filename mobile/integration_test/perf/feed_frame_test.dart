// ABOUTME: #9045 — captures real UI (build) and raster frame times while the
// ABOUTME: fullscreen feed plays and animates between pages on the device under
// ABOUTME: test, so budget-Android jank can be measured before any fix.
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
// section of the perf lane's emulator dump, or `adb logcat -s flutter` on the
// device.

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'feed_perf_fixtures.dart';

/// Minimum frames a measured window must render for its statistics to mean
/// anything. A window that fell silent is a harness failure, not a fast feed.
const int _minFramesPerWindow = 30;

/// Ceiling for the p90 UI-thread (build) frame time. Build is CPU-bound and
/// device-relative; this is a catastrophic-regression guard, not the budget
/// under investigation. Raster is reported, not gated: on an emulator it is
/// software-rendered and not comparable to the budget hardware the report
/// ([#9045]) is about.
const double _maxBuildP90Ms = 50;

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
    final build = timings.map((t) => ms(t.buildDuration)).toList()..sort();
    final raster = timings.map((t) => ms(t.rasterDuration)).toList()..sort();
    double p(List<double> xs, double q) =>
        xs.isEmpty ? 0 : xs[(xs.length * q).floor().clamp(0, xs.length - 1)];

    return _WindowStats._(
      label: label,
      frames: timings.length,
      buildP50Ms: p(build, 0.5),
      buildP90Ms: p(build, 0.9),
      rasterP50Ms: p(raster, 0.5),
      rasterP90Ms: p(raster, 0.9),
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
      '#9045 playback and page-animation frame times',
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
        // to measure the app's real scroll/playback work, not an isolated page.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InfiniteVideoFeed(
                key: feedKey,
                videos: feedPerfVideos(6),
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

        Future<_WindowStats> measure(
          String label,
          Future<void> Function() action,
        ) async {
          final raw = <FrameTiming>[];
          void callback(List<FrameTiming> timings) => raw.addAll(timings);
          binding.addTimingsCallback(callback);
          await action();
          // FrameTimings are flushed by the engine about once a second; drain
          // the tail before detaching the callback.
          await Future<void>.delayed(const Duration(seconds: 2));
          binding.removeTimingsCallback(callback);
          return _WindowStats.from(label, raw, frameBudgetMs);
        }

        final stats = <_WindowStats>[
          // Watching the active video, the "just watch a video" half of #9045.
          await measure(
            'playback',
            () => Future<void>.delayed(const Duration(seconds: 4)),
          ),
          // Page transitions exercise the scroll path and its overlay fade.
          await measure('page_animation', () async {
            for (var index = 1; index <= 3; index++) {
              await feedKey.currentState!.animateToPage(index);
            }
            await Future<void>.delayed(const Duration(seconds: 1));
          }),
        ];

        final report = StringBuffer()
          ..writeln(
            '================ #9045 FEED FRAME TIMING ================',
          )
          ..writeln(
            'device refreshRate=${refreshHz.toStringAsFixed(1)}Hz '
            'frameBudget=${frameBudgetMs.toStringAsFixed(2)}ms '
            'backend=not queryable from Dart (read logcat for the Impeller '
            'line on the device under test)',
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

        for (final window in stats) {
          expect(
            window.frames,
            greaterThan(_minFramesPerWindow),
            reason:
                '${window.label} rendered only ${window.frames} frames; the '
                'window measured nothing',
          );
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
