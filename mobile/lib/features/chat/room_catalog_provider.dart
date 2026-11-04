// ABOUTME: Resolves configured real Rooms from verified Concord membership.
// ABOUTME: Keeps invalid production configuration visibly closed.
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/concord_store.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/provider_detached_future.dart';

const concordInviteUrl = String.fromEnvironment('CONCORD_INVITE_URL');

class ConcordRoomCatalog {
  ConcordRoomCatalog.poc() : session = null;
  ConcordRoomCatalog.real(this.session);
  final ConcordCommunitySession? session;
  bool get isReal => session != null;
  bool get ready => session?.ready ?? true;
  bool get canSend => session?.canPublish ?? true;
  List<ChatCommunity> get communities {
    final real = session;
    if (real == null) return const ChatState().communities;
    if (!real.ready) return const [];
    final channels = real.control!.publicChannels.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [
      ChatCommunity(
        real.bundle!.communityId,
        real.control!.name!,
        channels.map((c) => c.id).toList(),
        channelNames: {for (final c in channels) c.id: c.name},
      ),
    ];
  }

  String channelId(String channel) =>
      isReal ? channel : pocChannelIdFor(channel);
  GroupKey stream(String channel) => isReal
      ? publicChannelKey(
          session!.bundle!.communityRoot,
          channel,
          session!.bundle!.rootEpoch,
        )
      : pocStreamKeyFor(channel);
  Map<String, ConcordOutboxReadKey> outboxReadKeys(String channel) {
    final keys = <String, ConcordOutboxReadKey>{};
    for (final held
        in session?.heldMembership ?? const <ConcordInviteBundle>[]) {
      if (held.rootEpoch >= epoch) continue;
      final key = publicChannelKey(held.communityRoot, channel, held.rootEpoch);
      keys[key.pubkey] = (key: key, epoch: held.rootEpoch);
    }
    return Map.unmodifiable(keys);
  }

  int get epoch => session?.bundle?.rootEpoch ?? 0;
  // Rotation changes carrier keys, not the ownership of durable drafts.
  String get scope => session == null
      ? concordRelayUrl
      : '$concordRelayUrl/${session!.bundle?.communityId}';
}

final StreamProvider<ConcordRoomCatalog> concordRoomCatalogProvider =
    StreamProvider.autoDispose<ConcordRoomCatalog>((ref) async* {
      if (concordInviteUrl.isEmpty) {
        yield ConcordRoomCatalog.poc();
        return;
      }
      ref.watch(currentAuthStateProvider);
      final auth = ref.watch(authServiceProvider);
      final account = auth.currentPublicKeyHex;
      if (!auth.isAuthenticated ||
          account == null ||
          auth.currentIdentity == null) {
        throw StateError('Sign in to open this community');
      }
      final uri = Uri.parse(concordInviteUrl);
      if (!uri.path.startsWith('/invite/')) {
        throw const FormatException('Invalid community invitation');
      }
      final coordinate = NIP19Tlv.decodeNaddr(
        uri.path.substring('/invite/'.length).replaceFirst(RegExp(r'/$'), ''),
      );
      if (coordinate == null ||
          coordinate.kind != 33301 ||
          coordinate.id.isNotEmpty) {
        throw const FormatException('Invalid community invite coordinate');
      }
      final relay = WebSocketRelayGateway(concordRelayUrl);
      final session = ConcordCommunitySession(
        relay: relay,
        linkSigner: coordinate.author,
        fragment: ConcordInviteFragment.decode(uri.fragment),
        account: account,
        store: DriftConcordStore(
          dao: ref.watch(databaseProvider).concordStoreDao,
          account: account,
          scope: '$concordRelayUrl/community/${coordinate.author}',
        ),
      );
      final close = ref.read(accountStateWriteBarrierProvider).register(
        account,
        () async {
          await session.close();
          await relay.close();
        },
      );
      ref.onDispose(
        () => runProviderDetached(
          close(),
          'close community membership',
          logName: 'ConcordCommunity',
        ),
      );
      await session.start();
      String signatureOf() => jsonEncode([
        session.control!.name,
        for (final channel in session.control!.publicChannels)
          [channel.id, channel.name],
      ]);
      var signature = signatureOf();
      yield ConcordRoomCatalog.real(session);
      await for (final _ in session.changes) {
        if (!session.ready) {
          throw StateError(
            'Community authority is unavailable: ${session.failure}',
          );
        }
        final next = signatureOf();
        if (next == signature) continue;
        signature = next;
        yield ConcordRoomCatalog.real(session);
      }
    });

/// POC synchronous callers stay available when no real invite is configured.
/// Configured real Rooms never fall through to deterministic test keys.
ConcordRoomCatalog? resolveConcordCatalog(
  AsyncValue<ConcordRoomCatalog> state,
) =>
    state.asData?.value ??
    (concordInviteUrl.isEmpty ? ConcordRoomCatalog.poc() : null);

ConcordRoomCatalog? currentConcordCatalog(Ref ref) =>
    resolveConcordCatalog(ref.watch(concordRoomCatalogProvider));
