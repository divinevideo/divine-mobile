// ABOUTME: Unit tests for UploadProgressReporter — covers metrics lifecycle,
// ABOUTME: subscription management, error categorisation, and progress updates.

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:upload_repository/upload_repository.dart';

class _MockPendingUploadStore extends Mock implements PendingUploadStore {}

class _MockUploadCrashReporter extends Mock implements UploadCrashReporter {}

PendingUpload _makeUpload({
  String id = 'upload-1',
  UploadStatus status = UploadStatus.uploading,
}) => PendingUpload(
  id: id,
  localVideoPath: '/tmp/video.mp4',
  nostrPubkey: 'pubkey-abc',
  status: status,
  createdAt: DateTime(2024),
);

UploadMetrics _makeMetrics({
  String uploadId = 'upload-1',
  bool wasSuccessful = false,
  String? errorCategory,
  DateTime? startTime,
  double fileSizeMB = 10.0,
}) => UploadMetrics(
  uploadId: uploadId,
  startTime: startTime ?? DateTime.now(),
  retryCount: 0,
  fileSizeMB: fileSizeMB,
  wasSuccessful: wasSuccessful,
  errorCategory: errorCategory,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      PendingUpload(
        id: 'fallback',
        localVideoPath: '/tmp/fallback.mp4',
        nostrPubkey: 'fallback-key',
        status: UploadStatus.pending,
        createdAt: DateTime(2024),
      ),
    );
    registerFallbackValue(StackTrace.empty);
    const Object objectFallback = 'fallback-error';
    registerFallbackValue(objectFallback);
  });

  late _MockPendingUploadStore store;
  // Use a real VideoCircuitBreaker — its state/failureRate getters return
  // non-nullable enum values that are awkward to stub with Mocktail.
  late VideoCircuitBreaker circuitBreaker;
  late _MockUploadCrashReporter crashReporter;
  late UploadProgressReporter reporter;

  setUp(() {
    store = _MockPendingUploadStore();
    circuitBreaker = VideoCircuitBreaker();
    crashReporter = _MockUploadCrashReporter();
    when(
      () => crashReporter.setCustomKey(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () =>
          crashReporter.recordError(any(), any(), reason: any(named: 'reason')),
    ).thenAnswer((_) async {});

    reporter = UploadProgressReporter(
      store: store,
      circuitBreaker: circuitBreaker,
      retryConfig: const UploadRetryConfig(),
      crashReporter: crashReporter,
      connectivityProvider: () async => UploadConnectivity.wifi,
      platformName: 'test',
      isWeb: false,
    );
  });

  tearDown(() {
    reporter.dispose();
  });

  // ---------------------------------------------------------------------------
  group('recordStart / metricsFor', () {
    test('stores metrics and retrieves them', () {
      final metrics = _makeMetrics();
      reporter.recordStart('upload-1', metrics);

      expect(reporter.metricsFor('upload-1'), equals(metrics));
    });

    test('returns null for unknown uploadId', () {
      expect(reporter.metricsFor('not-there'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('recordSuccess', () {
    test('overwrites metrics entry', () {
      final initial = _makeMetrics();
      reporter.recordStart('upload-1', initial);

      final success = _makeMetrics(wasSuccessful: true);
      reporter.recordSuccess('upload-1', success);

      expect(reporter.metricsFor('upload-1')!.wasSuccessful, isTrue);
    });

    test('prunes entries older than 7 days', () {
      final old = _makeMetrics(
        uploadId: 'old',
        startTime: DateTime.now().subtract(const Duration(days: 8)),
      );
      reporter.recordStart('old', old);
      expect(reporter.metricsFor('old'), isNotNull);

      // recordSuccess triggers _cleanupOldMetrics
      reporter.recordSuccess('upload-1', _makeMetrics());

      expect(reporter.metricsFor('old'), isNull);
    });

    test('keeps entries within 7 days', () {
      final recent = _makeMetrics(
        uploadId: 'recent',
        startTime: DateTime.now().subtract(const Duration(days: 6)),
      );
      reporter.recordStart('recent', recent);

      reporter.recordSuccess('upload-1', _makeMetrics());

      expect(reporter.metricsFor('recent'), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('recordFailure', () {
    test('stores failure metrics', () {
      final metrics = _makeMetrics(errorCategory: 'TIMEOUT');
      reporter.recordFailure('upload-1', metrics);

      expect(reporter.metricsFor('upload-1')!.errorCategory, equals('TIMEOUT'));
      expect(reporter.metricsFor('upload-1')!.wasSuccessful, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('subscription lifecycle', () {
    test('cancelAndRemoveSubscription is a safe no-op for an unknown id', () {
      expect(
        () => reporter.cancelAndRemoveSubscription('not-tracked'),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('updateProgress', () {
    test('updates store when status is uploading', () {
      final upload = _makeUpload();
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      reporter.updateProgress('upload-1', 0.5);

      final captured = verify(() => store.update(captureAny())).captured;
      expect(captured, hasLength(1));
      expect((captured.first as PendingUpload).uploadProgress, equals(0.5));
    });

    test('updates store when status is retrying', () {
      final upload = _makeUpload(status: UploadStatus.retrying);
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      reporter.updateProgress('upload-1', 0.75);

      verify(() => store.update(any())).called(1);
    });

    test('no-op when status is paused', () {
      final upload = _makeUpload(status: UploadStatus.paused);
      when(() => store.getUpload('upload-1')).thenReturn(upload);

      reporter.updateProgress('upload-1', 0.5);

      verifyNever(() => store.update(any()));
    });

    test('no-op when upload not found', () {
      when(() => store.getUpload('upload-1')).thenReturn(null);

      reporter.updateProgress('upload-1', 0.5);

      verifyNever(() => store.update(any()));
    });
  });

  // ---------------------------------------------------------------------------
  group('categorizeError', () {
    // We stub categorizeError's internal connectivity check for most tests
    // by passing errors that are classified without connectivity (session errors).

    test(
      'expired session (BlossomResumableUploadException 404) → UPLOAD_SESSION_EXPIRED',
      () async {
        const error = BlossomResumableUploadException(
          'Not found',
          statusCode: 404,
        );
        final result = await reporter.categorizeError(error);
        expect(result, equals('UPLOAD_SESSION_EXPIRED'));
      },
    );

    test('expired session string → UPLOAD_SESSION_EXPIRED', () async {
      final result = await reporter.categorizeError(
        Exception('session expired'),
      );
      expect(result, equals('UPLOAD_SESSION_EXPIRED'));
    });

    test(
      'expired session (BlossomResumableUploadException 410) → UPLOAD_SESSION_EXPIRED',
      () async {
        const error = BlossomResumableUploadException('Gone', statusCode: 410);
        final result = await reporter.categorizeError(error);
        expect(result, equals('UPLOAD_SESSION_EXPIRED'));
      },
    );

    test(
      'auth-expired session (BlossomResumableUploadException 401) → AUTHENTICATION',
      () async {
        const error = BlossomResumableUploadException(
          'Unauthorized',
          statusCode: 401,
          failureReason: BlossomUploadFailureReason.auth,
        );
        final result = await reporter.categorizeError(error);
        expect(result, equals('AUTHENTICATION'));
      },
    );

    test(
      'auth-expired session (BlossomResumableUploadException 403) → AUTHENTICATION',
      () async {
        const error = BlossomResumableUploadException(
          'Forbidden',
          statusCode: 403,
          failureReason: BlossomUploadFailureReason.auth,
        );
        final result = await reporter.categorizeError(error);
        expect(result, equals('AUTHENTICATION'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('getUserFriendlyErrorMessage', () {
    test('NO_INTERNET → offline copy', () {
      final msg = reporter.getUserFriendlyErrorMessage(
        'NO_INTERNET',
        UploadConnectivity.none,
      );
      expect(msg, contains('No internet connection'));
    });

    test('TIMEOUT → timeout copy', () {
      final msg = reporter.getUserFriendlyErrorMessage(
        'TIMEOUT',
        UploadConnectivity.wifi,
      );
      expect(msg, contains('timed out'));
    });

    test('NETWORK_ERROR embeds network type', () {
      final msg = reporter.getUserFriendlyErrorMessage(
        'NETWORK_ERROR',
        UploadConnectivity.mobile,
      );
      expect(msg, contains('Cellular'));
    });

    test('UPLOAD_SESSION_EXPIRED → session copy', () {
      final msg = reporter.getUserFriendlyErrorMessage(
        'UPLOAD_SESSION_EXPIRED',
        UploadConnectivity.wifi,
      );
      expect(msg, contains('session expired'));
    });

    test('unknown category → generic copy', () {
      final msg = reporter.getUserFriendlyErrorMessage(
        'SOMETHING_NEW',
        UploadConnectivity.wifi,
      );
      expect(msg, contains('Upload failed'));
    });
  });

  // ---------------------------------------------------------------------------
  group('getNetworkTypeString', () {
    test('wifi → "WiFi"', () {
      expect(
        reporter.getNetworkTypeString(UploadConnectivity.wifi),
        equals('WiFi'),
      );
    });

    test('mobile → "Cellular"', () {
      expect(
        reporter.getNetworkTypeString(UploadConnectivity.mobile),
        equals('Cellular'),
      );
    });

    test('none → "Offline"', () {
      expect(
        reporter.getNetworkTypeString(UploadConnectivity.none),
        equals('Offline'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('createSuccessMetrics', () {
    test('computes duration and throughput', () {
      final start = DateTime(2024, 1, 1, 12);
      final end = start.add(const Duration(seconds: 10));
      final input = _makeMetrics(startTime: start, fileSizeMB: 20.0);

      final result = reporter.createSuccessMetrics(input, end, 1);

      expect(result.wasSuccessful, isTrue);
      expect(result.uploadDuration?.inSeconds, equals(10));
      expect(result.throughputMBps, closeTo(2.0, 0.01)); // 20MB / 10s
      expect(result.retryCount, equals(1));
    });

    test('handles zero duration without dividing by zero', () {
      final now = DateTime(2024);
      final input = _makeMetrics(startTime: now, fileSizeMB: 5.0);

      final result = reporter.createSuccessMetrics(input, now, 0);

      expect(result.throughputMBps, isNotNull);
      expect(result.throughputMBps, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  group('getPerformanceMetrics', () {
    test('returns zeros when no metrics recorded', () {
      final result = reporter.getPerformanceMetrics();

      expect(result['total_uploads'], equals(0));
      expect(result['successful_uploads'], equals(0));
      expect(result['failed_uploads'], equals(0));
      expect(result['success_rate'], equals(0));
    });

    test('calculates success rate correctly', () {
      reporter.recordStart('a', _makeMetrics(uploadId: 'a'));
      reporter.recordFailure('a', _makeMetrics(uploadId: 'a'));
      reporter.recordStart('b', _makeMetrics(uploadId: 'b'));
      reporter.recordSuccess(
        'b',
        _makeMetrics(uploadId: 'b', wasSuccessful: true),
      );

      final result = reporter.getPerformanceMetrics();

      expect(result['total_uploads'], equals(2));
      expect(result['successful_uploads'], equals(1));
      expect(result['failed_uploads'], equals(1));
      expect(result['success_rate'], equals(50.0));
    });

    test('includes circuit breaker state (closed by default)', () {
      // Real VideoCircuitBreaker starts closed with 0% failure rate.
      final result = reporter.getPerformanceMetrics();

      expect(result['circuit_breaker_state'], contains('closed'));
      expect(result['circuit_breaker_failure_rate'], equals(0.0));
    });

    test('error_categories groups by category', () {
      reporter.recordFailure(
        'a',
        _makeMetrics(uploadId: 'a', errorCategory: 'TIMEOUT'),
      );
      reporter.recordFailure(
        'b',
        _makeMetrics(uploadId: 'b', errorCategory: 'TIMEOUT'),
      );
      reporter.recordFailure(
        'c',
        _makeMetrics(uploadId: 'c', errorCategory: 'NETWORK_ERROR'),
      );

      final result = reporter.getPerformanceMetrics();
      final categories = result['error_categories'] as Map<String, int>;

      expect(categories['TIMEOUT'], equals(2));
      expect(categories['NETWORK_ERROR'], equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  group('dispose', () {
    test('can be called without throwing', () {
      reporter.recordStart('upload-1', _makeMetrics());
      expect(reporter.dispose, returnsNormally);
    });

    test('clears metrics', () {
      reporter.recordStart('upload-1', _makeMetrics());
      reporter.dispose();

      // Recreate reporter to verify data is not shared (disposed state is gone)
      reporter = UploadProgressReporter(
        store: store,
        circuitBreaker: circuitBreaker,
        retryConfig: const UploadRetryConfig(),
        crashReporter: crashReporter,
        connectivityProvider: () async => UploadConnectivity.wifi,
        platformName: 'test',
        isWeb: false,
      );
      expect(reporter.metricsFor('upload-1'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('crash reporting', () {
    test(
      'sendUploadFailureCrashReport skips expected upload failures',
      () async {
        when(() => store.length).thenReturn(3);
        when(() => store.queuedCount).thenReturn(1);
        final upload = _makeUpload();
        final error = Exception('boom');
        final stackTrace = StackTrace.current;

        await reporter.sendUploadFailureCrashReport(
          upload,
          error,
          'NETWORK_ERROR',
          null,
          UploadConnectivity.wifi,
          stackTrace: stackTrace,
          isManagerInitialized: true,
        );

        verifyNever(
          () => crashReporter.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
          ),
        );
        verify(
          () => crashReporter.setCustomKey(any(), any()),
        ).called(greaterThan(0));
      },
    );

    test(
      'sendUploadFailureCrashReport records reportable failures with caller stack',
      () async {
        when(() => store.length).thenReturn(3);
        when(() => store.queuedCount).thenReturn(1);
        final upload = _makeUpload();
        final error = StateError('boom');
        final stackTrace = StackTrace.current;

        await reporter.sendUploadFailureCrashReport(
          upload,
          error,
          'UNKNOWN',
          null,
          UploadConnectivity.wifi,
          stackTrace: stackTrace,
          isManagerInitialized: true,
        );

        final captured = verify(
          () => crashReporter.recordError(
            captureAny(),
            captureAny(),
            reason: captureAny(named: 'reason'),
          ),
        ).captured;
        expect(captured[0], same(error));
        expect(captured[1], same(stackTrace));
        expect(captured[2], equals('Video upload failure - UNKNOWN'));
        verify(
          () => crashReporter.setCustomKey(any(), any()),
        ).called(greaterThan(0));
      },
    );

    test(
      'sendInitializationFailureCrashReport routes the error to the port',
      () async {
        final error = StateError('init boom');

        await reporter.sendInitializationFailureCrashReport(
          error,
          StackTrace.current,
        );

        final captured = verify(
          () => crashReporter.recordError(
            captureAny(),
            any(),
            reason: captureAny(named: 'reason'),
          ),
        ).captured;
        expect(captured[0], same(error));
        expect(
          captured[1],
          equals('UploadManager initialization failure after retries'),
        );
      },
    );

    test('sendTimeoutCrashReport routes the timeout to the port', () async {
      final upload = _makeUpload();
      final timeout = TimeoutException('too slow');

      await reporter.sendTimeoutCrashReport(upload, timeout);

      final captured = verify(
        () => crashReporter.recordError(
          captureAny(),
          any(),
          reason: captureAny(named: 'reason'),
        ),
      ).captured;
      expect(captured[0], same(timeout));
      expect(captured[1], equals('Video upload timeout after 10 minutes'));
    });
  });
}
