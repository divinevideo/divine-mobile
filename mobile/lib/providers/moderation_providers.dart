// ABOUTME: Content-moderation Riverpod providers split from app_providers.dart
// ABOUTME: Policy engine, host/age/content filters, NIP-32 labels, blocklist + sync bridge

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blocklist_content_filter.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'moderation_providers.g.dart';

@Riverpod(keepAlive: true)
ContentPolicyEngine contentPolicyEngine(Ref ref) {
  return ContentPolicyEngine.defaultRules();
}

/// Whether the UI may offer interactions that target [pubkey] —
/// follow, DM, reply, mention, share-to, tag.
///
/// When this returns `false` the affordance must be *absent*: no disabled
/// state, no tooltip, no copy. Revealing why would violate the disclosure
/// invariant (the app never tells a user someone blocked or muted them).
///
/// Consults [ContentPolicyEngine.canTarget]: the affordance is hidden when
/// the target's published kind 30000 d=block or kind 10000 mute list names
/// the current user.
@riverpod
bool canTargetUser(Ref ref, String pubkey) {
  // Re-evaluate when any block/mute state changes.
  ref.watch(blocklistVersionProvider);
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final engine = ref.watch(contentPolicyEngineProvider);
  return engine.canTarget(pubkey, blocklistRepository.currentState);
}

/// Divine-hosted-only filter preference service.
final divineHostFilterServiceProvider = Provider<DivineHostFilterService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = DivineHostFilterService(prefs);
  ref.onDispose(service.dispose);
  return service;
});

/// Rebuild trigger for consumers that need to react to Divine-host filter
/// preference changes.
final divineHostFilterVersionProvider =
    NotifierProvider<DivineHostFilterVersion, int>(DivineHostFilterVersion.new);

class DivineHostFilterVersion extends Notifier<int> {
  @override
  int build() {
    final service = ref.watch(divineHostFilterServiceProvider);
    service.addListener(increment);
    ref.onDispose(() => service.removeListener(increment));
    return 0;
  }

  void increment() => state++;
}

/// Capture-verified-only filter preference service.
///
/// Separate axis from [divineHostFilterServiceProvider]: hosting says who
/// can moderate the media, provenance says whether it traces to a camera.
final videoProvenanceFilterServiceProvider =
    Provider<VideoProvenanceFilterService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final service = VideoProvenanceFilterService(prefs);
      ref.onDispose(service.dispose);
      return service;
    });

/// Rebuild trigger for consumers that need to react to provenance-filter
/// preference changes.
final videoProvenanceFilterVersionProvider =
    NotifierProvider<VideoProvenanceFilterVersion, int>(
      VideoProvenanceFilterVersion.new,
    );

class VideoProvenanceFilterVersion extends Notifier<int> {
  @override
  int build() {
    final service = ref.watch(videoProvenanceFilterServiceProvider);
    service.addListener(increment);
    ref.onDispose(() => service.removeListener(increment));
    return 0;
  }

  void increment() => state++;
}

/// Increments whenever passive adult-media image auth must be invalidated.
final adultMediaAccessRevocationVersionProvider =
    NotifierProvider<AdultMediaAccessRevocationVersion, int>(
      AdultMediaAccessRevocationVersion.new,
    );

class AdultMediaAccessRevocationVersion extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Increments after persisted 18+ verification loads or changes.
final adultContentVerificationVersionProvider =
    NotifierProvider<AdultContentVerificationVersion, int>(
      AdultContentVerificationVersion.new,
    );

class AdultContentVerificationVersion extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

Future<void> _clearAdultMediaAccessCaches(Ref ref) async {
  try {
    await clearOpenVineImageCache();
  } finally {
    if (ref.mounted) {
      ref.read(adultMediaAccessRevocationVersionProvider.notifier).increment();
    }
  }
}

