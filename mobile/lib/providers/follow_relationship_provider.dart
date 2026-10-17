// ABOUTME: Reactive per-pubkey follow relationship for user rows
// ABOUTME: Backs the social-proof identifier line that replaced truncated npubs

import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'follow_relationship_provider.g.dart';

/// Refreshes the current user's local follower cache within repository budgets.
///
/// [FollowRepository.relationshipTo] reads that cache but never fills it, and
/// a user row must not trigger its own fetch — one shared warm-up keeps the
/// work shared across rows while preserving incremental and full-retry limits.
///
/// Completes with no value on failure: an unreachable relay degrades the
/// relationship to "unknown", which [FollowRelationship] already models, and
/// is not worth surfacing on a secondary identifier line.
@Riverpod(keepAlive: true)
Future<void> myFollowersWarmup(Ref ref) async {
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient) return;

  final repository = ref.watch(followRepositoryProvider);
  try {
    await repository.syncMyFollowers();
  } on Exception {
    return;
  }
}

/// The current user's follow relationship with [pubkey], kept live.
///
/// Re-emits when the current user's following list changes and again when the
/// follower warm-up lands, so a row that first renders as
/// [FollowRelationship.youFollow] upgrades to [FollowRelationship.mutual]
/// without a rebuild of the surrounding list.
@riverpod
Stream<FollowRelationship> followRelationship(Ref ref, String pubkey) async* {
  final repository = ref.watch(followRepositoryProvider);

  // Watched, not read: the loading -> data transition re-runs this body, which
  // is what promotes a relationship once the follower cache is populated.
  ref.watch(myFollowersWarmupProvider);

  yield repository.relationshipTo(pubkey);
  yield* repository.followingStream.map(
    (_) => repository.relationshipTo(pubkey),
  );
}
