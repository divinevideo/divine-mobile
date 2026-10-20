// ABOUTME: Multipart contract tests for ApiService's parent-consent upload
// ABOUTME: Pins URL, email/video parts, binary NIP-98 body binding, and timeout.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/consent_upload_session.dart';
import 'package:openvine/services/nip98_auth_service.dart';

/// Placeholder author for the fake signed event; [Event] only requires a
/// 32-byte hex pubkey.
const _placeholderPubkey =
    '0000000000000000000000000000000000000000000000000000000000000000';

class _MockAuthService extends Mock implements AuthService {}

/// Records how [ApiService] asks for a NIP-98 token.
class _RecordingNip98AuthService implements Nip98AuthService {
  _RecordingNip98AuthService()
    : token = Nip98Token(
        token: 'test-token',
        signedEvent: Event(
          _placeholderPubkey,
          27235,
          const <List<String>>[],
          '',
        ),
        createdAt: DateTime(2026),
        expiresAt: DateTime(2100),
      );

  final Nip98Token token;
  bool createCalled = false;
  int createCount = 0;
  String? capturedUrl;
  HttpMethod? capturedMethod;
  String? capturedPayload;
  String? capturedPayloadHash;
  bool? capturedReuseCached;

  @override
  Future<Nip98Token?> createAuthToken({
    required String url,
    required HttpMethod method,
    String? payload,
    String? payloadHash,
    bool reuseCached = true,
  }) async {
    createCalled = true;
    createCount++;
    capturedUrl = url;
    capturedMethod = method;
    capturedPayload = payload;
    capturedPayloadHash = payloadHash;
    capturedReuseCached = reuseCached;
    return token;
  }

  @override
  bool get canCreateTokens => true;

  @override
  String? get currentUserPubkey => null;

  @override
  Map<String, dynamic> get cacheStats => const <String, dynamic>{};

  @override
  bool isCurrentOwner(String pubkey) => pubkey == _placeholderPubkey;

  @override
  void updateServerTime(Uri uri, DateTime serverTime) {}

  @override
  void clearTokenCache() {}

  @override
  void dispose() {}
}

