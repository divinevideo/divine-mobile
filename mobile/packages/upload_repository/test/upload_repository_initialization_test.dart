import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:upload_repository/upload_repository.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockPendingUploadBox extends Mock implements Box<PendingUpload> {}

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

class _HookRecordingUploadRepository extends UploadRepository {
  _HookRecordingUploadRepository({
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

void main() {
  group(UploadRepository, () {
    group('lazy initialization', () {
      test('notifies the facade when startUpload opens storage', () async {
        final box = _MockPendingUploadBox();
        when(() => box.isOpen).thenReturn(true);
        final repository = _HookRecordingUploadRepository(
          blossomService: _MockBlossomUploadService(),
          box: box,
        );
        addTearDown(repository.dispose);

        await expectLater(
          repository.startUpload(
            videoFile: File('/tmp/unsupported.webm'),
            nostrPubkey:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
          throwsA(isA<Exception>()),
        );

        expect(repository.readyCount, 1);
        expect(repository.isInitialized, isTrue);
      });
    });
  });
}
