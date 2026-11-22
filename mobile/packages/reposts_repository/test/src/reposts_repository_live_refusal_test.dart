// ABOUTME: The live reposts subscription comes back after every relay refuses
// ABOUTME: it, instead of staying dead for the rest of the session.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _pubkey =
    'f3e2d1c0b9a8f7e6d5c4b3a2f1e0d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2';

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group(RepostsRepository, () {
    late _MockNostrClient client;
    late Object firstError;
    late int subscribes;

    setUp(() {
      client = _MockNostrClient();
      subscribes = 0;
      when(client.resolvePublicKey).thenAnswer((_) async => _pubkey);
      when(() => client.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => client.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) {
        subscribes++;
        return subscribes == 1
            ? Stream.error(firstError)
            : const Stream.empty();
      });
    });

    group('initialize', () {
      test(
        'reopens the live reposts subscription after every relay refuses it',
        () {
          fakeAsync((async) {
            firstError = const RelaySubscriptionRefusedException(
              'rate-limited: slow down',
            );
            final repository = RepostsRepository(nostrClient: client);
            unawaited(repository.initialize());
            async.flushMicrotasks();
            expect(subscribes, equals(1));

            async.elapse(const Duration(minutes: 10));

            expect(subscribes, greaterThan(1));
            repository.dispose();
            async.flushMicrotasks();
          });
        },
      );

      test(
        'does not reopen the live reposts subscription after any other error',
        () {
          fakeAsync((async) {
            firstError = StateError('socket gone');
            final repository = RepostsRepository(nostrClient: client);
            unawaited(repository.initialize());
            async
              ..flushMicrotasks()
              ..elapse(const Duration(minutes: 10));

            expect(subscribes, equals(1));
            repository.dispose();
            async.flushMicrotasks();
          });
        },
      );
    });
  });
}
