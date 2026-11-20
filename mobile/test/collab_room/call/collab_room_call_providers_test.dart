// ABOUTME: Tests for the shared room call provider: who it connects to, and
// ABOUTME: that it waits for the account to be able to sign

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmMessage;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/collab_room/call/collab_room_call_providers.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';

import '../view/collab_room_test_fixtures.dart' show joinMessage;

class _MockNostrClient extends Mock implements NostrClient {}

class _MockBlocklist extends Mock implements ContentBlocklistRepository {}

class _MockCollabRoomService extends Mock implements CollabRoomService {}

class _Session extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: _sam);
}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _roomId = '0123456789abcdef0123456789abcdef';
const _callKey =
    '1111111111111111111111111111111111111111111111111111111111111111';

/// Sam's view of a room Sam joined, with a call.
final CollabRoom _room = foldCollabRooms([
  DmMessage(
    id: '1' * 64,
    conversationId: DmRepository.computeConversationId([_author, _sam]),
    senderPubkey: _author,
    content: 'text',
    createdAt: 1,
    giftWrapId: '2' * 64,
    tags: collabRoomTags(
      roomId: _roomId,
      type: CollabRoomMessageType.invite,
      recipientPubkey: _sam,
      snapshot: const CollabRoomSnapshot(
        revision: 0,
        phase: CollabRoomPhase.lobby,
        callKey: _callKey,
        members: [
          CollabRoomMember(
            pubkey: _author,
            status: CollabRoomMemberStatus.joined,
          ),
          CollabRoomMember(pubkey: _sam, status: CollabRoomMemberStatus.joined),
        ],
      ),
    ),
  ),
  joinMessage(from: _sam, to: _author, room: _roomId),
], ownerPubkey: _sam).single;

void main() {
  group('collabRoomCallProvider', () {
    test('connects to no one until the account can sign', () async {
      final client = _MockNostrClient();
      when(() => client.publicKey).thenReturn(_sam);
      when(() => client.hasKeys).thenReturn(true);
      final blocklist = _MockBlocklist();
      when(() => blocklist.blockedPubkeysForAccount(_sam)).thenReturn({});
      when(() => blocklist.changes).thenAnswer((_) => const Stream.empty());
      final service = _MockCollabRoomService();
      when(
        () => service.watchRoom(_roomId),
      ).thenAnswer((_) => Stream.value(_room));
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(client),
          contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          collabRoomServiceProvider.overrideWithValue(service),
          nostrSessionProvider.overrideWith(_Session.new),
        ],
      );
      addTearDown(container.dispose);
      const id = (roomId: _roomId, callKey: _callKey, me: _sam);
      final subscription = container.listen(
        collabRoomCallProvider(id),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final call = subscription.read();
      await pumpEventQueue();

      // The identity is known, its signer not yet: nobody to call.
      expect(call.state.others, isEmpty);

      container
          .read(nostrSessionProvider.notifier)
          .update(
            NostrSessionReadiness.nostrReady(pubkey: _sam, client: client),
          );
      await pumpEventQueue();

      expect(call.state.others, {_author});
    });
  });
}
