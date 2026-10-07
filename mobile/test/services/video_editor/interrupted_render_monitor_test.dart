// ABOUTME: Tests the render markers that outlive a process killed mid-render
// ABOUTME: and the report the next launch files for each of them (#9872)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_editor/interrupted_render_monitor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _RecordingCrashReporter implements CrashReporter {
  final reports = <({Object error, String? reason})>[];

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    reports.add((error: error, reason: reason));
  }
}

/// The first 24 bytes of a PNG of [width] x [height]: all the monitor reads.
Uint8List _pngHeader(int width, int height) {
  List<int> uint32(int value) => [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
  return Uint8List.fromList([
    ...[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ...uint32(13),
    ...ascii.encode('IHDR'),
    ...uint32(width),
    ...uint32(height),
  ]);
}

const int _mb = 1024 * 1024;

void main() {
  group(InterruptedRenderMonitor, () {
    late Directory markers;
    late _RecordingCrashReporter reporter;
    late int? footprintBytes;

    final originalDirectory = InterruptedRenderMonitor.markerDirectory;
    final originalFootprint = InterruptedRenderMonitor.readFootprintBytes;
    final originalLifecycle = InterruptedRenderMonitor.readLifecycleState;
    final originalInterval = InterruptedRenderMonitor.sampleInterval;
    final originalReporter = InterruptedRenderMonitor.crashReporter;

    List<File> markerFiles() =>
        markers.listSync().whereType<File>().toList(growable: false);

    Map<String, Object?> readOnlyMarker() {
      final files = markerFiles();
      expect(files, hasLength(1));
      return jsonDecode(files.single.readAsStringSync())
          as Map<String, Object?>;
    }

    setUp(() async {
      markers = Directory.systemTemp.createTempSync('render_markers_');
      reporter = _RecordingCrashReporter();
      footprintBytes = 900 * _mb;
      InterruptedRenderMonitor.markerDirectory = () async => markers;
      InterruptedRenderMonitor.readFootprintBytes = () async => footprintBytes;
      InterruptedRenderMonitor.readLifecycleState = () => 'resumed';
      // Long enough that the periodic refresh never fires on its own, so each
      // test decides when a sample is taken.
      InterruptedRenderMonitor.sampleInterval = const Duration(hours: 1);
      InterruptedRenderMonitor.crashReporter = reporter;
      await InterruptedRenderMonitor.initialize();
    });

    tearDown(() {
      InterruptedRenderMonitor.resetForTesting();
      InterruptedRenderMonitor.markerDirectory = originalDirectory;
      InterruptedRenderMonitor.readFootprintBytes = originalFootprint;
      InterruptedRenderMonitor.readLifecycleState = originalLifecycle;
      InterruptedRenderMonitor.sampleInterval = originalInterval;
      InterruptedRenderMonitor.crashReporter = originalReporter;
      if (markers.existsSync()) markers.deleteSync(recursive: true);
    });

    /// Starts a render that runs until [finish] completes, and returns once
    /// its marker has been written.
    Future<Future<String>> startRender(
      Completer<String> finish, {
      Map<String, Object> details = const {'segments': 2},
    }) async {
      final started = Completer<void>();
      final render = InterruptedRenderMonitor.track(
        taskId: 'draft_autosave',
        kind: 'video',
        details: details,
        operation: () {
          started.complete();
          return finish.future;
        },
      );
      await started.future;
      // Lets the first footprint sample land in the marker.
      await pumpEventQueue();
      return render;
    }

    group('track', () {
      test('keeps a marker on disk while the render runs', () async {
        final finish = Completer<String>();
        final render = await startRender(finish);

        final marker = readOnlyMarker();
        expect(marker['kind'], equals('video'));
        expect(marker['details'], equals({'segments': 2}));
        expect(marker['footprintMb'], equals(900));
        expect(marker['lifecycle'], equals('resumed'));

        finish.complete('out.mp4');
        await render;
      });

      test('deletes the marker once the render completes', () async {
        final finish = Completer<String>();
        final render = await startRender(finish);
        expect(markerFiles(), hasLength(1));

        finish.complete('out.mp4');

        expect(await render, equals('out.mp4'));
        expect(markerFiles(), isEmpty);
      });

      test('deletes the marker when the render fails', () async {
        final finish = Completer<String>();
        final render = await startRender(finish);
        expect(markerFiles(), hasLength(1));

        finish.completeError(StateError('native render failed'));

        await expectLater(render, throwsStateError);
        expect(markerFiles(), isEmpty);
      });

      test('records the footprint the render climbs to', () async {
        final finish = Completer<String>();
        final render = await startRender(finish);

        footprintBytes = 2800 * _mb;
        await InterruptedRenderMonitor.sampleActiveRendersForTesting();
        footprintBytes = 1500 * _mb;
        await InterruptedRenderMonitor.sampleActiveRendersForTesting();

        final marker = readOnlyMarker();
        expect(marker['startFootprintMb'], equals(900));
        expect(marker['peakFootprintMb'], equals(2800));
        expect(marker['footprintMb'], equals(1500));
        expect(marker['samples'], equals(3));

        finish.complete('out.mp4');
        await render;
      });

      test(
        'runs the render unmarked before the monitor knows its folder',
        () async {
          InterruptedRenderMonitor.resetForTesting();

          final result = await InterruptedRenderMonitor.track(
            taskId: 'draft_autosave',
            kind: 'video',
            details: const {},
            operation: () async {
              expect(markerFiles(), isEmpty);
              return 'out.mp4';
            },
          );

          expect(result, equals('out.mp4'));
        },
      );

      test('runs the render when its marker cannot be written', () async {
        // A file where the folder should be makes every marker write fail.
        final blocked = File('${markers.path}/blocked')..writeAsStringSync('');
        InterruptedRenderMonitor.resetForTesting();
        InterruptedRenderMonitor.markerDirectory = () async =>
            Directory(blocked.path);
        await InterruptedRenderMonitor.initialize();

        final result = await InterruptedRenderMonitor.track(
          taskId: 'draft_autosave',
          kind: 'video',
          details: const {},
          operation: () async => 'out.mp4',
        );

        expect(result, equals('out.mp4'));
      });
    });

    group('initialize', () {
      test('reports and deletes a marker a previous session left', () async {
        File('${markers.path}/1_draft_autosave.json').writeAsStringSync(
          jsonEncode({
            'session': 'a-process-that-died',
            'kind': 'video',
            'elapsedMs': 1800,
            'samples': 8,
            'startFootprintMb': 1010,
            'footprintMb': 2950,
            'peakFootprintMb': 2950,
            'lifecycle': 'resumed',
            'details': {'imageLayers': 21, 'audioTracks': 3},
          }),
        );

        await InterruptedRenderMonitor.initialize();

        expect(reporter.reports, hasLength(1));
        final report = reporter.reports.single;
        expect(
          report.reason,
          equals('render interrupted by process termination'),
        );
        expect(
          report.error,
          isA<InterruptedRenderException>().having(
            (e) => e.summary,
            'summary',
            allOf(
              contains('kind=video'),
              contains('elapsedMs=1800'),
              contains('startFootprintMb=1010'),
              contains('peakFootprintMb=2950'),
              contains('imageLayers=21'),
              contains('audioTracks=3'),
            ),
          ),
        );
        expect(markerFiles(), isEmpty);
      });

      test('leaves a render still running in this process alone', () async {
        final finish = Completer<String>();
        final render = await startRender(finish);

        await InterruptedRenderMonitor.initialize();

        expect(reporter.reports, isEmpty);
        expect(markerFiles(), hasLength(1));

        finish.complete('out.mp4');
        await render;
      });

      test('reports an unreadable marker once and removes it', () async {
        File('${markers.path}/1_torn.json').writeAsStringSync('{"session"');

        await InterruptedRenderMonitor.initialize();
        await InterruptedRenderMonitor.initialize();

        expect(reporter.reports, hasLength(1));
        expect(
          reporter.reports.single.error,
          isA<InterruptedRenderException>().having(
            (e) => e.summary,
            'summary',
            equals('unreadable marker'),
          ),
        );
        expect(markerFiles(), isEmpty);
      });
    });
  });

  group('describeVideoRender', () {
    test('counts what the native render will have to hold', () {
      final details = describeVideoRender(
        VideoRenderData(
          videoSegments: [
            VideoSegment(video: EditorVideo.file('/a.mp4'), volume: 2.5),
            VideoSegment(video: EditorVideo.file('/b.mp4'), reverseVideo: true),
          ],
          imageLayers: [
            ImageLayer(image: EditorLayerImage.memory(_pngHeader(547, 199))),
            ImageLayer(image: EditorLayerImage.memory(_pngHeader(1080, 1920))),
            ImageLayer(image: EditorLayerImage.memory(Uint8List(8))),
          ],
          audioTracks: const [
            VideoAudioTrack(path: '/voice.m4a', volume: 3),
            VideoAudioTrack(path: '/sound.m4a'),
          ],
        ),
      );

      expect(details['segments'], equals(2));
      expect(details['reversed'], equals(1));
      expect(details['maxSegmentVolume'], equals(2.5));
      expect(details['imageLayers'], equals(3));
      expect(details['largestLayer'], equals('1080x1920'));
      expect(details['layerMegapixels'], equals('2.2'));
      expect(details['unsizedLayers'], equals(1));
      expect(details['audioTracks'], equals(2));
      expect(details['maxAudioVolume'], equals(3.0));
    });
  });

  group('summarizeMarker', () {
    test('leaves out values the render never recorded', () {
      final summary = summarizeMarker(const {
        'kind': 'stop_motion',
        'elapsedMs': 40,
        'details': {'frames': 12},
      });

      expect(summary, equals('kind=stop_motion elapsedMs=40 frames=12'));
    });
  });
}
