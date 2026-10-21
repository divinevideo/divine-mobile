// ABOUTME: Account-scoped dependency wiring for local user-ranking signals.
// ABOUTME: Rebuilds the stateless loader when its repositories or identity change.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_ranking_providers.g.dart';

/// Local ranking dependencies, scoped to the current account's repositories.
@riverpod
UserRankingSignalsLoader userRankingSignalsLoader(Ref ref) {
  final blocklist = ref.watch(contentBlocklistRepositoryProvider);
  return _rankingSignalsLoader(
    ref,
    isBlocked: blocklist.shouldFilterFromFeeds,
  );
}

/// Ranking for the signed-in user's own Following and Followers lists.
///
/// These lists hide only accounts the viewer blocked, as they did before
/// ranking. An account that mutes or blocks the viewer stays listed, so the
/// viewer can still open it to unfollow or report it.
@riverpod
UserRankingSignalsLoader ownFollowListRankingSignalsLoader(Ref ref) {
  final blocklist = ref.watch(contentBlocklistRepositoryProvider);
  return _rankingSignalsLoader(ref, isBlocked: blocklist.isBlocked);
}

UserRankingSignalsLoader _rankingSignalsLoader(
  Ref ref, {
  required bool Function(String pubkey) isBlocked,
}) {
  final database = ref.watch(databaseProvider);
  // Selected, not watched: readiness has no value equality, and a failed
  // client init re-reports the same identity, which replaced every list.
  final currentUserPubkey = ref.watch(
    nostrSessionProvider.select(
      (session) =>
          session.phase == NostrSessionPhase.identityKnown ||
              session.phase == NostrSessionPhase.nostrReady
          ? session.pubkey ?? ''
          : '',
    ),
  );
  return UserRankingSignalsLoader(
    dmRepository: ref.watch(dmRepositoryProvider),
    followRepository: ref.watch(followRepositoryProvider),
    profileRepository: ref.watch(profileRepositoryProvider),
    myFollowersDao: database.myFollowersDao,
    profileStatsDao: database.profileStatsDao,
    nostrEventsDao: database.nostrEventsDao,
    nip05VerificationsDao: database.nip05VerificationsDao,
    currentUserPubkey: currentUserPubkey,
    isBlocked: isBlocked,
  );
}
