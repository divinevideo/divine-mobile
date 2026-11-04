// ABOUTME: Shares each account's verified Concord sessions between list and room.
// ABOUTME: Tears down relay listeners when authentication or chat access changes.

import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/concord_store.dart';
import 'package:openvine/features/chat/room_catalog_provider.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

final Provider<RoomActivityRepository?> roomActivityRepositoryProvider =
    Provider.autoDispose<RoomActivityRepository?>((ref) {
      ref.watch(currentAuthStateProvider);
      if (!ref.watch(isFeatureEnabledProvider(FeatureFlag.concordChat)) ||
          ref.watch(isDmRestrictedProvider)) {
        return null;
      }
      final auth = ref.watch(authServiceProvider);
      final account = auth.currentPublicKeyHex;
      if (!auth.isAuthenticated || account == null || account.isEmpty) {
        return null;
      }
      final signer = auth.currentIdentity;
      if (signer == null) return null;
      final catalog = currentConcordCatalog(ref);
      if (catalog == null || !catalog.ready) return null;
      final database = ref.watch(databaseProvider);
      final activity = RoomActivityRepository(
        ownPubkey: account,
        channels: [
          for (final community in catalog.communities)
            for (final channel in community.channels)
              (() {
                final store = DriftConcordStore(
                  dao: database.concordStoreDao,
                  account: account,
                  scope: '${catalog.scope}/$channel',
                );
                final key = catalog.stream(channel);
                final historicalKeys = catalog.outboxReadKeys(channel);
                return RoomActivityChannel(
                  channelId: catalog.channelId(channel),
                  epoch: catalog.epoch,
                  repository: buildConcordRepository(
                    pubkey: account,
                    signer: signer,
                    store: store,
                    controlState: () => catalog.session?.control,
                    historicalOutboxKeys: () => historicalKeys,
                    canPublish: () =>
                        catalog.canSend &&
                        catalog.communities.any(
                          (c) => c.channels.contains(channel),
                        ),
                    signerForSend: () =>
                        auth.isAuthenticated &&
                            auth.currentPublicKeyHex == account
                        ? auth.currentIdentity
                        : null,
                  ),
                  store: store,
                  streamSeedHex: key.seedHex,
                  streamPubkey: key.pubkey,
                );
              })(),
        ],
      );
      final authorityChanges = catalog.session?.changes.listen(
        (_) => activity.refreshModeration(),
      );
      final close = ref.read(accountStateWriteBarrierProvider).register(
        account,
        () async {
          final closing = activity.close();
          await authorityChanges?.cancel();
          await closing;
        },
      );
      ref.onDispose(() {
        runDetached(
          close(),
          'close room activity',
          logName: 'RoomActivityRepository',
          category: LogCategory.system,
        );
      });
      return activity;
    });
