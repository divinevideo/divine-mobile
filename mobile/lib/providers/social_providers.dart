// ABOUTME: Social, foundation, and collaborator Riverpod providers split from app_providers.dart
// ABOUTME: Final batch (9c) — pendingAction, outgoingDmRetry, analytics, hashtag, draft, clip,
// ABOUTME: userDataCleanup, social, contentReporting, contentDeletion, collaborator-3

import 'dart:async';

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/background_activity_provider.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/collaborator_invite_local_state_adapter.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/dm_reaction_retry_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/services/profile_save_retry_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/view_event_retry_service.dart';
import 'package:openvine/utils/local_content_owner.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'social_providers.g.dart';

/// Reconnect trigger for the DM reaction retry sweep: emits once each time
/// `connectivity_plus` reports any non-`none` result, so work queued during a
/// brief network drop is re-driven the moment connectivity returns — without
/// waiting for an app-foreground transition. The sweep short-circuits when
/// nothing is retryable. For [DmReactionRetryService], `→ none` transitions
/// are filtered out because a sweep fired on going offline has nothing to do:
/// its own offline gate skips the pass anyway. The filter is a cheap
/// short-circuit for the reaction consumer; the profile-save consumer also
/// shares this stream and relies on the filter to avoid a futile offline
/// trigger until it gains the same guard.
Stream<void> _dmRetryConnectivityTriggerStream() => Connectivity()
    .onConnectivityChanged
    .where((results) => results.any((r) => r != ConnectivityResult.none))
    .map<void>((_) {});

/// Upper bound on the pool repair awaited inside
/// [dmMessageRetryTriggerWithRelayRepair] before the sweep trigger is emitted
/// anyway. `forceReconnectAll` reconnects relays serially, so a slow relay
/// must not starve the retry sweep indefinitely — on timeout the sweep runs
/// and the SDK's own OK-timeout remediation backstops any still-stale socket.
const _relayRepairTimeout = Duration(seconds: 15);

typedef PendingUploadOwnerCleanup = Future<int> Function(String ownerPubkey);

final openVineImageCacheClearProvider = Provider<Future<void> Function()>((
  ref,
) {
  return clearOpenVineImageCache;
});

final pendingUploadOwnerCleanupProvider = Provider<PendingUploadOwnerCleanup>((
  ref,
) {
  return (ownerPubkey) =>
      ref.read(uploadManagerProvider).deleteAllForOwner(ownerPubkey);
});

/// Stops the live DM gift-wrap subscription during account cleanup.
///
/// The indirection is load-bearing: reading [dmRepositoryProvider] from
/// [userDataCleanupServiceProvider]'s own callback closes the loop
/// userDataCleanup → dmRepository → nostrService → authService →
/// userDataCleanup, which Riverpod's debug cycle guard rejects. See #7389.
final dmListeningStopProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Cleanup must not construct a repository just to stop it.
    if (!ref.exists(dmRepositoryProvider)) return;
    await ref.read(dmRepositoryProvider).stopListening();
  };
});

