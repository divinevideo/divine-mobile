// ABOUTME: Unit tests for AudioExtractionService
// ABOUTME: Tests audio extraction result model, exceptions, cleanup, and
// ABOUTME: core extraction path with ProVideoEditor mock.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Mock ProVideoEditor that provides controllable behavior for testing
/// the core audio extraction path.
class _MockProVideoEditor extends ProVideoEditor {
  bool hasAudio = true;
  Duration videoDuration = const Duration(seconds: 6);
  bool shouldThrowOnExtract = false;
  bool shouldThrowNoTrack = false;
  bool shouldThrowOnHasAudio = false;
  bool shouldThrowOnGetMetadata = false;
  AudioExtractConfigs? lastAudioExtractConfigs;

  @override
  void initializeStream() {
    // No-op for testing
  }

  @override
  Future<bool> hasAudioTrack(
    EditorVideo value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (shouldThrowOnHasAudio) throw Exception('hasAudioTrack failed');
    return hasAudio;
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (shouldThrowOnGetMetadata) throw Exception('getMetadata failed');
    return VideoMetadata(
      duration: videoDuration,
      extension: 'mp4',
      fileSize: 1024000,
      resolution: const Size(1920, 1080),
      rotation: 0,
      bitrate: 3000000,
    );
  }

  @override
  Future<String> extractAudioToFile(
    String filePath,
    AudioExtractConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    lastAudioExtractConfigs = value;
    if (shouldThrowNoTrack) throw const AudioNoTrackException();
    if (shouldThrowOnExtract) throw Exception('extraction failed');
    // Create a small file to simulate extraction
    final file = File(filePath);
    await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]);
    return filePath;
  }

  bool shouldThrowOnMerge = false;
  AudioMergeConfigs? lastMergeConfigs;

  @override
  Future<AudioMergeResult> mergeAudioToFile(
    String filePath,
    AudioMergeConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    lastMergeConfigs = value;
    if (shouldThrowOnMerge) throw Exception('merge failed');
    await File(filePath).writeAsBytes([0x00, 0x01]);
    // Concatenate each segment's contribution with no gaps, mirroring native.
    var start = Duration.zero;
    final offsets = <AudioMergeSegmentOffset>[];
    for (final segment in value.segments) {
      offsets.add(
        AudioMergeSegmentOffset(
          outputStart: start,
          outputDuration: segment.outputDuration,
        ),
      );
      start += segment.outputDuration;
    }
    return AudioMergeResult(
      outputPath: filePath,
      segments: offsets,
      totalDuration: start,
    );
  }
}

