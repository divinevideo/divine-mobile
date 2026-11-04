// ABOUTME: Pins how two watchers of one video must share the relay state.
// ABOUTME: A narrower taggedPubkeys list replaces the shared subscription.

import 'dart:async';

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

class _NoLocalState implements CollaboratorInviteLocalStateReader {
  @override
  CollaboratorStatus? readLocalState({
    required String videoAddress,
    required String creatorPubkey,
    required String collaboratorPubkey,
  }) => null;
}

const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collabA =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collabB =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _videoAddress = '34236:$_creatorPubkey:vine-1';

Event _acceptance(String pubkey) => Event(pubkey, 34238, [
  ['a', _videoAddress, 'wss://relay.divine.video', 'root'],
  ['p', _creatorPubkey],
  ['status', 'accepted'],
], '');

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_FakeFilter());
  });

  group(CollaboratorConfirmationRepository, () {
    late _MockNostrClient nostrClient;
    late List<StreamController<Event>> relayControllers;
    late List<String> unsubscribed;

    setUp(() {
      nostrClient = _MockNostrClient();
      relayControllers = [];
      unsubscribed = [];
      when(
        () => nostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) {
        final controller = StreamController<Event>.broadcast();
        relayControllers.add(controller);
        return controller.stream;
      });
      when(() => nostrClient.unsubscribe(any())).thenAnswer((invocation) async {
        unsubscribed.add(invocation.positionalArguments.first as String);
      });
    });

    tearDown(() async {
      for (final controller in relayControllers) {
        await controller.close();
      }
    });

    CollaboratorConfirmationRepository buildRepo() =>
        CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _NoLocalState(),
          currentUserPubkey: _creatorPubkey,
        );

    group('watch', () {
      test('a second watcher with the full tagged list shares the '
          'subscription and keeps both confirmations', () async {
        final repo = buildRepo();
        final feed = <VideoCollaboratorStatus>[];
        final feedSub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collabA, _collabB],
            )
            .listen(feed.add);
        await pumpEventQueue();
        relayControllers.single
          ..add(_acceptance(_collabA))
          ..add(_acceptance(_collabB));
        await pumpEventQueue();
        expect(feed.last.statusFor(_collabA), CollaboratorStatus.confirmed);
        expect(feed.last.statusFor(_collabB), CollaboratorStatus.confirmed);

        final dmSub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collabB, _collabA],
            )
            .listen((_) {});
        await pumpEventQueue();

        expect(relayControllers, hasLength(1));
        expect(unsubscribed, isEmpty);
        expect(feed.last.statusFor(_collabA), CollaboratorStatus.confirmed);
        expect(feed.last.statusFor(_collabB), CollaboratorStatus.confirmed);

        await dmSub.cancel();
        await feedSub.cancel();
        await repo.close();
      });

      test('a second watcher with a narrower tagged list cancels the first '
          "watcher's subscription and drops its confirmations", () async {
        final repo = buildRepo();
        final feed = <VideoCollaboratorStatus>[];
        final feedSub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collabA, _collabB],
            )
            .listen(feed.add);
        await pumpEventQueue();
        relayControllers.single
          ..add(_acceptance(_collabA))
          ..add(_acceptance(_collabB));
        await pumpEventQueue();
        expect(feed.last.statusFor(_collabA), CollaboratorStatus.confirmed);
        expect(feed.last.statusFor(_collabB), CollaboratorStatus.confirmed);

        final dmSub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collabB],
            )
            .listen((_) {});
        await pumpEventQueue();

        expect(unsubscribed, hasLength(1));
        expect(relayControllers, hasLength(2));
        expect(
          feed.last.statusFor(_collabA),
          isNot(CollaboratorStatus.confirmed),
        );
        expect(feed.last.statusFor(_collabB), CollaboratorStatus.pending);

        await dmSub.cancel();
        await feedSub.cancel();
        await repo.close();
      });
    });
  });
}
