// ABOUTME: Tests for readDmVideoPreview and readDmVideoCardFrame, read through
// ABOUTME: a mocked pro_video_editor channel.

import 'dart:async';
import 'dart:io';

import 'package:blurhash_service/blurhash_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/dm_video_preview.dart';
// Not exported from pro_video_editor's barrel. Imported by path so the test
// can subclass MethodChannelProVideoEditor without its EventChannel setup.
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';
import 'package:unified_logger/unified_logger.dart';

class _NoopInitProVideoEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
}

class _RecordingCrashReporter implements CrashReporter {
  final recorded = <({Object error, String? reason})>[];

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    recorded.add((error: error, reason: reason));
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

/// A PNG frame filled with one colour, as the native thumbnailer returns.
Uint8List _solidFrame(int red, int green, int blue) => img.encodePng(
  img.fill(
    img.Image(width: 32, height: 32),
    color: img.ColorRgb8(red, green, blue),
  ),
);

const _portraitMetadata = <String, Object>{
  'width': 1080,
  'height': 1920,
  'rotation': 0,
  'duration': 6300,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('readDmVideoPreview', () {
    const channel = MethodChannel('pro_video_editor');
    late ProVideoEditor originalProVideoEditor;
    late Directory tempDir;
    late File video;
    late Future<Object?> Function(MethodCall call) answer;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _NoopInitProVideoEditor();
      tempDir = Directory.systemTemp.createTempSync('dm_video_preview_');
      video = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(const [1, 2, 3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) => answer(call));
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('reads a blurhash of the frame and the displayed size', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[_solidFrame(255, 0, 0)],
        'getMetadata' => _portraitMetadata,
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.dimensions, equals('1080x1920'));
      final decoded = BlurhashService.decodeBlurhash(preview.blurhash ?? '');
      expect(decoded, isNotNull);
      expect(decoded!.primaryColor.r, closeTo(1, 0.05));
      expect(decoded.primaryColor.g, closeTo(0, 0.05));
      expect(decoded.primaryColor.b, closeTo(0, 0.05));
    });

    test('keeps the size when no frame can be extracted', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[],
        'getMetadata' => _portraitMetadata,
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.blurhash, isNull);
      expect(preview.dimensions, equals('1080x1920'));
    });

    test('keeps the blurhash when the size cannot be read', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[_solidFrame(0, 0, 255)],
        'getMetadata' => throw PlatformException(code: 'unreadable'),
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.blurhash, isNotNull);
      expect(preview.dimensions, isNull);
    });

    test('leaves out a size the platform reports as empty', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[_solidFrame(0, 255, 0)],
        'getMetadata' => const <String, Object>{'width': 0, 'height': 0},
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.blurhash, isNotNull);
      expect(preview.dimensions, isNull);
    });

    test(
      'tries one frame and keeps the attachment name out of logs and crash '
      'reports',
      () async {
        // A picked attachment keeps its gallery name, which can say who or
        // what is in a private video.
        final logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
        addTearDown(logCapture.clearAllLogs);
        final reporter = _RecordingCrashReporter();
        var frameAttempts = 0;
        answer = (call) async {
          if (call.method == 'getThumbnails') frameAttempts++;
          throw PlatformException(
            code: 'decode',
            message: 'cannot open ${video.path}',
          );
        };

        final preview = await readDmVideoPreview(video, reporter: reporter);

        expect(preview.blurhash, isNull);
        expect(preview.dimensions, isNull);
        expect(frameAttempts, equals(1));
        expect(reporter.recorded, isEmpty);
        for (final entry in logCapture.getRecentLogs()) {
          expect(entry.message, isNot(contains('clip.mp4')));
          expect(entry.error ?? '', isNot(contains('clip.mp4')));
        }
      },
    );

    test(
      'leaves out a part that fails with a programming error, reports it, and '
      'still sends the other part',
      () async {
        final reporter = _RecordingCrashReporter();
        answer = (call) async => switch (call.method) {
          'getThumbnails' => <Uint8List>[_solidFrame(255, 0, 0)],
          // Not the map the plugin expects, so its cast throws a TypeError.
          'getMetadata' => const ['not', 'a', 'map'],
          _ => null,
        };

        final preview = await readDmVideoPreview(video, reporter: reporter);

        expect(preview.blurhash, isNotNull);
        expect(preview.dimensions, isNull);
        expect(reporter.recorded, hasLength(1));
        expect(reporter.recorded.single.error, isA<ReportableError>());
      },
    );

    test(
      'gives up on a platform call that never answers, so the send is not '
      'held',
      () async {
        final logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
        addTearDown(logCapture.clearAllLogs);
        final never = Completer<Object?>();
        answer = (call) => never.future;

        final preview = await readDmVideoPreview(
          video,
          timeout: const Duration(milliseconds: 50),
        );

        expect(preview.blurhash, isNull);
        expect(preview.dimensions, isNull);
        final timeouts = logCapture.getRecentLogs().where(
          (entry) => entry.name == 'DmVideoPreview',
        );
        expect(timeouts, hasLength(2));
      },
    );
  });

  group('readDmVideoCardFrame', () {
    const channel = MethodChannel('pro_video_editor');
    late ProVideoEditor originalProVideoEditor;
    late Directory tempDir;
    late File video;
    late Future<Object?> Function(MethodCall call) answer;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _NoopInitProVideoEditor();
      tempDir = Directory.systemTemp.createTempSync('dm_video_card_frame_');
      video = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(const [1, 2, 3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) => answer(call));
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
      "reads one frame at Divine's thumbnail time, cropped to the card",
      () async {
        final frame = _solidFrame(255, 0, 0);
        final calls = <MethodCall>[];
        answer = (call) async {
          calls.add(call);
          return <Uint8List>[frame];
        };

        final read = await readDmVideoCardFrame(video);

        expect(read, equals(frame));
        final arguments = calls.single.arguments as Map<Object?, Object?>;
        expect(calls.single.method, equals('getThumbnails'));
        expect(arguments['outputWidth'], equals(744));
        expect(arguments['outputHeight'], equals(1050));
        expect(arguments['timestamps'], equals([200000]));
        expect(arguments['maxParallelDecoders'], equals(1));
      },
    );

    test('is null when the platform returns no frame', () async {
      answer = (call) async => <Uint8List>[];

      expect(await readDmVideoCardFrame(video), isNull);
    });

    test(
      'is null when the platform fails, and keeps the file name out of logs',
      () async {
        final logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
        addTearDown(logCapture.clearAllLogs);
        final reporter = _RecordingCrashReporter();
        answer = (call) async => throw PlatformException(
          code: 'decode',
          message: 'cannot open ${video.path}',
        );

        final read = await readDmVideoCardFrame(video, reporter: reporter);

        expect(read, isNull);
        expect(reporter.recorded, isEmpty);
        final logs = logCapture.getRecentLogs();
        expect(logs, isNotEmpty);
        for (final entry in logs) {
          expect(entry.message, isNot(contains('clip.mp4')));
          expect(entry.error ?? '', isNot(contains('clip.mp4')));
        }
      },
    );
  });
}