/// Connectivity trigger for the message retry sweep: fires on EVERY
/// connectivity transition, including `→ none`. [OutgoingDmRetryService] runs
/// its own offline probe per pass: an online pass re-drives retryable rows,
/// and an offline pass surfaces aged still-`pending` rows as red failed
/// bubbles (a pending row renders identically to a delivered one, so without
/// this a send that went unconfirmed just before the network dropped stays
/// sent-looking — and untappable — for the whole offline window). See #6046.
///
/// Before an ONLINE transition's trigger is emitted, [repairRelayPool] (wired
/// to `NostrClient.forceReconnectAll`) is awaited: after an interface change
/// the pool's WebSockets are half-open zombies that still report `connected`
/// — publishes buffer into them and no OK ever arrives — and nothing else
/// repairs the pool while the app stays foregrounded (`forceReconnectAll`
/// otherwise only runs on app-resume, relay-set change, or a manual settings
/// action). Without the repair, the sweep fired by the same connectivity
/// event races the zombie window and every re-driven row soft-fails, leaving
/// red bubbles unresendable until the 90s idle detector fires. The first
/// emission after subscribe describes the current state, not a transition,
/// so it never triggers a repair (app start must not cycle sockets that are
/// still connecting). Repair failures and timeouts are logged and the
/// trigger is emitted regardless. Public for testing; production wiring is
/// in [outgoingDmRetryService].
@visibleForTesting
Stream<void> dmMessageRetryTriggerWithRelayRepair({
  required Stream<List<ConnectivityResult>> connectivityChanges,
  required Future<void> Function() repairRelayPool,
}) {
  // asyncMap rather than an async* generator: a generator suspended at its
  // `await for` only processes a subscription cancel when the source emits
  // again, so cancelling on dispose would leave the subscription dangling
  // until the next connectivity event. asyncMap cancels the source promptly
  // while keeping the same serialization (the source is paused while a
  // repair is awaited, so triggers never overtake their repair).
  List<ConnectivityResult>? previous;
  return connectivityChanges.asyncMap((results) async {
    final prior = previous;
    previous = results;
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online && prior != null && !_sameConnectivity(prior, results)) {
      try {
        await repairRelayPool().timeout(_relayRepairTimeout);
      } on Object catch (e) {
        Log.warning(
          'Relay pool repair on connectivity change failed: $e',
          name: 'SocialProviders',
          category: LogCategory.system,
        );
      }
    }
  });
}

/// Whether two connectivity reports describe the same set of transports.
/// Order-insensitive: `connectivity_plus` gives no ordering guarantee.
bool _sameConnectivity(List<ConnectivityResult> a, List<ConnectivityResult> b) {
  final aSet = a.toSet();
  final bSet = b.toSet();
  return aSet.length == bSet.length && aSet.containsAll(bSet);
}

/// Reports whether the device currently has no network connectivity. Wired into
/// `NIP17MessageService` so an offline DM send fails hard (a red "Not delivered"
/// bubble that re-drives on reconnect) instead of being misread as a soft "OK
/// lost" send — the misclassification a stale-`connected` relay socket causes in
/// airplane mode. Mirrors the online predicate in
/// [_dmRetryConnectivityTriggerStream] so the connectivity contract stays in one
/// place. See #6046.
Future<bool> dmSendConnectivityIsOffline() async {
  final results = await Connectivity().checkConnectivity();
  return !results.any((r) => r != ConnectivityResult.none);
}

final collaboratorResponseServiceProvider =
    Provider<CollaboratorResponseService>((ref) {
      return CollaboratorResponseService(
        authService: ref.watch(authServiceProvider),
        nostrClient: ref.watch(nostrServiceProvider),
      );
    });

final collaboratorInviteStateStoreProvider =
    Provider<CollaboratorInviteStateStore>((ref) {
      return CollaboratorInviteStateStore(
        prefs: ref.watch(sharedPreferencesProvider),
      );
    });

final collaboratorInviteRecoveryRepositoryProvider = Provider<DmRepository?>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  ref.watch(currentAuthStateProvider);
  final readiness = ref.watch(nostrSessionProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null || userPubkey.isEmpty) return null;
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  return ref.watch(dmRepositoryProvider);
});

final pendingCollaboratorInviteGroupsProvider =
    StreamProvider<List<PendingCollaboratorInviteGroup>>((ref) {
      final repository = ref.watch(
        collaboratorInviteRecoveryRepositoryProvider,
      );
      if (repository == null) {
        return Stream.value(const <PendingCollaboratorInviteGroup>[]);
      }
      return repository.watchPendingCollaboratorInviteGroups();
    });

