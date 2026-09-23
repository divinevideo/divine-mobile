// ABOUTME: Riverpod wiring for scheduled posts (#3538): the relay client,
// ABOUTME: the per-account outbox repository, and the coordinator that
// ABOUTME: drives it while the app is in the foreground.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/scheduled_posts_repository.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:openvine/services/scheduled_post_coordinator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'scheduled_posts_providers.g.dart';

/// Client for the relay's scheduled-post endpoints.
///
/// Signs NIP-98 against the relay HTTP origin, like the events endpoint:
/// `/api/schedule` lives beside `/api/events` in the relay process.
@Riverpod(keepAlive: true)
ScheduleApiClient scheduleApiClient(Ref ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(httpClient.close);
  return ScheduleApiClient(
    httpClient: httpClient,
    nip98AuthService: ref.watch(nip98AuthServiceProvider),
    apiBaseUrl: () => environmentConfig.eventPublishBaseUrl,
  );
}

/// The signed-in account's scheduled-post outbox, or null before the Nostr
/// session is ready for it. Rebuilt on every account change, so a row is
/// only ever read or written under its owner.
@Riverpod(keepAlive: true)
ScheduledPostsRepository? scheduledPostsRepository(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) return null;

  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  final repository = ScheduledPostsRepository(
    dao: ref.watch(databaseProvider).scheduledPostsDao,
    client: ref.watch(scheduleApiClientProvider),
    ownerPubkey: userPubkey,
  );
  ref.onDispose(repository.dispose);
  return repository;
}

/// Drives the outbox: hand-off retries, relay-state sync, the client-side
/// publish of posts the relay is late on, and the confirmed-publish side
/// effects. Activated from the app root so it runs whether or not the
/// Scheduled section is on screen.
@Riverpod(keepAlive: true)
ScheduledPostCoordinator? scheduledPostCoordinator(Ref ref) {
  final repository = ref.watch(scheduledPostsRepositoryProvider);
  if (repository == null) return null;

  final authService = ref.watch(authServiceProvider);
  final publisher = ref.watch(videoEventPublisherProvider);
  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  final coordinator = ScheduledPostCoordinator(
    repository: repository,
    broadcast: (event, {isRetry = false}) =>
        publisher.broadcastScheduledEvent(event),
    recordPublish: publisher.recordScheduledPublish,
    sign: authService.createAndSignEvent,
    draftService: ref.watch(draftStorageServiceProvider),
    collaboratorInviteService: CollaboratorInviteService(
      dmRepository: ref.watch(dmRepositoryProvider),
      l10n: currentAppL10n(ref.watch(sharedPreferencesProvider)),
    ),
    appForegroundStream: foregroundController.stream,
    retryTriggerStream: Connectivity().onConnectivityChanged
        .where((results) => results.any((r) => r != ConnectivityResult.none))
        .map<void>((_) {}),
    outboxChangedStream: repository.changes,
    currentPubkey: () => authService.currentPublicKeyHex ?? '',
  );

  unawaited(
    coordinator.initialize().catchError((Object e) {
      Log.error(
        'Failed to initialize ScheduledPostCoordinator',
        name: 'ScheduledPostsProviders',
        error: e,
      );
    }),
  );

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (!foregroundController.isClosed) {
      foregroundController.add(next);
    }
  }, fireImmediately: true);

  ref.onDispose(coordinator.dispose);
  return coordinator;
}
