// ABOUTME: Tests for WatermarkDownloadService result types and stage enums
// ABOUTME: Validates the sealed class hierarchy and download flow contracts

import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_path_provider_platform.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _MockC2paSigningService extends Mock implements C2paSigningService {}

/// Fake native editor: reports fixed metadata and "renders" by writing the
/// output file, so [WatermarkDownloadService.downloadWithWatermark] can run
/// end-to-end without a native platform.
class _FakeProVideoEditor extends ProVideoEditor {
  /// The last task handed to the renderer, so tests can assert what the
  /// service asked the native side to produce.
  VideoRenderData? lastRenderTask;

  @override
  void initializeStream() {}

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 6),
      extension: 'mp4',
      fileSize: 1024,
      resolution: const Size(320, 568),
      rotation: 0,
      bitrate: 1_000_000,
    );
  }

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    lastRenderTask = value;
    File(filePath).writeAsStringSync('watermarked');
    return filePath;
  }

  @override
  Future<void> cancel(String taskId) async {}
}

VideoEvent _createTestVideo() => VideoEvent(
  id: 'test-video-id-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  pubkey:
      'pubkey-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  content: 'Test video',
  timestamp: DateTime.now(),
  videoUrl: 'https://example.com/video.mp4',
);

/// Stands a `downloadWithWatermark` run up without a native platform: a temp
/// directory holding the source video and receiving the render output, a fake
/// editor that records the render task, and cache/gallery stubs.
///
/// Registers its own teardown, so call it from inside a test body.
({File videoFile, _FakeProVideoEditor editor}) _arrangeWatermarkRender({
  required String tempPrefix,
  required _MockMediaCacheManager mockCache,
  required _MockGallerySaveService mockGallerySave,
}) {
  final tempDir = Directory.systemTemp.createTempSync(tempPrefix);
  addTearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final videoFile = File('${tempDir.path}/video.mp4')
    ..writeAsBytesSync(const [1, 2, 3, 4]);

  final originalPathProvider = PathProviderPlatform.instance;
  PathProviderPlatform.instance = MockPathProviderPlatform()
    ..setTemporaryPath(tempDir.path);
  addTearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
  });

  final editor = _FakeProVideoEditor();
  final originalEditor = ProVideoEditor.instance;
  ProVideoEditor.instance = editor;
  addTearDown(() {
    ProVideoEditor.instance = originalEditor;
  });

  when(() => mockCache.getCachedFileSync(any())).thenReturn(videoFile);
  when(
    () => mockGallerySave.saveVideoToGallery(any()),
  ).thenAnswer((_) async => const GallerySaveSuccess());

  return (videoFile: videoFile, editor: editor);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(EditorVideo.file('/tmp/fallback.mp4'));
  });

  group('WatermarkDownloadStage', () {
    test('has all three stages', () {
      expect(WatermarkDownloadStage.values, hasLength(3));
      expect(
        WatermarkDownloadStage.values,
        containsAll([
          WatermarkDownloadStage.downloading,
          WatermarkDownloadStage.watermarking,
          WatermarkDownloadStage.saving,
        ]),
      );
    });
  });

  group('OriginalSaveStage', () {
    test('has two stages', () {
      expect(OriginalSaveStage.values, hasLength(2));
      expect(
        OriginalSaveStage.values,
        containsAll([OriginalSaveStage.downloading, OriginalSaveStage.saving]),
      );
    });
  });

  group('WatermarkDownloadResult', () {
    test('WatermarkDownloadSuccess is a WatermarkDownloadResult', () {
      const result = WatermarkDownloadSuccess('/path/to/file.mp4');
      expect(result, isA<WatermarkDownloadResult>());
      expect(result.filePath, '/path/to/file.mp4');
    });

    test('WatermarkDownloadFailure is a WatermarkDownloadResult', () {
      const result = WatermarkDownloadFailure('Network error');
      expect(result, isA<WatermarkDownloadResult>());
      expect(result.reason, 'Network error');
    });

    test('WatermarkDownloadPermissionDenied is a WatermarkDownloadResult', () {
      const result = WatermarkDownloadPermissionDenied();
      expect(result, isA<WatermarkDownloadResult>());
    });

    test('pattern matching works on WatermarkDownloadResult', () {
      const WatermarkDownloadResult success = WatermarkDownloadSuccess(
        '/tmp/video.mp4',
      );
      const WatermarkDownloadResult failure = WatermarkDownloadFailure('Error');
      const WatermarkDownloadResult permDenied =
          WatermarkDownloadPermissionDenied();

      expect(success is WatermarkDownloadSuccess, isTrue);
      expect(failure is WatermarkDownloadFailure, isTrue);
      expect(permDenied is WatermarkDownloadPermissionDenied, isTrue);
    });

    test('WatermarkDownloadFailure extracts reason via pattern match', () {
      const WatermarkDownloadResult result = WatermarkDownloadFailure(
        'Connection timeout',
      );

      final reason = switch (result) {
        WatermarkDownloadSuccess() => null,
        WatermarkDownloadPermissionDenied() => null,
        WatermarkDownloadFailure(:final reason) => reason,
      };

      expect(reason, 'Connection timeout');
    });
  });

  group(WatermarkDownloadService, () {
    late _MockMediaCacheManager mockCache;
    late _MockGallerySaveService mockGallerySave;
    late _MockC2paSigningService mockC2pa;
    late WatermarkDownloadService service;

    setUp(() {
      mockCache = _MockMediaCacheManager();
      mockGallerySave = _MockGallerySaveService();
      mockC2pa = _MockC2paSigningService();
      when(
        () => mockC2pa.resignDerived(
          outputPath: any(named: 'outputPath'),
          sourcePath: any(named: 'sourcePath'),
          action: any(named: 'action'),
        ),
      ).thenAnswer(
        (_) async =>
            const C2paSigningResult(signedFilePath: '', success: false),
      );
      service = WatermarkDownloadService(
        mediaCache: mockCache,
        gallerySaveService: mockGallerySave,
        c2paSigningService: mockC2pa,
      );
    });

    test('can be instantiated', () {
      expect(service, isA<WatermarkDownloadService>());
    });

    group('deleteStaleWatermarkRenders', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('watermark_stale_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      test('removes only aged watermark renders', () {
        final oldMtime = DateTime.now().subtract(const Duration(hours: 2));
        final stale1 = File('${tempDir.path}/watermarked_111.mp4')
          ..writeAsStringSync('a')
          ..setLastModifiedSync(oldMtime);
        final stale2 = File('${tempDir.path}/watermarked_222.mp4')
          ..writeAsStringSync('b')
          ..setLastModifiedSync(oldMtime);
        final unrelatedVideo = File('${tempDir.path}/merged_333.mp4')
          ..writeAsStringSync('c')
          ..setLastModifiedSync(oldMtime);
        final unrelatedImage = File('${tempDir.path}/watermarked_444.jpg')
          ..writeAsStringSync('d')
          ..setLastModifiedSync(oldMtime);

        service.deleteStaleWatermarkRenders(tempDir);

        expect(stale1.existsSync(), isFalse);
        expect(stale2.existsSync(), isFalse);
        expect(unrelatedVideo.existsSync(), isTrue);
        expect(unrelatedImage.existsSync(), isTrue);
      });

      test('keeps renders younger than the stale window', () {
        // A dismissed save can still be rendering into this file, and a
        // completed save's file may still be presented in the share sheet.
        final recent = File('${tempDir.path}/watermarked_555.mp4')
          ..writeAsStringSync('e');

        service.deleteStaleWatermarkRenders(tempDir);

        expect(recent.existsSync(), isTrue);
      });

      test('does not throw when the directory does not exist', () {
        final missing = Directory('${tempDir.path}/missing');

        expect(
          () => service.deleteStaleWatermarkRenders(missing),
          returnsNormally,
        );
      });
    });

    group('downloadOriginal', () {
      test('saves a cached video file successfully', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'watermark-download-service-test',
        );
        final videoFile = File('${tempDir.path}/video.mp4');
        await videoFile.writeAsBytes(const [1, 2, 3, 4]);

        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final stages = <OriginalSaveStage>[];

        when(() => mockCache.getCachedFileSync(any())).thenReturn(videoFile);
        when(
          () => mockGallerySave.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySaveSuccess());

        final result = await service.downloadOriginal(
          video: _createTestVideo(),
          onProgress: stages.add,
        );

        expect(result, isA<WatermarkDownloadSuccess>());
        expect(stages, [
          OriginalSaveStage.downloading,
          OriginalSaveStage.saving,
        ]);
        verify(() => mockGallerySave.saveVideoToGallery(any())).called(1);
      });
    });

    group('downloadWithWatermark', () {
      test(
        'carries the C2PA manifest onto the rendered file before the '
        'gallery save',
        () async {
          final videoFile = _arrangeWatermarkRender(
            tempPrefix: 'watermark-c2pa-test',
            mockCache: mockCache,
            mockGallerySave: mockGallerySave,
          ).videoFile;

          final stages = <WatermarkDownloadStage>[];
          final result = await service.downloadWithWatermark(
            video: _createTestVideo(),
            watermarkText: 'alice@divine.video',
            onProgress: stages.add,
          );

          expect(result, isA<WatermarkDownloadSuccess>());
          final outputPath = (result as WatermarkDownloadSuccess).filePath;
          expect(outputPath, isNot(equals(videoFile.path)));

          final ordered = verifyInOrder([
            () => mockC2pa.resignDerived(
              outputPath: outputPath,
              sourcePath: videoFile.path,
              action: C2paEditActions.edited,
            ),
            () => mockGallerySave.saveVideoToGallery(captureAny()),
          ]);
          final savedVideo = ordered.last.captured.single as EditorVideo;
          expect(savedVideo.file!.path, equals(outputPath));
          expect(stages, [
            WatermarkDownloadStage.downloading,
            WatermarkDownloadStage.watermarking,
            WatermarkDownloadStage.saving,
          ]);
        },
      );

      test('caps the rendered frame rate so the camera roll does not treat '
          'the download as slow motion', () async {
        final editor = _arrangeWatermarkRender(
          tempPrefix: 'watermark-fps-test',
          mockCache: mockCache,
          mockGallerySave: mockGallerySave,
        ).editor;

        final result = await service.downloadWithWatermark(
          video: _createTestVideo(),
          watermarkText: 'alice@divine.video',
          onProgress: (_) {},
        );

        expect(result, isA<WatermarkDownloadSuccess>());
        expect(editor.lastRenderTask, isNotNull);
        // Exactly 60, not merely at-or-under it: an import above ~60 fps is
        // what iOS Photos plays back as Slo-Mo, and 60 is the highest rate it
        // still treats as ordinary, so a lower cap would throw away frames a
        // genuine 60 fps source actually has.
        expect(editor.lastRenderTask!.maxFrameRate, 60);
      });
    });

    group('_getVideoFile (cached file fallback)', () {
      test(
        'returns cached file when extension is .mp4 and file exists',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'watermark-ext-test',
          );
          final videoFile = File('${tempDir.path}/video.mp4');
          await videoFile.writeAsBytes(const [1, 2, 3, 4]);
          addTearDown(() async {
            if (tempDir.existsSync()) await tempDir.delete(recursive: true);
          });

          when(() => mockCache.getCachedFileSync(any())).thenReturn(videoFile);
          when(
            () => mockGallerySave.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final result = await service.downloadOriginal(
            video: _createTestVideo(),
            onProgress: (_) {},
          );

          // File was used — gallery save was called
          verify(() => mockGallerySave.saveVideoToGallery(any())).called(1);
          // removeCachedFile must NOT have been called
          verifyNever(() => mockCache.removeCachedFile(any()));
          expect(result, isA<WatermarkDownloadSuccess>());
        },
      );

      test(
        'evicts cache and re-downloads when cached file has .bin extension',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'watermark-ext-test',
          );
          // Simulate stale download stored as .bin (seen in flutter_cache_manager
          // when a previous download was interrupted without a Content-Type header)
          final badFile = File('${tempDir.path}/video.bin');
          await badFile.writeAsBytes(const [0, 0, 0, 0]);

          final freshFile = File('${tempDir.path}/fresh.mp4');
          await freshFile.writeAsBytes(const [1, 2, 3, 4]);

          addTearDown(() async {
            if (tempDir.existsSync()) await tempDir.delete(recursive: true);
          });

          when(() => mockCache.getCachedFileSync(any())).thenReturn(badFile);
          when(
            () => mockCache.removeCachedFile(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockCache.cacheFile(any(), key: any(named: 'key')),
          ).thenAnswer((_) async => freshFile);
          when(
            () => mockGallerySave.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          await service.downloadOriginal(
            video: _createTestVideo(),
            onProgress: (_) {},
          );

          verify(() => mockCache.removeCachedFile(any())).called(1);
          verify(
            () => mockCache.cacheFile(any(), key: any(named: 'key')),
          ).called(1);
        },
      );

      test('evicts cache when cached file has no extension', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'watermark-ext-test',
        );
        final badFile = File('${tempDir.path}/video');
        await badFile.writeAsBytes(const [0, 0, 0, 0]);

        addTearDown(() async {
          if (tempDir.existsSync()) await tempDir.delete(recursive: true);
        });

        when(() => mockCache.getCachedFileSync(any())).thenReturn(badFile);
        when(() => mockCache.removeCachedFile(any())).thenAnswer((_) async {});
        when(
          () => mockCache.cacheFile(any(), key: any(named: 'key')),
        ).thenAnswer((_) async => null);

        final result = await service.downloadOriginal(
          video: _createTestVideo(),
          onProgress: (_) {},
        );

        verify(() => mockCache.removeCachedFile(any())).called(1);
        expect(result, isA<WatermarkDownloadFailure>());
      });

      test(
        'fresh download continues when invalid cache eviction fails',
        () async {
          final video = _createTestVideo();
          final tempDir = await Directory.systemTemp.createTemp(
            'watermark-ext-test',
          );
          final badFile = File('${tempDir.path}/video.bin');
          await badFile.writeAsBytes(const [0, 0, 0, 0]);

          final freshFile = File('${tempDir.path}/fresh.mp4');
          await freshFile.writeAsBytes(const [1, 2, 3, 4]);

          addTearDown(() async {
            if (tempDir.existsSync()) await tempDir.delete(recursive: true);
          });

          when(() => mockCache.getCachedFileSync(any())).thenReturn(badFile);
          when(
            () => mockCache.removeCachedFile(any()),
          ).thenThrow(Exception('eviction failed'));
          when(
            () => mockCache.cacheFile(any(), key: any(named: 'key')),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as String;
            return key == video.id ? badFile : freshFile;
          });
          when(
            () => mockGallerySave.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final result = await service.downloadOriginal(
            video: video,
            onProgress: (_) {},
          );

          verify(() => mockCache.removeCachedFile(any())).called(1);
          final cacheKey =
              verify(
                    () => mockCache.cacheFile(
                      any(),
                      key: captureAny(named: 'key'),
                    ),
                  ).captured.single
                  as String;
          expect(cacheKey, isNot(video.id));
          expect(cacheKey, startsWith('${video.id}-redownload-'));
          final savedVideo =
              verify(
                    () => mockGallerySave.saveVideoToGallery(captureAny()),
                  ).captured.single
                  as EditorVideo;
          expect(savedVideo.file!.path, freshFile.path);
          expect(result, isA<WatermarkDownloadSuccess>());
        },
      );

      test('accepts .mov cached files without eviction', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'watermark-ext-test',
        );
        final movFile = File('${tempDir.path}/video.mov');
        await movFile.writeAsBytes(const [1, 2, 3, 4]);
        addTearDown(() async {
          if (tempDir.existsSync()) await tempDir.delete(recursive: true);
        });

        when(() => mockCache.getCachedFileSync(any())).thenReturn(movFile);
        when(
          () => mockGallerySave.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySaveSuccess());

        await service.downloadOriginal(
          video: _createTestVideo(),
          onProgress: (_) {},
        );

        verifyNever(() => mockCache.removeCachedFile(any()));
      });

      test(
        'falls back to fresh download when getCachedFileSync returns null',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'watermark-ext-test',
          );
          final freshFile = File('${tempDir.path}/fresh.mp4');
          await freshFile.writeAsBytes(const [1, 2, 3, 4]);
          addTearDown(() async {
            if (tempDir.existsSync()) await tempDir.delete(recursive: true);
          });

          when(() => mockCache.getCachedFileSync(any())).thenReturn(null);
          when(
            () => mockCache.cacheFile(any(), key: any(named: 'key')),
          ).thenAnswer((_) async => freshFile);
          when(
            () => mockGallerySave.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final result = await service.downloadOriginal(
            video: _createTestVideo(),
            onProgress: (_) {},
          );

          verify(
            () => mockCache.cacheFile(any(), key: any(named: 'key')),
          ).called(1);
          expect(result, isA<WatermarkDownloadSuccess>());
        },
      );
    });
  });
}
