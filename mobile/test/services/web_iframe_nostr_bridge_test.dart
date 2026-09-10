// ABOUTME: Tests for WebIframeNostrBridge — postMessage envelope parsing,
// ABOUTME: origin gating, and signer routing via the test hook.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/web_iframe_nostr_bridge.dart';

class _MockWebAuthService extends Mock implements WebAuthService {}

class _MockWebSigner extends Mock implements WebSigner {}

void main() {
  group(WebIframeNostrBridge, () {
    const allowedOrigin = 'https://verifier.divine.video';
    const fakePubkey =
        'aaaa11111111111111111111111111111111111111111111111111111111aaaa';

    late _MockWebAuthService auth;
    late _MockWebSigner signer;
    late WebIframeNostrBridge bridge;
    late List<({Object? message, String origin})> replies;
    late NostrAppDirectoryEntry app;

    setUp(() {
      auth = _MockWebAuthService();
      signer = _MockWebSigner();
      app = const NostrAppDirectoryEntry(
        id: 'verifier',
        slug: 'verifier',
        name: 'Verifier',
        tagline: 'tagline',
        description: 'description',
        iconUrl: 'https://verifier.divine.video/favicon.ico',
        launchUrl: '$allowedOrigin/',
        allowedOrigins: [allowedOrigin],
        allowedMethods: ['getPublicKey', 'getRelays', 'signEvent'],
        allowedSignEventKinds: [0],
        promptRequiredFor: [],
        status: 'approved',
        sortOrder: 1,
        createdAt: null,
        updatedAt: null,
      );
      bridge = WebIframeNostrBridge(
        app: app,
        authService: auth,
      );
      replies = [];
    });

    Future<void> dispatch(String origin, dynamic data) async {
      await bridge.handleMessageForTest(
        origin: origin,
        data: data,
        postReply: (message, targetOrigin) {
          replies.add((message: message, origin: targetOrigin));
        },
      );
    }

    group('origin gating', () {
      test('ignores messages from a non-allowed origin', () async {
        when(() => auth.signer).thenReturn(signer);
        when(() => auth.publicKey).thenReturn(fakePubkey);

        await dispatch('https://evil.example.com', {
          'type': 'divine:nostr.request',
          'id': 1,
          'method': 'getPublicKey',
        });

        expect(replies, isEmpty);
        verifyNever(() => auth.publicKey);
      });
    });

    group('envelope parsing', () {
      test('ignores non-Map data', () async {
        await dispatch(allowedOrigin, 'not-a-map');
        expect(replies, isEmpty);
      });

      test('ignores messages with the wrong type tag', () async {
        await dispatch(allowedOrigin, {
          'type': 'something.else',
          'id': 1,
          'method': 'getPublicKey',
        });
        expect(replies, isEmpty);
      });

      test('ignores messages without a numeric id', () async {
        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 'not-a-number',
          'method': 'getPublicKey',
        });
        expect(replies, isEmpty);
      });

      test('ignores messages without a string method', () async {
        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 1,
          'method': 42,
        });
        expect(replies, isEmpty);
      });
    });

    group('getPublicKey', () {
      test('returns the host signer pubkey', () async {
        when(() => auth.signer).thenReturn(signer);
        when(() => auth.publicKey).thenReturn(fakePubkey);

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 7,
          'method': 'getPublicKey',
        });

        expect(replies, hasLength(1));
        final reply = replies.single;
        expect(reply.origin, equals(allowedOrigin));
        final message = reply.message! as Map<String, dynamic>;
        expect(message['type'], equals('divine:nostr.response'));
        expect(message['id'], equals(7));
        expect(message['result'], equals(fakePubkey));
        expect(message.containsKey('error'), isFalse);
      });

      test('replies with error when no signer is active', () async {
        when(() => auth.signer).thenReturn(null);

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 8,
          'method': 'getPublicKey',
        });

        expect(replies, hasLength(1));
        final message = replies.single.message! as Map<String, dynamic>;
        expect(message['id'], equals(8));
        expect(message.containsKey('result'), isFalse);
        expect(message['error'], contains('No active Divine signer'));
      });
    });

    group('signEvent', () {
      test(
        'forwards the unsigned event and returns the signed payload',
        () async {
          when(() => auth.signer).thenReturn(signer);
          final unsigned = <String, dynamic>{
            'kind': 0,
            'content': 'hi',
            'tags': <List<String>>[],
          };
          final signed = <String, dynamic>{
            ...unsigned,
            'pubkey': fakePubkey,
            'id': 'bbbb22222222222222222222222222222222222222222222222222222222bbbb',
            'sig': 'cafe' * 32,
          };
          when(() => signer.signEvent(any())).thenAnswer((_) async => signed);

          await dispatch(allowedOrigin, {
            'type': 'divine:nostr.request',
            'id': 11,
            'method': 'signEvent',
            'params': {'event': unsigned},
          });

          expect(replies, hasLength(1));
          final message = replies.single.message! as Map<String, dynamic>;
          expect(message['id'], equals(11));
          expect(message['result'], equals(signed));
          verify(() => signer.signEvent(unsigned)).called(1);
        },
      );

      test('replies with error when params.event is missing', () async {
        when(() => auth.signer).thenReturn(signer);

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 12,
          'method': 'signEvent',
          'params': <String, dynamic>{},
        });

        expect(replies, hasLength(1));
        final message = replies.single.message! as Map<String, dynamic>;
        expect(message['id'], equals(12));
        expect(message['error'], contains('params.event must be an object'));
      });

      test('replies with error when the signer returns null', () async {
        when(() => auth.signer).thenReturn(signer);
        when(() => signer.signEvent(any())).thenAnswer((_) async => null);

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 13,
          'method': 'signEvent',
          'params': {
            'event': <String, dynamic>{'kind': 0, 'content': ''},
          },
        });

        expect(replies, hasLength(1));
        final message = replies.single.message! as Map<String, dynamic>;
        expect(message['id'], equals(13));
        expect(message['error'], contains('user rejected or failed'));
      });

      test(
        'replies with error when signEvent kind is outside allowlist',
        () async {
          when(() => auth.signer).thenReturn(signer);

          await dispatch(allowedOrigin, {
            'type': 'divine:nostr.request',
            'id': 13,
            'method': 'signEvent',
            'params': {
              'event': <String, dynamic>{'kind': 1, 'content': ''},
            },
          });

          expect(replies, hasLength(1));
          final message = replies.single.message! as Map<String, dynamic>;
          expect(message['id'], equals(13));
          expect(message['error'], contains('Blocked signEvent kind'));
          verifyNever(() => signer.signEvent(any()));
        },
      );

      test('surfaces signer exceptions to the iframe', () async {
        when(() => auth.signer).thenReturn(signer);
        when(
          () => signer.signEvent(any()),
        ).thenThrow(StateError('signer offline'));

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 14,
          'method': 'signEvent',
          'params': {
            'event': <String, dynamic>{'kind': 0, 'content': 'x'},
          },
        });

        expect(replies, hasLength(1));
        final message = replies.single.message! as Map<String, dynamic>;
        expect(message['id'], equals(14));
        expect(message['error'], contains('signer offline'));
      });
    });

    group('getRelays', () {
      test('returns an empty object', () async {
        when(() => auth.signer).thenReturn(signer);

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 21,
          'method': 'getRelays',
        });

        expect(replies, hasLength(1));
        final message = replies.single.message! as Map<String, dynamic>;
        expect(message['id'], equals(21));
        expect(message['result'], equals(<String, dynamic>{}));
      });
    });

    group('unknown methods', () {
      test('replies with an error for unsupported methods', () async {
        when(() => auth.signer).thenReturn(signer);

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 31,
          'method': 'nip04_encrypt',
        });

        expect(replies, hasLength(1));
        final message = replies.single.message! as Map<String, dynamic>;
        expect(message['id'], equals(31));
        expect(message['error'], contains('Unsupported embed-bridge method'));
      });
    });

    group('prompt-required capabilities', () {
      test('denies signEvent when the app requires prompting for it', () async {
        when(() => auth.signer).thenReturn(signer);
        bridge = WebIframeNostrBridge(
          app: NostrAppDirectoryEntry(
            id: app.id,
            slug: app.slug,
            name: app.name,
            tagline: app.tagline,
            description: app.description,
            iconUrl: app.iconUrl,
            launchUrl: app.launchUrl,
            allowedOrigins: app.allowedOrigins,
            allowedMethods: app.allowedMethods,
            allowedSignEventKinds: app.allowedSignEventKinds,
            promptRequiredFor: const ['signEvent'],
            status: app.status,
            sortOrder: app.sortOrder,
            createdAt: app.createdAt,
            updatedAt: app.updatedAt,
            autoLoginScript: app.autoLoginScript,
          ),
          authService: auth,
        );

        await dispatch(allowedOrigin, {
          'type': 'divine:nostr.request',
          'id': 41,
          'method': 'signEvent',
          'params': {
            'event': <String, dynamic>{'kind': 0, 'content': 'x'},
          },
        });

        expect(replies, hasLength(1));
        final message = replies.single.message! as Map<String, dynamic>;
        expect(message['id'], equals(41));
        expect(
          message['error'],
          contains(
            'Prompt-required bridge capabilities are not supported on web',
          ),
        );
        verifyNever(() => signer.signEvent(any()));
      });
    });
  });
}
