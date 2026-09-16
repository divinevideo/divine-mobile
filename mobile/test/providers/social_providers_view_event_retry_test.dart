// ABOUTME: Tests the wiring between the analytics service and the durable
// ABOUTME: view-event retry sweep: immediate flush, startup replay, consent.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockViewEventPublisher extends Mock implements ViewEventPublisher {}

class _MockProductEventQueue extends Mock implements ProductEventQueue {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _ReadyNostrSession extends NostrSession {
  _ReadyNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

const _pubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _videoPubkey =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(ViewTrafficSource.unknown);
  });

  group('viewEventRetryServiceProvider', () {
    late AppDatabase database;
    late _MockViewEventPublisher publisher;
    late ProviderContainer container;

    PendingViewEvent queuedView(String id) => PendingViewEvent(
      id: id,
      videoId: 'video-$id',
      videoPubkey: _videoPubkey,
      videoVineId: 'vine-$id',
      videoAddressableDTag: 'd-tag',
      videoEventKind: NIP71VideoKinds.addressableShortVideo,
      userPubkey: _pubkey,
      watchDurationMs: 2500,
      totalDurationMs: 6000,
      loopCount: 1,
      trafficSource: 'home',
      sourceDetail: 'following',
      status: PendingViewEventStatus.pending,
      createdAt: DateTime.utc(2026, 5),
      phase: 'end',
      appVersion: '1.0.22',
    );

    void expectNothingPublished() => verifyNever(
      () => publisher.publishViewEvent(
        video: any(named: 'video'),
        startSeconds: any(named: 'startSeconds'),
        endSeconds: any(named: 'endSeconds'),
        source: any(named: 'source'),
        sourceDetail: any(named: 'sourceDetail'),
        loopCount: any(named: 'loopCount'),
        phase: any(named: 'phase'),
        appVersion: any(named: 'appVersion'),
      ),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);

      final client = _MockNostrClient();
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(_pubkey);

      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => authService.registerBeforeSessionTeardownCallback(any()),
      ).thenReturn(() {});

      publisher = _MockViewEventPublisher();
      when(() => publisher.appVersion).thenReturn('1.0.22');
      when(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: any(named: 'phase'),
          appVersion: any(named: 'appVersion'),
        ),
      ).thenAnswer((_) async => true);

      final productQueue = _MockProductEventQueue();
      when(productQueue.clear).thenAnswer((_) async {});
      when(productQueue.recoverPublishingAndFlush).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWithValue('1.0.22'),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          nostrSessionProvider.overrideWith(
            () => _ReadyNostrSession(
              NostrSessionReadiness.nostrReady(pubkey: _pubkey, client: client),
            ),
          ),
          databaseProvider.overrideWithValue(database),
          viewEventPublisherProvider.overrideWithValue(publisher),
          productEventQueueProvider.overrideWithValue(productQueue),
        ],
      );
      addTearDown(container.dispose);
    });

    test('replays a queued view on the startup foreground sweep', () async {
      // The analytics service watches the retry service, and the sweep in
      // turn consults analytics consent. That read used to close a provider
      // cycle, which Riverpod rejects in debug builds — the sweep threw
      // before publishing anything, on every launch and every swipe.
      await database.pendingViewEventsDao.enqueue(queuedView('view-a'));

      container.read(analyticsServiceProvider);
      container.read(viewEventRetryServiceProvider);
      await pumpEventQueue();

      expect(await database.pendingViewEventsDao.getById('view-a'), isNull);
    });

    test('publishes a tracked view immediately', () async {
      final analytics = container.read(analyticsServiceProvider);
      await analytics.initialize();
      // Let the startup sweep finish first: overlapping sweeps are dropped,
      // and this test is about the flush the tracked view triggers itself.
      await pumpEventQueue();

      await analytics.trackDetailedVideoViewWithUser(
        VideoEvent(
          id: 'a' * 64,
          pubkey: _videoPubkey,
          createdAt: DateTime.utc(2026, 5).millisecondsSinceEpoch ~/ 1000,
          content: '',
          timestamp: DateTime.utc(2026, 5),
          vineId: 'vine-a',
          addressableDTag: 'd-tag',
          eventKind: NIP71VideoKinds.addressableShortVideo,
        ),
        userId: _pubkey,
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: const Duration(milliseconds: 2500),
        totalDuration: const Duration(seconds: 6),
        trafficSource: ViewTrafficSource.home,
      );

      verify(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: ViewEventPhase.end,
          appVersion: any(named: 'appVersion'),
        ),
      ).called(1);
      expect(
        await database.pendingViewEventsDao.getRetryableForUser(
          userPubkey: _pubkey,
        ),
        isEmpty,
      );
    });

    test('withdrawing consent stops the sweep from publishing', () async {
      final analytics = container.read(analyticsServiceProvider);
      await analytics.initialize();
      await analytics.setAnalyticsEnabled(false);
      // Queued after the withdrawal deleted the existing rows, so this one
      // survives only if the sweep itself honours the decision.
      await database.pendingViewEventsDao.enqueue(queuedView('view-a'));

      await container.read(viewEventRetryServiceProvider)!.sweep();

      expectNothingPublished();
      expect(
        await database.pendingViewEventsDao.getById('view-a'),
        isNotNull,
      );
    });
  });
}
