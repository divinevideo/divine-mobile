import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

/// Emits [emitOnEnqueue] as soon as [enqueue] is called, after the service has
/// already subscribed — so the terminal event is never missed by a race.
class _FakeTransport implements BlossomBackgroundTransport {
  _FakeTransport({
    this.emitOnEnqueue = const [],
    this.throwOnEnqueue = false,
    Map<String, BlossomBackgroundTransferEvent>? bufferedTerminals,
  }) : bufferedTerminals =
           bufferedTerminals ?? <String, BlossomBackgroundTransferEvent>{};

  final List<BlossomBackgroundTransferEvent> emitOnEnqueue;
  final bool throwOnEnqueue;

  /// Terminal events the OS delivered while nothing was listening, keyed by
  /// taskId. Claimed (and removed) by [takeBufferedTerminalEvent].
  final Map<String, BlossomBackgroundTransferEvent> bufferedTerminals;
  final StreamController<BlossomBackgroundTransferEvent> _controller =
      StreamController<BlossomBackgroundTransferEvent>.broadcast();
  final List<String> enqueued = <String>[];
  final List<Map<String, String>> enqueuedHeaders = <Map<String, String>>[];
  final List<String> enqueuedMethods = <String>[];
  final List<String> enqueuedUrls = <String>[];
  final List<String> cancelled = <String>[];

  @override
  Stream<BlossomBackgroundTransferEvent> get events => _controller.stream;

  @override
  Future<void> enqueue({
    required String taskId,
    required String url,
    required String method,
    required Map<String, String> headers,
    required String filePath,
  }) async {
    enqueued.add(taskId);
    enqueuedUrls.add(url);
    enqueuedMethods.add(method);
    enqueuedHeaders.add(Map<String, String>.from(headers));
    if (throwOnEnqueue) {
      throw Exception('enqueue failed');
    }
    emitOnEnqueue.forEach(_controller.add);
  }

  @override
  Future<void> cancel(String taskId) async => cancelled.add(taskId);

