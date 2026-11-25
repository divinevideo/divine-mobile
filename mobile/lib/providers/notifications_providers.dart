// ABOUTME: Notification-stack Riverpod providers split from app_providers.dart
// ABOUTME: FCM messaging, push registration, in-app prefs sync, dirty-state retry

import 'dart:async';
import 'dart:convert';

import 'package:dm_repository/dm_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/notifications/routing/dm_message_visibility.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/services/app_badge_service.dart';
import 'package:openvine/services/notification_background_preloader.dart';
import 'package:openvine/services/notification_content_preloader.dart';
import 'package:openvine/services/notification_helpers.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/services/push_device_metadata.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/services/push_notification_session_coordinator.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'notifications_providers.g.dart';

final notificationContentPreloaderProvider =
    Provider<NotificationContentPreloader>((ref) {
      final preloader = NotificationContentPreloader(
        loadVideo: (id) => ref
            .read(videosRepositoryProvider)
            .fetchVideoWithStatsForRouteId(id),
        resolveVideoTarget: (id) => NotificationTargetResolver(
          videoEventService: ref.read(videoEventServiceProvider),
          nostrService: ref.read(nostrServiceProvider),
        ).resolveVideoEventIdFromNotificationTarget(id),
        loadProfile: (pubkey) async {
          await ref
              .read(profileRepositoryProvider)
              ?.fetchFreshProfile(pubkey: pubkey);
        },
        cacheThumbnail: cacheNotificationThumbnail,
      );
      ref.onDispose(preloader.dispose);
      return preloader;
    });

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final firebaseOnMessageProvider = Provider<Stream<RemoteMessage>>(
  (ref) => FirebaseMessaging.onMessage,
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  unawaited(service.initialize());
  ref.onDispose(service.dispose);
  return service;
});

final appBadgeServiceProvider = Provider<AppBadgeClearer>(
  (ref) => const AppBadgeService(),
);

final notificationPreferencesStoreProvider =
    Provider<NotificationPreferencesStore>((ref) {
      return const HiveNotificationPreferencesStore(
        openBox: HiveNotificationPreferencesStore.openBox,
      );
    });

final pushNotificationServiceProvider = Provider<PushNotificationService?>((
  ref,
) {
  // Only Android, iOS and macOS have a real Firebase project.
  if (!isFirebaseSupported || kIsWeb) {
    return null;
  }

  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.client == null) {
    return null;
  }

  final authService = ref.watch(authServiceProvider);
  if (authService.currentIdentity?.pubkey != readiness.pubkey) {
    return null;
  }

  final notificationService = ref.watch(notificationServiceProvider);
  final envConfig = ref.watch(currentEnvironmentProvider);
  final firebaseMessaging = ref.watch(firebaseMessagingProvider);

  final pushService = PushNotificationService(
    authService: authService,
    nostrClient: readiness.client!,
    notificationService: notificationService,
    environmentConfig: envConfig,
    getToken: firebaseMessaging.getToken,
    deviceMetadata: PushDeviceMetadata.resolve(
      platform: defaultTargetPlatform,
      source: ref.watch(installSourceProvider),
      appVersion: ref.watch(appVersionProvider),
    ),
    isCurrent: () {
      final currentReadiness = ref.read(nostrSessionProvider);
      return currentReadiness.isReadyForActiveClient &&
          currentReadiness.pubkey == readiness.pubkey &&
          identical(currentReadiness.client, readiness.client) &&
          authService.currentIdentity?.pubkey == readiness.pubkey;
    },
  );

  ref.onDispose(pushService.dispose);
  return pushService;
});

Future<bool> _updateNotificationPreferencesSafely(
  PushNotificationService pushService,
  NotificationPreferences preferences,
) async {
  try {
    return await pushService.updatePreferences(preferences);
  } catch (e) {
    Log.warning(
      'Push notification preference publish failed: $e',
      name: 'PushNotificationSync',
      category: LogCategory.system,
    );
    return false;
  }
}

