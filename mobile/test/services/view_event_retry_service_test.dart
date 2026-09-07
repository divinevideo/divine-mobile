// ABOUTME: Unit tests for durable view-event retry sweeping.
// ABOUTME: Verifies queued views publish, fail, back off, and terminally drop.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/view_event_retry_service.dart';

class _MockViewEventPublisher extends Mock implements ViewEventPublisher {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _ConsentWithdrawingPendingViewEventsDao extends PendingViewEventsDao {
  _ConsentWithdrawingPendingViewEventsDao(
    super.attachedDatabase, {
    required this.onMarkedPublishing,
  });

  final void Function() onMarkedPublishing;

  @override
  Future<bool> markPublishing(String id) async {
    final marked = await super.markPublishing(id);
    onMarkedPublishing();
    return marked;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(ViewTrafficSource.unknown);
  });

  group(ViewEventRetryService, () {
    late AppDatabase database;
    late PendingViewEventsDao dao;
    late _MockViewEventPublisher publisher;
    late String tempDbPath;
    late DateTime now;

    const userPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const videoPubkey =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    PendingViewEvent makeEvent({
      required String id,
      PendingViewEventStatus status = PendingViewEventStatus.pending,
      int watchDurationMs = 2500,
      int retryCount = 0,
      DateTime? lastAttemptAt,
      String eventVideoPubkey = videoPubkey,
      DateTime? createdAt,
      String? addressableDTag = 'd-tag',
      int? videoEventKind = NIP71VideoKinds.addressableShortVideo,
      String? eventVideoId,
      String? videoVineId,

      String? phase,
    }) {
      return PendingViewEvent(
        id: id,
        videoId: eventVideoId ?? 'video-$id',
        videoPubkey: eventVideoPubkey,
        videoVineId: videoVineId ?? 'vine-$id',
        videoAddressableDTag: addressableDTag,
        videoEventKind: videoEventKind,
        userPubkey: userPubkey,
        watchDurationMs: watchDurationMs,
        totalDurationMs: 6000,
        loopCount: 1,
        trafficSource: 'home',
        sourceDetail: 'following',
        status: status,
        retryCount: retryCount,
        lastAttemptAt: lastAttemptAt,
        createdAt: createdAt ?? DateTime.utc(2026, 5),
        phase: phase,
      );
    }

    ViewEventRetryService makeService({
      Stream<bool>? foregroundStream,
      ViewEventRetryConfig retryConfig = const ViewEventRetryConfig(),
      bool Function()? isAnalyticsEnabled,
    }) {
      return ViewEventRetryService(
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
        userPubkey: userPubkey,
        appForegroundStream: foregroundStream ?? const Stream<bool>.empty(),
        isAnalyticsEnabled: isAnalyticsEnabled,
        retryConfig: retryConfig,
        now: () => now,
      );
    }

    setUp(() {
      final tempDir = Directory.systemTemp.createTempSync(
        'view_event_retry_service_test_',
      );
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
      dao = database.pendingViewEventsDao;
      publisher = _MockViewEventPublisher();
      now = DateTime.utc(2026, 5, 23, 12);

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
    });

    tearDown(() async {
      await database.close();
      final file = File(tempDbPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      final dir = Directory(tempDbPath).parent;
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    group('analytics consent', () {
      test('does not publish while consent is withdrawn', () async {
        // This queue outlives the switch: rows survive a restart, and rows
        // written by a build that predates the switch were never offered a
        // consent decision at all. Publishing them is irreversible, so the
        // sweep asks before it publishes rather than trusting the queue.
        await dao.enqueue(makeEvent(id: 'view-a'));
        final service = makeService(isAnalyticsEnabled: () => false);

        await service.sweep();

        verifyNever(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
            phase: any(named: 'phase'),
          ),
        );
        expect(await dao.getById('view-a'), isNotNull);
      });

      test('publishes again once consent is granted', () async {
        // Consent is sampled per sweep, so the gate tracks a mid-session
        // change instead of freezing whatever was true at construction.
        await dao.enqueue(makeEvent(id: 'view-a'));
        var consented = false;
        final service = makeService(isAnalyticsEnabled: () => consented);
        await service.sweep();
        expect(await dao.getById('view-a'), isNotNull);

        consented = true;
        await service.sweep();

        expect(await dao.getById('view-a'), isNull);
      });

      test(
        'a foreground wake cannot publish while consent is withdrawn',
        () async {
          // The foreground listener is the path that runs unattended, so the
          // gate has to hold there and not only on a direct sweep() call.
          await dao.enqueue(makeEvent(id: 'view-a'));
          final foreground = StreamController<bool>();
          addTearDown(foreground.close);
          final service = makeService(
            foregroundStream: foreground.stream,
            isAnalyticsEnabled: () => false,
          );
          await service.initialize();
          addTearDown(service.dispose);

          foreground.add(true);
          await pumpEventQueue();

          verifyNever(
            () => publisher.publishViewEvent(
              video: any(named: 'video'),
              startSeconds: any(named: 'startSeconds'),
              endSeconds: any(named: 'endSeconds'),
              source: any(named: 'source'),
              sourceDetail: any(named: 'sourceDetail'),
              loopCount: any(named: 'loopCount'),
              phase: any(named: 'phase'),
            ),
          );
          expect(await dao.getById('view-a'), isNotNull);
        },
      );

      test(
        'does not publish when consent is withdrawn during a sweep',
        () async {
          await dao.enqueue(makeEvent(id: 'view-a'));
          var consented = true;
          dao = _ConsentWithdrawingPendingViewEventsDao(
            database,
            onMarkedPublishing: () => consented = false,
          );
          final service = makeService(isAnalyticsEnabled: () => consented);

          await service.sweep();

          verifyNever(
            () => publisher.publishViewEvent(
              video: any(named: 'video'),
              startSeconds: any(named: 'startSeconds'),
              endSeconds: any(named: 'endSeconds'),
              source: any(named: 'source'),
              sourceDetail: any(named: 'sourceDetail'),
              loopCount: any(named: 'loopCount'),
              phase: any(named: 'phase'),
            ),
          );
        },
      );
    });

    test('publishes retryable view and deletes it after success', () async {
      await dao.enqueue(makeEvent(id: 'view-a'));
      final service = makeService();

      await service.sweep();

      expect(await dao.getById('view-a'), isNull);
      final captured = verify(
        () => publisher.publishViewEvent(
          video: captureAny(named: 'video'),
          startSeconds: captureAny(named: 'startSeconds'),
          endSeconds: captureAny(named: 'endSeconds'),
          source: captureAny(named: 'source'),
          sourceDetail: captureAny(named: 'sourceDetail'),
          loopCount: captureAny(named: 'loopCount'),
          phase: captureAny(named: 'phase'),
        ),
      ).captured;
      final video = captured[0] as VideoEvent;
      expect(video.id, 'video-view-a');
      expect(video.pubkey, videoPubkey);
      expect(video.vineId, 'vine-view-a');
      // Without this the publisher skips on a null addressableId, which is
      // what made every queued view event unpublishable (#7169).
      expect(video.addressableDTag, 'd-tag');
      expect(video.eventKind, NIP71VideoKinds.addressableShortVideo);
      expect(video.addressableId, isNotNull);
      expect(captured[1], 0);
      expect(captured[2], 2);
      expect(captured[3], ViewTrafficSource.home);
      expect(captured[4], 'following');
      expect(captured[5], closeTo(0.416, 0.01));
    });

    test(
      'passes a missing d tag through the publisher then deletes the row',
      () async {
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
        ).thenAnswer((_) async => false);
        await dao.enqueue(
          makeEvent(
            id: 'legacy',
            addressableDTag: null,
            videoVineId: 'vine-legacy',
          ),
        );
        final service = makeService();

        await service.sweep();

        // ViewEventPublisher owns the missing-d-tag drop decision (and its
        // Crashlytics reporting). The queue snapshot cannot grow a d-tag
        // later, so retrying would only re-fire the structural report.
        final captured = verify(
          () => publisher.publishViewEvent(
            video: captureAny(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        ).captured;
        expect((captured.single as VideoEvent).addressableDTag, isNull);
        expect(await dao.getById('legacy'), isNull);
      },
    );

    test(
      'deletes an empty stored d tag after the publisher returns false',
      () async {
        when(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
          ),
        ).thenAnswer((_) async => false);
        await dao.enqueue(makeEvent(id: 'empty-d', addressableDTag: ''));
        final service = makeService();

        await service.sweep();

        expect(await dao.getById('empty-d'), isNull);
      },
    );

    test(
      'marks row failed and increments retry count after publish failure',
      () async {
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
        ).thenAnswer((_) async => false);
        await dao.enqueue(makeEvent(id: 'view-a'));
        final service = makeService();

        await service.sweep();

        final failed = await dao.getById('view-a');
        expect(failed, isNotNull);
        expect(failed!.status, PendingViewEventStatus.failed);
        expect(failed.retryCount, 1);
        expect(failed.lastError, 'publish returned false');
        expect(failed.lastAttemptAt, isNotNull);
      },
    );

    test('skips failed rows whose retry backoff has not elapsed', () async {
      await dao.enqueue(
        makeEvent(
          id: 'view-a',
          status: PendingViewEventStatus.failed,
          retryCount: 2,
          lastAttemptAt: now.subtract(const Duration(seconds: 1)),
        ),
      );
      final service = makeService();

      await service.sweep();

      verifyNever(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: any(named: 'phase'),
        ),
      );
      final skipped = await dao.getById('view-a');
      expect(skipped!.status, PendingViewEventStatus.failed);
      expect(skipped.retryCount, 2);
    });

    test(
      'retries high-retry failed rows after capped backoff elapses',
      () async {
        await dao.enqueue(
          makeEvent(
            id: 'view-a',
            status: PendingViewEventStatus.failed,
            retryCount: 7,
            lastAttemptAt: now.subtract(const Duration(minutes: 6)),
          ),
        );
        final service = makeService();

        await service.sweep();

        expect(await dao.getById('view-a'), isNull);
        verify(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
            phase: any(named: 'phase'),
          ),
        ).called(1);
      },
    );

    test('limits each sweep to the configured batch size', () async {
      await dao.enqueue(
        makeEvent(id: 'oldest', createdAt: DateTime.utc(2026, 5)),
      );
      await dao.enqueue(
        makeEvent(id: 'middle', createdAt: DateTime.utc(2026, 5, 2)),
      );
      await dao.enqueue(
        makeEvent(id: 'newest', createdAt: DateTime.utc(2026, 5, 3)),
      );
      final service = makeService(
        retryConfig: const ViewEventRetryConfig(maxEventsPerSweep: 2),
      );

      await service.sweep();

      expect(await dao.getById('oldest'), isNull);
      expect(await dao.getById('middle'), isNull);
      expect(await dao.getById('newest'), isNotNull);
      verify(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: any(named: 'phase'),
        ),
      ).called(2);
    });

