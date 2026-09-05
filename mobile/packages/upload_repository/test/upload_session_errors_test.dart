// ABOUTME: Unit tests for the shared isExpiredResumableSessionError predicate
// ABOUTME: used by UploadRetryPolicy, UploadProgressReporter, and UploadManager.

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
}
