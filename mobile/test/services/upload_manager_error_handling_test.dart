// ABOUTME: Tests for upload error categorization, retry logic,
// ABOUTME: and user-friendly error messages in UploadManager.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBlossomUploadService mockBlossomService;
  late UploadManager uploadManager;
  late Directory testDir;

  /// Mock the connectivity plugin to return [result].
  void mockConnectivity(String result) {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'check') return [result];
          return null;
        });
  }

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp(
      'upload_manager_error_test_',
    );

    Hive.init(testDir.path);

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }

    mockBlossomService = _MockBlossomUploadService();
    uploadManager = UploadManager(
      backgroundActivityManager: BackgroundActivityManager(),
      blossomService: mockBlossomService,
    );

    mockConnectivity('wifi');
  });

  tearDown(() async {
    uploadManager.dispose();
    try {
      await Hive.close();
    } on PathNotFoundException catch (_) {
      // Hive may already have removed the lock file during async shutdown.
    }
    try {
      await testDir.delete(recursive: true);
    } on PathNotFoundException catch (_) {
      // Lock file may already be deleted by Hive.close().
    }
  });

  group(BlossomUploadFailureException, () {
    test('stores message and statusCode', () {
      const exception = BlossomUploadFailureException(
        'Server error',
        statusCode: 502,
      );

      expect(exception.message, equals('Server error'));
      expect(exception.statusCode, equals(502));
    });

    test('toString returns message', () {
      const exception = BlossomUploadFailureException('Bad gateway');

      expect(exception.toString(), equals('Bad gateway'));
    });

    test('statusCode defaults to null', () {
      const exception = BlossomUploadFailureException('Unknown');

      expect(exception.statusCode, isNull);
    });
  });

  group('isRetriableError', () {
    group('BlossomUploadFailureException with statusCode', () {
      test('returns true for 408 request timeout', () {
        const error = BlossomUploadFailureException(
          'Request Timeout',
          statusCode: 408,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 429 rate limited', () {
        const error = BlossomUploadFailureException(
          'Rate limited',
          statusCode: 429,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 500 internal server error', () {
        const error = BlossomUploadFailureException(
          'Internal Server Error',
          statusCode: 500,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 502 bad gateway', () {
        const error = BlossomUploadFailureException(
          'Bad Gateway',
          statusCode: 502,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 503 service unavailable', () {
        const error = BlossomUploadFailureException(
          'Service Unavailable',
          statusCode: 503,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 504 gateway timeout', () {
        const error = BlossomUploadFailureException(
          'Gateway Timeout',
          statusCode: 504,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns false for 501 not implemented', () {
        const error = BlossomUploadFailureException(
          'Not Implemented',
          statusCode: 501,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 505 http version not supported', () {
        const error = BlossomUploadFailureException(
          'HTTP Version Not Supported',
          statusCode: 505,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 400 bad request', () {
        const error = BlossomUploadFailureException(
          'Bad Request',
          statusCode: 400,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 401 unauthorized', () {
        const error = BlossomUploadFailureException(
          'Unauthorized',
          statusCode: 401,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 403 forbidden', () {
        const error = BlossomUploadFailureException(
          'Forbidden',
          statusCode: 403,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 404 not found', () {
        const error = BlossomUploadFailureException(
          'Not Found',
          statusCode: 404,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 413 payload too large', () {
        const error = BlossomUploadFailureException(
          'Payload Too Large',
          statusCode: 413,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });
    });

    group('BlossomUploadFailureException without statusCode', () {
      test('falls back to string matching for timeout', () {
        const error = BlossomUploadFailureException('Connection timeout');

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('falls back to string matching for network error', () {
        const error = BlossomUploadFailureException(
          'Network error: connection refused',
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });
    });

    group('BlossomUploadFailureException with failureReason', () {
      test('returns true for authUnavailable (signer briefly unreachable)', () {
        // The regression this fixes: a momentary signer DNS blip leaves
        // the auth header un-creatable. statusCode is null, so without the
        // typed reason the old "Failed to create Blossom authentication"
        // string matched contains('auth') and killed the retry forever.
        const error = BlossomUploadFailureException(
          'Failed to create Blossom authentication',
          failureReason: BlossomUploadFailureReason.authUnavailable,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for network reason', () {
        const error = BlossomUploadFailureException(
          'Cannot connect to Blossom server',
          failureReason: BlossomUploadFailureReason.network,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns false for a permanent auth rejection (no statusCode)', () {
        // The "not authenticated" path: the user genuinely has no signer.
        const error = BlossomUploadFailureException(
          'User not authenticated - please sign in to upload',
          failureReason: BlossomUploadFailureReason.auth,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for fileTooLarge reason', () {
        const error = BlossomUploadFailureException(
          'Server error (413)',
          failureReason: BlossomUploadFailureReason.fileTooLarge,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });
    });

    group('generic exceptions (string matching fallback)', () {
      test('returns true for timeout errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Connection timeout')),
          isTrue,
        );
      });

      test('returns true for connection errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Cannot connect to server')),
          isTrue,
        );
      });

      test('returns true for socket errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Socket closed')),
          isTrue,
        );
      });

      test('returns false for required thumbnail upload failures', () {
        expect(
          uploadManager.isRetriableError(StateError('Thumbnail upload failed')),
          isFalse,
        );
      });

      test('returns false for file not found', () {
        expect(
          uploadManager.isRetriableError(Exception('File not found')),
          isFalse,
        );
      });

      test(
        'returns true for a bare auth string with no structured classification',
        () {
          // The substring "auth" no longer gates retries: a permanent
          // rejection now arrives as a 401/403 statusCode or a typed
          // failureReason (see the structured group below). A bare string
          // is ambiguous, so it falls through to retriable-by-default —
          // biasing toward retry rather than permanently killing the upload.
          expect(
            uploadManager.isRetriableError(Exception('Authentication failed')),
            isTrue,
          );
        },
      );

      test('returns false for permission errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Permission denied')),
          isFalse,
        );
      });

      test('returns true for unknown errors by default', () {
        expect(
          uploadManager.isRetriableError(Exception('Something unexpected')),
          isTrue,
        );
      });
    });
  });

  group('categorizeError', () {
    group('BlossomUploadFailureException with statusCode', () {
      test('returns TIMEOUT for 408', () async {
        const error = BlossomUploadFailureException(
          'Request Timeout',
          statusCode: 408,
        );

        expect(await uploadManager.categorizeError(error), equals('TIMEOUT'));
      });

      test('returns FILE_TOO_LARGE for 413', () async {
        const error = BlossomUploadFailureException(
          'Payload Too Large',
          statusCode: 413,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('FILE_TOO_LARGE'),
        );
      });

      test('returns RATE_LIMITED for 429', () async {
        const error = BlossomUploadFailureException(
          'Too Many Requests',
          statusCode: 429,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('RATE_LIMITED'),
        );
      });

      test('returns AUTHENTICATION for 401', () async {
        const error = BlossomUploadFailureException(
          'Unauthorized',
          statusCode: 401,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('AUTHENTICATION'),
        );
      });

      test('returns AUTHENTICATION for 403', () async {
        const error = BlossomUploadFailureException(
          'Forbidden',
          statusCode: 403,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('AUTHENTICATION'),
        );
      });

      test('returns SERVER_UNAVAILABLE for 502', () async {
        const error = BlossomUploadFailureException(
          'Bad Gateway',
          statusCode: 502,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_UNAVAILABLE'),
        );
      });

      test('returns SERVER_UNAVAILABLE for 503', () async {
        const error = BlossomUploadFailureException(
          'Service Unavailable',
          statusCode: 503,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_UNAVAILABLE'),
        );
      });

      test('returns SERVER_UNAVAILABLE for 504', () async {
        const error = BlossomUploadFailureException(
          'Gateway Timeout',
          statusCode: 504,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_UNAVAILABLE'),
        );
      });

      test('returns SERVER_ERROR for 500', () async {
        const error = BlossomUploadFailureException(
          'Internal Server Error',
          statusCode: 500,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_ERROR'),
        );
      });

      test('returns SERVER_ERROR for 501', () async {
        const error = BlossomUploadFailureException(
          'Not Implemented',
          statusCode: 501,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_ERROR'),
        );
      });

      test('returns CLIENT_ERROR for 400', () async {
        const error = BlossomUploadFailureException(
          'Bad Request',
          statusCode: 400,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('CLIENT_ERROR'),
        );
      });

      test('returns CLIENT_ERROR for 404', () async {
        const error = BlossomUploadFailureException(
          'Not Found',
          statusCode: 404,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('CLIENT_ERROR'),
        );
      });

      test('returns CLIENT_ERROR for 422', () async {
        const error = BlossomUploadFailureException(
          'Unprocessable Entity',
          statusCode: 422,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('CLIENT_ERROR'),
        );
      });
    });

    group('BlossomUploadFailureException with failureReason', () {
      test('returns NETWORK_ERROR for authUnavailable (signer briefly '
          'unreachable, no statusCode)', () async {
        // Without the typed reason this null-statusCode failure fell through
        // to the generic UNKNOWN bucket; classify it as a connectivity issue
        // to match the network-framed copy the user sees.
        const error = BlossomUploadFailureException(
          'Failed to create Blossom authentication',
          failureReason: BlossomUploadFailureReason.authUnavailable,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('NETWORK_ERROR'),
        );
      });

      test(
        'still classifies a network reason via its message (DNS not shortcut)',
        () async {
          // Only authUnavailable is shortcut on the reason; a network reason
          // keeps flowing through string matching so DNS_ERROR vs NETWORK_ERROR
          // stays distinguishable.
          const error = BlossomUploadFailureException(
            'Failed host lookup: blossom.divine.video',
            failureReason: BlossomUploadFailureReason.network,
          );

          expect(
            await uploadManager.categorizeError(error),
            equals('DNS_ERROR'),
          );
        },
      );
    });

    group('no internet', () {
      test('returns NO_INTERNET when connectivity is none', () async {
        mockConnectivity('none');

        final error = Exception('Some error');

        expect(
          await uploadManager.categorizeError(error),
          equals('NO_INTERNET'),
        );
      });
    });

    group('string matching fallback', () {
      test('returns DNS_ERROR for host lookup failures', () async {
        final error = Exception('Failed to lookup host');

        expect(await uploadManager.categorizeError(error), equals('DNS_ERROR'));
      });

      test('returns DNS_ERROR for DNS resolution failures', () async {
        final error = Exception('DNS resolution failed');

        expect(await uploadManager.categorizeError(error), equals('DNS_ERROR'));
      });

      test('returns TIMEOUT for timeout errors', () async {
        final error = Exception('Connection timeout');

        expect(await uploadManager.categorizeError(error), equals('TIMEOUT'));
      });

      test('returns SLOW_CONNECTION for timeout on cellular', () async {
        mockConnectivity('mobile');

        final error = Exception('Connection timeout');

        expect(
          await uploadManager.categorizeError(error),
          equals('SLOW_CONNECTION'),
        );
      });

      test('returns NETWORK_ERROR for connection errors', () async {
        final error = Exception('Cannot connect to server');

        expect(
          await uploadManager.categorizeError(error),
          equals('NETWORK_ERROR'),
        );
      });

      test('returns FILE_NOT_FOUND for missing files', () async {
        final error = Exception('File not found');

        expect(
          await uploadManager.categorizeError(error),
          equals('FILE_NOT_FOUND'),
        );
      });

      test('returns OUT_OF_MEMORY for memory errors', () async {
        final error = Exception('Out of memory');

        expect(
          await uploadManager.categorizeError(error),
          equals('OUT_OF_MEMORY'),
        );
      });

      test('returns PERMISSION_DENIED for permission errors', () async {
        final error = Exception('Permission denied');

        expect(
          await uploadManager.categorizeError(error),
          equals('PERMISSION_DENIED'),
        );
      });

      test('returns UNKNOWN for unrecognized errors', () async {
        final error = Exception('Something completely unexpected');

        expect(await uploadManager.categorizeError(error), equals('UNKNOWN'));
      });
    });
  });

  group('userFriendlyErrorMessage', () {
    test('NO_INTERNET', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'NO_INTERNET',
          UploadConnectivity.none,
        ),
        contains('No internet connection'),
      );
    });

    test('SLOW_CONNECTION', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'SLOW_CONNECTION',
          UploadConnectivity.mobile,
        ),
        contains('WiFi'),
      );
    });

    test('TIMEOUT', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'TIMEOUT',
          UploadConnectivity.wifi,
        ),
        contains('timed out'),
      );
    });

    test('NETWORK_ERROR includes network type', () {
      final message = UploadProgressReporter.userFriendlyErrorMessage(
        'NETWORK_ERROR',
        UploadConnectivity.wifi,
      );

      expect(message, contains('WiFi'));
      expect(message, contains('Network error'));
    });

    test('DNS_ERROR', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'DNS_ERROR',
          UploadConnectivity.wifi,
        ),
        contains('Could not reach'),
      );
    });

    test('FILE_NOT_FOUND', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'FILE_NOT_FOUND',
          UploadConnectivity.wifi,
        ),
        contains('not found'),
      );
    });

    test('FILE_TOO_LARGE', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'FILE_TOO_LARGE',
          UploadConnectivity.wifi,
        ),
        contains('too large'),
      );
    });

    test('AUTHENTICATION', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'AUTHENTICATION',
          UploadConnectivity.wifi,
        ),
        contains('sign in'),
      );
    });

    test('RATE_LIMITED', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'RATE_LIMITED',
          UploadConnectivity.wifi,
        ),
        contains('Too many uploads'),
      );
    });

    test('SERVER_UNAVAILABLE', () {
      final message = UploadProgressReporter.userFriendlyErrorMessage(
        'SERVER_UNAVAILABLE',
        UploadConnectivity.wifi,
      );

      expect(message, contains('temporarily unavailable'));
      expect(message, contains('retry'));
    });

    test('SERVER_ERROR', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'SERVER_ERROR',
          UploadConnectivity.wifi,
        ),
        contains('encountered an error'),
      );
    });

    test('CLIENT_ERROR', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'CLIENT_ERROR',
          UploadConnectivity.wifi,
        ),
        contains('request failed'),
      );
    });

    test('UNKNOWN returns default message', () {
      expect(
        UploadProgressReporter.userFriendlyErrorMessage(
          'UNKNOWN',
          UploadConnectivity.wifi,
        ),
        contains('Upload failed'),
      );
    });
  });

  group('retry counter', () {
    late UploadManager retryUploadManager;
    late _MockBlossomUploadService retryMockBlossom;
    late Directory retryTestDir;
    late PathProviderPlatform originalPathProvider;

    setUpAll(() {
      registerFallbackValue(File(''));
    });

    setUp(() async {
      retryTestDir = await Directory.systemTemp.createTemp(
        'upload_retry_counter_test_',
      );
      originalPathProvider = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(retryTestDir.path)
        ..setApplicationDocumentsPath('${retryTestDir.path}/documents')
        ..setApplicationSupportPath('${retryTestDir.path}/support');
      PathProviderPlatform.instance = mockPathProvider;

      await Directory('${retryTestDir.path}/support').create(recursive: true);

      retryMockBlossom = _MockBlossomUploadService();

      // Zero delays so the test completes instantly.
      retryUploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: retryMockBlossom,
        retryConfig: const UploadRetryConfig(
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
          networkTimeout: Duration(seconds: 30),
        ),
      );
      mockConnectivity('wifi');
      await retryUploadManager.initialize();
    });

    tearDown(() async {
      retryUploadManager.dispose();
      PathProviderPlatform.instance = originalPathProvider;
      try {
        await Hive.close();
      } catch (_) {}
      try {
        await retryTestDir.delete(recursive: true);
      } catch (_) {}
    });

    /// Stubs [mock] so that [uploadVideoWithResume] fails [failCount] times before
    /// succeeding. The success result includes a server thumbnail URL so these
    /// retry-counter tests do not depend on thumbnail extraction from fake
    /// video bytes.
    void stubUploadSequence(
      _MockBlossomUploadService mock, {
      required int failCount,
    }) {
      when(() => mock.isBlossomEnabled()).thenAnswer((_) async => false);
      when(
        () => mock.uploadImage(
          imageFile: any(named: 'imageFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          maxAttempts: any(named: 'maxAttempts'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => const BlossomUploadResult(success: false));

      var calls = 0;
      when(
        () => mock.uploadVideoWithResume(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          proofManifestJson: any(named: 'proofManifestJson'),
          useBackgroundFirst: any(named: 'useBackgroundFirst'),
          resumableTimeout: any(named: 'resumableTimeout'),
          resumableSession: any(named: 'resumableSession'),
          onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls <= failCount) {
          throw const BlossomUploadFailureException(
            'Network error: connection refused',
          );
        }
        return const BlossomUploadResult(
          success: true,
          videoId: 'vid-ok',
          url: 'https://media.divine.video/vid-ok',
          fallbackUrl: 'https://media.divine.video/vid-ok',
          thumbnailUrl: 'https://media.divine.video/vid-ok-thumb.jpg',
        );
      });
    }

    test(
      'status advances uploading → retrying across consecutive auto-attempts',
      () async {
        final videoFile = File('${retryTestDir.path}/video.mp4')
          ..writeAsBytesSync([0, 1, 2, 3]);

        final observedStatuses = <UploadStatus>[];

        // Fail once then succeed so we observe exactly two status snapshots.
        stubUploadSequence(retryMockBlossom, failCount: 1);

        // Replace the uploadVideoWithResume stub with one that also captures status.
        var calls = 0;
        when(
          () => retryMockBlossom.uploadVideoWithResume(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            taskId: any(named: 'taskId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            useBackgroundFirst: any(named: 'useBackgroundFirst'),
            resumableTimeout: any(named: 'resumableTimeout'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async {
          calls++;
          final all = retryUploadManager.pendingUploads;
          if (all.isNotEmpty) observedStatuses.add(all.first.status);
          if (calls == 1) {
            throw const BlossomUploadFailureException(
              'Network error: connection refused',
            );
          }
          return const BlossomUploadResult(
            success: true,
            videoId: 'vid-status',
            url: 'https://media.divine.video/vid-status',
            fallbackUrl: 'https://media.divine.video/vid-status',
            thumbnailUrl: 'https://media.divine.video/vid-status-thumb.jpg',
          );
        });

        await retryUploadManager.startUpload(
          videoFile: videoFile,
          nostrPubkey: 'test-pubkey',
        );

        expect(calls, equals(2));
        expect(observedStatuses.first, equals(UploadStatus.uploading));
        expect(observedStatuses[1], equals(UploadStatus.retrying));
      },
    );

    test(
      'retryCount is NOT mutated by auto-attempts — manual retry remains available after exhausted session',
      () async {
        // Regression test for the reviewer-identified bug: if auto-attempts
        // were to write retryCount + 1 to Hive on every attempt,
        // PendingUpload.canRetry (retryCount < 3) would become false after
        // the maxRetries (5) auto-attempts, permanently locking the user out
        // of retryUpload(). The correct fix keeps the increment local.
        final videoFile = File('${retryTestDir.path}/video2.mp4')
          ..writeAsBytesSync([0, 1, 2, 3]);

        // All 6 auto-attempts (1 initial + 5 retries) fail.
        stubUploadSequence(retryMockBlossom, failCount: 999);

        // Absorb the rethrown failure; we only care about the persisted state.
        await expectLater(
          retryUploadManager.startUpload(
            videoFile: videoFile,
            nostrPubkey: 'test-pubkey',
          ),
          throwsA(anything),
        );

        final failedUpload = retryUploadManager.pendingUploads.firstOrNull;
        expect(failedUpload, isNotNull);
        expect(failedUpload!.status, equals(UploadStatus.failed));

        // Auto-attempts must NOT have modified the manual-retry budget.
        expect(
          failedUpload.retryCount,
          equals(0),
          reason: 'auto-attempts must not mutate retryCount — it is the manual-retry budget',
        );
        expect(
          failedUpload.canRetry,
          isTrue,
          reason: 'user must still be able to manually retry after auto-retry exhaustion',
        );

        // Verify retryUpload() actually re-activates the upload and does not
        // hard-return due to canRetry being false.
        when(
          () => retryMockBlossom.uploadVideoWithResume(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            taskId: any(named: 'taskId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            useBackgroundFirst: any(named: 'useBackgroundFirst'),
            resumableTimeout: any(named: 'resumableTimeout'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            videoId: 'vid-manual',
            url: 'https://media.divine.video/vid-manual',
            fallbackUrl: 'https://media.divine.video/vid-manual',
            thumbnailUrl: 'https://media.divine.video/vid-manual-thumb.jpg',
          ),
        );

        await retryUploadManager.retryUpload(failedUpload.id);

        final recovered = retryUploadManager.getUpload(failedUpload.id);
        expect(recovered, isNotNull);
        expect(recovered!.status, equals(UploadStatus.readyToPublish));
        expect(
          recovered.retryCount,
          equals(1),
          reason: 'manual retry must consume one retry budget slot',
        );
      },
    );

    test(
      'manual retries consume budget and the fourth retry is blocked',
      () async {
        final videoFile = File('${retryTestDir.path}/video3.mp4')
          ..writeAsBytesSync([0, 1, 2, 3]);

        when(
          () => retryMockBlossom.isBlossomEnabled(),
        ).thenAnswer((_) async => false);
        when(
          () => retryMockBlossom.uploadImage(
            imageFile: any(named: 'imageFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            maxAttempts: any(named: 'maxAttempts'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => const BlossomUploadResult(success: false));
        when(
          () => retryMockBlossom.uploadVideoWithResume(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            taskId: any(named: 'taskId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            useBackgroundFirst: any(named: 'useBackgroundFirst'),
            resumableTimeout: any(named: 'resumableTimeout'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(
          const BlossomUploadFailureException(
            'Network error: connection refused',
          ),
        );

        await expectLater(
          retryUploadManager.startUpload(
            videoFile: videoFile,
            nostrPubkey: 'test-pubkey',
          ),
          throwsA(anything),
        );

        final upload = retryUploadManager.pendingUploads.firstOrNull;
        expect(upload, isNotNull);
        expect(upload!.retryCount, equals(0));

        for (var manualRetry = 1; manualRetry <= 3; manualRetry++) {
          await retryUploadManager.retryUpload(upload.id);

          final latest = retryUploadManager.getUpload(upload.id);
          expect(latest, isNotNull);
          expect(latest!.status, equals(UploadStatus.failed));
          expect(latest.retryCount, equals(manualRetry));
          expect(
            latest.canRetry,
            equals(manualRetry < 3),
            reason: 'manual retry budget should stop after three tries',
          );
        }

        clearInteractions(retryMockBlossom);

        await retryUploadManager.retryUpload(upload.id);

        verifyNever(
          () => retryMockBlossom.uploadVideoWithResume(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            taskId: any(named: 'taskId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            useBackgroundFirst: any(named: 'useBackgroundFirst'),
            resumableTimeout: any(named: 'resumableTimeout'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
            onProgress: any(named: 'onProgress'),
          ),
        );

        final blocked = retryUploadManager.getUpload(upload.id);
        expect(blocked, isNotNull);
        expect(blocked!.status, equals(UploadStatus.failed));
        expect(blocked.retryCount, equals(3));
        expect(blocked.canRetry, isFalse);
      },
    );
  });
}
