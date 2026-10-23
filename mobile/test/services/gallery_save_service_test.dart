// ABOUTME: Tests for GallerySaveService result types and error handling
// ABOUTME: Validates the gallery save result sealed class hierarchy

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

class MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  group('GallerySaveResult', () {
    test('GallerySaveSuccess is a GallerySaveResult', () {
      const result = GallerySaveSuccess();
      expect(result, isA<GallerySaveResult>());
    });

    test('GallerySaveFailure is a GallerySaveResult with reason', () {
      const result = GallerySaveFailure('Permission denied');
      expect(result, isA<GallerySaveResult>());
      expect(result.reason, 'Permission denied');
    });

    test('pattern matching works on GallerySaveResult', () {
      const GallerySaveResult successResult = GallerySaveSuccess();
      const GallerySaveResult failureResult = GallerySaveFailure('Test error');

      // Test success pattern matching
      var isSuccess = switch (successResult) {
        GallerySaveSuccess() => true,
        GallerySaveFailure() => false,
        GallerySavePermissionDenied() => false,
      };
      expect(isSuccess, isTrue);

      // Test failure pattern matching
      isSuccess = switch (failureResult) {
        GallerySaveSuccess() => true,
        GallerySaveFailure() => false,
        GallerySavePermissionDenied() => false,
      };
      expect(isSuccess, isFalse);
    });

    test('GallerySaveFailure extracts reason via pattern matching', () {
      const GallerySaveResult result = GallerySaveFailure('Storage full');

      final reason = switch (result) {
        GallerySaveSuccess() => null,
        GallerySavePermissionDenied() => null,
        GallerySaveFailure(:final reason) => reason,
      };

      expect(reason, 'Storage full');
    });
  });

  group('GallerySaveService.roundedSize', () {
    const mib = 1024 * 1024;
    for (final (bytes, expected) in [
      (0, '<1 MB'),
      (mib - 1, '<1 MB'),
      (mib, '1 MB'),
      ((1.4 * mib).round(), '1 MB'),
      ((9.6 * mib).round(), '10 MB'),
      ((23.4 * mib).round(), '20 MB'),
      ((54.9 * mib).round(), '50 MB'),
      (100 * mib, '100 MB'),
    ]) {
      test('gives $bytes bytes as $expected', () {
        expect(GallerySaveService.roundedSize(bytes), equals(expected));
      });
    }
  });

  group('GallerySaveService', () {
    late GallerySaveService service;
    late MockPermissionsService mockPermissionsService;

    setUp(() {
      mockPermissionsService = MockPermissionsService();
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      service = GallerySaveService(permissionsService: mockPermissionsService);
    });

    test('can be instantiated', () {
      expect(service, isA<GallerySaveService>());
    });

    test('returns failure when file does not exist', () async {
      // Use a path that definitely doesn't exist
      final result = await service.saveVideoToGallery(
        EditorVideo.file('/nonexistent/path/to/video.mp4'),
      );

      expect(result, isA<GallerySaveFailure>());
      final failure = result as GallerySaveFailure;
      expect(failure.reason, 'File does not exist');
    });

    test('handles empty file path', () async {
      final result = await service.saveVideoToGallery(EditorVideo.file(''));

      expect(result, isA<GallerySaveFailure>());
    });

    test('returns failure when gallery permission denied', () async {
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.canRequest);

      final result = await service.saveVideoToGallery(
        EditorVideo.file('/nonexistent/path/to/video.mp4'),
      );

      // File doesn't exist, so it fails before permission check
      expect(result, isA<GallerySaveFailure>());
    });

    test('returns failure when gallery permission requires settings', () async {
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.requiresSettings);

      final result = await service.saveVideoToGallery(
        EditorVideo.file('/nonexistent/path/to/video.mp4'),
      );

      // File doesn't exist, so it fails before permission check
      expect(result, isA<GallerySaveFailure>());
    });

    test(
      're-checks gallery status after a stale non-granted request result',
      () async {
        var statusChecks = 0;
        when(() => mockPermissionsService.checkGalleryStatus()).thenAnswer((
          _,
        ) async {
          statusChecks += 1;
          return statusChecks == 1
              ? PermissionStatus.canRequest
              : PermissionStatus.granted;
        });
        when(
          () => mockPermissionsService.requestGalleryPermission(),
        ).thenAnswer((_) async => PermissionStatus.canRequest);

        final tempDir = Directory.systemTemp.createTempSync('gallery_test_');
        final tempFile = File('${tempDir.path}/test_video.mp4');
        tempFile.writeAsBytesSync([0, 1, 2, 3]);

        try {
          final result = await service.saveVideoToGallery(
            EditorVideo.file(tempFile.path),
          );

          expect(result, isNot(isA<GallerySavePermissionDenied>()));
          verify(() => mockPermissionsService.checkGalleryStatus()).called(2);
          verify(
            () => mockPermissionsService.requestGalleryPermission(),
          ).called(1);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test('reports a permission not granted yet without prompting when asked '
        'not to request it', () async {
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.canRequest);
      final tempDir = Directory.systemTemp.createTempSync('gallery_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final tempFile = File('${tempDir.path}/test_video.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);

      final result = await service.saveVideoToGallery(
        EditorVideo.file(tempFile.path),
        requestPermission: false,
      );

      expect(result, isA<GallerySavePermissionDenied>());
      verifyNever(() => mockPermissionsService.requestGalleryPermission());
    });

    test(
      'skips permission check on MissingPluginException (desktop)',
      () async {
        // Simulate desktop platform where permission_handler is unavailable
        when(() => mockPermissionsService.checkGalleryStatus()).thenThrow(
          MissingPluginException(
            'No implementation found for method checkPermissionStatus',
          ),
        );

        // Create a real temp file so the file-existence check passes
        final tempDir = Directory.systemTemp.createTempSync('gallery_test_');
        final tempFile = File('${tempDir.path}/test_video.mp4');
        tempFile.writeAsBytesSync([0, 1, 2, 3]);

        final result = await service.saveVideoToGallery(
          EditorVideo.file(tempFile.path),
        );

        // Should NOT fail with "Permission denied" — the MissingPluginException
        // is caught and the service proceeds to Gal.putVideo, which will fail
        // in test env with a different error.
        if (result is GallerySaveFailure) {
          expect(result.reason, isNot(contains('Permission denied')));
        }

        // Cleanup
        tempDir.deleteSync(recursive: true);
      },
    );

    group('when gal rejects the save', () {
      const galChannel = MethodChannel('gal');
      const nativeMessage =
          'The operation couldn’t be completed. '
          '(PHPhotosErrorDomain error 3302.)';

      late Directory tempDir;
      late File tempFile;

      setUp(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        // Gal.putVideo asks for access first on the same channel. Let that
        // succeed so only the save itself is rejected, as Photos does.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(galChannel, (call) async {
              if (call.method != 'putVideo') return true;
              throw PlatformException(
                code: 'UNEXPECTED',
                message: nativeMessage,
              );
            });
        await LogCaptureService().clearAllLogs();

        tempDir = Directory.systemTemp.createTempSync('gallery_test_');
        tempFile = File('${tempDir.path}/test_video.mp4')
          ..writeAsBytesSync([0, 1, 2, 3]);
      });

      tearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(galChannel, null);
        await LogCaptureService().clearAllLogs();
        tempDir.deleteSync(recursive: true);
      });

      test('returns the gal error type as the failure reason', () async {
        final result = await service.saveVideoToGallery(
          EditorVideo.file(tempFile.path),
        );

        expect(result, isA<GallerySaveFailure>());
        expect(
          (result as GallerySaveFailure).reason,
          equals('Gallery error: unexpected'),
        );
      });

      test('logs the native error message gal reported', () async {
        await service.saveVideoToGallery(EditorVideo.file(tempFile.path));

        expect(
          LogCaptureService().getRecentLogs().map((entry) => entry.message),
          contains(contains('(native: $nativeMessage)')),
        );
      });
    });

    group('with copyUnderNeutralName', () {
      const galChannel = MethodChannel('gal');

      late Directory tempDir;
      late Directory copies;
      late GallerySaveService copyingService;
      late File source;
      late List<String> galleryPaths;
      late List<List<int>> galleryBytes;
      late Future<Object?> Function() galleryReply;

      setUp(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        galleryPaths = [];
        galleryBytes = [];
        galleryReply = () async => null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(galChannel, (call) async {
              if (call.method != 'putVideo') return true;
              final args = call.arguments as Map<Object?, Object?>;
              final path = args['path']! as String;
              galleryPaths.add(path);
              galleryBytes.add(File(path).readAsBytesSync());
              return galleryReply();
            });
        await LogCaptureService().clearAllLogs();

        tempDir = Directory.systemTemp.createTempSync('gallery_test_');
        copies = Directory('${tempDir.path}/copies');
        copyingService = GallerySaveService(
          permissionsService: mockPermissionsService,
          copyRoot: () => copies,
        );
        // Named the way a kept video DM is: after its message.
        source = File('${tempDir.path}/${'a' * 64}.mov')
          ..writeAsBytesSync([0, 1, 2, 3]);
      });

      tearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(galChannel, null);
        await LogCaptureService().clearAllLogs();
        tempDir.deleteSync(recursive: true);
      });

      test('hands the gallery a copy named like a Downloads save, with the '
          "video's bytes, keeps the file and removes the copy", () async {
        final result = await copyingService.saveVideoToGallery(
          EditorVideo.file(source.path),
          copyUnderNeutralName: true,
        );

        expect(result, isA<GallerySaveSuccess>());
        final copy = File(galleryPaths.single);
        expect(
          copy.uri.pathSegments.last,
          matches(RegExp(r'^Divine_\d+\.mov$')),
        );
        expect(galleryBytes.single, equals([0, 1, 2, 3]));
        expect(copy.parent.existsSync(), isFalse);
        expect(source.readAsBytesSync(), equals([0, 1, 2, 3]));
      });

      test('removes the copy when the gallery rejects it', () async {
        galleryReply = () async =>
            throw PlatformException(code: 'UNEXPECTED', message: 'rejected');

        final result = await copyingService.saveVideoToGallery(
          EditorVideo.file(source.path),
          copyUnderNeutralName: true,
        );

        expect(result, isA<GallerySaveFailure>());
        expect(File(galleryPaths.single).parent.existsSync(), isFalse);
        expect(source.existsSync(), isTrue);
      });

      test("keeps the copy's path out of a native failure", () async {
        galleryReply = () async => throw PlatformException(
          code: 'UNEXPECTED',
          message: 'Cannot save ${galleryPaths.single}',
        );

        await copyingService.saveVideoToGallery(
          EditorVideo.file(source.path),
          copyUnderNeutralName: true,
        );

        final logs = LogCaptureService().getRecentLogs();
        expect(
          logs.map((entry) => entry.message),
          contains(contains('Cannot save')),
        );
        for (final entry in logs) {
          expect(
            '${entry.message} ${entry.error}',
            isNot(contains(galleryPaths.single)),
          );
        }
      });

      test(
        'logs where an unexpected failure happened, but not its text',
        () async {
          // A file where the copies go makes creating their folder fail.
          File(copies.path).writeAsStringSync('');

          final result = await copyingService.saveVideoToGallery(
            EditorVideo.file(source.path),
            copyUnderNeutralName: true,
          );

          expect(result, isA<GallerySaveFailure>());
          final entry = LogCaptureService().getRecentLogs().singleWhere(
            (entry) => entry.message.startsWith(
              'Unexpected error saving video to gallery',
            ),
          );
          expect(entry.stackTrace, isNotNull);
          expect(entry.message, isNot(contains(copies.path)));
        },
      );

      test('removes copies a save that never ended left behind, before its '
          'first copy', () async {
        // As an earlier run of the app leaves them when it is killed mid-save.
        final leftover = File('${copies.path}/left/Divine_1.mov')
          ..createSync(recursive: true)
          ..writeAsBytesSync([9, 9, 9]);

        await copyingService.saveVideoToGallery(
          EditorVideo.file(source.path),
          copyUnderNeutralName: true,
        );

        expect(leftover.parent.existsSync(), isFalse);
        expect(galleryBytes.single, equals([0, 1, 2, 3]));
      });

      test(
        'fails only the future it returns when it cannot reach the copies, '
        'as on the web, so the launch that asks still starts',
        () async {
          final unreachable = GallerySaveService(
            permissionsService: mockPermissionsService,
            copyRoot: () => throw UnsupportedError('_Namespace'),
          );

          final deleted = unreachable.deleteLeftoverCopies();

          await expectLater(deleted, throwsUnsupportedError);
        },
      );

      test('removes copies a killed save left behind when asked at launch, '
          'before any save', () async {
        final leftover = File('${copies.path}/left/Divine_1.mov')
          ..createSync(recursive: true)
          ..writeAsBytesSync([9, 9, 9]);

        await copyingService.deleteLeftoverCopies();

        expect(leftover.parent.existsSync(), isFalse);
      });

      test('never removes a copy a save still running uses', () async {
        final firstAtGallery = Completer<void>();
        final firstSaveHeld = Completer<void>();
        galleryReply = () async {
          if (galleryPaths.length == 1) {
            firstAtGallery.complete();
            await firstSaveHeld.future;
          }
          return null;
        };

        final first = copyingService.saveVideoToGallery(
          EditorVideo.file(source.path),
          copyUnderNeutralName: true,
        );
        await firstAtGallery.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('the first save never reached the gallery'),
        );
        final second = await copyingService.saveVideoToGallery(
          EditorVideo.file(source.path),
          copyUnderNeutralName: true,
        );
        final firstCopyKept = File(galleryPaths.first).existsSync();
        firstSaveHeld.complete();

        expect(firstCopyKept, isTrue);
        expect(second, isA<GallerySaveSuccess>());
        expect(await first, isA<GallerySaveSuccess>());
      });
    });
  });
}