/// Age verification service for content creation restrictions
/// keepAlive preserves one coordinator and callback instance. Verification
/// values are read synchronously from preferences for the active account.
@Riverpod(keepAlive: true)
AgeVerificationService ageVerificationService(Ref ref) {
  final authService = ref.read(authServiceProvider);
  final service = AgeVerificationService(
    preferences: ref.watch(sharedPreferencesProvider),
    isProtectedMinor: () => ref.read(isProtectedMinorProvider),
    currentPubkeyHex: () => authService.currentPublicKeyHex,
    onAdultMediaAccessRevoked: () => _clearAdultMediaAccessCaches(ref),
    onAdultContentVerificationChanged: () {
      if (ref.mounted) {
        ref.read(adultContentVerificationVersionProvider.notifier).increment();
      }
    },
  );
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Content filter service for per-category Show/Warn/Hide preferences.
/// keepAlive ensures preferences persist and are consistent across the app.
@Riverpod(keepAlive: true)
ContentFilterService contentFilterService(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final service = ContentFilterService(
    ageVerificationService: ageVerificationService,
    onAdultMediaAccessRevoked: () => _clearAdultMediaAccessCaches(ref),
  );
  service.initialize(); // Initialize asynchronously
  ref.onDispose(service.dispose);
  return service;
}

/// Tracks feed-filter preference changes. Feed providers watch this to rebuild
/// when the user changes a Show/Warn/Hide or video-shape setting.
final contentFilterVersionProvider =
    NotifierProvider<ContentFilterVersion, int>(ContentFilterVersion.new);

class ContentFilterVersion extends Notifier<int> {
  @override
  int build() {
    final service = ref.watch(contentFilterServiceProvider);
    final aspectRatioPreference = ref.watch(
      feedAspectRatioPreferenceServiceProvider,
    );
    service.addListener(increment);
    aspectRatioPreference.addListener(increment);
    ref.onDispose(() {
      service.removeListener(increment);
      aspectRatioPreference.removeListener(increment);
    });
    return 0;
  }

  void increment() => state++;
}

/// Account label service for self-labeling content (NIP-32 Kind 1985).
@Riverpod(keepAlive: true)
AccountLabelService accountLabelService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final nostrClient = ref.watch(nostrServiceProvider);
  final service = AccountLabelService(
    authService: authService,
    nostrClient: nostrClient,
  );
  service.initialize();
  return service;
}

/// Moderation label service for subscribing to Kind 1985 labeler events.
@Riverpod(keepAlive: true)
ModerationLabelService moderationLabelService(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = ModerationLabelService(
    nostrClient: nostrClient,
    authService: authService,
    sharedPreferences: prefs,
    canQueryRelays: () {
      if (!ref.mounted) return false;
      final readiness = ref.read(nostrSessionProvider);
      return readiness.isReadyForActiveClient &&
          identical(readiness.client, nostrClient);
    },
  );

  StreamSubscription<List<String>>? followingSubscription;

  Future<void> startRelaySync(NostrSessionReadiness readiness) async {
    if (!readiness.isReadyForActiveClient ||
        !identical(readiness.client, nostrClient)) {
      return;
    }

    final followRepository = ref.read(followRepositoryProvider);
    await service.initialize();
    await service.syncFollowedLabelers(followRepository.followingPubkeys);
    followingSubscription ??= followRepository.followingStream.listen((
      pubkeys,
    ) {
      unawaited(service.syncFollowedLabelers(pubkeys));
    });
  }

  unawaited(startRelaySync(ref.read(nostrSessionProvider)));

  ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, next) {
    unawaited(startRelaySync(next));
  });

  ref.onDispose(() {
    unawaited(followingSubscription?.cancel());
    service.dispose();
  });
  return service;
}

/// Content blocklist service for filtering unwanted content from feeds
///
/// Injects SharedPreferences for local block persistence across restarts.
/// Nostr publishing (kind 10000 mute list, plus the legacy kind 30000
/// block list) is initialized via [syncBlockListsInBackground] during app
/// startup in main.dart.
///
/// keepAlive ensures the relay subscription created by
/// [syncBlockListsInBackground] survives widget rebuilds. Without it the
/// provider auto-disposes, the subscription is lost, and blocks restored
/// from the relay are never delivered to new instances.
@Riverpod(keepAlive: true)
ContentBlocklistRepository contentBlocklistRepository(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ContentBlocklistRepository(
    prefs: prefs,
    onChanged: () {
      if (!ref.mounted) return;
      ref.read(blocklistVersionProvider.notifier).increment();
    },
  );
}

/// Version counter to trigger rebuilds when blocklist changes.
/// Widgets watching this will rebuild when block/unblock actions occur.
@riverpod
class BlocklistVersion extends _$BlocklistVersion {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Bridge that starts blocklist sync when the Nostr session becomes ready.
///
/// Activated by `AppShellSideEffects`. It listens to [nostrSessionProvider] and
/// triggers [syncMuteListsInBackground] + [syncBlockListsInBackground]
/// the first time the signer-backed Nostr client is initialized. This covers:
/// - Already-authenticated startup (iOS keychain persists across reinstalls)
/// - Post-login authentication (Android wipes credentials on uninstall)
///
/// Both sync methods have internal guards (`_mutualMuteSyncStarted`,
/// `_blockListSyncStarted`) so duplicate calls are no-ops.
///
/// It also flushes a mute-list publish that was withheld because the read
/// preceding it was inconclusive (#6750). A block is kept local rather than
/// published over a list we could not read, so something has to retry it: a
/// later block republishes the whole list anyway, and this covers the user who
/// blocked once while relays were unhealthy and has not blocked since. The
/// signal is the app returning to the foreground — "we might be healthy
/// again". A restart is covered inside the repository instead, which
/// reconciles its persisted blocks against the list the relay serves back.
@Riverpod(keepAlive: true)
void blocklistSyncBridge(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

  Future<void> startSync(NostrSessionReadiness readiness) async {
    final pubkey = readiness.pubkey;
    final client = readiness.client;
    if (!readiness.isReadyForActiveClient || pubkey == null || client == null) {
      return;
    }

    if (authService.currentIdentity?.pubkey != pubkey) {
      return;
    }

    try {
      await Future.wait([
        blocklistRepository.syncMuteListsInBackground(client, pubkey),
        blocklistRepository.syncBlockListsInBackground(
          client,
          authService,
          pubkey,
        ),
      ]);
      Log.info(
        '[BRIDGE] Block/mute list sync started',
        name: 'BlocklistSyncBridge',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        '[BRIDGE] Block/mute list sync failed (non-critical): $e',
        name: 'BlocklistSyncBridge',
        category: LogCategory.system,
      );
    }
  }

  unawaited(startSync(ref.read(nostrSessionProvider)));

  ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, next) {
    unawaited(startSync(next));
  });

  ref.listen<bool>(appForegroundProvider, (previous, next) {
    if (next && previous != true) {
      unawaited(blocklistRepository.retryPendingMuteListPublish());
    }
  });
}

