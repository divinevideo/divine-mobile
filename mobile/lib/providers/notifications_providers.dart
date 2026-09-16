// ABOUTME: Notification-stack Riverpod providers split from app_providers.dart
// ABOUTME: FCM messaging, push registration, in-app prefs sync, dirty-state retry

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/services/app_badge_service.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/services/push_notification_session_coordinator.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'notifications_providers.g.dart';

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
  // Firebase Messaging only supports Android, iOS, macOS, and web.
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

      return NotificationPreferencesService(
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
  // Firebase Messaging only supports Android, iOS, macOS, and web.
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

  // Set up foreground message handler
  final onMessageSubscription = ref.read(firebaseOnMessageProvider).listen((
    message,
  ) {
    final pushService = ref.read(pushNotificationServiceProvider);
    if (pushService != null) {
      unawaited(pushService.handleForegroundMessage(message.data));
    }
    ref.read(notificationRefreshCoordinatorProvider)?.schedulePushRefresh();
  });

  ref.onDispose(() {
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
