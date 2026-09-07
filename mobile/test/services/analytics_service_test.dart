// ABOUTME: Tests for analytics service view tracking and Nostr event publishing
// ABOUTME: Verifies user preference controls, deduplication, and event flow

import 'dart:io';

import 'package:analytics/analytics.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _MockViewEventPublisher extends Mock implements ViewEventPublisher {}

class _MockPendingViewEventsDao extends Mock implements PendingViewEventsDao {}

class _MockProductEventQueue extends Mock implements ProductEventQueue {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// Records what the consent switch asked of the Firebase backend.
class _RecordingCollectionControl implements AnalyticsCollectionControl {
  final List<bool> collectionEnabled = [];
  int resetCount = 0;

  @override
  Future<void> setCollectionEnabled({required bool enabled}) async {
    collectionEnabled.add(enabled);
  }

  @override
  Future<void> resetAnalyticsData() async {
    resetCount++;
  }
}

/// A store whose writes fail the way a real device's can.
class _FailingWriteSharedPreferencesStore
    extends InMemorySharedPreferencesStore {
  _FailingWriteSharedPreferencesStore.withData(super.data, {required this.mode})
    : super.withData();

  final _WriteFailure mode;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    return switch (mode) {
      _WriteFailure.rejected => false,
      _WriteFailure.throws => throw Exception('storage unavailable'),
    };
  }
}

class _FailingReadSharedPreferencesStore
    extends InMemorySharedPreferencesStore {
  _FailingReadSharedPreferencesStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() async {
    throw Exception('storage unavailable');
  }
}

