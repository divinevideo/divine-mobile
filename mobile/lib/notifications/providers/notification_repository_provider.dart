// ABOUTME: Riverpod provider that constructs NotificationRepository
// ABOUTME: with all dependencies (API client, profile repo, DAO, auth).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/announcement_providers.dart';
import 'package:openvine/notifications/services/announcement_store.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nip98_http_client.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Riverpod provider that creates and exposes a [NotificationRepository].
///
/// Bridges the BLoC-based notification system into the existing Riverpod
/// dependency graph so the BLoC can be constructed in a ConsumerWidget.
///
/// Returns `null` when the [ProfileRepository] is not yet available
/// (e.g. during early auth when the NostrClient hasn't been initialised).
final notificationRepositoryProvider = Provider<NotificationRepository?>((ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final notificationsBaseUrl = resolvePinnedApiBaseUrlFromRelays(
    configuredRelays: nostrService.configuredRelays,
    fallbackBaseUrl: relayWsToHttpBase(environmentConfig.relayUrl),
  );
  final profileRepository = ref.watch(profileRepositoryProvider);

  // ProfileRepository is nullable during early auth. Return null so the
  // page can show a loading state until deps are ready.
  if (profileRepository == null) return null;

  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  final httpClient = Nip98HttpClient(
    inner: http.Client(),
    authService: nip98AuthService,
    trustedOrigin: Uri.parse(notificationsBaseUrl),
  );
  ref.onDispose(httpClient.close);
  final funnelcakeApiClient = FunnelcakeApiClient(
    baseUrl: notificationsBaseUrl,
    httpClient: httpClient,
    appVersion: ref.watch(appVersionProvider),
  );
  // The close aborts any request in flight; disposing stops it retrying.
  ref.onDispose(funnelcakeApiClient.dispose);
  final db = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  final userPubkey = authService.currentPublicKeyHex ?? '';

  final sessions = ref.watch(announcementSessionsProvider);
  final announcements = userPubkey.isEmpty
      ? null
      : AnnouncementsRepository(
          httpClient: ref.watch(announcementHttpClientFactoryProvider)(),
          store: SharedPreferencesAnnouncementStore(
            prefs: ref.watch(sharedPreferencesProvider),
            owner: userPubkey,
          ),
          platform: kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
          appVersion: ref.watch(appVersionProvider),
        );
  if (announcements != null) {
    sessions.register(userPubkey, announcements);
    unawaited(
      announcements
          .initialize()
          .then((_) => announcements.refresh())
          .catchError((Object error) {
            Log.warning(
              'Announcement catalog unavailable',
              name: 'Announcements',
            );
          }),
    );
    ref.onDispose(() => unawaited(sessions.release(userPubkey, announcements)));
  }

  final repository = NotificationRepository(
    announcementsRepository: announcements,
    funnelcakeApiClient: funnelcakeApiClient,
    profileRepository: profileRepository,
    notificationsDao: db.notificationsDao,
    userPubkey: userPubkey,
    // Engine-backed blocked-author filter.
    blockFilter: createBlockedAuthorFilter(ref),
    authHeadersProvider: (url, method, {body}) async {
      final httpMethod = HttpMethod.parse(method) ?? HttpMethod.get;
      // Forward the request body so the NIP-98 `payload` tag hashes the
      // bytes the request actually sends — without this the server 401s
      // with `payload hash mismatch` and mark-read silently rolls back.
      final token = await nip98AuthService.createAuthToken(
        url: url,
        method: httpMethod,
        payload: body,
      );
      if (token == null) {
        throw const Nip98AuthException(
          'Unable to sign notifications request',
          code: 'token_unavailable',
        );
      }
      return {'Authorization': token.authorizationHeader};
    },
  );
  // Close the internal BehaviorSubject when this provider rebuilds or the
  // container disposes (e.g. auth flip, account switch). The feed bloc and
  // badge cubit swap away before this fires, but the refresh coordinator
  // may still hold this instance across an in-flight refresh. That is
  // benign: getNotifications emits to the snapshot before persisting, so a
  // close-during-refresh fails on the emit with a StateError — before any
  // DAO write — and the coordinator treats that as account-switch noise.
  ref.onDispose(repository.close);
  return repository;
});
