// ABOUTME: Multipart contract tests for ApiService's parent-consent upload
// ABOUTME: Pins URL, email field, video part, payload-free NIP-98 token, timeout

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

/// Placeholder author for the fake signed event; [Event] only requires a
/// 32-byte hex pubkey.
const _placeholderPubkey =
    '0000000000000000000000000000000000000000000000000000000000000000';

/// Records how [ApiService] asks for a NIP-98 token, so the payload omission
/// ruling can be asserted without constructing a signing [Nip98AuthService].
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
  String? capturedUrl;
  HttpMethod? capturedMethod;
  String? capturedPayload;

  @override
  Future<Nip98Token?> createAuthToken({
    required String url,
    required HttpMethod method,
    String? payload,
  }) async {
    createCalled = true;
    capturedUrl = url;
    capturedMethod = method;
    capturedPayload = payload;
    return token;
  }

  @override
  bool get canCreateTokens => true;

  @override
  String? get currentUserPubkey => null;

  @override
  Map<String, dynamic> get cacheStats => const <String, dynamic>{};

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

    test('creates the NIP-98 token without a payload', () async {
      final client = MockClient((request) async => http.Response('', 201));
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
    });

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