  @override
  Future<BlossomBackgroundTransferEvent?> takeBufferedTerminalEvent(
    String taskId,
  ) async => bufferedTerminals.remove(taskId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const server = 'https://media.divine.video';
  const taskId = 'upload-1';
  late _MockAuthProvider auth;
  late Directory tempDir;
  late File videoFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    auth = _MockAuthProvider();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer(
      (_) async => const BlossomSignedEvent(
        json: <String, dynamic>{
          'id': 'abc',
          'kind': 24242,
          'pubkey': 'pk',
          'created_at': 1,
          'tags': <dynamic>[],
        },
      ),
    );

    tempDir = await Directory.systemTemp.createTemp('blossom_bg_test_');
    videoFile = File('${tempDir.path}/video.mp4')
      ..writeAsBytesSync(List<int>.generate(64, (i) => i));
  });

  tearDown(() async => tempDir.delete(recursive: true));

  BlossomUploadService service(_FakeTransport? transport) {
    return BlossomUploadService(
      authProvider: auth,
      defaultServerUrl: server,
      backgroundTransport: transport,
    );
  }

  group('uploadVideoInBackground', () {
    test('returns failure when no transport is configured', () async {
      final result = await service(null).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      expect(result.success, isFalse);
      expect(result.failureReason, BlossomUploadFailureReason.unknown);
    });

    test('returns auth failure when unauthenticated', () async {
      when(() => auth.isAuthenticated).thenReturn(false);

      final result = await service(_FakeTransport()).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      expect(result.success, isFalse);
      expect(result.failureReason, BlossomUploadFailureReason.auth);
    });

    test('enqueues a single PUT and resolves with the canonical URL', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.completed,
            progress: 1,
            httpStatusCode: 200,
          ),
        ],
      );
      final progress = <double>[];

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
        onProgress: progress.add,
      );

      expect(transport.enqueued, <String>[taskId]);
      expect(result.success, isTrue);
      expect(result.url, startsWith('$server/'));
      expect(result.videoId, isNotEmpty);
      expect(progress.last, 1.0);
    });

    test('maps an HTTP error terminal event to a server failure', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.failed,
            httpStatusCode: 503,
          ),
        ],
      );

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      expect(result.success, isFalse);
      expect(result.statusCode, 503);
      expect(result.failureReason, BlossomUploadFailureReason.server);
    });

    test(
      'logs the HTTP status and server response of a failed upload',
      () async {
        // The result keeps only the status code, and the caller falls back to
        // a full resumable re-upload, so this line is the only record of why
        // the server rejected the OS transfer.
        await LogCaptureService().clearAllLogs();
        addTearDown(LogCaptureService().clearAllLogs);
        const serverError =
            '{"error":"user list update changed too many times"}';
        final transport = _FakeTransport(
          emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
            BlossomBackgroundTransferEvent(
              taskId: taskId,
              status: BlossomBackgroundTransferStatus.failed,
              httpStatusCode: 500,
              responseBody: serverError,
            ),
          ],
        );

        await service(transport).uploadVideoInBackground(
          videoFile: videoFile,
          taskId: taskId,
          proofManifestJson: null,
        );

        final failureLogs = LogCaptureService()
            .getRecentLogs(minLevel: LogLevel.warning)
            .where(
              (log) =>
                  log.name == 'BlossomUploadService' &&
                  log.message.startsWith('Background upload failed'),
            );
        expect(failureLogs, hasLength(1));
        expect(failureLogs.single.message, contains('HTTP 500'));
        expect(failureLogs.single.message, contains(serverError));
      },
    );

    test('treats HTTP 409 (already stored) as success with the '
        'content-addressed URL', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.failed,
            httpStatusCode: 409,
          ),
        ],
      );

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      expect(result.success, isTrue);
      expect(result.url, startsWith('$server/'));
      expect(result.fallbackUrl, startsWith('$server/'));
      expect(result.videoId, isNotEmpty);
    });

    test(
      'maps a transport error (no status) to a transient network failure',
      () async {
        final transport = _FakeTransport(
          emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
            BlossomBackgroundTransferEvent(
              taskId: taskId,
              status: BlossomBackgroundTransferStatus.failed,
              error: 'Connection reset by peer',
            ),
          ],
        );

        final result = await service(transport).uploadVideoInBackground(
          videoFile: videoFile,
          taskId: taskId,
          proofManifestJson: null,
        );

        expect(result.success, isFalse);
        expect(result.failureReason, BlossomUploadFailureReason.network);
        expect(result.isTransientNetworkFailure, isTrue);
      },
    );

    test('parses streaming metadata from the response body', () async {
      final body = jsonEncode(<String, dynamic>{
        'streaming': <String, dynamic>{
          'mp4Url': 'https://media.divine.video/stream.mp4',
          'status': 'processing',
        },
      });
      final transport = _FakeTransport(
        emitOnEnqueue: <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.completed,
            httpStatusCode: 200,
            responseBody: body,
          ),
        ],
      );

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      expect(result.success, isTrue);
      expect(result.streamingMp4Url, 'https://media.divine.video/stream.mp4');
      expect(result.streamingStatus, 'processing');
    });

    test('attaches auth, content type, and ProofMode headers', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.completed,
            progress: 1,
            httpStatusCode: 200,
          ),
        ],
      );

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: '{"pgpSignature":"sig"}',
      );

      expect(result.success, isTrue);
      expect(transport.enqueued, <String>[taskId]);
      expect(transport.enqueuedUrls, <String>['$server/upload']);
      expect(transport.enqueuedMethods, <String>['PUT']);
      expect(
        transport.enqueuedHeaders.single['Authorization'],
        startsWith('Nostr '),
      );
      expect(transport.enqueuedHeaders.single['Content-Type'], 'video/mp4');
      expect(transport.enqueuedHeaders.single['Content-Length'], '64');
      expect(
        utf8.decode(
          base64.decode(
            transport.enqueuedHeaders.single['X-ProofMode-Manifest']!,
          ),
        ),
        '{"pgpSignature":"sig"}',
      );
      expect(
        utf8.decode(
          base64.decode(
            transport.enqueuedHeaders.single['X-ProofMode-Signature']!,
          ),
        ),
        'sig',
      );
    });

    test('forwards intermediate progress for non-terminal events', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.running,
            progress: 0.5,
          ),
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.completed,
            progress: 1,
            httpStatusCode: 200,
          ),
        ],
      );
      final progress = <double>[];

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
        onProgress: progress.add,
      );

      expect(result.success, isTrue);
      // The running event maps into the 0.2–0.9 reporting band, distinct from
      // the final 1.0.
      expect(progress.where((p) => p > 0.2 && p < 0.9), isNotEmpty);
    });

    test('returns failure when the transport rejects enqueue', () async {
      final result = await service(_FakeTransport(throwOnEnqueue: true))
          .uploadVideoInBackground(
            videoFile: videoFile,
            taskId: taskId,
            proofManifestJson: null,
          );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        contains('Failed to enqueue background upload'),
      );
    });

    test(
      'targets the injected default server when no custom server is stored',
      () async {
        // A LOCAL build injects the local stack's Blossom. With nothing
        // stored, the upload must go there, not to production media (#9660).
        const localServer = 'http://localhost:43003';
        final transport = _FakeTransport(
          emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
            BlossomBackgroundTransferEvent(
              taskId: taskId,
              status: BlossomBackgroundTransferStatus.completed,
              httpStatusCode: 200,
            ),
          ],
        );
        final svc = BlossomUploadService(
          authProvider: auth,
          defaultServerUrl: localServer,
          backgroundTransport: transport,
        );

        final result = await svc.uploadVideoInBackground(
          videoFile: videoFile,
          taskId: taskId,
          proofManifestJson: null,
        );

        expect(transport.enqueuedUrls, <String>['$localServer/upload']);
        expect(result.success, isTrue);
        expect(result.url, startsWith('$localServer/'));
        expect(result.fallbackUrl, startsWith('$localServer/'));
      },
    );

    test(
      'resolves the success URL from the custom server actually used, not '
      'the injected default server',
      () async {
        const customServer = 'https://blossom.example.com';
        SharedPreferences.setMockInitialValues(const <String, Object>{
          'blossom_server_url': customServer,
        });
        final transport = _FakeTransport(
          emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
            BlossomBackgroundTransferEvent(
              taskId: taskId,
              status: BlossomBackgroundTransferStatus.completed,
              httpStatusCode: 200,
            ),
          ],
        );
        final svc = BlossomUploadService(
          authProvider: auth,
          defaultServerUrl: 'https://staging.divine.video',
          backgroundTransport: transport,
        );

        final result = await svc.uploadVideoInBackground(
          videoFile: videoFile,
          taskId: taskId,
          proofManifestJson: null,
        );

        expect(transport.enqueuedUrls, <String>['$customServer/upload']);
        expect(result.success, isTrue);
        expect(result.url, startsWith('$customServer/'));
        expect(result.url, isNot(contains('staging')));
        expect(result.fallbackUrl, startsWith('$customServer/'));
      },
    );

    test('prefers the server-returned url over the content-addressed '
        'fallback', () async {
      final body = jsonEncode(<String, dynamic>{
        'url': 'https://media.divine.video/hls/master.m3u8',
        'fallbackUrl': 'https://media.divine.video/mp4/video.mp4',
      });
      final transport = _FakeTransport(
        emitOnEnqueue: <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.completed,
            httpStatusCode: 200,
            responseBody: body,
          ),
        ],
      );

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      expect(result.url, 'https://media.divine.video/hls/master.m3u8');
      expect(result.fallbackUrl, 'https://media.divine.video/mp4/video.mp4');
    });

    test('signs the background auth header with an extended TTL', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.completed,
            httpStatusCode: 200,
          ),
        ],
      );
      final before = DateTime.now();

      await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      final captured = verify(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;
      final tags = (captured.single as List).cast<List<dynamic>>();
      final expirationTag = tags.firstWhere((tag) => tag.first == 'expiration');
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        int.parse(expirationTag[1] as String) * 1000,
      );

      // The background TTL (6h) must be well beyond the 5-minute in-process
      // TTL, so an OS-deferred transfer isn't rejected as expired.
      expect(expiresAt.isAfter(before.add(const Duration(hours: 1))), isTrue);
    });

    test('times out and releases its listener when no terminal event '
        'arrives', () async {
      final transport = _FakeTransport(); // emits nothing after enqueue

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
        timeout: const Duration(milliseconds: 50),
      );

      expect(transport.enqueued, <String>[taskId]);
      expect(result.success, isFalse);
      expect(result.failureReason, BlossomUploadFailureReason.network);
      expect(result.isTransientNetworkFailure, isTrue);
      // The subscription is cancelled on timeout, so a late terminal event is
      // ignored rather than throwing "Future already completed".
      transport._controller.add(
        const BlossomBackgroundTransferEvent(
          taskId: taskId,
          status: BlossomBackgroundTransferStatus.completed,
          httpStatusCode: 200,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('cancelBackgroundUpload', () {
    test(
      'cancelBackgroundUpload stops the OS transfer via the transport',
      () async {
        final transport = _FakeTransport();

        await service(transport).cancelBackgroundUpload(taskId);

        expect(transport.cancelled, <String>[taskId]);
      },
    );

    test('cancelBackgroundUpload is a no-op without a transport', () async {
      // Must not throw when background uploads are disabled.
      await expectLater(
        service(null).cancelBackgroundUpload(taskId),
        completes,
      );
    });
  });

  group('buffered terminal events', () {
    test('skips re-upload when a completed terminal was buffered', () async {
      // Simulates relaunch after the OS finished the blob while the app was
      // dead: the terminal event is waiting in the buffer, so the retry must
      // not re-enqueue the file.
      final body = jsonEncode(<String, dynamic>{
        'url': 'https://media.divine.video/hls/master.m3u8',
        'fallbackUrl': 'https://media.divine.video/mp4/video.mp4',
      });
      final transport = _FakeTransport(
        bufferedTerminals: <String, BlossomBackgroundTransferEvent>{
          taskId: BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.completed,
            httpStatusCode: 200,
            responseBody: body,
          ),
        },
      );
      final progress = <double>[];

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
        onProgress: progress.add,
      );

      expect(result.success, isTrue);
      expect(result.url, 'https://media.divine.video/hls/master.m3u8');
      expect(transport.enqueued, isEmpty, reason: 'must not re-upload');
      expect(transport.bufferedTerminals, isEmpty, reason: 'event consumed');
      expect(progress.last, 1.0);
    });

    test(
      'a buffered failed terminal does not skip; the upload retries',
      () async {
        final transport = _FakeTransport(
          bufferedTerminals: <String, BlossomBackgroundTransferEvent>{
            taskId: const BlossomBackgroundTransferEvent(
              taskId: taskId,
              status: BlossomBackgroundTransferStatus.failed,
              httpStatusCode: 500,
            ),
          },
          emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
            BlossomBackgroundTransferEvent(
              taskId: taskId,
              status: BlossomBackgroundTransferStatus.completed,
              httpStatusCode: 200,
            ),
          ],
        );

        final result = await service(transport).uploadVideoInBackground(
          videoFile: videoFile,
          taskId: taskId,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);
        expect(transport.enqueued, <String>[taskId], reason: 're-uploaded');
      },
    );
  });
}