void main() {
  group('AudioExtractionResult', () {
    test('creates result with all required fields', () {
      const result = AudioExtractionResult(
        audioFilePath: '/path/to/audio.aac',
        duration: 6.5,
        fileSize: 102400,
        sha256Hash: 'abc123def456',
        mimeType: 'audio/aac',
      );

      expect(result.audioFilePath, equals('/path/to/audio.aac'));
      expect(result.duration, equals(6.5));
      expect(result.fileSize, equals(102400));
      expect(result.sha256Hash, equals('abc123def456'));
      expect(result.mimeType, equals('audio/aac'));
    });

    test('toString provides human-readable output', () {
      const result = AudioExtractionResult(
        audioFilePath: '/path/to/audio.aac',
        duration: 6.5,
        fileSize: 102400,
        sha256Hash: 'abc123def456',
        mimeType: 'audio/aac',
      );

      final str = result.toString();

      expect(str, contains('6.50s'));
      expect(str, contains('100.00KB'));
      expect(str, contains('audio/aac'));
    });

    test('fileSize displays correctly in KB', () {
      const result = AudioExtractionResult(
        audioFilePath: '/path/to/audio.aac',
        duration: 3.0,
        fileSize: 51200, // 50 KB
        sha256Hash: 'hash',
        mimeType: 'audio/aac',
      );

      final str = result.toString();
      expect(str, contains('50.00KB'));
    });
  });

  group('AudioExtractionException', () {
    test('creates exception with message only', () {
      const exception = AudioExtractionException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
      expect(
        exception.toString(),
        equals('AudioExtractionException: Test error'),
      );
    });

    test('creates exception with message and cause', () {
      final cause = Exception('Underlying error');
      final exception = AudioExtractionException('Test error', cause: cause);

      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('caused by:'));
    });

    test('toString includes cause when present', () {
      const exception = AudioExtractionException(
        'Audio extraction failed',
        cause: 'Error: No audio stream found',
      );

      final str = exception.toString();
      expect(str, contains('Audio extraction failed'));
      expect(str, contains('caused by:'));
      expect(str, contains('No audio stream found'));
    });
  });

  group('AudioExtractionService', () {
    late AudioExtractionService service;

    setUp(() {
      service = AudioExtractionService();
    });

    test('throws exception when video file does not exist', () async {
      const nonExistentPath = '/path/that/does/not/exist/video.mp4';

      expect(
        () => service.extractAudio(videoPath: nonExistentPath),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Video file not found',
          ),
        ),
      );
    });

    test('cleanupTemporaryFiles handles empty list', () async {
      await expectLater(service.cleanupTemporaryFiles([]), completes);
    });

    test(
      'cleanupTemporaryFiles handles non-existent files gracefully',
      () async {
        await expectLater(
          service.cleanupTemporaryFiles([
            '/non/existent/file1.aac',
            '/non/existent/file2.aac',
          ]),
          completes,
        );
      },
    );

    test('cleanupAudioFile delegates to cleanupTemporaryFiles', () async {
      await expectLater(
        service.cleanupAudioFile('/non/existent/audio.aac'),
        completes,
      );
    });

    group('with temporary files', () {
      late Directory tempDir;
      late File tempFile;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('audio_test_');
        tempFile = File('${tempDir.path}/test_audio.aac');
        await tempFile.writeAsString('test content');
      });

      tearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // Ignore cleanup errors in teardown
        }
      });

      test('cleanupTemporaryFiles deletes existing files', () async {
        expect(tempFile.existsSync(), isTrue);

        await service.cleanupTemporaryFiles([tempFile.path]);

        expect(tempFile.existsSync(), isFalse);
      });

      test('cleanupAudioFile deletes single file', () async {
        expect(tempFile.existsSync(), isTrue);

        await service.cleanupAudioFile(tempFile.path);

        expect(tempFile.existsSync(), isFalse);
      });
    });
  });

  group('AudioExtractionService with ProVideoEditor mock', () {
    late AudioExtractionService service;
    late _MockProVideoEditor mockEditor;
    late ProVideoEditor originalProVideoEditorInstance;
    late Directory tempDir;
    late File fakeVideoFile;

    setUp(() async {
      service = AudioExtractionService();
      mockEditor = _MockProVideoEditor();
      originalProVideoEditorInstance = ProVideoEditor.instance;
      ProVideoEditor.instance = mockEditor;

      tempDir = await Directory.systemTemp.createTemp('extraction_test_');
      fakeVideoFile = File('${tempDir.path}/test_video.mp4');
      await fakeVideoFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
    });

    tearDown(() async {
      ProVideoEditor.instance = originalProVideoEditorInstance;
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Intentional no-op: ignore cleanup errors in teardown.
      }
    });

    test('extractAudio returns result when video has audio', () async {
      final result = await service.extractAudio(videoPath: fakeVideoFile.path);

      expect(result.audioFilePath, endsWith('.wav'));
      expect(result.duration, equals(6));
      expect(result.fileSize, greaterThan(0));
      expect(result.sha256Hash, isNotEmpty);
      expect(result.sha256Hash.length, equals(64));
      expect(result.mimeType, equals('audio/wav'));

      // Cleanup extraction output
      final outputFile = File(result.audioFilePath);
      if (outputFile.existsSync()) {
        await outputFile.delete();
      }
    });

    test('extractAudio forwards playback speed to ProVideoEditor', () async {
      final result = await service.extractAudio(
        videoPath: fakeVideoFile.path,
        speed: 0.5,
      );

      expect(mockEditor.lastAudioExtractConfigs?.speed, equals(0.5));
      expect(result.duration, equals(12.0));

      // Cleanup extraction output
      final outputFile = File(result.audioFilePath);
      if (outputFile.existsSync()) {
        await outputFile.delete();
      }
    });

    test('extractAudio writes into a caller-owned directory', () async {
      final directory = await Directory.systemTemp.createTemp('draft_audio');
      addTearDown(() => directory.delete(recursive: true));

      final result = await service.extractAudio(
        videoPath: fakeVideoFile.path,
        outputDirectory: directory,
      );

      expect(result.audioFilePath, startsWith(directory.path));
      expect(File(result.audioFilePath).existsSync(), isTrue);
    });

    test('extractAudio leaves a caller-owned file out of the sweep', () async {
      // A draft-owned track lives for as long as the draft does. If it were
      // tracked as temporary, the no-argument sweep would delete a file the
      // draft still points at.
      final directory = await Directory.systemTemp.createTemp('draft_audio');
      addTearDown(() => directory.delete(recursive: true));

      final result = await service.extractAudio(
        videoPath: fakeVideoFile.path,
        outputDirectory: directory,
      );
      await service.cleanupTemporaryFiles();

      expect(File(result.audioFilePath).existsSync(), isTrue);
    });

    test('cleanupAudioFile deletes a caller-owned file', () async {
      // The discard path is the only thing reclaiming a draft-owned track the
      // editor decided not to attach. Untracked no longer means undeletable.
      final directory = await Directory.systemTemp.createTemp('draft_audio');
      addTearDown(() => directory.delete(recursive: true));

      final result = await service.extractAudio(
        videoPath: fakeVideoFile.path,
        outputDirectory: directory,
      );
      await service.cleanupAudioFile(result.audioFilePath);

      expect(File(result.audioFilePath).existsSync(), isFalse);
    });

    test('extractAudio still sweeps its own temporary output', () async {
      final result = await service.extractAudio(videoPath: fakeVideoFile.path);

      await service.cleanupTemporaryFiles();

      expect(File(result.audioFilePath).existsSync(), isFalse);
    });

    test('extractAudio throws when video has no audio track', () async {
      mockEditor.hasAudio = false;

      expect(
        () => service.extractAudio(videoPath: fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Video has no audio track',
          ),
        ),
      );
    });

    test('extractAudio throws when hasAudioTrack check fails', () async {
      mockEditor.shouldThrowOnHasAudio = true;

      expect(
        () => service.extractAudio(videoPath: fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Video has no audio track',
          ),
        ),
      );
    });

    test('extractAudio throws when getMetadata fails', () async {
      mockEditor.shouldThrowOnGetMetadata = true;

      expect(
        () => service.extractAudio(videoPath: fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Could not determine audio duration',
          ),
        ),
      );
    });

    test('extractAudio throws when duration is zero', () async {
      mockEditor.videoDuration = Duration.zero;

      expect(
        () => service.extractAudio(videoPath: fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Could not determine audio duration',
          ),
        ),
      );
    });

    test(
      'extractAudio handles AudioNoTrackException from extraction',
      () async {
        mockEditor.shouldThrowNoTrack = true;

        expect(
          () => service.extractAudio(videoPath: fakeVideoFile.path),
          throwsA(
            isA<AudioExtractionException>().having(
              (e) => e.message,
              'message',
              'Video has no audio track',
            ),
          ),
        );
      },
    );

    test('extractAudio handles generic extraction failure', () async {
      mockEditor.shouldThrowOnExtract = true;

      expect(
        () => service.extractAudio(videoPath: fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Failed to extract audio',
          ),
        ),
      );
    });

    test('extractAudio uses correct duration from video metadata', () async {
      mockEditor.videoDuration = const Duration(seconds: 3, milliseconds: 500);

      final result = await service.extractAudio(videoPath: fakeVideoFile.path);

      expect(result.duration, equals(3.5));

      // Cleanup extraction output
      final outputFile = File(result.audioFilePath);
      if (outputFile.existsSync()) {
        await outputFile.delete();
      }
    });

    test(
      'mergeClipAudio returns per-segment offsets and forwards format',
      () async {
        final result = await service.mergeClipAudio(
          segments: [
            AudioMergeSegment(
              video: EditorVideo.file('/tmp/a.mp4'),
              startTime: Duration.zero,
              endTime: const Duration(seconds: 2),
            ),
            AudioMergeSegment(
              video: EditorVideo.file('/tmp/b.mp4'),
              startTime: Duration.zero,
              endTime: const Duration(seconds: 2),
              speed: 2,
            ),
          ],
          sampleRate: 16000,
          channels: 1,
        );

        expect(result.outputPath, contains('merged_audio_'));
        expect(result.outputPath, endsWith('.wav'));
        expect(result.segments, hasLength(2));
        expect(result.segments[0].outputStart, equals(Duration.zero));
        expect(
          result.segments[0].outputDuration,
          equals(const Duration(seconds: 2)),
        );
        // The 2x segment contributes half its window length.
        expect(
          result.segments[1].outputStart,
          equals(const Duration(seconds: 2)),
        );
        expect(
          result.segments[1].outputDuration,
          equals(const Duration(seconds: 1)),
        );
        expect(result.totalDuration, equals(const Duration(seconds: 3)));
        expect(mockEditor.lastMergeConfigs?.sampleRate, equals(16000));
        expect(mockEditor.lastMergeConfigs?.channels, equals(1));

        final outputFile = File(result.outputPath);
        if (outputFile.existsSync()) {
          await outputFile.delete();
        }
      },
    );

    test('mergeClipAudio wraps failures in AudioExtractionException', () async {
      mockEditor.shouldThrowOnMerge = true;

      expect(
        () => service.mergeClipAudio(
          segments: [
            AudioMergeSegment(
              video: EditorVideo.file('/tmp/a.mp4'),
              startTime: Duration.zero,
              endTime: const Duration(seconds: 2),
            ),
          ],
        ),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Failed to merge audio',
          ),
        ),
      );
    });
  });
}