final Provider<void Function(String)>
notificationPreferencesDirtySyncBridgeProvider =
    Provider<void Function(String)>((ref) {
      const maxDirtySyncRetries = 3;
      var disposed = false;
      var drainGeneration = 0;
      final activeDrainPubkeys = <String>{};
      final retryCountsByPubkey = <String, int>{};

      ref.onDispose(() {
        disposed = true;
        drainGeneration += 1;
      });

      bool isReadyForPubkey(
        String pubkey, {
        PushNotificationService? pushService,
      }) {
        if (disposed) return false;

        final authService = ref.read(authServiceProvider);
        if (authService.currentIdentity?.pubkey != pubkey) return false;

        final readiness = ref.read(nostrSessionProvider);
        if (!readiness.isReadyForActiveClient || readiness.pubkey != pubkey) {
          return false;
        }

        return pushService == null ||
            identical(ref.read(pushNotificationServiceProvider), pushService);
      }

      Future<void> drainDirtyPreferences(String pubkey) async {
        if (!activeDrainPubkeys.add(pubkey)) return;
        final generation = ++drainGeneration;
        var shouldRetry = false;
        try {
          final preferencesService = ref.read(
            notificationPreferencesServiceProvider,
          );
          if (!isReadyForPubkey(pubkey)) return;
          // Upgrades that changed the published kind list have nothing marked
          // dirty, so without this the drain finds nothing and the push
          // service keeps filtering on the pre-upgrade kinds.
          await preferencesService.markDirtyIfSchemaOutdated(pubkey);
          if (!isReadyForPubkey(pubkey)) return;
          final outcome = await preferencesService
              .syncDirtyPreferencesForPubkey(
                pubkey,
              );
          if (disposed || generation != drainGeneration) return;
          switch (outcome) {
            case NotificationPreferencesSyncOutcome.publishedAndCleared:
            case NotificationPreferencesSyncOutcome.nothingToDrain:
              retryCountsByPubkey.remove(pubkey);
            case NotificationPreferencesSyncOutcome.stillDirty:
              shouldRetry = isReadyForPubkey(pubkey);
          }
        } catch (e) {
          Log.warning(
            'Push notification preference drain failed: $e',
            name: 'PushNotificationSync',
            category: LogCategory.system,
          );
        } finally {
          activeDrainPubkeys.remove(pubkey);
        }

        if (!shouldRetry || disposed) return;
        final retryCount = retryCountsByPubkey[pubkey] ?? 0;
        if (retryCount >= maxDirtySyncRetries) return;
        retryCountsByPubkey[pubkey] = retryCount + 1;
        runProviderDetached(
          Future<void>.microtask(() async {
            if (disposed || !isReadyForPubkey(pubkey)) return;
            await drainDirtyPreferences(pubkey);
          }),
          'retry dirty notification preferences',
          logName: 'PushNotificationSync',
        );
      }

      void scheduleDirtyPreferencesDrain(String pubkey) {
        if (disposed || !isReadyForPubkey(pubkey)) return;
        runProviderDetached(
          Future<void>.microtask(() async {
            if (disposed || !isReadyForPubkey(pubkey)) return;
            await drainDirtyPreferences(pubkey);
          }),
          'schedule dirty notification preferences',
          logName: 'PushNotificationSync',
        );
      }

      void handleReadiness(NostrSessionReadiness readiness) {
        final readinessPubkey = readiness.pubkey;
        if (readiness.isReadyForActiveClient && readinessPubkey != null) {
          unawaited(drainDirtyPreferences(readinessPubkey));
        }
      }

      ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, readiness) {
        handleReadiness(readiness);
      });

      runProviderDetached(
        Future.microtask(
          () => handleReadiness(ref.read(nostrSessionProvider)),
        ),
        'apply initial notification readiness',
        logName: 'PushNotificationSync',
      );
      return scheduleDirtyPreferencesDrain;
    });

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) {
      final authService = ref.watch(authServiceProvider);

      final service = NotificationPreferencesService(
        accountPreferences: ref.watch(accountPreferenceStoreProvider),
        store: ref.watch(notificationPreferencesStoreProvider),
        currentPubkey: () => authService.currentIdentity?.pubkey,
        onStillDirty: (pubkey) {
          if (!ref.mounted) return;
          ref.read(notificationPreferencesDirtySyncBridgeProvider)(pubkey);
        },
        publishPreferences: (pubkey, prefs) {
          if (authService.currentIdentity?.pubkey != pubkey) {
            return Future<bool>.value(false);
          }

          final pushService = ref.read(pushNotificationServiceProvider);
          final readiness = ref.read(nostrSessionProvider);
          if (pushService == null ||
              !readiness.isReadyForActiveClient ||
              readiness.pubkey != pubkey) {
            return Future<bool>.value(false);
          }

          return _updateNotificationPreferencesSafely(pushService, prefs);
        },
      );
      ref.onDispose(service.dispose);
      return service;
    });

