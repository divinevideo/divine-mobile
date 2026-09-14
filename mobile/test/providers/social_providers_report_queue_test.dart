// ABOUTME: Tests the durable report queue wiring between the reporting
// ABOUTME: service and its retry worker (#8053).

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _ReadyNostrSession extends NostrSession {
  _ReadyNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

class _FixedNostrService extends NostrService {
  _FixedNostrService(this._client);

  final NostrClient _client;

  @override
  NostrClient build() => _client;
}

class _Foregrounded extends AppForeground {
  @override
  bool build() => true;
}

const _pubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _reportedEventId =
    'abababababababababababababababababababababababababababababababab';
const _reportedAuthor =
    'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contentReportingServiceProvider', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const connectivityStatus = EventChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      messenger.setMockStreamHandler(
        connectivityStatus,
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      addTearDown(
        () => messenger.setMockStreamHandler(connectivityStatus, null),
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      database = AppDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _MockNostrClient();
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(_pubkey);
      when(() => client.isInitialized).thenReturn(true);

      // No signer under test: the relay leg records a failed attempt, which
      // is the observable proof that a sweep ran.
      final authService = _MockAuthService();
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => null);

      final moderation = _MockModerationLabelService();
      when(
        () => moderation.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);

      // The moderation leg is not under test: a repository owned by nobody
      // makes its delivery refuse before any DM work.
      final dmRepository = _MockDmRepository();
      when(() => dmRepository.userPubkey).thenReturn('');
      when(dmRepository.stopListening).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          nostrSessionProvider.overrideWith(
            () => _ReadyNostrSession(
              NostrSessionReadiness.nostrReady(pubkey: _pubkey, client: client),
            ),
          ),
          nostrServiceProvider.overrideWith(() => _FixedNostrService(client)),
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          moderationLabelServiceProvider.overrideWithValue(moderation),
          dmRepositoryProvider.overrideWithValue(dmRepository),
          appForegroundProvider.overrideWith(_Foregrounded.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'a saved report wakes the retry worker for its first attempt',
      () async {
        // The worker watches the reporting service, exactly as the app shell
        // wires it, so the service's wake-up has to reach a provider that
        // depends on its own.
        final worker = await container.read(reportRetryServiceProvider.future);
        expect(worker, isNotNull);
        await pumpEventQueue();
        final service = await container.read(
          contentReportingServiceProvider.future,
        );

        final result = await service.reportContent(
          eventId: _reportedEventId,
          authorPubkey: _reportedAuthor,
          reason: ContentFilterReason.spam,
          details: 'spam',
        );
        expect(result.isSilentSuccess, isTrue);

        // Nothing else schedules work here: the worker found an empty queue
        // when it started, so only the post-save wake-up can drive this row.
        final attempted =
            (database.select(database.pendingReports)
                  ..where((row) => row.reportId.equals(result.reportId!)))
                .watchSingle()
                .firstWhere((row) => row.relayAttempts > 0)
                .timeout(const Duration(seconds: 5));
        await expectLater(attempted, completes);
      },
    );
  });
}
