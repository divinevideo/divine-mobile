// ABOUTME: Shares each account's verified Concord sessions between list and room.
// ABOUTME: Tears down relay listeners when authentication or chat access changes.

import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/concord_store.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
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
      final database = ref.watch(databaseProvider);
      final activity = RoomActivityRepository(
        ownPubkey: account,
        channels: [
          for (final community in const ChatState().communities)
            for (final channel in community.channels)
              (() {
                final store = DriftConcordStore(
                  dao: database.concordStoreDao,
                  account: account,
                  scope: '$concordRelayUrl/$channel',
                );
                final key = pocStreamKeyFor(channel);
                return RoomActivityChannel(
                  channelId: pocChannelIdFor(channel),
                  repository: buildConcordRepository(
                    pubkey: account,
                    signer: signer,
                    store: store,
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
      ref.onDispose(() {
        runDetached(
          activity.close(),
          'close room activity',
          logName: 'RoomActivityRepository',
          category: LogCategory.system,
        );
      });
      return activity;
    });