/// Bridges Nostr session readiness to push notification registration.
///
/// Registers FCM token only after the signer-backed Nostr client is ready.
/// Deregisters the last ready client through AuthService's pre-teardown hook so
/// outgoing-session cleanup runs before signers and callbacks are cleared. The
/// returned coordinator lets account switching run the same captured-identity
/// cleanup after the replacement account has committed.
@Riverpod(keepAlive: true)
PushNotificationSessionCoordinator? pushNotificationSync(Ref ref) {
  // Only Android, iOS and macOS have a real Firebase project.
  if (!isFirebaseSupported) {
    return null;
  }

  final authService = ref.watch(authServiceProvider);
  ref.watch(notificationPreferencesDirtySyncBridgeProvider);
  final nostrClientFactory = ref.read(nostrClientFactoryProvider);
  final dbClient = ref.read(appDbClientProvider);

  final coordinator = PushNotificationSessionCoordinator(
    authService: authService,
    firebaseMessaging: ref.read(firebaseMessagingProvider),
    readReadiness: () => ref.read(nostrSessionProvider),
    readPushService: () => ref.read(pushNotificationServiceProvider),
    readCleanupClientFactory: () {
      final environmentConfig = ref.read(currentEnvironmentProvider);
      return (identity) => nostrClientFactory(
        signer: identity,
        environmentConfig: environmentConfig,
        dbClient: dbClient,
      );
    },
  );

  final unregisterBeforeSessionTeardown = authService
      .registerBeforeSessionTeardownCallback(
        coordinator.deregisterLastReadyPubkey,
      );

  final authStateSubscription = authService.authStateStream.listen((_) {
    coordinator.handleAuthStateChange();
  });

  coordinator.handleReadiness(ref.read(nostrSessionProvider));

  ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, next) {
    coordinator.handleReadiness(next);
  });

  final lifecycle = AppLifecycleListener(
    onResume: () => runProviderDetached(
      coordinator.handleAppResumed(),
      'refresh the push timezone after resume',
      logName: 'PushNotificationSync',
    ),
  );

  // Set up foreground message handler
  final onMessageSubscription = ref.read(firebaseOnMessageProvider).listen((
    message,
  ) {
    if (message.data[NotificationPayloadKeys.wireType] ==
        NotificationWireValues.directMessage) {
      unawaited(_handleForegroundDm(ref, message));
      return;
    }
    unawaited(
      ref.read(notificationContentPreloaderProvider).preload(message.data),
    );
    final pushService = ref.read(pushNotificationServiceProvider);
    if (pushService != null) {
      unawaited(
        pushService.handleForegroundMessage(
          fcmPayloadWithMessageId(message.data, message.messageId),
        ),
      );
    }
    ref.read(notificationRefreshCoordinatorProvider)?.schedulePushRefresh();
  });

  ref.onDispose(() {
    lifecycle.dispose();
    coordinator.dispose();
    unregisterBeforeSessionTeardown();
    runProviderDetached(
      authStateSubscription.cancel(),
      'cancel the notification auth subscription',
      logName: 'PushNotificationSync',
    );
    runProviderDetached(
      onMessageSubscription.cancel(),
      'cancel the foreground notification subscription',
      logName: 'PushNotificationSync',
    );
  });

  return coordinator;
}

Future<void> _handleForegroundDm(Ref ref, RemoteMessage message) async {
  final data = fcmPayloadWithMessageId(message.data, message.messageId);
  final parsed = parseFcmPayload(data);
  final owner = parsed?.receiverPubkey?.toLowerCase();
  final wrap = parsed?.eventId?.toLowerCase();
  final hex = RegExp(r'^[0-9a-f]{64}$');
  if (owner == null ||
      wrap == null ||
      !hex.hasMatch(owner) ||
      !hex.hasMatch(wrap)) {
    return;
  }
  bool current() =>
      ref.mounted &&
      ref.read(authServiceProvider).currentPublicKeyHex == owner &&
      ref.read(accountPreferenceStoreProvider).boundPubkey == owner &&
      ref.read(nostrSessionProvider).pubkey == owner;
  if (!current()) return;
  try {
    final service = ref.read(notificationServiceProvider);
    final prefs = ref.read(notificationPreferencesServiceProvider);
    if (!service.hasPermissions ||
        !(await prefs.loadPreferences()).directMessagesEnabled ||
        !current()) {
      return;
    }
    final lookup = await ref
        .read(dmRepositoryProvider)
        .watchWrapLookup(ownerPubkey: owner, giftWrapId: wrap)
        .where((result) => result is! DmWrapPending)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) {
            sink.add(const DmWrapPending());
            sink.close();
          },
        )
        .first;
    if (!current() || !service.hasPermissions) return;
    if (!shouldDisplayDmAlert(
      lookup,
      owner: owner,
      restricted: ref.read(isDmRestrictedProvider),
      allowedPeer: ref
          .read(officialAccountsServiceProvider)
          .isReadableByProtectedMinor,
    )) {
      return;
    }
    if (!(await prefs.loadPreferences()).directMessagesEnabled || !current()) {
      return;
    }
    final context = NavigatorKeys.root.currentContext;
    if (context == null || !context.mounted) return;
    await service.sendLocal(
      title: 'Divine',
      body: context.l10n.newMessageTitle,
      payload: jsonEncode(localNotificationTapPayload(data)),
    );
  } on Object {
    // A retired account scope or unavailable private state cannot authorize an alert.
    return;
  }
}