void main() {
  late Directory tempDir;
  late File clip;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('consent-api-test');
    clip = File('${tempDir.path}/consent.mp4')..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ApiService.submitMinorAccountReviewParentConsent', () {
    test(
      'retries send the same multipart bytes after a transport failure',
      () async {
        final session = ConsentUploadSession();
        addTearDown(session.dispose);
        final bodies = <List<int>>[];
        final auth = _RecordingNip98AuthService();
        final api = ApiService(
          relayManagerBaseUrl: 'https://api.test',
          appVersion: 'test',
          authService: auth,
          client: MockClient((request) async {
            bodies.add(request.bodyBytes);
            if (bodies.length == 1) throw const SocketException('offline');
            return http.Response('', 201);
          }),
        );
        Future<void> submit() => api.submitMinorAccountReviewParentConsent(
          caseId: 'case-123',
          email: 'parent@example.com',
          videoPath: clip.path,
          session: session,
        );
        await expectLater(submit(), throwsA(isA<ApiException>()));
        await submit();
        expect(bodies[1], bodies[0]);
      },
    );

    test(
      'timed-out retry waits for the existing transport and keeps its file',
      () async {
        final session = ConsentUploadSession();
        addTearDown(session.dispose);
        final response = Completer<http.Response>();
        final started = Completer<void>();
        var sends = 0;
        final client = MockClient((request) async {
          sends++;
          if (!started.isCompleted) started.complete();
          return response.future;
        });
        final auth = _RecordingNip98AuthService();
        ApiService api({Duration? timeout}) => ApiService(
          relayManagerBaseUrl: 'https://api.test',
          appVersion: 'test',
          uploadTimeout: timeout ?? const Duration(seconds: 120),
          authService: auth,
          client: client,
        );
        Future<void> submit(ApiService service) =>
            service.submitMinorAccountReviewParentConsent(
              caseId: 'case-123',
              email: 'parent@example.com',
              videoPath: clip.path,
              session: session,
            );
        // Expire only the first caller; Retry uses the real upload budget.
        await expectLater(
          submit(api(timeout: Duration.zero)),
          throwsA(isA<ApiException>()),
        );
        await started.future;
        final retry = submit(api());
        response.complete(http.Response('', 201));
        await retry;
        expect(sends, 1);
        expect(auth.createCount, 1);
      },
    );

    test(
      'retry after timed-out transport succeeds does not upload or sign again',
      () async {
        final session = ConsentUploadSession();
        addTearDown(session.dispose);
        final response = Completer<http.Response>();
        final started = Completer<void>();
        final auth = _RecordingNip98AuthService();
        var sends = 0;
        final client = MockClient((request) async {
          sends++;
          if (!started.isCompleted) started.complete();
          return response.future;
        });
        ApiService api({Duration? timeout}) => ApiService(
          relayManagerBaseUrl: 'https://api.test',
          appVersion: 'test',
          uploadTimeout: timeout ?? const Duration(seconds: 120),
          authService: auth,
          client: client,
        );
        Future<void> submit(ApiService service) =>
            service.submitMinorAccountReviewParentConsent(
              caseId: 'case-123',
              email: 'parent@example.com',
              videoPath: clip.path,
              session: session,
            );
        await expectLater(
          submit(api(timeout: Duration.zero)),
          throwsA(isA<ApiException>()),
        );
        await started.future;
        // Join only to observe the original transport settling before Retry.
        final settled = session.send(
          prepare: () => throw StateError('must reuse pending upload'),
          transmit: (_) => throw StateError('must reuse pending transport'),
        );
        response.complete(http.Response('', 201));
        await settled;
        await submit(api());
        expect(sends, 1);
        expect(auth.createCount, 1);
      },
    );

    test(
      'signs the exact binary multipart snapshot sent to the server',
      () async {
        final originalVideo = [0, 128, 255, 13, 10, 1];
        clip.writeAsBytesSync(originalVideo);
        const syntheticKey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        final pubkey = getPublicKey(syntheticKey);
        final signer = _MockAuthService();
        when(() => signer.isAuthenticated).thenReturn(true);
        when(() => signer.currentPublicKeyHex).thenReturn(pubkey);
        when(
          () => signer.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((call) async {
          // A remote signer can yield long enough for the source to change.
          // The upload must still send the already-hashed snapshot.
          clip.writeAsBytesSync([9, 9, 9]);
          return Event(
            pubkey,
            27235,
            call.namedArguments[#tags]! as List<List<String>>,
            '',
            createdAt: call.namedArguments[#createdAt] as int?,
          )..sign(syntheticKey);
        });
        final auth = Nip98AuthService(authService: signer);
        addTearDown(auth.dispose);
        http.Request? sent;
        final api = ApiService(
          relayManagerBaseUrl: 'https://api.test',
          appVersion: 'test',
          authService: auth,
          client: MockClient((request) async {
            sent = request;
            return http.Response('', 201);
          }),
        );
        await api.submitMinorAccountReviewParentConsent(
          caseId: 'case-123',
          email: 'parent@example.com',
          videoPath: clip.path,
        );
        final request = sent!;
        final event = jsonDecode(
          utf8.decode(
            base64Decode(request.headers['Authorization']!.substring(6)),
          ),
        ) as Map<String, dynamic>;
        final tags = event['tags'] as List<dynamic>;
        expect(Event.fromJson(event).isSigned, isTrue);
        expect(
          tags.singleWhere((dynamic tag) => tag[0] == 'payload')[1],
          sha256.convert(request.bodyBytes).toString(),
        );
        expect(request.bodyBytes, containsAllInOrder(originalVideo));
      },
    );

    test('posts multipart with the email field and video file part', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('', 201);
      });
      final auth = _RecordingNip98AuthService();
      final api = ApiService(
        client: client,
        authService: auth,
        relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
        appVersion: '1.0.20',
      );

      await api.submitMinorAccountReviewParentConsent(
        caseId: 'case-123',
        email: 'parent@example.com',
        videoPath: clip.path,
      );

      final request = captured!;
      expect(request.method, 'POST');
      expect(request.url.host, 'api-relay-prod.divine.video');
      expect(
        request.url.path,
        '/v1/minor-review-cases/case-123/parent-consent',
      );
      expect(
        request.headers['Content-Type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['X-Divine-Platform'], isNotNull);

      final body = utf8.decode(request.bodyBytes);
      expect(body, contains('name="email"'));
      expect(body, contains('parent@example.com'));
      expect(body, contains('name="video"'));
      expect(body, contains('filename="consent.mp4"'));
    });

    test('labels the video part as video/mp4', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('', 201);
      });
      final api = ApiService(
        client: client,
        authService: _RecordingNip98AuthService(),
        relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
        appVersion: '1.0.20',
      );

      await api.submitMinorAccountReviewParentConsent(
        caseId: 'case-123',
        email: 'parent@example.com',
        videoPath: clip.path,
      );

      // relay-manager rejects a video part whose Content-Type is not video/*
      // with a 415, so the default application/octet-stream never uploads.
      final boundary = captured!.headers['Content-Type']!.split(
        'boundary=',
      )[1];
      final videoPart = utf8
          .decode(captured!.bodyBytes)
          .split('--$boundary')
          .singleWhere((part) => part.contains('name="video"'));
      final partHeaders = videoPart.split('\r\n\r\n').first.toLowerCase();
      expect(partHeaders, contains('content-type: video/mp4'));
    });

    test(
      'creates fresh NIP-98 auth bound to the entire multipart body',
      () async {
        http.Request? sent;
        final client = MockClient((request) async {
          sent = request;
          return http.Response('', 201);
        });
        final auth = _RecordingNip98AuthService();
        final api = ApiService(
          client: client,
          authService: auth,
          relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
          appVersion: '1.0.20',
        );

        await api.submitMinorAccountReviewParentConsent(
          caseId: 'case-123',
          email: 'parent@example.com',
          videoPath: clip.path,
        );

        expect(auth.createCalled, isTrue);
        expect(auth.capturedMethod, HttpMethod.post);
        expect(
          auth.capturedUrl,
          'https://api-relay-prod.divine.video/v1/minor-review-cases/'
          'case-123/parent-consent',
        );
        expect(auth.capturedPayload, isNull);
        expect(
          auth.capturedPayloadHash,
          sha256.convert(sent!.bodyBytes).toString(),
        );
        expect(auth.capturedReuseCached, isFalse);
      },
    );

    test('upload path uses the longer multipart timeout', () async {
      final timers = <Timer>[];
      final client = MockClient((request) {
        final gate = Completer<http.Response>();
        timers.add(
          Timer(
            const Duration(milliseconds: 80),
            () => gate.complete(http.Response('', 201)),
          ),
        );
        return gate.future;
      });
      addTearDown(() {
        for (final timer in timers) {
          timer.cancel();
        }
      });
      final api = ApiService(
        client: client,
        authService: _RecordingNip98AuthService(),
        relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
        appVersion: 'test',
        requestTimeout: const Duration(milliseconds: 20),
      );

      // Completes after 80 ms, well past the 20 ms default: reaching here means
      // the upload ran under the 120 s multipart timeout, not the default.
      await api.submitMinorAccountReviewParentConsent(
        caseId: 'case-123',
        email: 'parent@example.com',
        videoPath: clip.path,
      );
    });
  });
}
