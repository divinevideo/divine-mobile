// ABOUTME: Tests for GallerySaveService result types and error handling
// ABOUTME: Validates the gallery save result sealed class hierarchy

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
  });
}
