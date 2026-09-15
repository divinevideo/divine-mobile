// ABOUTME: Public-API contract tests for UploadRepository — every public method
// ABOUTME: is exercised through the package's own ports and a mocked Hive box.

import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:upload_repository/upload_repository.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockPendingUploadBox extends Mock implements Box<PendingUpload> {}

class _FakePendingUpload extends Fake implements PendingUpload {}

class _NoopCrashReporter implements UploadCrashReporter {
  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

class _NoopTransientRenderCleaner implements TransientRenderCleaner {
  @override
  Future<void> cleanupMaterializedOutputPath(String filePath) async {}

  @override
  bool isMaterializedOutputPath(String filePath) => false;
}

class _RecordingRepository extends UploadRepository {
  _RecordingRepository({
    required BlossomUploadService blossomService,
    required Box<PendingUpload> box,
  }) : super(
         blossomService: blossomService,
         openPendingUploadsBox: ({bool forceReinit = false}) async => box,
         crashReporter: _NoopCrashReporter(),
         thumbnailExtractor:
             ({
               required String videoPath,
               required Duration targetTimestamp,
               required int quality,
             }) async => null,
         blurhashGenerator: (Uint8List bytes) async => null,
         transientRenderCleaner: _NoopTransientRenderCleaner(),
         connectivityProvider: () async => UploadConnectivity.none,
         debugStateProvider: () => const <String, Object?>{},
         platformName: 'test',
         isWeb: false,
         defaultThumbnailTimestamp: Duration.zero,
       );

  int readyCount = 0;

  @override
  void onStorageReady() => readyCount++;
}

Box<PendingUpload> _emptyBox() {
  final box = _MockPendingUploadBox();
  when(() => box.isOpen).thenReturn(true);
  when(() => box.length).thenReturn(0);
  when(() => box.values).thenReturn(const <PendingUpload>[]);
  when(() => box.get(any())).thenReturn(null);
  when(() => box.put(any(), any())).thenAnswer((_) async {});
  when(() => box.delete(any())).thenAnswer((_) async {});
  return box;
}

_RecordingRepository _repository(Box<PendingUpload> box) =>
    _RecordingRepository(
      blossomService: _MockBlossomUploadService(),
      box: box,
    );

PendingUpload _upload({UploadStatus status = UploadStatus.pending}) =>
    PendingUpload.create(
      localVideoPath: '/tmp/video.mp4',
      nostrPubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ).copyWith(status: status);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePendingUpload());
  });

  group(UploadRepository, () {
    group('lifecycle', () {
      test('is not initialized before initialize', () {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);

        expect(repository.isInitialized, isFalse);
      });

      test('initialize opens storage and notifies storage handlers', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);

        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.readyCount, 1);
      });

      test(
        'initialize is idempotent and re-notifies storage handlers',
        () async {
          final repository = _repository(_emptyBox());
          addTearDown(repository.dispose);

          await repository.initialize();
          await repository.initialize();

          expect(repository.readyCount, 2);
        },
      );

      test('dispose is safe before and after initialize', () async {
        final uninitialized = _repository(_emptyBox());
        uninitialized.dispose();

        final repository = _repository(_emptyBox());
        await repository.initialize();
        repository.dispose();

        expect(repository.isInitialized, isFalse);
      });
    });

    group('queries', () {
      test('empty storage reports no uploads and zeroed stats', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        expect(repository.pendingUploads, isEmpty);
        expect(repository.uploadStats, containsPair('total', 0));
        expect(repository.uploadStats.values.every((v) => v == 0), isTrue);
      });

      test('lookups return null for unknown ids and paths', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        expect(repository.getUpload('missing'), isNull);
        expect(repository.getUploadByFilePath('/tmp/missing.mp4'), isNull);
        expect(repository.findReusableUpload('/tmp/missing.mp4'), isNull);
      });

      test(
        'in-flight and backoff probes are false for unknown uploads',
        () async {
          final repository = _repository(_emptyBox());
          addTearDown(repository.dispose);
          await repository.initialize();

          expect(repository.isUploadInFlight('missing'), isFalse);
          expect(repository.isUploadWaitingForRetryBackoff('missing'), isFalse);
        },
      );
    });

    group('error classification', () {
      test('isRetriableError follows the string fallback contract', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);

        expect(
          repository.isRetriableError(Exception('file not found')),
          isFalse,
        );
        expect(
          repository.isRetriableError(Exception('socket closed')),
          isTrue,
        );
      });

      test(
        'categorizeError reports NO_INTERNET without connectivity',
        () async {
          final repository = _repository(_emptyBox());
          addTearDown(repository.dispose);

          expect(
            await repository.categorizeError(StateError('unexpected')),
            'NO_INTERNET',
          );
        },
      );
    });

    group('mutations without a stored upload', () {
      test('retryUpload completes for an unknown upload', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        await expectLater(repository.retryUpload('missing'), completes);
      });

      test('resumeInterruptedUpload ignores an unknown upload', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        expect(
          () => repository.resumeInterruptedUpload('missing'),
          returnsNormally,
        );
      });

      test('cancelUpload completes for an unknown upload', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        await expectLater(repository.cancelUpload('missing'), completes);
      });

      test('updateUploadStatus completes for an unknown upload', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        await expectLater(
          repository.updateUploadStatus('missing', UploadStatus.published),
          completes,
        );
      });
    });

    group('cleanup delegation', () {
      test('deleteAllForOwner returns zero on empty storage', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        expect(await repository.deleteAllForOwner('owner'), 0);
      });

      test('cleanup sweeps run over empty storage', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        await expectLater(repository.cleanupCompletedUploads(), completes);
        await expectLater(repository.cleanupProblematicUploads(), completes);
      });

      test('recoverInterruptedUploads is inert before initialize', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);

        await expectLater(repository.recoverInterruptedUploads(), completes);
      });
    });

    group('diagnostics', () {
      test('getPerformanceMetrics reports no uploads', () async {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);
        await repository.initialize();

        final metrics = repository.getPerformanceMetrics();
        expect(metrics['total_uploads'], 0);
        expect(metrics['success_rate'], 0);
      });

      test('registerTransientRenderPaths accepts a path set', () {
        final repository = _repository(_emptyBox());
        addTearDown(repository.dispose);

        expect(
          () => repository.registerTransientRenderPaths('upload-1', {
            '/tmp/render.mp4',
          }),
          returnsNormally,
        );
      });

      test('startProcessingPoll arms a timer that dispose cancels', () {
        fakeAsync((async) {
          final repository = _repository(_emptyBox());

          repository.startProcessingPoll(
            _upload(status: UploadStatus.processing),
          );
          expect(async.pendingTimers, isNotEmpty);

          repository.dispose();
          expect(async.pendingTimers, isEmpty);
        });
      });
    });
  });
}
