import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nip98_http_client.dart';
import 'package:openvine/services/notification_activity_sender.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(NotificationActivitySender, () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const update = NotificationActivityUpdate(
      sessionId: 'c8da3021-9bd3-48fb-81e6-4b709a5b86f3',
      sequence: 1,
      visit: 1,
      state: NotificationActivityState.foreground,
    );
    late _MockAuthService auth;
    late Nip98AuthService nip98;
    late List<http.Request> requests;
    late NotificationActivitySender sender;
    late int signatures;
    var rejectClock = false;
    Future<void> Function()? beforeSignature;
    var current = true;

    setUp(() {
      signatures = 0;
      rejectClock = false;
      current = true;
      beforeSignature = null;
      auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
          allowUserInteraction: false,
        ),
      ).thenAnswer((invocation) async {
        signatures++;
        await beforeSignature?.call();
        return Event(
          owner,
          27235,
          invocation.namedArguments[#tags]! as List<List<String>>,
          '',
          createdAt: invocation.namedArguments[#createdAt] as int?,
        );
      });
      nip98 = Nip98AuthService(authService: auth);
      requests = [];
      final transport = MockClient((request) async {
        requests.add(request);
        if (rejectClock && requests.length == 1) {
          return http.Response(
            '{"error":"Auth failed: event timestamp is in the future"}',
            401,
            headers: {'date': 'Thu, 29 Oct 2026 19:00:00 GMT'},
          );
        }
        return http.Response('', 204);
      });
      final signedTransport = Nip98HttpClient(
        inner: transport,
        authService: nip98,
        trustedOrigin: Uri.parse('https://api.example.com'),
        allowUserInteraction: false,
      );
      final client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: signedTransport,
      );
      addTearDown(signedTransport.close);
      addTearDown(transport.close);
      addTearDown(client.dispose);
      addTearDown(nip98.dispose);
      sender = NotificationActivitySender(
        client: client,
        authService: nip98,
      );
    });

    test('every retry freshly signs the exact URL, method, and body', () async {
      await sender.send(owner, update, () => current);
      await sender.send(owner, update, () => current);

      expect(signatures, 2);
      expect(requests, hasLength(2));
      expect(requests.last.body, requests.first.body);
      for (final request in requests) {
        final event = jsonDecode(
          utf8.decode(
            base64Decode(
              request.headers['Authorization']!.substring(6),
            ),
          ),
        ) as Map<String, dynamic>;
        expect(event['pubkey'], owner);
        expect(event['tags'], contains(equals(['u', request.url.toString()])));
        expect(event['tags'], contains(equals(['method', 'POST'])));
        expect(
          event['tags'],
          contains(
            equals([
              'payload',
              sha256.convert(utf8.encode(request.body)).toString(),
            ]),
          ),
        );
      }
    });

    test('account switch during signing prevents HTTP transmission', () async {
      final signing = Completer<void>();
      beforeSignature = () => signing.future;
      final operation = sender.send(owner, update, () => current);
      current = false;
      signing.complete();
      await operation;
      expect(requests, isEmpty);
    });

    test('clock-skew retry also uses only noninteractive signing', () async {
      rejectClock = true;
      await sender.send(owner, update, () => current);
      expect(requests, hasLength(2));
      expect(signatures, 2);
      expect(requests.last.body, update.body);
    });

    test('a different current signing owner is never used', () async {
      await sender.send('b' * 64, update, () => current);
      expect(signatures, 0);
      expect(requests, isEmpty);
    });
  });
}