/// Per-video collaborator confirmation status. Returns `null` until
/// [nostrSessionProvider] has a ready active client, so consumers render a safe
/// fallback instead of capturing a stale Nostr client.
final collaboratorConfirmationRepositoryProvider =
    Provider<CollaboratorConfirmationRepository?>((ref) {
      final authService = ref.watch(authServiceProvider);
      final readiness = ref.watch(nostrSessionProvider);
      final currentUserPubkey = readiness.pubkey;
      final nostrClient = readiness.client;
      if (!readiness.isReadyForActiveClient ||
          currentUserPubkey == null ||
          currentUserPubkey.isEmpty ||
          nostrClient == null ||
          authService.currentIdentity?.pubkey != currentUserPubkey) {
        return null;
      }

      final localStore = ref.watch(collaboratorInviteStateStoreProvider);
      final repo = CollaboratorConfirmationRepository(
        nostrClient: nostrClient,
        localStateReader: CollaboratorInviteLocalStateAdapter(localStore),
        currentUserPubkey: currentUserPubkey,
      );
      ref.onDispose(repo.close);
      return repo;
    });

/// Pending action service for offline sync of social actions
/// Returns null when not authenticated (no userPubkey available)
@Riverpod(keepAlive: true)
PendingActionService? pendingActionService(Ref ref) {
  final connectionStatusService = ref.watch(connectionStatusServiceProvider);
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild when authentication changes
  ref.watch(currentAuthStateProvider);

  // Need authenticated user for DAO operations
  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) {
    return null;
  }

  final db = ref.watch(databaseProvider);

  final service = PendingActionService(
    connectionStatusService: connectionStatusService,
    pendingActionsDao: db.pendingActionsDao,
    userPubkey: userPubkey,
  );

  // Initialize asynchronously
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize PendingActionService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.onDispose(service.dispose);
  return service;
}

/// Auto-sweep service for the durable `outgoing_dms` queue.
///
/// Listens to app-foreground transitions and re-publishes the missing
/// self-wrap for any row in `recipient: sent / self: failed` state via
/// [DmRepository.recoverSelfWrap]. Closes the gap left by the
/// SnackBar-only manual retry from PR #4106 — see issue #4124.
///
/// The service is keepAlive but has no UI consumer, so it is read
/// eagerly at app shell startup (`main.dart`) so the foreground
/// subscription is wired up.
///
/// Returns null when the user is not authenticated or when the current Nostr
/// session is not ready — the underlying [DmRepository.recoverSelfWrap]
/// requires `setCredentials` to have run, and gating here is cleaner than
/// catching `StateError` in every sweep pass.
@Riverpod(keepAlive: true)
OutgoingDmRetryService? outgoingDmRetryService(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild on sign-in / sign-out / account switch.
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) return null;

  // Gate on matching Nostr readiness so DmRepository.setCredentials has run by
  // the time the service's first foreground sweep fires.
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  final dmRepository = ref.watch(dmRepositoryProvider);
  final db = ref.watch(databaseProvider);

  // Bridge the synchronous AppForeground notifier into a Stream<bool>
  // so the service's contract stays free of Riverpod types and is easy
  // to drive from unit tests.
  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  // Re-drive undelivered messages the moment connectivity returns, not only on
  // app-foreground transitions — a message queued during a brief network drop
  // would otherwise sit undelivered until the app is backgrounded and
  // re-foregrounded. Fires on `→ none` too, so the service's offline pass can
  // surface unconfirmed pending rows as failed the moment the network drops.
  // Online transitions force-reconnect the relay pool first, so the sweep
  // publishes on fresh sockets instead of the zombies the old network left
  // behind (see dmMessageRetryTriggerWithRelayRepair).
  final nostrService = ref.watch(nostrServiceProvider);
  final retryTriggerStream = dmMessageRetryTriggerWithRelayRepair(
    connectivityChanges: Connectivity().onConnectivityChanged,
    repairRelayPool: nostrService.forceReconnectAll,
  );

  final service = OutgoingDmRetryService(
    crashReporting: ref.read(crashReportingServiceProvider),
    dmRepository: dmRepository,
    outgoingDmsDao: db.outgoingDmsDao,
    userPubkey: userPubkey,
    appForegroundStream: foregroundController.stream,
    retryTriggerStream: retryTriggerStream,
    // Same probe the send path uses: an offline sweep pass would burn every
    // row's retry budget on attempts that deterministically fail.
    isOffline: dmSendConnectivityIsOffline,
  );

  // initialize() subscribes to the controller's stream synchronously
  // (no await before the .listen call), so it is safe to register the
  // ref.listen below afterwards — fireImmediately will reach the
  // service's subscriber.
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize OutgoingDmRetryService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (!foregroundController.isClosed) {
      foregroundController.add(next);
    }
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  return service;
}

