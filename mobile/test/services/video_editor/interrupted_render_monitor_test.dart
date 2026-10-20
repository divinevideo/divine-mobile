// ABOUTME: Tests the render markers that outlive a process killed mid-render
// ABOUTME: and the report the next launch files for each of them (#9872)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_editor/interrupted_render_monitor.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
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

/// Runs [onCancel] where the native cancel would reach the platform.
class _FakeProVideoEditor extends ProVideoEditor {
  _FakeProVideoEditor({required this.onCancel});

  final void Function(String taskId) onCancel;

  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<void> cancel(String taskId) async => onCancel(taskId);
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
  // Lifecycle changes reach the markers through the widgets binding.
  TestWidgetsFlutterBinding.ensureInitialized();

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

    Map<String, Object?> decodeMarker(File file) =>
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

    Map<String, Object?> readOnlyMarker() {
      final files = markerFiles();
      expect(files, hasLength(1));
      return decodeMarker(files.single);
    }

    /// The marker of the running render of [taskId].
    Map<String, Object?> readMarker(String taskId) {
      // Markers are named `<microseconds>_<sanitized task id>.json`; anchoring
      // the whole name keeps `autosave` from matching `draft_autosave`.
      final safeId = taskId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
      final name = RegExp(
        '^[0-9]+_${RegExp.escape(safeId)}'
        r'\.json$',
      );
      return decodeMarker(
        markerFiles().singleWhere(
          (file) => name.hasMatch(file.uri.pathSegments.last),
        ),
      );
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
      String taskId = 'draft_autosave',
      Map<String, Object> details = const {'segments': 2},
    }) async {
      final started = Completer<void>();
      final render = InterruptedRenderMonitor.track(
        taskId: taskId,
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

    group('begin', () {
      test('keeps a marker on disk until it is closed', () async {
        final close = InterruptedRenderMonitor.begin(
          taskId: 'editor_layer_capture',
          kind: 'editor_layer_capture',
          details: const {'detachedClips': 3},
        );
        await pumpEventQueue();

        final marker = readOnlyMarker();
        expect(marker['kind'], equals('editor_layer_capture'));
        expect(marker['details'], equals({'detachedClips': 3}));

        close();
        await pumpEventQueue();

        expect(markerFiles(), isEmpty);
      });
    });

    group('watchdog timeout', () {
      tearDown(() => VideoRenderWatchdog.crashReporterOverride = null);

      test('lands in the marker before the timeout is reported and the '
          'native task cancelled', () async {
        final finish = Completer<String>();
        final render = await startRender(finish, taskId: 'seam');
        Map<String, Object?>? markerWhenReported;
        Map<String, Object?>? markerWhenCancelled;
        VideoRenderWatchdog.crashReporterOverride = (_, _) =>
            markerWhenReported = readMarker('seam');

        await expectLater(
          VideoRenderWatchdog.run(
            render: render,
            taskId: 'seam',
            cancelTask: (_) async => markerWhenCancelled = readMarker('seam'),
            timeout: Duration.zero,
          ),
          throwsA(isA<VideoRenderFailedException>()),
        );

        expect(
          markerWhenReported,
          containsPair('watchdogFiredAtMs', isA<int>()),
        );
        expect(
          markerWhenCancelled,
          containsPair('watchdogFiredAtMs', isA<int>()),
        );

        finish.complete('out.mp4');
        await render;
      });

      test('leaves the marker of the render beside it alone', () async {
        final finishTimedOut = Completer<String>();
        final finishBeside = Completer<String>();
        final timedOut = await startRender(finishTimedOut, taskId: 'seam-a');
        final beside = await startRender(finishBeside, taskId: 'seam-b');
        VideoRenderWatchdog.crashReporterOverride = (_, _) {};

        await expectLater(
          VideoRenderWatchdog.run(
            render: timedOut,
            taskId: 'seam-a',
            cancelTask: (_) async {},
            timeout: Duration.zero,
          ),
          throwsA(isA<VideoRenderFailedException>()),
        );

        expect(readMarker('seam-a'), contains('watchdogFiredAtMs'));
        expect(readMarker('seam-b'), isNot(contains('watchdogFiredAtMs')));

        finishTimedOut.complete('a.mp4');
        finishBeside.complete('b.mp4');
        await Future.wait([timedOut, beside]);
      });
    });

    group('native cancel', () {
      late ProVideoEditor originalProVideoEditor;

      setUp(() => originalProVideoEditor = ProVideoEditor.instance);
      tearDown(() => ProVideoEditor.instance = originalProVideoEditor);

      test('lands in the marker before the platform call and notes its '
          'return after it', () async {
        final finish = Completer<String>();
        final render = await startRender(finish, taskId: 'seam');
        Map<String, Object?>? markerAtPlatformCall;
        ProVideoEditor.instance = _FakeProVideoEditor(
          onCancel: (_) => markerAtPlatformCall = readMarker('seam'),
        );

        await VideoEditorRenderService.cancelTask('seam');

        expect(
          markerAtPlatformCall,
          containsPair('cancelRequestedAtMs', isA<int>()),
        );
        expect(markerAtPlatformCall, isNot(contains('cancelReturnedAtMs')));
        expect(
          readMarker('seam'),
          containsPair('cancelReturnedAtMs', isA<int>()),
        );

        finish.complete('out.mp4');
        await render;
      });
    });

    group('lifecycle history', () {
      late TestWidgetsFlutterBinding binding;

      setUp(() {
        binding = TestWidgetsFlutterBinding.instance;
        addTearDown(binding.resetInternalState);
      });

      void moveThrough(List<AppLifecycleState> states) =>
          states.forEach(binding.handleAppLifecycleStateChanged);

      List<String> statesIn(Map<String, Object?> marker) => [
        for (final entry in marker['lifecycleHistory']! as List<Object?>)
          (entry! as String).split('@').first,
      ];

      test(
        'records each change the app goes through while rendering',
        () async {
          final finish = Completer<String>();
          final render = await startRender(finish);

          moveThrough(const [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]);

          expect(
            statesIn(readOnlyMarker()),
            equals(['resumed', 'inactive', 'hidden', 'paused']),
          );

          finish.complete('out.mp4');
          await render;
        },
      );

      test('keeps the last five states', () async {
        final finish = Completer<String>();
        final render = await startRender(finish);

        moveThrough(const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]);

        expect(
          statesIn(readOnlyMarker()),
          equals(['hidden', 'paused', 'hidden', 'inactive', 'resumed']),
        );

        finish.complete('out.mp4');
        await render;
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

    test('names the lifecycle changes and the last things done to the '
        'render', () {
      final summary = summarizeMarker(const {
        'kind': 'video',
        'elapsedMs': 119751,
        'lifecycle': 'resumed',
        'lifecycleHistory': ['resumed@0', 'inactive@2140', 'resumed@2610'],
        'watchdogFiredAtMs': 119750,
        'cancelRequestedAtMs': 119751,
        'details': {'segments': 2},
      });

      expect(
        summary,
        equals(
          'kind=video elapsedMs=119751 lifecycle=resumed '
          'lifecycleHistory=resumed@0,inactive@2140,resumed@2610 '
          'watchdogFiredAtMs=119750 '
          'cancelRequestedAtMs=119751 segments=2',
        ),
      );
    });

    test('names when the native cancel came back', () {
      final summary = summarizeMarker(const {
        'kind': 'video',
        'elapsedMs': 4310,
        'cancelRequestedAtMs': 4012,
        'cancelReturnedAtMs': 4013,
        'details': {'segments': 1},
      });

      expect(
        summary,
        equals(
          'kind=video elapsedMs=4310 cancelRequestedAtMs=4012 '
          'cancelReturnedAtMs=4013 segments=1',
        ),
      );
    });
  });
}