/// Republishes the contact list when a block contradicts the published
/// follow list.
///
/// [FollowRepository] drops blocked accounts from the kind 3 it publishes,
/// but blocking never runs through follow/unfollow and nothing republishes
/// kind 3 on a schedule — so without a trigger the contradiction would sit
/// on relays until the user's next unrelated follow, possibly never (#6903).
/// Three triggers cover it:
///
/// - a fresh block, via [ContentBlocklistRepository.changes];
/// - the follow list arriving, via `followingStream`. This is the one that
///   heals a block made before the list finished loading — a fresh install,
///   a new sign-in, a cleared cache — and settles contradictions that
///   predate this code.
/// - [FollowRepository.initialized], for the launch where the relay list
///   matches LocalStorage: the merge emits nothing then, so the two stream
///   triggers would both miss a contradiction that was already on disk.
///
/// Every trigger is gated on [FollowRepository.isInitialized]. Until the
/// relay query lands, `followingStream` carries the LocalStorage snapshot,
/// and republishing from a derived source destroys the follows it is
/// missing — the #6109 class of loss, on the write side where no merge
/// guard can catch it.
///
/// Activated by `AppShellSideEffects`.
@Riverpod(keepAlive: true)
void blockedFollowReconciler(Ref ref) {
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final followRepository = ref.watch(followRepositoryProvider);
  final nostrClient = ref.watch(nostrServiceProvider);

  // At most one republish per blocked pubkey per *current* block. divine-web
  // keeps whichever kind 3 carries more entries (divinevideo/divine-web#551),
  // so it can resurrect an entry we just dropped; unbounded, the two clients
  // would trade publishes for as long as both sessions are open. Cleared on
  // unblock so a later same-session re-block can drop the follow again after
  // an intervening publish re-included it.
  final settled = <String>{};
  var disposed = false;

  Future<void> reconcile() async {
    if (disposed || !followRepository.isInitialized) return;

    final blocked = blocklistRepository.blockedPubkeysForAccount(
      nostrClient.publicKey,
    );
    if (blocked.isEmpty) return;

    final contradicting = followRepository.followingPubkeys
        .where(blocked.contains)
        .where((pubkey) => !settled.contains(pubkey))
        .toList();
    if (contradicting.isEmpty) return;

    settled.addAll(contradicting);
    try {
      await followRepository.republishContactList();
      Log.info(
        'Republished contact list without ${contradicting.length} '
        'blocked account(s)',
        name: 'BlockedFollowReconciler',
        category: LogCategory.system,
      );
    } catch (e) {
      // Let the next block or follow-list emission try again.
      settled.removeAll(contradicting);
      Log.warning(
        'Failed to republish contact list after a block: $e',
        name: 'BlockedFollowReconciler',
        category: LogCategory.system,
      );
    }
  }

  final subscriptions = <StreamSubscription<void>>[
    blocklistRepository.changes.listen((change) {
      if (change.op == BlocklistOp.unblocked) {
        settled.remove(change.pubkey);
        return;
      }
      if (change.op == BlocklistOp.blocked) {
        unawaited(reconcile());
      }
    }),
    // Replays its latest value, so an already-loaded list reconciles here
    // rather than needing a separate priming call.
    followRepository.followingStream.listen((_) => unawaited(reconcile())),
  ];

  if (followRepository.isInitialized) {
    unawaited(reconcile());
  } else {
    unawaited(followRepository.initialized.then((_) => reconcile()));
  }

  ref.onDispose(() {
    disposed = true;
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  });
}

/// Builds the blocked-author video filter backed by the content-policy
/// engine.
BlockedVideoFilter createBlockedAuthorFilter(Ref ref) {
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final engine = ref.watch(contentPolicyEngineProvider);
  return createPolicyEngineFilter(
    engine,
    () => blocklistRepository.currentState,
  );
}