enum _WriteFailure { rejected, throws }

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(_productAnalyticsEventFallback());
    registerFallbackValue(_pendingViewEventFallback());
    registerFallbackValue(ViewTrafficSource.unknown);
  });
  group('AnalyticsService', () {
    late AnalyticsService analyticsService;
    late BackgroundActivityManager backgroundActivityManager;
    AppDatabase? database;
    String? tempDbPath;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      backgroundActivityManager = BackgroundActivityManager();
      analyticsService = AnalyticsService(
        backgroundActivityManager: backgroundActivityManager,
        disableNostrPublishing: true,
      );
    });

    group('background activity registration', () {
      List<String> registeredServiceNames() =>
          (backgroundActivityManager.getStatus()['serviceNames']! as List)
              .cast<String>();

      test(
        'initialize registers with the background activity manager',
        () async {
          await analyticsService.initialize();

          expect(registeredServiceNames(), contains('AnalyticsService'));
        },
      );

      test(
        'dispose unregisters from the background activity manager',
        () async {
          await analyticsService.initialize();
          expect(registeredServiceNames(), contains('AnalyticsService'));

          analyticsService.dispose();

          // A service left registered keeps receiving lifecycle callbacks for
          // as long as the manager lives, so dispose must remove it (#6880).
          expect(registeredServiceNames(), isNot(contains('AnalyticsService')));
        },
      );

      test('dispose is safe when initialize never ran', () {
        expect(analyticsService.dispose, returnsNormally);
        // This test owns its manager (#4743), so nothing else can register
        // into it.
        expect(registeredServiceNames(), isNot(contains('AnalyticsService')));
      });

      test('a deferred initialize cannot re-register after dispose', () async {
        // analyticsServiceProvider defers initialize onto a microtask, so a
        // container torn down before that microtask lands calls dispose()
        // first. Without the guard the late initialize re-registers a dead
        // instance that nothing can ever unregister (#8398).
        final pending = Future.microtask(analyticsService.initialize);
        analyticsService.dispose();
        await pending;

        expect(registeredServiceNames(), isNot(contains('AnalyticsService')));
      });

      test(
        'dispose while initialize is awaiting prevents registration',
        () async {
          // initialize() runs synchronously up to its first await, so
          // disposing here lands between that suspension point and the
          // registration. An entry guard alone would not catch this (#8398).
          final pending = analyticsService.initialize();
          analyticsService.dispose();
          await pending;

          expect(registeredServiceNames(), isNot(contains('AnalyticsService')));
        },
      );
    });

    group('initialize', () {
      test('runs its body once when two callers race', () async {
        final queue = _MockProductEventQueue();
        when(queue.clear).thenAnswer((_) async {});
        when(queue.recoverPublishingAndFlush).thenAnswer((_) async {});
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: backgroundActivityManager,
          productEventQueue: queue,
          productAnalyticsEnabled: true,
          disableNostrPublishing: true,
        );

        // `_isInitialized` is only set past the first await, so two callers
        // that start in the same turn both used to run the whole body — a
        // second cleanup timer, a second queue recovery.
        // `analyticsServiceProvider` starts one on a microtask and the
        // Settings consent toggle awaits another to read the stored answer.
        await Future.wait([
          analyticsService.initialize(),
          analyticsService.initialize(),
        ]);

        verify(() => queue.setSendingEnabled(true)).called(1);
        verify(queue.recoverPublishingAndFlush).called(1);
      });
    });

    tearDown(() async {
      analyticsService.dispose();
      await database?.close();
      final path = tempDbPath;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
        final dir = Directory(path).parent;
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      }
    });

    test('should initialize with analytics enabled by default', () async {
      await analyticsService.initialize();
      expect(analyticsService.analyticsEnabled, isTrue);
    });

    test('should report operational when analytics enabled', () async {
      await analyticsService.initialize();
      expect(analyticsService.isOperational, isTrue);
    });

    test('should report not operational when analytics disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);
      expect(analyticsService.isOperational, isFalse);
    });

    test('should not track views when analytics is disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Should complete without error even when disabled
      await expectLater(analyticsService.trackVideoView(video), completes);
    });

    test('should track view_start without publishing Nostr event', () async {
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // view_start should complete without error (no Nostr event published)
      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: 'test-user',
          source: 'mobile',
          eventType: 'view_start',
        ),
        completes,
      );
    });

    test('matches the cross-language event ID vector', () {
      final eventWithoutId = <String, Object?>{
        'schema_version': 2,
        'occurred_at': '2026-08-20T00:00:00Z',
        'anonymous_id': '22222222-2222-4222-8222-222222222222',
        'session_id': '33333333-3333-4333-8333-333333333333',
        'source': 'web',
        'platform': 'web',
        'release': '2026.08.20',
        'consent_category': 'product_analytics',
        'event_name': 'content_impression_recorded',
        'properties': <String, Object?>{
          'content_id':
              '4444444444444444444444444444444444444444444444444444444444444444',
          'surface': 'feed',
          'position': 3,
          'visible_ms': 1500,
        },
      };

      expect(
        AnalyticsService.computeProductAnalyticsEventId(eventWithoutId),
        '0592b5a4908ee37cc24348ca8292152498e7caed970c043526051818c15b22cd',
      );
      expect(
        AnalyticsService.computeProductAnalyticsEventId({
          'properties': eventWithoutId['properties'],
          ...eventWithoutId,
        }),
        '0592b5a4908ee37cc24348ca8292152498e7caed970c043526051818c15b22cd',
      );
    });

    test(
      'records a signed version-two impression with no raw identity',
      () async {
        final queue = _MockProductEventQueue();
        when(
          () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) async {});
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: true,
          currentUserPubkey: () =>
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          anonymousId: () => '018ff7d7-2ef5-7000-8000-000000000001',
          sessionId: () => '018ff7d7-2ef5-7000-8000-000000000002',
          platform: () => 'ios',
          appVersion: () => '1.2.3',
          now: () => DateTime.utc(2026, 8, 20),
        );
        await analyticsService.initialize();

        final eventId = await analyticsService.recordContentImpression(
          contentId:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          surface: ProductAnalyticsV2Surface.feed,
          position: 4,
          visibleMs: 1000,
        );

        final captured = verify(
          () => queue.enqueue(
            captureAny(),
            ownerPubkey: captureAny(named: 'ownerPubkey'),
          ),
        ).captured;
        final event = captured[0] as ProductAnalyticsV2Event;
        expect(
          captured[1],
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );
        expect(event.eventName, 'content_impression_recorded');
        expect(event.envelope.eventId, eventId);
        expect(event.envelope.eventId, hasLength(64));
        expect(event.envelope.schemaVersion, 2);
        expect(event.envelope.occurredAt, DateTime.utc(2026, 8, 20));
        expect(
          event.envelope.anonymousId,
          '018ff7d7-2ef5-7000-8000-000000000001',
        );
        expect(
          event.envelope.sessionId,
          '018ff7d7-2ef5-7000-8000-000000000002',
        );
        expect(event.envelope.platform, ProductAnalyticsV2Platform.ios);
        expect(event.envelope.release, '1.2.3');
        expect(event.toJson(), isNot(contains('user_pubkey')));
        expect(event.propertiesJson, containsPair('position', 4));
        expect(event.propertiesJson, containsPair('visible_ms', 1000));
      },
    );

    test(
      'does not collect product events while the launch flag is off',
      () async {
        final queue = _MockProductEventQueue();
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: false,
          currentUserPubkey: () => 'a' * 64,
        );
        await analyticsService.initialize();

        final eventId = await analyticsService.recordContentImpression(
          contentId: 'b' * 64,
          surface: ProductAnalyticsV2Surface.feed,
          position: 0,
          visibleMs: 1000,
        );

        expect(eventId, isNull);
        verifyNever(
          () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
        );
      },
    );

    test('requires an identity for user-linked product events', () async {
      final queue = _MockProductEventQueue();
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        productEventQueue: queue,
        productAnalyticsEnabled: true,
        currentUserPubkey: () => null,
      );
      await analyticsService.initialize();

      final eventId = await analyticsService.recordContentImpression(
        contentId: 'b' * 64,
        surface: ProductAnalyticsV2Surface.feed,
        position: 0,
        visibleMs: 1000,
      );

      expect(eventId, isNull);
      verifyNever(
        () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
      );
    });

    test('queues a private experiment assignment', () async {
      final queue = _MockProductEventQueue();
      when(
        () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
      ).thenAnswer((_) async {});
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        productEventQueue: queue,
        productAnalyticsEnabled: true,
        currentUserPubkey: () => 'a' * 64,
        anonymousId: () => '018ff7d7-2ef5-7000-8000-000000000001',
        sessionId: () => '018ff7d7-2ef5-7000-8000-000000000002',
        platform: () => 'ios',
        appVersion: () => '1.2.3',
        now: () => DateTime.utc(2026, 8, 21),
      );
      await analyticsService.initialize();

      await analyticsService.recordExperimentExposure(
        experimentKey: 'post_publish_confirmation',
        variantKey: 'view_share',
        assignmentSource: ProductAnalyticsV2AssignmentSource.client,
      );

      final captured = verify(
        () => queue.enqueue(
          captureAny(),
          ownerPubkey: captureAny(named: 'ownerPubkey'),
        ),
      ).captured;
      final event = captured[0] as ProductAnalyticsV2Event;
      expect(captured[1], 'a' * 64);
      expect(event.eventName, 'experiment_exposure');
      expect(event.propertiesJson, {
        'experiment_key': 'post_publish_confirmation',
        'variant_key': 'view_share',
        'assignment_source': 'client',
      });
    });

    test('keeps only bounded UTM values on anonymous registration', () async {
      final queue = _MockProductEventQueue();
      when(
        () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
      ).thenAnswer((_) async {});
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        productEventQueue: queue,
        productAnalyticsEnabled: true,
        currentUserPubkey: () => null,
      );
      await analyticsService.initialize();

      analyticsService.captureProductAnalyticsUtm({
        'utm_source': 'Newsletter',
        'utm_medium': 'email',
        'utm_campaign': 'launch-1',
        'utm_term': 'private',
        'utm_content': 'has spaces',
      });
      await analyticsService.recordRegistrationStarted(
        entryPoint: ProductAnalyticsV2RegistrationEntryPoint.invite,
      );

      final event =
          verify(
                () => queue.enqueue(captureAny()),
              ).captured.single
              as ProductAnalyticsV2Event;
      expect(event.eventName, 'registration_started');
      expect(event.propertiesJson, {
        'entry_point': 'invite',
        'utm_source': 'newsletter',
        'utm_medium': 'email',
        'utm_campaign': 'launch-1',
      });
    });

    test(
      'consent withdrawal rotates identifiers and clears queued data',
      () async {
        final queue = _MockProductEventQueue();
        final recordedEvents = <ProductAnalyticsV2Event>[];
        when(
          () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((invocation) async {
          recordedEvents.add(
            invocation.positionalArguments.single as ProductAnalyticsV2Event,
          );
        });
        when(() => queue.enqueue(any())).thenAnswer((invocation) async {
          recordedEvents.add(
            invocation.positionalArguments.single as ProductAnalyticsV2Event,
          );
        });
        when(queue.clear).thenAnswer((_) async {});
        when(queue.flush).thenAnswer((_) async {});
        when(queue.recoverPublishingAndFlush).thenAnswer((_) async {});
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: true,
        );
        await analyticsService.initialize();
        analyticsService.captureProductAnalyticsUtm({
          'utm_source': 'newsletter',
        });
        await analyticsService.recordRegistrationStarted(
          entryPoint: ProductAnalyticsV2RegistrationEntryPoint.landing,
        );

        await analyticsService.setAnalyticsEnabled(false);
        await analyticsService.setAnalyticsEnabled(true);
        await analyticsService.recordRegistrationStarted(
          entryPoint: ProductAnalyticsV2RegistrationEntryPoint.invite,
        );

        verify(queue.clear).called(1);
        expect(analyticsService.productAnalyticsUtm, isEmpty);
        final envelopes = recordedEvents
            .map((event) => event.envelope)
            .toList();
        expect(envelopes, hasLength(2));
        expect(envelopes[1].anonymousId, isNot(envelopes[0].anonymousId));
        expect(envelopes[1].sessionId, isNot(envelopes[0].sessionId));
      },
    );

    test(
      'account changes purge every queued row and acquisition data',
      () async {
        final queue = _MockProductEventQueue();
        when(queue.clear).thenAnswer((_) async {});
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: true,
        );
        await analyticsService.initialize();
        analyticsService.captureProductAnalyticsUtm({
          'utm_source': 'newsletter',
        });

        await analyticsService.handleIdentityChange();

        verify(queue.clear).called(1);
        expect(analyticsService.productAnalyticsUtm, isEmpty);
      },
    );

    test(
      'stored opt-out clears queued events and never recovers them',
      () async {
        SharedPreferences.setMockInitialValues({'analytics_enabled': false});
        final queue = _MockProductEventQueue();
        when(queue.clear).thenAnswer((_) async {});
        when(queue.recoverPublishingAndFlush).thenAnswer((_) async {});
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: true,
          currentUserPubkey: () => 'a' * 64,
        );

        await analyticsService.initialize();

        expect(analyticsService.analyticsEnabled, isFalse);
        verify(queue.clear).called(1);
        verify(() => queue.setSendingEnabled(false)).called(1);
        verifyNever(queue.recoverPublishingAndFlush);

        final eventId = await analyticsService.recordContentImpression(
          contentId: 'b' * 64,
          surface: ProductAnalyticsV2Surface.feed,
          position: 0,
          visibleMs: 1000,
        );

        expect(eventId, isNull);
        verifyNever(
          () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
        );
      },
    );

    test(
      'does not record product events before initialize loads consent',
      () async {
        final queue = _MockProductEventQueue();
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: true,
          currentUserPubkey: () => 'a' * 64,
        );
        // No initialize() call: consent state is still unknown.

        final eventId = await analyticsService.recordContentImpression(
          contentId: 'b' * 64,
          surface: ProductAnalyticsV2Surface.feed,
          position: 0,
          visibleMs: 1000,
        );

        expect(eventId, isNull);
        verifyNever(
          () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
        );
      },
    );

    test(
      'rotates identifiers when an account session is torn down',
      () async {
        final queue = _MockProductEventQueue();
        when(
          () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) async {});
        when(queue.flush).thenAnswer((_) async {});
        when(queue.clear).thenAnswer((_) async {});
        when(queue.recoverPublishingAndFlush).thenAnswer((_) async {});
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: true,
          currentUserPubkey: () => 'a' * 64,
        );
        await analyticsService.initialize();

        await analyticsService.recordContentImpression(
          contentId: 'b' * 64,
          surface: ProductAnalyticsV2Surface.feed,
          position: 0,
          visibleMs: 1000,
        );
        await analyticsService.handleIdentityChange();
        await analyticsService.recordContentImpression(
          contentId: 'c' * 64,
          surface: ProductAnalyticsV2Surface.feed,
          position: 1,
          visibleMs: 1000,
        );

        final envelopes =
            verify(
                  () => queue.enqueue(
                    captureAny(),
                    ownerPubkey: any(named: 'ownerPubkey'),
                  ),
                ).captured
                .cast<ProductAnalyticsV2Event>()
                .map((event) => event.envelope)
                .toList();
        expect(envelopes, hasLength(2));
        expect(envelopes[1].anonymousId, isNot(envelopes[0].anonymousId));
        expect(envelopes[1].sessionId, isNot(envelopes[0].sessionId));
      },
    );

    test(
      'rotates identifiers across the anonymous-to-first-login boundary',
      () async {
        final queue = _MockProductEventQueue();
        when(
          () => queue.enqueue(any(), ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) async {});
        when(queue.clear).thenAnswer((_) async {});
        when(queue.flush).thenAnswer((_) async {});
        when(queue.recoverPublishingAndFlush).thenAnswer((_) async {});
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          productEventQueue: queue,
          productAnalyticsEnabled: true,
          currentUserPubkey: () => null,
        );
        await analyticsService.initialize();

        await analyticsService.recordRegistrationStarted(
          entryPoint: ProductAnalyticsV2RegistrationEntryPoint.landing,
        );
        // First login is still an identity boundary. Pre-login activity must
        // not be joinable to the newly authenticated account.
        await analyticsService.handleIdentityChange();
        await analyticsService.recordRegistrationStarted(
          entryPoint: ProductAnalyticsV2RegistrationEntryPoint.invite,
        );

        final envelopes =
            verify(
                  () => queue.enqueue(
                    captureAny(),
                    ownerPubkey: any(named: 'ownerPubkey'),
                  ),
                ).captured
                .cast<ProductAnalyticsV2Event>()
                .map((event) => event.envelope)
                .toList();
        expect(envelopes, hasLength(2));
        expect(envelopes[1].anonymousId, isNot(envelopes[0].anonymousId));
        expect(envelopes[1].sessionId, isNot(envelopes[0].sessionId));
        verify(queue.clear).called(1);
      },
    );

    test('enqueues eligible view_end before triggering a retry flush', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_pending_view_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      var flushCount = 0;
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async {
          flushCount++;
        },
      );
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
        vineId: 'vine-id',
        addressableDTag: 'the-d-tag',
        eventKind: NIP71VideoKinds.addressableShortVideo,
      );

      await analyticsService.trackDetailedVideoViewWithUser(
        video,
        userId:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: const Duration(milliseconds: 2500),
        totalDuration: const Duration(seconds: 6),
        loopCount: 1,
        trafficSource: ViewTrafficSource.home,
        sourceDetail: 'following',
      );

      final retryable = await database!.pendingViewEventsDao.getRetryableForUser(
        userPubkey:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(retryable, hasLength(1));
      expect(retryable.single.videoId, video.id);
      expect(retryable.single.videoPubkey, video.pubkey);
      expect(retryable.single.videoVineId, 'vine-id');
      // Without this the row cannot address its subject, and every retry is
      // skipped by ViewEventPublisher for the lifetime of the queue (#7169).
      expect(retryable.single.videoAddressableDTag, 'the-d-tag');
      expect(
        retryable.single.videoEventKind,
        NIP71VideoKinds.addressableShortVideo,
      );
      expect(retryable.single.watchDurationMs, 2500);
      expect(retryable.single.totalDurationMs, 6000);
      expect(retryable.single.loopCount, 1);
      expect(retryable.single.trafficSource, 'home');
      expect(retryable.single.sourceDetail, 'following');
      expect(flushCount, 1);
    });

    test(
      'does not enqueue or directly publish regular videos without d tags',
      () async {
        final publisher = _MockViewEventPublisher();
        final dao = _MockPendingViewEventsDao();
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          viewEventPublisher: publisher,
          pendingViewEventsDao: dao,
        );
        await analyticsService.initialize();

        final video = VideoEvent(
          id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          pubkey:
              'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          eventKind: NIP71VideoKinds.shortVideo,
        );

        await analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(seconds: 2),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => dao.enqueue(any()));
        verifyNever(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        );
      },
    );

    test('view_start enqueues a start-phase row with zero watch', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_pending_start_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async {},
      );
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
        vineId: 'vine-id',
        addressableDTag: 'the-d-tag',
      );
      const user =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      await analyticsService.trackDetailedVideoViewWithUser(
        video,
        userId: user,
        source: 'mobile',
        eventType: 'view_start',
        sessionToken: 'mount-1',
        trafficSource: ViewTrafficSource.home,
      );

      final rows = await database!.pendingViewEventsDao.getRetryableForUser(
        userPubkey: user,
      );
      expect(rows, hasLength(1));
      expect(rows.single.phase, 'start');
      // A start knows nothing about watch time yet — the row must not mint
      // engagement the viewer never gave.
      expect(rows.single.watchDurationMs, 0);
      expect(rows.single.loopCount, isNull);
      expect(rows.single.videoAddressableDTag, 'the-d-tag');
    });

    test(
      'view_start dedupes within a session token but a new token re-publishes',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'analytics_pending_start_dedupe_test_',
        );
        tempDbPath = '${tempDir.path}/test.db';
        database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
        analyticsService.dispose();
        analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          pendingViewEventsDao: database!.pendingViewEventsDao,
          flushPendingViewEvents: () async {},
        );
        await analyticsService.initialize();

        final video = VideoEvent(
          id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          pubkey:
              'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          vineId: 'vine-id',
          addressableDTag: 'the-d-tag',
        );
        const user =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        Future<void> start(String token) =>
            analyticsService.trackDetailedVideoViewWithUser(
              video,
              userId: user,
              source: 'mobile',
              eventType: 'view_start',
              sessionToken: token,
            );

        // A double-fire inside one mount collapses; a remount (re-watch) is
        // a new session and must report its own start.
        await start('mount-1');
        await start('mount-1');
        await start('mount-2');

        final rows = await database!.pendingViewEventsDao.getRetryableForUser(
          userPubkey: user,
        );
        expect(rows, hasLength(2));
        expect(rows.every((row) => row.phase == 'start'), isTrue);
      },
    );

    test('does not enqueue when analytics is disabled', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_disabled_pending_view_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      var flushCount = 0;
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async {
          flushCount++;
        },
      );
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      await analyticsService.trackDetailedVideoViewWithUser(
        video,
        userId:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: const Duration(seconds: 2),
      );

      final retryable = await database!.pendingViewEventsDao.getRetryableForUser(
        userPubkey:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(retryable, isEmpty);
      expect(flushCount, 0);
    });

    test('falls back to direct publish when pending enqueue fails', () async {
      final publisher = _MockViewEventPublisher();
      final dao = _MockPendingViewEventsDao();
      when(() => dao.enqueue(any())).thenThrow(StateError('enqueue failed'));
      when(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: any(named: 'phase'),
        ),
      ).thenAnswer((_) async => true);
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
      );
      await analyticsService.initialize();
      final video = _testVideo();

      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(seconds: 2),
          trafficSource: ViewTrafficSource.home,
        ),
        completes,
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => publisher.publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: 2,
          source: ViewTrafficSource.home,
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          // The direct-publish fallback carries the same phase the queued
          // row would have, so the relay counts it identically.
          phase: ViewEventPhase.end,
        ),
      ).called(1);
    });

    test('keeps queued row when immediate flush fails', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'analytics_flush_failure_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
      final publisher = _MockViewEventPublisher();
      analyticsService.dispose();
      analyticsService = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        viewEventPublisher: publisher,
        pendingViewEventsDao: database!.pendingViewEventsDao,
        flushPendingViewEvents: () async => throw StateError('flush failed'),
      );
      await analyticsService.initialize();
      final video = _testVideo();
      const userPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: userPubkey,
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(seconds: 2),
          trafficSource: ViewTrafficSource.home,
        ),
        completes,
      );

      final retryable = await database!.pendingViewEventsDao
          .getRetryableForUser(userPubkey: userPubkey);
      expect(retryable, hasLength(1));
      verifyNever(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
        ),
      );
    });

    test('should persist analytics preference', () async {
      await analyticsService.initialize();

      // Disable analytics
      await analyticsService.setAnalyticsEnabled(false);

      // Verify persisted
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getBool('analytics_enabled');
      expect(savedValue, isFalse);

      // Re-enable
      await analyticsService.setAnalyticsEnabled(true);
      final savedValue2 = prefs.getBool('analytics_enabled');
      expect(savedValue2, isTrue);
    });

    test('clears the tracked views cache without error', () async {
      await analyticsService.initialize();

      expect(analyticsService.clearTrackedViews, returnsNormally);
    });

    test('should handle batch tracking of empty list', () async {
      await analyticsService.initialize();
      await expectLater(analyticsService.trackVideoViews([]), completes);
    });

    group('consent boundary', () {
      const viewerPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      late _RecordingCollectionControl collectionControl;

      PendingViewEventsDao openDao() {
        final tempDir = Directory.systemTemp.createTempSync(
          'analytics_consent_boundary_test_',
        );
        tempDbPath = '${tempDir.path}/test.db';
        database = AppDatabase.test(NativeDatabase(File(tempDbPath!)));
        return database!.pendingViewEventsDao;
      }

      AnalyticsService buildService({PendingViewEventsDao? dao}) {
        analyticsService.dispose();
        return analyticsService = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          pendingViewEventsDao: dao,
          analyticsCollectionControl: collectionControl,
          currentUserPubkey: () => viewerPubkey,
        );
      }

      Future<void> trackView(AnalyticsService service) {
        return service.trackDetailedVideoViewWithUser(
          VideoEvent(
            id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
            pubkey:
                'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            content: 'Test video',
            timestamp: DateTime.now(),
            vineId: 'vine-id',
            addressableDTag: 'the-d-tag',
            eventKind: NIP71VideoKinds.addressableShortVideo,
          ),
          userId: viewerPubkey,
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(milliseconds: 2500),
          totalDuration: const Duration(seconds: 6),
        );
      }

      Future<List<PendingViewEvent>> queuedViews(PendingViewEventsDao dao) {
        return dao.getRetryableForUser(userPubkey: viewerPubkey);
      }

      setUp(() {
        collectionControl = _RecordingCollectionControl();
      });

      test(
        'does not queue a view before the stored preference has been read',
        () async {
          // The startup window is the whole problem: `analyticsEnabled` holds
          // its pre-load default of `true`, and a view queued here lands in a
          // durable outbox that survives the moment initialize() corrects it.
          SharedPreferences.setMockInitialValues({'analytics_enabled': false});
          final dao = openDao();
          final service = buildService(dao: dao);

          await trackView(service);

          expect(await queuedViews(dao), isEmpty);

          // Positive control: the gate is initialization, not a permanent off
          // switch, so a consenting session must still queue.
          SharedPreferences.setMockInitialValues({'analytics_enabled': true});
          final consenting = buildService(dao: dao);
          await consenting.initialize();
          await trackView(consenting);

          expect(await queuedViews(dao), hasLength(1));
        },
      );

      test(
        'a stored opt-out keeps the view outbox empty after startup',
        () async {
          SharedPreferences.setMockInitialValues({'analytics_enabled': false});
          final dao = openDao();
          final service = buildService(dao: dao);
          await service.initialize();

          await trackView(service);

          expect(await queuedViews(dao), isEmpty);
        },
      );

      test('withdrawal deletes the durable view outbox', () async {
        // The switch's own copy promises queued data is deleted. That has to
        // hold for `pending_view_events` too, not only the product queue —
        // these are identity-bearing Kind 22236 events that the next
        // foreground sweep would otherwise publish.
        SharedPreferences.setMockInitialValues({'analytics_enabled': true});
        final dao = openDao();
        final service = buildService(dao: dao);
        await service.initialize();
        await trackView(service);
        expect(await queuedViews(dao), hasLength(1));

        await service.setAnalyticsEnabled(false);

        expect(await queuedViews(dao), isEmpty);
      });

      test('a stored opt-out reaches Firebase collection at startup', () async {
        SharedPreferences.setMockInitialValues({'analytics_enabled': false});
        final service = buildService();

        await service.initialize();

        expect(collectionControl.collectionEnabled, equals([false]));
        expect(collectionControl.resetCount, 1);
      });

      test('a stored opt-in leaves Firebase collection on', () async {
        SharedPreferences.setMockInitialValues({'analytics_enabled': true});
        final service = buildService();

        await service.initialize();

        expect(collectionControl.collectionEnabled, equals([true]));
        expect(collectionControl.resetCount, isZero);
      });

      test('withdrawal turns Firebase off and clears its identity', () async {
        SharedPreferences.setMockInitialValues({'analytics_enabled': true});
        final service = buildService();
        await service.initialize();
        collectionControl.collectionEnabled.clear();

        await service.setAnalyticsEnabled(false);

        expect(collectionControl.collectionEnabled, equals([false]));
        expect(collectionControl.resetCount, 1);
      });

      test('opting back in turns Firebase collection on again', () async {
        SharedPreferences.setMockInitialValues({'analytics_enabled': false});
        final service = buildService();
        await service.initialize();
        collectionControl.collectionEnabled.clear();

        await service.setAnalyticsEnabled(true);

        expect(collectionControl.collectionEnabled, equals([true]));
      });

      test(
        'a preference read failure applies the full withdrawal path',
        () async {
          final originalStore = SharedPreferencesStorePlatform.instance;
          final queue = _MockProductEventQueue();
          final dao = _MockPendingViewEventsDao();
          when(queue.clear).thenAnswer((_) async {});
          when(() => queue.setSendingEnabled(any())).thenReturn(null);
          when(
            () => dao.deleteAllForUser(viewerPubkey),
          ).thenAnswer((_) async => 1);
          SharedPreferencesStorePlatform.instance =
              _FailingReadSharedPreferencesStore();
          SharedPreferences.resetStatic();
          analyticsService.dispose();
          analyticsService = AnalyticsService(
            backgroundActivityManager: BackgroundActivityManager(),
            productEventQueue: queue,
            pendingViewEventsDao: dao,
            analyticsCollectionControl: collectionControl,
            currentUserPubkey: () => viewerPubkey,
          );

          try {
            await analyticsService.initialize();

            expect(analyticsService.analyticsEnabled, isFalse);
            expect(collectionControl.collectionEnabled, equals([false]));
            expect(collectionControl.resetCount, 1);
            verify(queue.clear).called(1);
            verify(() => dao.deleteAllForUser(viewerPubkey)).called(1);
          } finally {
            SharedPreferencesStorePlatform.instance = originalStore;
            SharedPreferences.resetStatic();
          }
        },
      );

      group('persistence failures', () {
        late SharedPreferencesStorePlatform originalStore;

        setUp(() {
          originalStore = SharedPreferencesStorePlatform.instance;
        });

        tearDown(() {
          SharedPreferencesStorePlatform.instance = originalStore;
          SharedPreferences.resetStatic();
        });

        Future<AnalyticsService> serviceWithFailingWrites(
          _WriteFailure mode, {
          required bool storedConsent,
        }) async {
          SharedPreferences.setMockInitialValues({
            'analytics_enabled': storedConsent,
          });
          final service = buildService();
          await service.initialize();
          SharedPreferencesStorePlatform.instance =
              _FailingWriteSharedPreferencesStore.withData({
                'flutter.analytics_enabled': storedConsent,
              }, mode: mode);
          SharedPreferences.resetStatic();
          return service;
        }

        test('a rejected write is reported as a failure', () async {
          final service = await serviceWithFailingWrites(
            _WriteFailure.rejected,
            storedConsent: true,
          );

          expect(await service.setAnalyticsEnabled(false), isFalse);
        });

        test('a throwing write is reported as a failure', () async {
          final service = await serviceWithFailingWrites(
            _WriteFailure.throws,
            storedConsent: true,
          );

          expect(await service.setAnalyticsEnabled(false), isFalse);
        });

        test('a failed opt-in does not start collecting', () async {
          // Consent that did not reach storage is gone at the next launch, so
          // honouring it in memory would collect under an answer the person
          // will never see again.
          final service = await serviceWithFailingWrites(
            _WriteFailure.rejected,
            storedConsent: false,
          );

          expect(await service.setAnalyticsEnabled(true), isFalse);
          expect(service.analyticsEnabled, isFalse);
        });

        test('a failed opt-out still stops collecting', () async {
          final service = await serviceWithFailingWrites(
            _WriteFailure.rejected,
            storedConsent: true,
          );
          expect(service.analyticsEnabled, isTrue);

          expect(await service.setAnalyticsEnabled(false), isFalse);
          expect(service.analyticsEnabled, isFalse);
        });
      });
    });

    test('should not batch track when analytics disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final now = DateTime.now();
      final videos = List.generate(
        3,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          content: 'Test video $i',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
        ),
      );

      await expectLater(analyticsService.trackVideoViews(videos), completes);
    });
  });
}

