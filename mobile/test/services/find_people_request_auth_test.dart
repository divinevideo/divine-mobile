import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/find_people_request_auth.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(FindPeopleRequestAuth, () {
    final owner = 'a' * 64;
    final other = 'b' * 64;
    late _MockAuthService auth;
    late Nip98AuthService nip98;
    late FindPeopleRequestAuth requestAuth;
    late String? current;
    late String signingOwner;
    late bool authenticated;
    late int signatures;
    Future<void> Function()? beforeSignature;
    final uri = Uri.https(
      'api.example.test',
      '/api/users/$owner/follow-suggestions',
      {
        'limit': '3',
        'content_safety': 'default',
        'cursor': 'opaque +/?=',
      },
    );

    setUp(() {
      current = owner;
      signingOwner = owner;
      authenticated = true;
      signatures = 0;
      beforeSignature = null;
      auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenAnswer((_) => authenticated);
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => current);
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
          signingOwner,
          27235,
          invocation.namedArguments[#tags]! as List<List<String>>,
          '',
          createdAt: invocation.namedArguments[#createdAt] as int?,
        );
      });
      nip98 = Nip98AuthService(authService: auth);
      requestAuth = FindPeopleRequestAuth(
        owner: owner,
        currentPubkey: () => current,
        authService: nip98,
      );
      addTearDown(nip98.dispose);
    });

    test(
      'signs the full encoded URL and GET as the current account passively',
      () async {
        final headers = await requestAuth.headersFor(uri);
        final header = headers['Authorization']!;
        expect(header, startsWith('Nostr '));
        final event = jsonDecode(
          utf8.decode(base64Decode(header.substring('Nostr '.length))),
        ) as Map<String, dynamic>;
        expect(event['pubkey'], owner);
        expect(event['kind'], 27235);
        final tags = event['tags']! as List<dynamic>;
        expect(tags, contains(equals(['u', uri.toString()])));
        expect(tags, contains(equals(['method', 'GET'])));
        expect(
          tags.where(
            (dynamic tag) => (tag as List<dynamic>).first == 'payload',
          ),
          isEmpty,
        );
        expect(signatures, 1);
      },
    );

    test('unavailable signer uses the public context', () async {
      authenticated = false;
      expect(await requestAuth.headersFor(uri), isEmpty);
      expect(signatures, 0);
    });

    test('failed signer uses the public context without prompting', () async {
      beforeSignature = () async => throw StateError('signing unavailable');
      expect(await requestAuth.headersFor(uri), isEmpty);
      expect(signatures, 1);
    });

    test('already retired account never asks the replacement signer', () async {
      current = other;
      expect(await requestAuth.headersFor(uri), isEmpty);
      expect(signatures, 0);
    });

    test(
      'account change while signing discards the old request token',
      () async {
        final started = Completer<void>();
        final finish = Completer<void>();
        beforeSignature = () {
          started.complete();
          return finish.future;
        };
        final pending = requestAuth.headersFor(uri);
        await started.future;
        current = other;
        finish.complete();
        expect(await pending, isEmpty);
      },
    );

    test(
      'unexpected signing identity cannot authenticate another owner',
      () async {
        signingOwner = other;
        expect(await requestAuth.headersFor(uri), isEmpty);
        expect(signatures, 1);
      },
    );
  });
}
