// ABOUTME: Unit tests for the shared upload failure types and the
// ABOUTME: isExpiredResumableSessionError predicate used across the package.

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

void main() {
  group('isExpiredResumableSessionError', () {
    test('BlossomResumableUploadException 404 → true', () {
      expect(
        isExpiredResumableSessionError(
          const BlossomResumableUploadException('Not found', statusCode: 404),
        ),
        isTrue,
      );
    });

    test('BlossomResumableUploadException 410 → true', () {
      expect(
        isExpiredResumableSessionError(
          const BlossomResumableUploadException('Gone', statusCode: 410),
        ),
        isTrue,
      );
    });

    test('BlossomResumableUploadException 401 → true', () {
      expect(
        isExpiredResumableSessionError(
          const BlossomResumableUploadException(
            'Unauthorized',
            statusCode: 401,
          ),
        ),
        isTrue,
      );
    });

    test('BlossomResumableUploadException 403 → true', () {
      expect(
        isExpiredResumableSessionError(
          const BlossomResumableUploadException('Forbidden', statusCode: 403),
        ),
        isTrue,
      );
    });

    test('BlossomResumableUploadException 500 → false', () {
      expect(
        isExpiredResumableSessionError(
          const BlossomResumableUploadException(
            'Server error',
            statusCode: 500,
          ),
        ),
        isFalse,
      );
    });

    test('"session expired" string → true', () {
      expect(
        isExpiredResumableSessionError(Exception('session expired')),
        isTrue,
      );
    });

    test('"session is no longer available" string → true', () {
      expect(
        isExpiredResumableSessionError(
          Exception('session is no longer available'),
        ),
        isTrue,
      );
    });

    test('generic network error → false', () {
      expect(
        isExpiredResumableSessionError(Exception('network error')),
        isFalse,
      );
    });
  });

  group(ThumbnailUploadException, () {
    group('fromUploadResult', () {
      test('keeps the server status, reason and message', () {
        final error = ThumbnailUploadException.fromUploadResult(
          const BlossomUploadResult(
            success: false,
            statusCode: 503,
            errorMessage: 'Upload failed: 503 - overloaded',
            failureReason: BlossomUploadFailureReason.server,
          ),
        );

        expect(error.stage, ThumbnailUploadFailureStage.upload);
        expect(error.statusCode, 503);
        expect(error.failureReason, BlossomUploadFailureReason.server);
        expect(
          error.toString(),
          'Thumbnail upload failed (upload): Upload failed: 503 - overloaded',
        );
      });

      test('names the missing URL when the server sent no message', () {
        final error = ThumbnailUploadException.fromUploadResult(
          const BlossomUploadResult(success: true),
        );

        expect(error.cause, 'the server returned no URL');
      });
    });

    group('isTransient', () {
      ThumbnailUploadException uploadFailure({
        int? statusCode,
        BlossomUploadFailureReason? failureReason,
        bool isTransientNetworkFailure = false,
      }) => ThumbnailUploadException(
        ThumbnailUploadFailureStage.upload,
        'failed',
        statusCode: statusCode,
        failureReason: failureReason,
        isTransientNetworkFailure: isTransientNetworkFailure,
      );

      for (final statusCode in [408, 429, 500, 502, 503, 504]) {
        test('$statusCode → true', () {
          expect(uploadFailure(statusCode: statusCode).isTransient, isTrue);
        });
      }

      for (final statusCode in [400, 401, 403, 413, 501]) {
        test('$statusCode → false', () {
          expect(uploadFailure(statusCode: statusCode).isTransient, isFalse);
        });
      }

      test('a dropped connection → true', () {
        expect(
          uploadFailure(isTransientNetworkFailure: true).isTransient,
          isTrue,
        );
      });

      test('a network or signer reason → true', () {
        expect(
          uploadFailure(
            failureReason: BlossomUploadFailureReason.network,
          ).isTransient,
          isTrue,
        );
        expect(
          uploadFailure(
            failureReason: BlossomUploadFailureReason.authUnavailable,
          ).isTransient,
          isTrue,
        );
      });

      test('an unclassified upload failure → false', () {
        expect(
          uploadFailure(
            failureReason: BlossomUploadFailureReason.unknown,
          ).isTransient,
          isFalse,
        );
      });

      test('an extraction failure → false', () {
        expect(
          const ThumbnailUploadException(
            ThumbnailUploadFailureStage.extraction,
            'no frame',
            isTransientNetworkFailure: true,
          ).isTransient,
          isFalse,
        );
      });
    });
  });
}