VideoEvent _testVideo() {
  return VideoEvent(
    id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
    pubkey: 'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: DateTime.now(),
    vineId: 'vine-id',
  );
}

PendingViewEvent _pendingViewEventFallback() {
  return PendingViewEvent(
    id: 'fallback',
    videoId: 'video-fallback',
    videoPubkey:
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
    userPubkey:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    watchDurationMs: 1000,
    trafficSource: 'unknown',
    status: PendingViewEventStatus.pending,
    createdAt: DateTime.utc(2026, 5),
  );
}

ProductAnalyticsV2Event _productAnalyticsEventFallback() {
  return ProductAnalyticsV2LandingViewedEvent(
    envelope: ProductAnalyticsV2Envelope(
      eventId: 'fallback',
      schemaVersion: 2,
      occurredAt: DateTime.utc(2026, 8, 20),
      anonymousId: '22222222-2222-4222-8222-222222222222',
      sessionId: '33333333-3333-4333-8333-333333333333',
      source: ProductAnalyticsV2Source.mobile,
      platform: ProductAnalyticsV2Platform.ios,
      release: 'test',
      consentCategory: ProductAnalyticsV2ConsentCategory.productAnalytics,
    ),
    properties: const ProductAnalyticsV2LandingViewedProperties(
      landingPage: ProductAnalyticsV2LandingPage.home,
      referrerClass: ProductAnalyticsV2ReferrerClass.direct,
    ),
  );
}