/// Auto-sweep service that re-drives the durable pending profile/username save
/// slot (#3161) so a save attempted while relays were unreachable is delivered
/// when connectivity returns. keepAlive with no UI consumer — read eagerly at
/// app shell startup (`main.dart`) so the foreground + connectivity
/// subscriptions are wired.
///
/// Returns null until the user is authenticated and the Nostr session is ready
/// for the active identity (the same readiness [profileRepository] gates on),
/// so drivePendingSave's claim + publish have a live signer and client.
final profileSaveRetryServiceProvider = Provider<ProfileSaveRetryService?>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);

  // Rebuild on sign-in / sign-out / account switch.
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null || userPubkey.isEmpty) return null;

  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  final profileRepository = ref.watch(profileRepositoryProvider);
  if (profileRepository == null) return null;

  final db = ref.watch(databaseProvider);

  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  final service = ProfileSaveRetryService(
    crashReporting: ref.read(crashReportingServiceProvider),
    profileRepository: profileRepository,
    pendingProfileSavesDao: db.pendingProfileSavesDao,
    userPubkey: userPubkey,
    appForegroundStream: foregroundController.stream,
    // Shared connectivity trigger: re-drive the moment the network returns,
    // not only on an app-foreground transition.
    retryTriggerStream: _dmRetryConnectivityTriggerStream(),
  );

  service.initialize().catchError((Object e) {
    Log.error(
      'Failed to initialize ProfileSaveRetryService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (!foregroundController.isClosed) {
      foregroundController.add(next);
    }
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  return service;
});

/// Auto-sweep service that re-drives undelivered DM reactions (publish failed
/// or interrupted mid-send) on app-foreground transitions via
/// [DmReactionsRepository.retry].
///
/// Gives reactions the durable delivery that DM messages already get from
/// [OutgoingDmRetryService] + the `outgoing_dms` queue: a reaction whose
/// recipient gift wrap failed to land (common on a flaky relay) is otherwise
/// lost with no automatic recovery. keepAlive with no UI consumer, so it is
/// read eagerly at app shell startup (`main.dart`) to wire the foreground
/// subscription.
///
/// Returns null until the user is authenticated and the Nostr session is
/// ready — the same readiness the reaction repository's `setCredentials`
/// needs before a retry can publish.
@Riverpod(keepAlive: true)
DmReactionRetryService? dmReactionRetryService(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild on sign-in / sign-out / account switch.
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) return null;

  // Gate on matching Nostr readiness so the reaction repository's
  // setCredentials has run by the time the first foreground sweep fires.
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  // The retry service can be constructed above the app composition tree.
  // Watching DmRepository makes its downward resolver wiring deterministic
  // before the fire-immediately sweep can settle a retry through the pool.
  ref.watch(dmRepositoryProvider);
  final reactionsRepository = ref.watch(dmReactionsRepositoryProvider);

  // Bridge the synchronous AppForeground notifier into a Stream<bool> so the
  // service's contract stays free of Riverpod types and is easy to drive from
  // unit tests.
  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  // Re-drive undelivered reactions/removals the moment connectivity returns,
  // not only on app-foreground transitions — a reaction left during a brief
  // network drop would otherwise sit undelivered until the app is backgrounded
  // and re-foregrounded.
  final retryTriggerStream = _dmRetryConnectivityTriggerStream();

  final service = DmReactionRetryService(
    crashReporting: ref.read(crashReportingServiceProvider),
    reactionsRepository: reactionsRepository,
    appForegroundStream: foregroundController.stream,
    retryTriggerStream: retryTriggerStream,
    isOffline: dmSendConnectivityIsOffline,
  );

  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize DmReactionRetryService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (!foregroundController.isClosed) {
      foregroundController.add(next);
    }
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  return service;
}

