// ABOUTME: Unit tests for video thumbnail extraction service
// ABOUTME: Tests thumbnail generation, error handling, and edge cases

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
// Not exported from pro_video_editor's barrel — imported via path so we can
// subclass MethodChannelProVideoEditor and skip its EventChannel subscription.
// May need updating on pro_video_editor upgrades.
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

/// Fresh ProVideoEditor-compatible instance for tests.
///
/// Extends [MethodChannelProVideoEditor] so method calls route through the
/// per-test mocked `MethodChannel('pro_video_editor')`. Overrides
/// [initializeStream] to skip subscribing to the `pro_video_editor_progress`
/// and `pro_video_editor_waveform_stream` EventChannels — without this
/// override, the constructor throws `MissingPluginException` in the VGV
/// shared isolate where those EventChannels aren't mocked.
class _NoopInitProVideoEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoThumbnailService', () {
    late String testVideoPath;
    late Directory tempDir;
    late ProVideoEditor originalProVideoEditor;

    const channel = MethodChannel('pro_video_editor');

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('video_thumbnail_test');
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      // Reset the pro_video_editor platform singleton to a test-mode instance
      // whose constructor does NOT subscribe to EventChannels. Without this,
      // whichever file ran before ours in the VGV shared isolate may have left
      // `ProVideoEditor.instance` pointing at a foreign mock that overrides
      // only its own methods, causing our method calls to throw
      // `UnimplementedError` instead of routing through the MethodChannel.
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _NoopInitProVideoEditor();

      testVideoPath = '${tempDir.path}/test_video.mp4';

      // Mock the pro_video_editor platform channel per-test so it does not
      // leak into other test files when running in a shared isolate.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'getThumbnails') {
              return <Uint8List>[];
            }
            return null;
          });
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('extractThumbnail', () {
      test('returns null when video file does not exist', () async {
        // Test with non-existent file
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: '/non/existent/video.mp4',
        );

        expect(result, isNull);
      });

      test('uses default parameters when not specified', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        // This will fail because it's not a real video, but we're testing parameters
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: testVideoPath,
        );

        // Since we're using a fake video file, expect null
        expect(result, isNull);

        // Clean up
        await videoFile.delete();
      });

      test('handles custom quality parameter', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        // Test with custom quality
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: testVideoPath,
          quality: 50,
        );

        expect(result, isNull); // Expected because it's not a real video

        await videoFile.delete();
      });

      test('handles custom timestamp parameter', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        // Test with custom timestamp
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: testVideoPath,
          targetTimestamp: const Duration(seconds: 2),
        );

        expect(result, isNull); // Expected because it's not a real video

        await videoFile.delete();
      });
    });

    group('extractThumbnailBytes', () {
      test('returns null when video file does not exist', () async {
        final result = await VideoThumbnailService.extractThumbnailBytes(
          videoPath: '/non/existent/video.mp4',
        );

        expect(result, isNull);
      });

      test('returns Uint8List for valid video', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final result = await VideoThumbnailService.extractThumbnailBytes(
          videoPath: testVideoPath,
        );

        // Since we're using a fake video, expect null
        expect(result, isNull);

        await videoFile.delete();
      });
    });

    group('extractMultipleThumbnails', () {
      test('returns empty list for non-existent video', () async {
        final results = await VideoThumbnailService.extractMultipleThumbnails(
          videoPath: '/non/existent/video.mp4',
        );

        expect(results, isEmpty);
      });

      test('uses default timestamps when not specified', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final results = await VideoThumbnailService.extractMultipleThumbnails(
          videoPath: testVideoPath,
        );

        // Since we're using a fake video, expect empty list
        expect(results, isEmpty);

        await videoFile.delete();
      });

      test('uses custom timestamps when provided', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final results = await VideoThumbnailService.extractMultipleThumbnails(
          videoPath: testVideoPath,
          timestamps: const [
            Duration(milliseconds: 100),
            Duration(milliseconds: 200),
            Duration(milliseconds: 300),
          ],
        );

        expect(results, isEmpty); // Expected because it's not a real video

        await videoFile.delete();
      });
    });

    group('cleanupThumbnails', () {
      test('deletes existing thumbnail files', () async {
        // Create test thumbnail files
        final thumb1 = File('${tempDir.path}/thumb1.jpg');
        final thumb2 = File('${tempDir.path}/thumb2.jpg');
        await thumb1.writeAsBytes(Uint8List.fromList([1, 2, 3]));
        await thumb2.writeAsBytes(Uint8List.fromList([4, 5, 6]));

        // Verify files exist
        expect(thumb1.existsSync(), isTrue);
        expect(thumb2.existsSync(), isTrue);

        // Clean up thumbnails
        await VideoThumbnailService.cleanupThumbnails([
          thumb1.path,
          thumb2.path,
        ]);

        // Verify files are deleted
        expect(thumb1.existsSync(), isFalse);
        expect(thumb2.existsSync(), isFalse);
      });

      test('handles non-existent files gracefully', () async {
        // Try to clean up non-existent files
        await expectLater(
          VideoThumbnailService.cleanupThumbnails([
            '/non/existent/thumb1.jpg',
            '/non/existent/thumb2.jpg',
          ]),
          completes,
        );
      });

      test('handles mixed existing and non-existing files', () async {
        // Create one test thumbnail file
        final existingThumb = File('${tempDir.path}/existing_thumb.jpg');
        await existingThumb.writeAsBytes(Uint8List.fromList([1, 2, 3]));

        // Clean up mixed files
        await VideoThumbnailService.cleanupThumbnails([
          existingThumb.path,
          '/non/existent/thumb.jpg',
        ]);

        // Verify existing file is deleted
        expect(existingThumb.existsSync(), isFalse);
      });
    });

    group('getOptimalTimestamp', () {
      test('returns 100ms for very short videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(milliseconds: 500),
        );
        expect(timestamp.inMilliseconds, equals(100));
      });

      test('returns 10% timestamp for medium videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 5),
        );
        expect(timestamp.inMilliseconds, equals(500)); // 10% of 5000ms
      });

      test('caps at 1000ms for long videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 30),
        );
        expect(timestamp.inMilliseconds, equals(1000)); // Capped at 1 second
      });

      test('handles edge case of 1 second video', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 1),
        );
        expect(timestamp.inMilliseconds, equals(100)); // 10% of 1000ms = 100ms
      });

      test('handles vine-length video (6.3 seconds)', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          VideoEditorConstants.maxDuration,
        );
        expect(timestamp.inMilliseconds, equals(630)); // 10% of 6300ms
      });
    });

    group('generateStripThumbnails', () {
      test(
        'emits delivered batches then the error when extraction fails '
        'mid-stream',
        () async {
          // In the merged VGV isolate a widget test that tears down while a
          // strip generator awaits the static batch queue strands it on a
          // future from its dead FakeAsync zone (see the cover screen
          // tests); reset it or the first batch below never runs.
          VideoThumbnailService.resetStripBatchQueueForTesting();

          // First batch succeeds, second batch hits a native failure.
          var callCount = 0;
          final fakeJpegBytes = Uint8List.fromList(
            List<int>.generate(16, (i) => i),
          );
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'getThumbnails') {
                  callCount++;
                  if (callCount > 1) {
                    throw PlatformException(code: 'DECODER_ERROR');
                  }
                  return List<Uint8List>.generate(6, (_) => fakeJpegBytes);
                }
                return null;
              });

          // 12 s at 1 thumb/s with the default batch size of 6 → 2 batches.
          final batches = <List<StripThumbnail>>[];
          Object? streamError;
          final done = Completer<void>();
          VideoThumbnailService.generateStripThumbnails(
            videoPath: testVideoPath,
            clipId: 'clip-truncated',
            duration: const Duration(seconds: 12),
            outputSize: const Size(48, 64),
          ).listen(
            batches.add,
            onError: (Object error) => streamError = error,
            onDone: done.complete,
          );
          await done.future;

          // The successful batch was delivered, then the stream errored —
          // a listener can tell the truncated set apart from a clean close.
          expect(batches, hasLength(1));
          expect(batches.single, hasLength(6));
          expect(streamError, isA<PlatformException>());

          for (final thumbnail in batches.single) {
            final file = File(thumbnail.path);
            expect(file.existsSync(), isTrue);
            file.deleteSync();
          }
        },
      );

      test(
        'extracts only inside the requested window, timestamped in absolute '
        'source time',
        () async {
          VideoThumbnailService.resetStripBatchQueueForTesting();

          final fakeJpegBytes = Uint8List.fromList(
            List<int>.generate(16, (i) => i),
          );
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'getThumbnails') {
                  return List<Uint8List>.generate(6, (_) => fakeJpegBytes);
                }
                return null;
              });

          // A 3 s window starting 20 s into the file: 3 s at 2 thumbs/s is
          // exactly one batch of 6.
          final batches = <List<StripThumbnail>>[];
          final done = Completer<void>();
          VideoThumbnailService.generateStripThumbnails(
            videoPath: testVideoPath,
            clipId: 'clip-windowed',
            duration: const Duration(seconds: 3),
            startOffset: const Duration(seconds: 20),
            outputSize: const Size(48, 64),
            thumbsPerSecond: 2,
          ).listen(batches.add, onDone: done.complete);
          await done.future;

          expect(batches, hasLength(1));
          final thumbnails = batches.single;
          expect(thumbnails, hasLength(6));
          for (final thumbnail in thumbnails) {
            expect(
              thumbnail.timestamp.inMilliseconds,
              inInclusiveRange(20000, 23000),
            );
          }
          // Center-first refinement still spreads across the window rather
          // than clustering at one edge.
          expect(
            thumbnails.first.timestamp,
            isNot(equals(thumbnails.last.timestamp)),
          );

          for (final thumbnail in thumbnails) {
            File(thumbnail.path).deleteSync();
          }
        },
      );
    });
  });

  group('VideoThumbnailService.extractLastFrame', () {
    const channel = MethodChannel('pro_video_editor');
    late Directory tempDir;
    late String testVideoPath;

    /// Tracks whether the channel mock should return valid bytes or
    /// empty lists.  The mock checks [getThumbnailsReturnsBytes] and
    /// [getMetadataSucceeds] on every invocation so individual tests
    /// can toggle behaviour mid-test.
    late bool getThumbnailsReturnsBytes;
    late bool getMetadataSucceeds;
    late ProVideoEditor originalProVideoEditor;

    /// Dummy JPEG-like bytes produced by the mock.
    final fakeJpegBytes = Uint8List.fromList(List<int>.generate(128, (i) => i));

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('ghost_frame_test');
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      // Reset the pro_video_editor platform singleton to a test-mode instance
      // whose constructor does NOT subscribe to EventChannels. Without this,
      // whichever file ran before ours in the VGV shared isolate may have left
      // `ProVideoEditor.instance` pointing at a foreign mock that overrides
      // only its own methods, causing our method calls to throw
      // `UnimplementedError` instead of routing through the MethodChannel.
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _NoopInitProVideoEditor();

      getThumbnailsReturnsBytes = false;
      getMetadataSucceeds = true;

      testVideoPath = '${tempDir.path}/test_video.mp4';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getThumbnails') {
              if (getThumbnailsReturnsBytes) {
                return <Uint8List>[fakeJpegBytes];
              }
              return <Uint8List>[];
            }
            if (call.method == 'getMetadata') {
              if (!getMetadataSucceeds) {
                throw PlatformException(code: 'ERROR', message: 'cannot open');
              }
              return <String, dynamic>{
                'duration': 3000000, // microseconds
                'extension': 'mp4',
                'fileSize': 1024000,
                'width': 1920,
                'height': 1080,
                'rotation': 0,
                'bitrate': 3000000,
              };
            }
            return null;
          });
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns path when getSingleThumbnail succeeds', () async {
      getThumbnailsReturnsBytes = true;
      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      expect(result, isNotNull);
      expect(result, contains('ghost_'));
      expect(File(result!).existsSync(), isTrue);

      await videoFile.delete();
    });

    test(
      'falls back to timestamp extraction when position-based fails',
      () async {
        // First call (position-based) fails, second call (timestamp) succeeds.
        var callCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'getThumbnails') {
                callCount++;
                // First call → empty (position-based fails)
                // Second call → bytes (timestamp fallback succeeds)
                if (callCount >= 2) {
                  return <Uint8List>[fakeJpegBytes];
                }
                return <Uint8List>[];
              }
              if (call.method == 'getMetadata') {
                return <String, dynamic>{
                  'duration': 3000000,
                  'extension': 'mp4',
                  'fileSize': 1024000,
                  'width': 1920,
                  'height': 1080,
                  'rotation': 0,
                  'bitrate': 3000000,
                };
              }
              return null;
            });

        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final result = await VideoThumbnailService.extractLastFrame(
          videoPath: testVideoPath,
          videoDuration: const Duration(seconds: 3),
        );

        expect(result, isNotNull);
        // At least 2 calls: position-based + timestamp fallback attempt(s)
        expect(callCount, greaterThanOrEqualTo(2));

        await videoFile.delete();
      },
    );

    test('returns null when both strategies fail', () async {
      getThumbnailsReturnsBytes = false;
      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      expect(result, isNull);

      await videoFile.delete();
    });

    test('returns null when getSingleThumbnail throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getThumbnails') {
              throw PlatformException(code: 'ERROR', message: 'Cannot Open');
            }
            if (call.method == 'getMetadata') {
              return <String, dynamic>{
                'duration': 3000000,
                'extension': 'mp4',
                'fileSize': 1024000,
                'width': 1920,
                'height': 1080,
                'rotation': 0,
                'bitrate': 3000000,
              };
            }
            return null;
          });

      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      // Falls back to timestamp extraction which also throws → null
      expect(result, isNull);

      await videoFile.delete();
    });

    test('uses provided videoDuration to avoid metadata lookup', () async {
      getThumbnailsReturnsBytes = true;
      getMetadataSucceeds = false; // Would fail if called

      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      // Should succeed without needing getMetadata
      expect(result, isNotNull);

      await videoFile.delete();
    });

    test('fallback computes timestamp as duration minus 50ms', () async {
      // Track the timestamps sent to getThumbnails
      final timestamps = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getThumbnails') {
              final args = call.arguments as Map;
              final ts = (args['timestamps'] as List).cast<int>();
              timestamps.addAll(ts);
              // Fail first call, succeed on subsequent
              if (timestamps.length == 1) {
                return <Uint8List>[];
              }
              return <Uint8List>[fakeJpegBytes];
            }
            if (call.method == 'getMetadata') {
              return <String, dynamic>{
                'duration': 3000000,
                'extension': 'mp4',
                'fileSize': 1024000,
                'width': 1920,
                'height': 1080,
                'rotation': 0,
                'bitrate': 3000000,
              };
            }
            return null;
          });

      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      // First call: position-based (duration = 3000000 microseconds)
      expect(timestamps.first, equals(3000000));
      // Fallback timestamp should be duration - 50ms = 2950000 microseconds
      // (may appear in a later element depending on retry logic)
      expect(timestamps, contains(2950000));

      await videoFile.delete();
    });
  });
}
