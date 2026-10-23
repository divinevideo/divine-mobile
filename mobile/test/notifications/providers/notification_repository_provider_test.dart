// ABOUTME: Tests the lifecycle wiring of notificationRepositoryProvider.
// ABOUTME: Pins that disposing the account container stops its REST retries.

import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:db_client/db_client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/notifications/providers/announcement_providers.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNotificationsDao extends Mock implements NotificationsDao {}

class _MockAuthService extends Mock implements AuthService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockContentPolicyEngine extends Mock implements ContentPolicyEngine {}

/// Holds its first request open; anything after that fails the way a closed
/// IOClient does, before any I/O.
class _CountingClient extends http.BaseClient {
  final firstSend = Completer<http.StreamedResponse>();
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends++;
    if (sends == 1) return firstSend.future;
    throw http.ClientException(
      'HTTP request failed. Client is already closed.',
    );
  }
}

void main() {
  group('notificationRepositoryProvider', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    const ownerPubkey =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const actorPubkey =
        'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
    const videoEventId =
        'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';

    ProviderContainer createContainer({http.Client? announcementClient}) {
      final nostrClient = _MockNostrClient();
      when(() => nostrClient.configuredRelays).thenReturn(<String>[]);

      // Held open so the enrichment that requested the stats never resumes:
      // this test pins only how often that request is sent.
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) => Completer<Map<String, models.UserProfile>>().future);

      // A cached like makes the new repository look up its video's stats.
      final dao = _MockNotificationsDao();
      when(
        () => dao.getAllNotifications(
          limit: any(named: 'limit'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer(
        (_) async => [
          NotificationRow(
            id: 'cached-like',
            type: 'like',
            fromPubkey: actorPubkey,
            targetEventId: videoEventId,
            hasCommentTarget: false,
            timestamp: 1760000000,
            isRead: false,
            cachedAt: DateTime(2026, 10),
            ownerPubkey: ownerPubkey,
          ),
        ],
      );
      final database = _MockAppDatabase();
      when(() => database.notificationsDao).thenReturn(dao);

      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(ownerPubkey);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          announcementHttpClientFactoryProvider.overrideWithValue(
            () =>
                announcementClient ??
                MockClient((_) async => http.Response('', 503)),
          ),
          currentEnvironmentProvider.overrideWithValue(
            EnvironmentConfig.production,
          ),
          nostrServiceProvider.overrideWithValue(nostrClient),
          profileRepositoryProvider.overrideWithValue(profileRepository),
          nip98AuthServiceProvider.overrideWithValue(_MockNip98AuthService()),
          databaseProvider.overrideWithValue(database),
          authServiceProvider.overrideWithValue(authService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            _MockContentBlocklistRepository(),
          ),
          contentPolicyEngineProvider.overrideWithValue(
            _MockContentPolicyEngine(),
          ),
          appVersionProvider.overrideWithValue('1.0.0'),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'iOS receives platform-targeted announcements over anonymous HTTP',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final now = DateTime.now().toUtc();
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://announcements.divine.video/v1/announcements',
          );
          expect(
            request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains('authorization')),
          );
          return http.Response(
            jsonEncode({
              'schemaVersion': 1,
              'announcements': [
                {
                  'id': '9cf3daa0-d982-47a9-a942-c907c223b8b5',
                  'title': 'Your profile has a home',
                  'body': 'Find your website on your profile.',
                  'publishedAt': now
                      .subtract(const Duration(minutes: 1))
                      .toIso8601String(),
                  'expiresAt': now
                      .add(const Duration(days: 1))
                      .toIso8601String(),
                  'platforms': ['ios'],
                  'minimumAppVersion': '1.0.0',
                  'learnMoreUrl': null,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final container = createContainer(announcementClient: client);
        final repository = container.read(notificationRepositoryProvider)!;
        await repository.announcementsRepository!.refresh();
        expect(
          repository.announcementsRepository!.items.single.title,
          'Your profile has a home',
        );
      },
    );

    // An in-place account switch disposes the outgoing container while its
    // notification enrichment is still waiting on the REST API (#10291).
    test('disposing the container stops retrying a request it cut '
        'off', () {
      fakeAsync((async) {
        final container = createContainer();
        final client = _CountingClient();
        http.runWithClient(
          () => container.read(notificationRepositoryProvider),
          () => client,
        );
        async.flushMicrotasks();
        expect(client.sends, equals(1));

        container.dispose();
        client.firstSend.completeError(
          http.ClientException('Connection closed while receiving data'),
        );
        // Past every backoff a retry could wait.
        async.elapse(const Duration(seconds: 5));

        expect(client.sends, equals(1));
      });
    });
  });
}