/// Auto-sweep service for the durable `pending_view_events` queue.
@Riverpod(keepAlive: true)
ViewEventRetryService? viewEventRetryService(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) return null;

  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  final db = ref.watch(databaseProvider);
  final viewPublisher = ref.watch(viewEventPublisherProvider);
  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  final service = ViewEventRetryService(
    viewEventPublisher: viewPublisher,
    pendingViewEventsDao: db.pendingViewEventsDao,
    userPubkey: userPubkey,
    appForegroundStream: foregroundController.stream,
  );

  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize ViewEventRetryService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (!foregroundController.isClosed) {
      foregroundController.add(next);
    }
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  return service;
}

/// Durable queue for first-party product analytics events.
@Riverpod(keepAlive: true)
ProductEventQueue productEventQueue(Ref ref) {
  final db = ref.watch(databaseProvider);
  final env = ref.watch(currentEnvironmentProvider);
  final client = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(client.close);

  final ingestClient = AnalyticsIngestClient(
    httpClient: client,
    nip98AuthService: ref.watch(nip98AuthServiceProvider),
    apiBaseUrl: () => env.apiBaseUrl,
  );
  final queue = ProductEventQueue(
    dao: db.pendingProductEventsDao,
    ingestClient: ingestClient,
    // Read fresh at flush so a logout/login as a different account only
    // publishes that account's own queued events under its own signature.
    currentOwnerPubkey: () => ref.read(authServiceProvider).currentPublicKeyHex,
    // AnalyticsService enables delivery only after it has loaded consent and
    // confirmed this is an explicitly enabled build (the queue defaults to
    // sending disabled).
  );

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (next) {
      queue.flush().catchError((Object e) {
        Log.debug(
          'Foreground ProductEventQueue flush failed: $e',
          name: 'AppProviders',
          category: LogCategory.system,
        );
      });
    }
  }, fireImmediately: true);

  return queue;
}

/// Analytics service with opt-out support.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].
String resolveProductAnalyticsRelease({
  required String runtimeVersion,
  required String environment,
  required String stagingOverride,
}) {
  final isStaging = environment.toUpperCase() == 'STAGING';
  final isSmokeMarker = RegExp(
    r'^staging-smoke-[0-9a-f]{32}$',
  ).hasMatch(stagingOverride);
  return isStaging && isSmokeMarker ? stagingOverride : runtimeVersion;
}

@Riverpod(keepAlive: true) // Keep alive to maintain singleton behavior
AnalyticsService analyticsService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  final viewPublisher = ref.watch(viewEventPublisherProvider);
  final retryService = ref.watch(viewEventRetryServiceProvider);
  final productQueue = ref.watch(productEventQueueProvider);
  final appVersion = resolveProductAnalyticsRelease(
    runtimeVersion: ref.watch(appVersionProvider),
    environment: const String.fromEnvironment('DEFAULT_ENV'),
    stagingOverride: const String.fromEnvironment('PRODUCT_ANALYTICS_RELEASE'),
  );
  final service = AnalyticsService(
    backgroundActivityManager: ref.read(backgroundActivityManagerProvider),
    viewEventPublisher: viewPublisher,
    pendingViewEventsDao: db.pendingViewEventsDao,
    flushPendingViewEvents: retryService?.sweep,
    productEventQueue: productQueue,
    currentUserPubkey: () => authService.currentPublicKeyHex,
    appVersion: () => appVersion,
  );

  var lastPubkey = authService.currentPublicKeyHex;
  final unregisterBeforeTeardown = authService
      .registerBeforeSessionTeardownCallback(() async {
        await service.handleIdentityChange();
        lastPubkey = null;
      });
  final authStateSubscription = authService.authStateStream.listen((_) {
    final nextPubkey = authService.currentPublicKeyHex;
    final previousPubkey = lastPubkey;
    lastPubkey = nextPubkey;
    if (previousPubkey != nextPubkey) {
      unawaited(
        service.handleIdentityChange().catchError((Object error) {
          Log.warning(
            'Failed to apply product analytics identity boundary: $error',
            name: 'SocialProviders',
            category: LogCategory.system,
          );
        }),
      );
    }
  });

  // Ensure cleanup on disposal
  ref.onDispose(() {
    unregisterBeforeTeardown();
    unawaited(authStateSubscription.cancel());
    service.dispose();
  });

  // Initialize asynchronously but don't block the provider
  Future.microtask(service.initialize);

  return service;
}

