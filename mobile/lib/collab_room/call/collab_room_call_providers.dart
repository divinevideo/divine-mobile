// ABOUTME: The call of a Together room as one instance shared by every screen
// ABOUTME: of the room's flow: the room itself and the editor of a part

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_cubit.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Which call: the room, its call key, and the account taking part.
typedef CollabRoomCallId = ({String roomId, String callKey, String me});

/// The call of one room, alive while any screen of the room's flow shows it.
///
/// The room screen holds it, and a part's editor screen shares it, so
/// someone can talk while editing and the call survives the camera flow. It
/// hangs up once no screen holds it any more. The call itself is a
/// [CollabRoomCallCubit]: Riverpod only keeps the one instance alive across
/// routes, which no widget above both screens could provide.
final ProviderFamily<CollabRoomCallCubit, CollabRoomCallId>
collabRoomCallProvider = Provider.autoDispose
    .family<CollabRoomCallCubit, CollabRoomCallId>((ref, id) {
      final client = ref.watch(nostrServiceProvider);
      final blocklist = ref.watch(contentBlocklistRepositoryProvider);
      final cubit = CollabRoomCallCubit(
        me: id.me,
        callKey: id.callKey,
        others: const {},
        createCall: ({required me, required others, required callKey}) =>
            WebRtcCollabRoomCall(
              me: me,
              others: others,
              callKey: callKey,
              accountSigner: client.signer,
              transport: NostrCollabRoomCallTransport(client),
            ),
      );
      // The call seals every message with the account's signer and sends it
      // through the client, so it waits for the session to be able to sign:
      // a Keycast identity is known before its signer is.
      bool canSign() {
        final session = ref.read(nostrSessionProvider);
        return session.isReadyForActiveClient && session.pubkey == id.me;
      }

      void syncPeers(CollabRoom? room) {
        if (room == null ||
            !canSign() ||
            client.publicKey != id.me ||
            room.ownerPubkey != id.me ||
            room.callKey != id.callKey ||
            !room.phase.isOpen ||
            room.me?.status != CollabRoomMemberStatus.joined) {
          cubit.othersChanged(const {});
          runDetached(
            cubit.leave(),
            'leave a closed collab room call',
            logName: 'CollabRoomCallProvider',
            category: LogCategory.video,
          );
          return;
        }
        final blocked = blocklist.blockedPubkeysForAccount(id.me);
        final peers = {
          for (final member in room.participants)
            if (member.pubkey != id.me && !blocked.contains(member.pubkey))
              member.pubkey,
        };
        cubit.othersChanged(peers);
        if (peers.isEmpty) {
          runDetached(
            cubit.leave(),
            'leave a collab room call without peers',
            logName: 'CollabRoomCallProvider',
            category: LogCategory.video,
          );
        }
      }

      final roomProvider = collabRoomLiveProvider(id.roomId);
      ref.listen(
        roomProvider,
        (_, next) => syncPeers(next.value),
        fireImmediately: true,
      );
      ref.listen(
        nostrSessionProvider,
        (_, _) => syncPeers(ref.read(roomProvider).value),
      );
      final blocks = blocklist.changes.listen(
        (_) => syncPeers(ref.read(roomProvider).value),
      );
      ref.onDispose(() => unawaited(blocks.cancel()));
      ref.onDispose(
        () => runDetached(
          cubit.close(),
          'hang up the collab room call',
          logName: 'CollabRoomCallProvider',
          category: LogCategory.video,
        ),
      );
      return cubit;
    });

/// The call of the part being filmed or edited, or `null` outside a part or
/// for a room without a call.
CollabRoomCallId? collabRoomPartCallId(CollabRoomPartContext? part) {
  final callKey = part?.callKey;
  final me = part?.me;
  if (part == null || !part.isActive || callKey == null || me == null) {
    return null;
  }
  return (roomId: part.roomId, callKey: callKey, me: me);
}

/// Leaves the call of the part being filmed, if the editor joined it, so the
/// camera can take the microphone back.
Future<void> leaveCollabRoomPartCall(WidgetRef ref) async {
  final id = collabRoomPartCallId(ref.read(collabRoomPartProvider));
  if (id == null) return;
  await ref.read(collabRoomCallProvider(id)).leave();
}
