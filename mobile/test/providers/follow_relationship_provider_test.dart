// ABOUTME: Tests for Riverpod follow relationship warm-up lifecycle.
// ABOUTME: Pins signed-out to ready transitions so follower cache warm-up reruns.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

void main() {
  const currentPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const targetPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group('myFollowersWarmupProvider', () {
    test(
      'warm-up waits for a ready Nostr session and reruns in the same container',
      () async {
        final repository = _MockFollowRepository();
        final nostrClient = _MockNostrClient();
        when(() => nostrClient.hasKeys).thenReturn(true);
        when(() => nostrClient.publicKey).thenReturn(currentPubkey);
        when(
          repository.getMyFollowers,
        ).thenAnswer((_) async => const <String>[]);

        final container = ProviderContainer(
          overrides: [
            followRepositoryProvider.overrideWithValue(repository),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(const NostrSessionReadiness.signedOut()),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(myFollowersWarmupProvider.future);
        verifyNever(repository.getMyFollowers);

        container
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.nostrReady(
                pubkey: currentPubkey,
                client: nostrClient,
              ),
            );

        await container.read(myFollowersWarmupProvider.future);
        verify(repository.getMyFollowers).called(1);
      },
    );
  });

  group('followRelationshipProvider', () {
    test(
      'relationship stream upgrades when follower warm-up completes',
      () async {
        final repository = _MockFollowRepository();
        final nostrClient = _MockNostrClient();
        final warmupCompleter = Completer<List<String>>();
        var warmupComplete = false;

        when(() => nostrClient.hasKeys).thenReturn(true);
        when(() => nostrClient.publicKey).thenReturn(currentPubkey);
        when(repository.getMyFollowers).thenAnswer((_) async {
          final followers = await warmupCompleter.future;
          warmupComplete = true;
          return followers;
        });
        when(() => repository.relationshipTo(targetPubkey)).thenAnswer(
          (_) => warmupComplete
              ? FollowRelationship.mutual
              : FollowRelationship.youFollow,
        );
        when(
          () => repository.followingStream,
        ).thenAnswer((_) => const Stream<List<String>>.empty());

        final container = ProviderContainer(
          overrides: [
            followRepositoryProvider.overrideWithValue(repository),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                NostrSessionReadiness.nostrReady(
                  pubkey: currentPubkey,
                  client: nostrClient,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <AsyncValue<FollowRelationship>>[];
        final initial = Completer<void>();
        final upgraded = Completer<void>();
        final subscription = container.listen(
          followRelationshipProvider(targetPubkey),
          (_, next) {
            emitted.add(next);
            if (next.value == FollowRelationship.youFollow &&
                !initial.isCompleted) {
              initial.complete();
            }
            if (next.value == FollowRelationship.mutual &&
                !upgraded.isCompleted) {
              upgraded.complete();
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await initial.future;
        expect(emitted.last.value, FollowRelationship.youFollow);

        warmupCompleter.complete(const <String>[targetPubkey]);
        await container.read(myFollowersWarmupProvider.future);
        await upgraded.future;

        expect(emitted.last.value, FollowRelationship.mutual);
      },
    );
  });
}