/// Hashtag cache service for persistent hashtag storage
@riverpod
HashtagCacheService hashtagCacheService(Ref ref) {
  final service = HashtagCacheService();
  // Initialize asynchronously to avoid blocking UI
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize HashtagCacheService',
      name: 'AppProviders',
      error: e,
    );
  });
  return service;
}

/// Draft storage service for persisting vine drafts
@riverpod
DraftStorageService draftStorageService(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Rebuild when account changes so ownerPubkey stays current
  ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final ownerPubkey = resolveLocalContentOwnerPubkey(
    currentPubkeyHex: authService.currentPublicKeyHex,
    preferences: ref.watch(sharedPreferencesProvider),
  );
  return DraftStorageService(
    crashReporter: ref.read(crashReportingServiceProvider),
    draftsDao: db.draftsDao,
    clipsDao: db.clipsDao,
    ownerPubkey: ownerPubkey,
    // Deleting a draft reclaims its audio files; My Sounds can point at one of
    // them, so cleanup has to be able to see the saved sound buckets.
    preferences: ref.watch(sharedPreferencesProvider),
  );
}

/// Clip library service for persisting individual video clips
@riverpod
ClipLibraryService clipLibraryService(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Rebuild when account changes so ownerPubkey stays current
  ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final ownerPubkey = resolveLocalContentOwnerPubkey(
    currentPubkeyHex: authService.currentPublicKeyHex,
    preferences: ref.watch(sharedPreferencesProvider),
  );
  return ClipLibraryService(
    clipsDao: db.clipsDao,
    draftsDao: db.draftsDao,
    clipCategoriesDao: db.clipCategoriesDao,
    ownerPubkey: ownerPubkey,
  );
}

