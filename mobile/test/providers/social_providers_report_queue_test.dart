// ABOUTME: Tests the durable report queue wiring between the reporting
// ABOUTME: service and its retry worker (#8053).

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/models/content_moderation.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

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

  setUpAll(() => registerFallbackValue(<List<String>>[]));

  group('contentReportingServiceProvider', () {
    late AppDatabase database;
    late ProviderContainer container;
    late _MockDmRepository dmRepository;

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
      dmRepository = _MockDmRepository();
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

    group('moderation DM delivery', () {
      const reportId = 'queued-before-update';
      const otherKey =
          'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef';
      late LogCaptureService logCapture;
      late bool recoverSucceeds;

      setUp(() async {
        logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
        addTearDown(logCapture.clearAllLogs);
        recoverSucceeds = true;
        when(() => dmRepository.userPubkey).thenReturn(_pubkey);
        when(
          () => dmRepository.enqueueSend(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            idempotencyKey: any(named: 'idempotencyKey'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async => const EnqueueSendResult.enqueued('rumor'));
        when(
          () => dmRepository.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        ).thenAnswer(
          (_) async => recoverSucceeds
              ? NIP17SendResult.success(
                  rumorEventId: 'rumor',
                  messageEventId: 'wrap',
                  recipientPubkey: kModerationPubkeyHex,
                )
              : const NIP17SendResult.failure('offline'),
        );
      });

      /// Queues a report whose moderation DM was addressed to [recipient] when
      /// it was filed, as a build that captured that key would have stored it.
      Future<PendingReport> queueReportFor(String recipient) async {
        final report = PendingReport(
          reportId: reportId,
          userPubkey: _pubkey,
          eventJson: '{}',
          zendeskPayload: '{}',
          createdAt: DateTime.utc(2026, 9, 28),
          moderationPayload: jsonEncode({
            'recipientPubkey': recipient,
            'content': 'Content Report',
            'tags': <List<String>>[],
          }),
          moderationStatus: PendingReportChannelStatus.pending,
        );
        await database.pendingReportsDao.enqueue(report);
        return report;
      }

      Future<bool> deliver(PendingReport report) async {
        final service = await container.read(
          contentReportingServiceProvider.future,
        );
        return service.deliverReportChannel(report, ReportChannel.moderation);
      }

      void verifySentTo(String recipient, {int times = 1}) {
        verify(
          () => dmRepository.enqueueSend(
            recipientPubkey: recipient,
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            idempotencyKey: any(named: 'idempotencyKey'),
            createdAt: any(named: 'createdAt'),
          ),
        ).called(times);
      }

      List<String> retargetLogs() => logCapture
          .getRecentLogs(minLevel: LogLevel.warning)
          .map((entry) => entry.message)
          .where((message) => message.contains(reportId))
          .toList();

      test(
        'delivers a report queued for a retired key to the pinned key',
        () async {
          final retired = kLegacyModerationPubkeys.first;
          final report = await queueReportFor(retired);

          expect(await deliver(report), isTrue);

          verifySentTo(kModerationPubkeyHex);
          verifyNever(
            () => dmRepository.enqueueSend(
              recipientPubkey: retired,
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              idempotencyKey: any(named: 'idempotencyKey'),
              createdAt: any(named: 'createdAt'),
            ),
          );
        },
      );

      test('keeps a stored recipient that is not retired', () async {
        final report = await queueReportFor(otherKey);

        expect(await deliver(report), isTrue);

        verifySentTo(otherKey);
        expect(retargetLogs(), isEmpty);
      });

      test('logs the re-target once however often it is retried', () async {
        recoverSucceeds = false;
        final report = await queueReportFor(kLegacyModerationPubkeys.first);

        expect(await deliver(report), isFalse);
        expect(await deliver(report), isFalse);

        verifySentTo(kModerationPubkeyHex, times: 2);
        final logged = retargetLogs();
        expect(logged, hasLength(1));
        // AGENTS.md: every pubkey reaching a log sink carries both encodings.
        expect(
          logged.single,
          allOf(
            contains(pubkeyForLogs(kLegacyModerationPubkeys.first)),
            contains(pubkeyForLogs(kModerationPubkeyHex)),
          ),
        );
      });
    });
  });
}
