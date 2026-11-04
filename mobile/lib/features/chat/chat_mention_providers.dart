// ABOUTME: Keeps room mention observation scoped to the active eligible account.
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/features/chat/chat_mention_repository.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/concord_store.dart';
import 'package:openvine/features/chat/room_catalog_provider.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/provider_detached_future.dart';

/// Builds each room the mention observer watches; tests keep relays offline.
final chatMentionRoomBuilderProvider = Provider<ConcordRepositoryBuilder>(
  (_) => buildConcordRepository,
);

final chatMentionRepositoryProvider = Provider<ChatMentionRepository?>((ref) {
  if (!ref.watch(isFeatureEnabledProvider(FeatureFlag.concordChat))) {
    return null;
  }
  ref.watch(currentAuthStateProvider);
  final auth = ref.watch(authServiceProvider);
  final owner = auth.currentPublicKeyHex;
  final signer = auth.currentIdentity;
  if (ref.watch(isDmRestrictedProvider) ||
      !auth.isAuthenticated ||
      owner == null ||
      signer == null) {
    return null;
  }
  final catalog = currentConcordCatalog(ref);
  if (catalog == null || !catalog.ready) return null;
  final dao = ref.watch(databaseProvider).concordStoreDao;
  final follows = ref.watch(followRepositoryProvider);
  final blocked = createBlockedAuthorFilter(ref);
  final blocklist = ref.watch(contentBlocklistRepositoryProvider);
  final profiles = ref.watch(profileRepositoryProvider);
  final buildRoom = ref.watch(chatMentionRoomBuilderProvider);
  final rooms = <ConcordRepository>[];
  final source = ChatMentionRepository(
    loadActors: (authors) async => [
      for (final profile
          in await profiles?.getCachedProfiles(pubkeys: authors.toList()) ??
              <UserProfile>[])
        ActorInfo(
          pubkey: profile.pubkey,
          displayName: profile.bestDisplayName,
          pictureUrl: profile.picture,
        ),
    ],
    owner: owner,
    communityId: catalog.communities.first.id,
    store: DriftConcordStore(
      dao: dao,
      account: owner,
      scope: '${catalog.scope}/mentions',
    ),
    now: () => DateTime.now().millisecondsSinceEpoch ~/ 1000,
    canNotify: (author) => follows.isFollowing(author) && !blocked(author),
    createRoom: (channel) {
      final room = buildRoom(
        pubkey: owner,
        signer: signer,
        store: DriftConcordStore(
          dao: dao,
          account: owner,
          scope: '${catalog.scope}/mention-observer/$channel',
        ),
      );
      room.controlState = () => catalog.session?.control;
      room.canPublish = () =>
          catalog.canSend &&
          catalog.communities.any((c) => c.channels.contains(channel));
      rooms.add(room);
      return room;
    },
    startRoom: (channel, repository) async {
      // Persisted metadata is local but validate it against the current catalog.
      if (!catalog.communities.any((c) => c.channels.contains(channel))) return;
      final stream = catalog.stream(channel);
      await repository.startChannel(
        channelId: catalog.channelId(channel),
        epoch: catalog.epoch,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
      );
    },
  );
  final authorityChanges = catalog.session?.changes.listen((_) {
    for (final room in rooms) {
      room.refreshModeration();
    }
  });
  final followChanges = follows.followingStream.listen(
    (_) => source.reevaluate(),
  );
  // Per-pubkey changes and whole-state reloads (an account switch) each
  // reach only one of these streams.
  final blockChanges = blocklist.changes.listen((_) => source.reevaluate());
  final blockStates = blocklist.stateStream.listen(
    (_) => source.reevaluate(),
  );
  final close = ref.read(accountStateWriteBarrierProvider).register(
    owner,
    () async {
      await authorityChanges?.cancel();
      await followChanges.cancel();
      await blockChanges.cancel();
      await blockStates.cancel();
      await source.close();
    },
  );
  ref.onDispose(
    () => runProviderDetached(
      close(),
      'close chat mentions',
      logName: 'ChatMentions',
    ),
  );
  runProviderDetached(
    source.initialize(),
    'restore chat mentions',
    logName: 'ChatMentions',
  );
  return source;
});