/// User data cleanup service for handling identity changes
/// Prevents data leakage between different Nostr accounts
@riverpod
UserDataCleanupService userDataCleanupService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  final service = UserDataCleanupService(prefs);

  // Wire database cleanup callback so signOut() clears DM and notification data.
  // Stop DM listening FIRST to prevent in-flight event handlers from writing
  // to tables that are being cleared (H3 race condition fix).
  // Escaping cleanup reads must go through port providers; direct reads of
  // auth-dependent providers from this callback can recreate #7389.
  //
  // Every delete here is scoped to [userPubkey], the account being left. The
  // DM family used to be wiped unqualified on this path, which destroyed every
  // account's decrypted history on an ordinary switch (#7325).
  //
  // [deleteUserData] additionally widens the destructive paths: it drops rows
  // this account may still need (removal tombstones, retryable reactions) that
  // a plain switch deliberately preserves.
  service.onDatabaseCleanup =
      ({
        String? userPubkey,
        bool deleteUserData = false,
        bool preserveActiveSession = false,
      }) async {
        Future<void> safeCleanup(
          String name,
          Future<void> Function() fn,
        ) async {
          try {
            await fn();
          } catch (e) {
            Log.warning(
              'Failed to clean $name for ${pubkeyForLogs(userPubkey, whenNull: "unknown user")}: $e',
              name: 'UserDataCleanup',
              category: LogCategory.auth,
            );
          }
        }

        Future<void> requiredCleanup(
          String name,
          Future<void> Function() fn,
        ) async {
          try {
            await fn();
          } catch (e) {
            Log.error(
              'Required account-boundary cleanup failed for $name and '
              '${pubkeyForLogs(userPubkey, whenNull: "unknown user")}: $e',
              name: 'UserDataCleanup',
              category: LogCategory.auth,
            );
            rethrow;
          }
        }

        if (!preserveActiveSession) {
          await requiredCleanup(
            'dmRepository',
            () => ref.read(dmListeningStopProvider)(),
          );
          try {
            await ref.read(openVineImageCacheClearProvider)();
            ref
                .read(adultMediaAccessRevocationVersionProvider.notifier)
                .increment();
          } catch (e) {
            Log.warning(
              'Failed to clear image cache during user data cleanup: $e',
              name: 'UserDataCleanup',
              category: LogCategory.auth,
            );
          }
        }
        // An active account may still own unattributed legacy rows, so only
        // device-wide teardown clears them.
        // See #7325.
        await requiredCleanup('DM tables', () async {
          await db.transaction(() async {
            if (userPubkey != null) {
              if (preserveActiveSession) {
                await db.directMessagesDao.deleteAllForOwner(userPubkey);
                await db.conversationsDao.deleteAllForOwner(userPubkey);
              } else {
                await db.directMessagesDao.clearForAccountSwitch(userPubkey);
                await db.conversationsDao.clearForAccountSwitch(userPubkey);
              }
              // Raw failed-decrypt wraps and their terminal dedup ledger must
              // never outlive the decrypted DM data they accompany.
              if (preserveActiveSession) {
                await db.pendingGiftWrapsDao.deleteAllForOwner(userPubkey);
                await db.processedGiftWrapsDao.deleteAllForOwner(userPubkey);
              } else {
                await db.pendingGiftWrapsDao.clearForAccountSwitch(userPubkey);
                await db.processedGiftWrapsDao.clearForAccountSwitch(
                  userPubkey,
                );
              }
            } else {
              await db.directMessagesDao.clearUnowned();
              await db.conversationsDao.clearUnowned();
              await db.pendingGiftWrapsDao.clearUnowned();
              await db.processedGiftWrapsDao.clearUnowned();
            }
          });
        });
        if (deleteUserData && userPubkey != null) {
          await requiredCleanup(
            'removedConversations',
            () => db.removedConversationsDao.clearAllForUser(userPubkey),
          );
        }
        // Reaction rows keep decrypted rumor payloads (rumor_event_json). Most
        // are re-fetchable DM data and should be wiped with direct_messages,
        // but retryable own rows are also the outgoing queue for unpublished
        // reactions and kind-5 removals. Preserve that subset on a plain
        // account switch, matching outgoing_dms; destructive cleanup wipes all.
        // Owner-scoped rather than clearAll: ownerPubkey is non-nullable here,
        // so unlike direct_messages there are no legacy NULL-owner rows a
        // scoped delete would strand. See #6984.
        if (userPubkey != null) {
          await (deleteUserData ? requiredCleanup : safeCleanup)(
            'dmReactions',
            () => deleteUserData
                ? db.dmReactionsDao.deleteAllForOwner(userPubkey)
                : db.dmReactionsDao.deleteNonRetryableForOwner(userPubkey),
          );
        }
        // Scoped to the leaving account so a switch does not wipe the other
        // account's cached inbox along with this one's.
        await (deleteUserData ? requiredCleanup : safeCleanup)(
          'notifications',
          () => db.notificationsDao.clearAll(ownerPubkey: userPubkey),
        );
        // Issue #3936 requires the NIP-39 identity caches to clear on logout
        // and account switches rather than persisting across identities.
        if (!preserveActiveSession) {
          await safeCleanup('identityEvents', db.identityEventsDao.clearAll);
          await safeCleanup(
            'identityVerifications',
            db.identityVerificationsDao.clearAll,
          );
        }
        // Clear the leaving account's DM sync cursors so its next login
        // re-fetches from relays instead of resuming from a `since:` boundary
        // whose local rows have just been deleted.
        //
        // Per-pubkey, not clearAll: the sweep is prefix-based over every
        // account's keys, so a switch used to drop the *other* accounts'
        // cursors and drain-complete flags too, re-opening a full history
        // re-download for each of them. `clear` has existed for this since it
        // was written — its doc comment already says "Called on account
        // switch" — it just was never wired up. See #7325.
        //
        // main.dart's onDatabaseReset callers keep clearAll: there the whole
        // database was recreated, so every account's cursors are genuinely
        // stale.
        if (userPubkey != null) {
          await (deleteUserData ? requiredCleanup : safeCleanup)(
            'dmSyncState',
            () => DmSyncState(prefs).clear(userPubkey),
          );
        }

        // Per-user data cleanup (#2999): only on destructive paths
        if (deleteUserData && userPubkey != null) {
          Future<void> requiredDelete(
            String name,
            Future<int> Function() fn,
          ) async {
            try {
              await fn();
            } catch (e) {
              Log.error(
                'Failed to clean $name for ${pubkeyForLogs(userPubkey)}: $e',
                name: 'UserDataCleanup',
                category: LogCategory.auth,
              );
              rethrow;
            }
          }

          await requiredDelete(
            'drafts',
            () => db.draftsDao.deleteAllForUser(userPubkey),
          );
          await requiredDelete(
            'clips',
            () => db.clipsDao.deleteAllForUser(userPubkey),
          );
          await requiredDelete(
            'clipCategories',
            () => db.clipCategoriesDao.deleteAllForUser(userPubkey),
          );
          await requiredDelete(
            'pendingUploads',
            () => db.pendingUploadsDao.deleteAllForUser(userPubkey),
          );
          await requiredDelete(
            'pendingUploadsHive',
            () => ref.read(pendingUploadOwnerCleanupProvider)(userPubkey),
          );
          await requiredDelete(
            'personalReactions',
            () => db.personalReactionsDao.deleteAllForUser(userPubkey),
          );
          await requiredDelete(
            'personalReposts',
            () => db.personalRepostsDao.deleteAllForUser(userPubkey),
          );
          await requiredDelete(
            'personalEvents',
            () => db.personalEventsDao.deleteAllForOwner(userPubkey),
          );
          await requiredDelete(
            'pendingActions',
            () => db.pendingActionsDao.clearAll(userPubkey),
          );
          await requiredDelete(
            'outgoingDms',
            () => db.outgoingDmsDao.clearAllForUser(userPubkey),
          );
        }
      };

  // Wire legacy row claim callback so session setup can attribute
  // pre-multi-account drafts/clips to the current user.
  service.onClaimLegacyRows = (String userPubkey) async {
    await db.draftsDao.claimLegacyRows(
      userPubkey,
      sourceOwnerPubkey: DraftStorageService.anonymousOwnerPubkey,
    );
    await db.clipsDao.claimLegacyRows(
      userPubkey,
      sourceOwnerPubkey: DraftStorageService.anonymousOwnerPubkey,
    );
    await db.clipCategoriesDao.claimLegacyRows(
      userPubkey,
      sourceOwnerPubkey: DraftStorageService.anonymousOwnerPubkey,
    );
    // Notifications shipped without an owner column, so pre-upgrade rows are
    // unattributed. Claim them for the first account to sign in after the
    // upgrade rather than leaving them visible to every account.
    await db.notificationsDao.claimLegacyRows(userPubkey);
  };

  return service;
}

/// Hashtag service depends on Video event service and cache service
@riverpod
HashtagService hashtagService(Ref ref) {
  final videoEventService = ref.watch(videoEventServiceProvider);
  final cacheService = ref.watch(hashtagCacheServiceProvider);
  return HashtagService(videoEventService, cacheService);
}

/// Social service for follow sets (NIP-51 Kind 30000).
///
/// Follower count stats have moved to [FollowRepository].
@Riverpod(keepAlive: true)
SocialService socialService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return SocialService(nostrService, authService);
}

/// Content reporting service for NIP-56 compliance
@riverpod
Future<ContentReportingService> contentReportingService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final env = ref.watch(currentEnvironmentProvider);
  final service = ContentReportingService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
    moderationRelayUrl: env.relayUrl,
  );

  // Initialize the service to enable reporting
  await service.initialize();

  return service;
}

/// Content deletion service for NIP-09 delete events
@riverpod
Future<ContentDeletionService> contentDeletionService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final profileStatsDao = ref.watch(databaseProvider).profileStatsDao;
  final service = ContentDeletionService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
    profileStatsDao: profileStatsDao,
  );

  // Initialize the service to enable content deletion
  await service.initialize();

  return service;
}