    test(
      'skips high-retry failed rows before capped backoff elapses',
      () async {
        await dao.enqueue(
          makeEvent(
            id: 'view-a',
            status: PendingViewEventStatus.failed,
            retryCount: 7,
            lastAttemptAt: now.subtract(const Duration(minutes: 4)),
          ),
        );
        final service = makeService();

        await service.sweep();

        verifyNever(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
            phase: any(named: 'phase'),
          ),
        );
        final skipped = await dao.getById('view-a');
        expect(skipped!.retryCount, 7);
      },
    );

    test('publishes self-views and sub-second partial-loop views', () async {
      await dao.enqueue(
        makeEvent(id: 'self-view', eventVideoPubkey: userPubkey),
      );
      await dao.enqueue(makeEvent(id: 'short-view', watchDurationMs: 999));
      final service = makeService();

      await service.sweep();

      expect(await dao.getById('self-view'), isNull);
      expect(await dao.getById('short-view'), isNull);
      final captured = verify(
        () => publisher.publishViewEvent(
          video: captureAny(named: 'video'),
          startSeconds: captureAny(named: 'startSeconds'),
          endSeconds: captureAny(named: 'endSeconds'),
          source: captureAny(named: 'source'),
          sourceDetail: captureAny(named: 'sourceDetail'),
          loopCount: captureAny(named: 'loopCount'),
          phase: captureAny(named: 'phase'),
        ),
      ).captured;
      // Two publishes: self-view + short partial-loop view.
      // Each call captures 7 args; legacy rows carry null phase.
      expect(captured.length, equals(14));
      final video = captured[0] as VideoEvent;
      expect(video.id, 'video-self-view');
      expect(video.pubkey, userPubkey);
      expect(video.vineId, 'vine-self-view');
      expect(captured[1], 0);
      expect(captured[2], 2);
      expect(captured[3], ViewTrafficSource.home);
      expect(captured[4], 'following');
      expect(captured[5], closeTo(0.416, 0.01));
      expect(captured[6], isNull);
    });

    test(
      'initialize resets interrupted publishing rows and sweeps on foreground',
      () async {
        final foregroundController = StreamController<bool>();
        addTearDown(foregroundController.close);
        await dao.enqueue(
          makeEvent(id: 'view-a', status: PendingViewEventStatus.publishing),
        );
        final service = makeService(
          foregroundStream: foregroundController.stream,
        );
        addTearDown(service.dispose);

        await service.initialize();
        foregroundController.add(true);
        await Future<void>.delayed(Duration.zero);

        expect(await dao.getById('view-a'), isNull);
        verify(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
            phase: any(named: 'phase'),
          ),
        ).called(1);
      },
    );

    test('start-phase queued row replays as a start event', () async {
      await dao.enqueue(
        makeEvent(id: 'view-start', watchDurationMs: 0, phase: 'start'),
      );
      final service = makeService();

      await service.sweep();

      expect(await dao.getById('view-start'), isNull);
      verify(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: 0,
          endSeconds: 0,
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: ViewEventPhase.start,
        ),
      ).called(1);
    });

    test('end-phase queued row replays as an end event', () async {
      await dao.enqueue(makeEvent(id: 'view-end', phase: 'end'));
      final service = makeService();

      await service.sweep();

      expect(await dao.getById('view-end'), isNull);
      verify(
        () => publisher.publishViewEvent(
          video: any(named: 'video'),
          startSeconds: any(named: 'startSeconds'),
          endSeconds: any(named: 'endSeconds'),
          source: any(named: 'source'),
          sourceDetail: any(named: 'sourceDetail'),
          loopCount: any(named: 'loopCount'),
          phase: ViewEventPhase.end,
        ),
      ).called(1);
    });

    test(
      'legacy queued row (null phase) replays without a phase tag',
      () async {
        await dao.enqueue(makeEvent(id: 'view-legacy'));
        final service = makeService();

        await service.sweep();

        // Pre-phase rows are legacy end-of-session events; replaying them
        // WITH phase=end would erase their view (the relay counts views on
        // start events only), so they go out with no phase at all.
        verify(
          () => publisher.publishViewEvent(
            video: any(named: 'video'),
            startSeconds: any(named: 'startSeconds'),
            endSeconds: any(named: 'endSeconds'),
            source: any(named: 'source'),
            sourceDetail: any(named: 'sourceDetail'),
            loopCount: any(named: 'loopCount'),
            phase: any(named: 'phase', that: isNull),
          ),
        ).called(1);
      },
    );
  });
}
