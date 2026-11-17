// ABOUTME: Binds recommendations and local dismissals to the current account.
// ABOUTME: Live block/follow changes invalidate every discovery surface.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/find_people_dismissal_store.dart';
import 'package:openvine/services/find_people_request_auth.dart';
import 'package:openvine/services/people_discovery_analytics.dart';
import 'package:profile_repository/profile_repository.dart';

/// Whether [pubkey] must never be suggested to the viewer: accounts hidden
/// from feeds (the viewer's blocks and mutes, and people who blocked or
/// mutually muted the viewer), policy blocks, and accounts the viewer may not
/// target. The repository re-reads this on every boundary.
@visibleForTesting
bool isExcludedFromFindPeople(
  String pubkey,
  ContentBlocklistRepository blocklist,
  ContentPolicyEngine engine,
) =>
    blocklist.shouldFilterFromFeeds(pubkey) ||
    engine.evaluate(PolicyInput(pubkey: pubkey), blocklist.currentState)
        is Block ||
    !engine.canTarget(pubkey, blocklist.currentState);

/// One shared repository per active account, cleared on account-container swap.
final findPeopleRepositoryProvider = Provider<FindPeopleRepository>((ref) {
  final owner = ref.watch(
    nostrSessionProvider.select(
      (session) => session.phase == NostrSessionPhase.tearingDown
          ? null
          : session.pubkey,
    ),
  );
  final auth = ref.watch(authServiceProvider);
  final follows = ref.watch(followRepositoryProvider);
  final blocklist = ref.watch(contentBlocklistRepositoryProvider);
  final engine = ref.watch(contentPolicyEngineProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final store = FindPeopleDismissalStore(prefs);
  final requestAuth = owner == null
      ? null
      : FindPeopleRequestAuth(
          owner: owner,
          currentPubkey: () => auth.currentPublicKeyHex,
          authService: ref.watch(nip98AuthServiceProvider),
        );
  final repository = FindPeopleRepository(
    apiClient: ref.watch(funnelcakeApiClientProvider),
    accountPubkey: owner,
    requestHeaders: requestAuth?.headersFor,
    currentPubkey: () => auth.currentPublicKeyHex,
    isFollowing: follows.isFollowing,
    isExcluded: (pubkey) => isExcludedFromFindPeople(pubkey, blocklist, engine),
    readDismissed: () => owner == null ? [] : store.read(owner),
    writeDismissed: (keys) async {
      if (owner == null || owner != auth.currentPublicKeyHex) return;
      await store.write(owner, keys);
    },
  );
  final followSubscription = follows.followingStream.listen(
    (_) => repository.notifyExclusionsChanged(),
  );
  ref.listen(
    blocklistVersionProvider,
    (_, _) => repository.notifyExclusionsChanged(),
  );
  final close = owner == null
      ? repository.dispose
      : ref
            .read(accountStateWriteBarrierProvider)
            .register(owner, repository.dispose);
  ref.onDispose(() {
    unawaited(followSubscription.cancel());
    unawaited(close());
  });
  return repository;
});

/// Captures the analytics service at binding time, safe after a row unmounts.
final findPeopleActionRecorderProvider =
    Provider<FindPeopleActionCallback Function(String)>((ref) {
      final analytics = ref.watch(analyticsServiceProvider);
      return (source) =>
          (action, suggestion, position) => unawaited(
            recordPeopleDiscoveryAction(
              analytics,
              source: source,
              action: action,
              position: position,
            ),
          );
    });

/// Records the optional step's deliberate skip independently of follow counts.
final findPeopleOnboardingSkipRecorderProvider = Provider<void Function()>((
  ref,
) {
  final analytics = ref.watch(analyticsServiceProvider);
  return () => unawaited(recordPeopleDiscoveryOnboardingSkip(analytics));
});
