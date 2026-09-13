// ABOUTME: Unit tests for UploadRetryPolicy — covers isRetriableError,
// ABOUTME: retryUpload, resumeInterruptedUpload, and enqueueSessionPersist.

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:upload_repository/upload_repository.dart';

class _MockPendingUploadStore extends Mock implements PendingUploadStore {}

PendingUpload _makeUpload({
  String id = 'upload-1',
  UploadStatus status = UploadStatus.uploading,
  int? retryCount = 0,
  DateTime? createdAt,
  DateTime? completedAt,
}) => PendingUpload(
  id: id,
  localVideoPath: '/tmp/video.mp4',
  nostrPubkey: 'pubkey-abc',
  status: status,
  createdAt: createdAt ?? DateTime(2024),
  completedAt: completedAt,
  retryCount: retryCount,
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
  });

  late _MockPendingUploadStore store;
  late UploadRetryPolicy policy;

  setUp(() {
    store = _MockPendingUploadStore();
    policy = UploadRetryPolicy(
      store: store,
      retryConfig: const UploadRetryConfig(),
    );
  });

  tearDown(() {
    policy.dispose();
  });

  // ---------------------------------------------------------------------------
  group('isRetriableError', () {
    group('network / timeout errors → true', () {
      test('string "timeout" → true', () {
        expect(policy.isRetriableError(Exception('timeout')), isTrue);
      });

      test('string "cannot connect" → true', () {
        expect(policy.isRetriableError(Exception('cannot connect')), isTrue);
      });

      test('string "connection refused" → true', () {
        expect(
          policy.isRetriableError(Exception('connection refused')),
          isTrue,
        );
      });

      test('string "socket" → true', () {
        expect(policy.isRetriableError(Exception('socket closed')), isTrue);
      });

      test('string "network error" → true', () {
        expect(policy.isRetriableError(Exception('network error')), isTrue);
      });

      test('unknown error → true by default', () {
        expect(
          policy.isRetriableError(Exception('some unknown issue')),
          isTrue,
        );
      });
    });

    group('BlossomUploadFailureException with 5xx status → true', () {
      test('500 → true', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException(
              'Server error',
              statusCode: 500,
            ),
          ),
          isTrue,
        );
      });

      test('502 → true', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException('Bad gateway', statusCode: 502),
          ),
          isTrue,
        );
      });

      test('408 → true', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException('Timeout', statusCode: 408),
          ),
          isTrue,
        );
      });

      test('429 → true', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException(
              'Rate limited',
              statusCode: 429,
            ),
          ),
          isTrue,
        );
      });

      test('authUnavailable reason → true', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException(
              'Signer unavailable',
              failureReason: BlossomUploadFailureReason.authUnavailable,
            ),
          ),
          isTrue,
        );
      });

      test('network reason → true', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException(
              'Network fail',
              failureReason: BlossomUploadFailureReason.network,
            ),
          ),
          isTrue,
        );
      });
    });

    group('non-retriable errors → false', () {
      test('expired session BlossomResumableUploadException (404) → false', () {
        expect(
          policy.isRetriableError(
            const BlossomResumableUploadException('Not found', statusCode: 404),
          ),
          isFalse,
        );
      });

      test('expired session BlossomResumableUploadException (410) → false', () {
        expect(
          policy.isRetriableError(
            const BlossomResumableUploadException('Gone', statusCode: 410),
          ),
          isFalse,
        );
      });

      test('auth-expired BlossomResumableUploadException (401) → false', () {
        expect(
          policy.isRetriableError(
            const BlossomResumableUploadException(
              'Unauthorized',
              statusCode: 401,
              failureReason: BlossomUploadFailureReason.auth,
            ),
          ),
          isFalse,
        );
      });

      test('auth-expired BlossomResumableUploadException (403) → false', () {
        expect(
          policy.isRetriableError(
            const BlossomResumableUploadException(
              'Forbidden',
              statusCode: 403,
              failureReason: BlossomUploadFailureReason.auth,
            ),
          ),
          isFalse,
        );
      });

      test('session expired string → false', () {
        expect(policy.isRetriableError(Exception('session expired')), isFalse);
      });

      test('session is no longer available → false', () {
        expect(
          policy.isRetriableError(Exception('session is no longer available')),
          isFalse,
        );
      });

      test('4xx status (401) → false', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException(
              'Unauthorized',
              statusCode: 401,
            ),
          ),
          isFalse,
        );
      });

      test('4xx status (400) → false', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException('Bad request', statusCode: 400),
          ),
          isFalse,
        );
      });

      test('auth reason → false', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException(
              'Auth rejected',
              failureReason: BlossomUploadFailureReason.auth,
            ),
          ),
          isFalse,
        );
      });

      test('fileTooLarge reason → false', () {
        expect(
          policy.isRetriableError(
            const BlossomUploadFailureException(
              'Too big',
              failureReason: BlossomUploadFailureReason.fileTooLarge,
            ),
          ),
          isFalse,
        );
      });

      test('"file not found" → false', () {
        expect(policy.isRetriableError(Exception('file not found')), isFalse);
      });

      test('"permission denied" → false', () {
        expect(
          policy.isRetriableError(Exception('permission denied')),
          isFalse,
        );
      });

      test('"cancelled" → false', () {
        expect(policy.isRetriableError(Exception('upload cancelled')), isFalse);
      });

      test('"thumbnail upload failed" → false', () {
        expect(
          policy.isRetriableError(Exception('thumbnail upload failed')),
          isFalse,
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  group('performWithRetry', () {
    test(
      'drains queued session persistence before starting an attempt',
      () async {
        final upload = _makeUpload();
        const session = BlossomResumableUploadSession(
          uploadId: 'session-1',
          uploadUrl: 'https://upload.divine.video/sessions/session-1',
          chunkSize: 1024,
          nextOffset: 512,
        );
        final persistStarted = Completer<void>();
        final allowPersistToFinish = Completer<void>();

        when(() => store.getUpload('upload-1')).thenReturn(upload);
        when(() => store.update(any())).thenAnswer((invocation) async {
          final updated = invocation.positionalArguments.first as PendingUpload;
          if (updated.resumableSession != null) {
            persistStarted.complete();
            await allowPersistToFinish.future;
          }
        });

        policy.enqueueSessionPersist('upload-1', session, 1024);

        var executeCalled = false;
        final retryFuture = policy.performWithRetry(upload, () async {
          executeCalled = true;
        }, isRetriable: (_) => false);

        await persistStarted.future;
        await pumpEventQueue(times: 1);
        expect(executeCalled, isFalse);

        allowPersistToFinish.complete();
        await retryFuture;

        expect(executeCalled, isTrue);
        final captured = verify(() => store.update(captureAny())).captured;
        expect(captured, hasLength(2));
        expect(
          (captured.first as PendingUpload).resumableSession,
          equals(session),
        );
        expect((captured.last as PendingUpload).status, UploadStatus.uploading);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('retryUpload', () {
    test('no-op when upload not found in store', () async {
      when(() => store.getUpload('upload-1')).thenReturn(null);

      var called = false;
      await policy.retryUpload(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      expect(called, isFalse);
    });

    test('no-op when canRetry is false (retryCount >= 3)', () async {
      final upload = _makeUpload(status: UploadStatus.failed, retryCount: 3);
      when(() => store.getUpload('upload-1')).thenReturn(upload);

      var called = false;
      await policy.retryUpload(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      expect(called, isFalse);
      verifyNever(() => store.update(any()));
    });

    test(
      'increments retryCount and calls performUpload when canRetry',
      () async {
        final upload = _makeUpload(status: UploadStatus.failed);
        when(() => store.getUpload('upload-1')).thenReturn(upload);
        when(() => store.update(any())).thenAnswer((_) async {});

        PendingUpload? received;
        await policy.retryUpload(
          'upload-1',
          performUpload: (u) async {
            received = u;
          },
        );

        expect(received, isNotNull);
        expect(received!.retryCount, equals(1));
        expect(received!.status, equals(UploadStatus.pending));
        verify(() => store.update(any())).called(1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('resumeInterruptedUpload', () {
    test('calls performUpload when status is uploading', () async {
      final upload = _makeUpload();
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      var called = false;
      policy.resumeInterruptedUpload(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      // Fire microtasks from unawaited calls
      await pumpEventQueue(times: 1);
      expect(called, isTrue);
    });

    test('calls performUpload when status is retrying', () async {
      final upload = _makeUpload(status: UploadStatus.retrying);
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      var called = false;
      policy.resumeInterruptedUpload(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      await pumpEventQueue(times: 1);
      expect(called, isTrue);
    });

    test('no-op when upload not found', () async {
      when(() => store.getUpload('upload-1')).thenReturn(null);

      var called = false;
      policy.resumeInterruptedUpload(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      await pumpEventQueue(times: 1);
      expect(called, isFalse);
    });

    test('no-op when upload is in pending status', () async {
      final upload = _makeUpload(status: UploadStatus.pending);
      when(() => store.getUpload('upload-1')).thenReturn(upload);

      var called = false;
      policy.resumeInterruptedUpload(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      await pumpEventQueue(times: 1);
      expect(called, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('retryUploadWithBackoff', () {
    test('resets retryCount to 1 when last attempt was >= 1h ago', () async {
      final upload = _makeUpload(
        status: UploadStatus.failed,
        retryCount: 2,
        completedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      PendingUpload? received;
      await policy.retryUploadWithBackoff(
        'upload-1',
        performUpload: (u) async {
          received = u;
        },
      );

      expect(received, isNotNull);
      expect(received!.retryCount, equals(1));
      expect(received!.status, equals(UploadStatus.pending));
    });

    test('increments retryCount when last attempt was < 1h ago', () async {
      final upload = _makeUpload(
        status: UploadStatus.failed,
        retryCount: 1,
        completedAt: DateTime.now(),
      );
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      PendingUpload? received;
      await policy.retryUploadWithBackoff(
        'upload-1',
        performUpload: (u) async {
          received = u;
        },
      );

      expect(received, isNotNull);
      expect(received!.retryCount, equals(2));
      expect(received!.status, equals(UploadStatus.pending));
    });

    test(
      'falls back to createdAt for the reset window when completedAt is null',
      () async {
        // createdAt defaults to 2024 (well over an hour ago) and completedAt
        // is null, so the reset window keys off createdAt and resets to 1.
        final upload = _makeUpload(status: UploadStatus.failed, retryCount: 2);
        when(() => store.getUpload('upload-1')).thenReturn(upload);
        when(() => store.update(any())).thenAnswer((_) async {});

        PendingUpload? received;
        await policy.retryUploadWithBackoff(
          'upload-1',
          performUpload: (u) async {
            received = u;
          },
        );

        expect(received, isNotNull);
        expect(received!.retryCount, equals(1));
      },
    );

    test('no-op when upload is not in failed state', () async {
      final upload = _makeUpload(status: UploadStatus.paused);
      when(() => store.getUpload('upload-1')).thenReturn(upload);

      var called = false;
      await policy.retryUploadWithBackoff(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      expect(called, isFalse);
      verifyNever(() => store.update(any()));
    });

    test('no-op when upload not found in store', () async {
      when(() => store.getUpload('upload-1')).thenReturn(null);

      var called = false;
      await policy.retryUploadWithBackoff(
        'upload-1',
        performUpload: (_) async {
          called = true;
        },
      );

      expect(called, isFalse);
      verifyNever(() => store.update(any()));
    });
  });

  // ---------------------------------------------------------------------------
  group('enqueueSessionPersist', () {
    test('updates store with session and progress', () async {
      final upload = _makeUpload();
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      const session = BlossomResumableUploadSession(
        uploadId: 'session-1',
        uploadUrl: 'https://example.com/upload',
        chunkSize: 1024 * 1024,
        nextOffset: 512000,
      );

      policy.enqueueSessionPersist('upload-1', session, 1024000);

      // Allow chained future to run
      await pumpEventQueue(times: 1);

      final captured = verify(() => store.update(captureAny())).captured;
      expect(captured, hasLength(1));
      final updated = captured.first as PendingUpload;
      expect(updated.resumableSession, equals(session));
      // progress = (512000 / 1024000) * videoProgressShare = 0.475
      expect(updated.uploadProgress, closeTo(0.475, 0.001));
    });

    test(
      'never lowers progress already reported by the live transfer',
      () async {
        final upload = _makeUpload().copyWith(uploadProgress: 0.7);
        when(() => store.getUpload('upload-1')).thenReturn(upload);
        when(() => store.update(any())).thenAnswer((_) async {});

        // The live callback and this checkpoint run on different curves, so a
        // checkpoint computed below the reported value must not drag it back.
        const session = BlossomResumableUploadSession(
          uploadId: 'session-1',
          uploadUrl: 'https://example.com/upload',
          chunkSize: 1024 * 1024,
          nextOffset: 512000,
        );

        policy.enqueueSessionPersist('upload-1', session, 1024000);
        await pumpEventQueue(times: 1);

        final captured = verify(() => store.update(captureAny())).captured;
        final updated = captured.first as PendingUpload;
        expect(updated.resumableSession, equals(session));
        expect(updated.uploadProgress, closeTo(0.7, 0.001));
      },
    );

    test('clamps progress to the video share', () async {
      final upload = _makeUpload();
      when(() => store.getUpload('upload-1')).thenReturn(upload);
      when(() => store.update(any())).thenAnswer((_) async {});

      // nextOffset > fileSizeBytes (shouldn't happen but guard against it)
      const session = BlossomResumableUploadSession(
        uploadId: 'session-1',
        uploadUrl: 'https://example.com/upload',
        chunkSize: 1024 * 1024,
        nextOffset: 2000000,
      );

      policy.enqueueSessionPersist('upload-1', session, 1000000);
      await pumpEventQueue(times: 1);

      final captured = verify(() => store.update(captureAny())).captured;
      final updated = captured.first as PendingUpload;
      expect(
        updated.uploadProgress,
        lessThanOrEqualTo(videoProgressShare),
      );
    });

    test('no-op when upload not found in store', () async {
      when(() => store.getUpload('upload-1')).thenReturn(null);

      const session = BlossomResumableUploadSession(
        uploadId: 'session-1',
        uploadUrl: 'https://example.com/upload',
        chunkSize: 1024 * 1024,
        nextOffset: 100,
      );

      policy.enqueueSessionPersist('upload-1', session, 1000);
      await pumpEventQueue(times: 1);

      verifyNever(() => store.update(any()));
    });
  });

  // ---------------------------------------------------------------------------
  group('dispose', () {
    test('can be called without throwing', () {
      expect(() => policy.dispose(), returnsNormally);
    });
  });
}
