// ABOUTME: End-to-end guard for the kind-22236 view-event outage in 1.0.19.
// ABOUTME: Sweeps a real queue row through the real publisher to the relay.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/view_event_drop_reason.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/view_event_retry_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  // The retry service rebuilds a VideoEvent from a handful of stored columns.
  // Wiring the *real* publisher to that reconstruction is the only way to
  // catch a new required field silently emptying the queue — the pre-existing
  // suite mocks ViewEventPublisher, which is why #6722 shipped green.
  group('a queued view event survives the sweep', () {
    late AppDatabase database;
    late PendingViewEventsDao dao;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late ViewEventPublisher publisher;
    late Directory tempDir;
    final drops = <ViewEventDropReason>[];

    const userPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const videoPubkey =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    setUp(() async {
      drops.clear();
      tempDir = Directory.systemTemp.createTempSync('view_event_queue_repro_');
      database = AppDatabase.test(
        NativeDatabase(File('${tempDir.path}/test.db')),
      );
      dao = database.pendingViewEventsDao;

      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.canPublishNostrWritesNow).thenReturn(true);
      when(() => mockNostr.connectedRelays).thenReturn([]);
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => Event.fromJson({
          'id': 'c' * 64,
          'pubkey': userPubkey,
          'created_at': 1786587097,
          'kind': invocation.namedArguments[#kind] as int,
          'tags': invocation.namedArguments[#tags],
          'content': '',
          'sig': 'sig',
        }),
      );
      when(() => mockNostr.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      publisher = ViewEventPublisher(
        nostrService: mockNostr,
        authService: mockAuth,
        appVersion: '1.0.23',
        onDrop: (reason, {required String videoId, required String method}) =>
            drops.add(reason),
      );

      await dao.enqueue(
        PendingViewEvent(
          id: 'queued-view',
          videoId: 'a' * 64,
          videoPubkey: videoPubkey,
          videoVineId: 'vine-id-from-queue-row',
          videoAddressableDTag: 'vine-id-from-queue-row',
          userPubkey: userPubkey,
          watchDurationMs: 6000,
          totalDurationMs: 6000,
          loopCount: 1,
          trafficSource: 'home',
          status: PendingViewEventStatus.pending,
          createdAt: DateTime.utc(2026, 8, 12),
        ),
      );
    });

    tearDown(() async {
      await database.close();
      tempDir.deleteSync(recursive: true);
    });

    test('publishes a kind 22236 event and clears the row', () async {
      final service = ViewEventRetryService(
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
        userPubkey: userPubkey,
        appForegroundStream: const Stream<bool>.empty(),
      );

      await service.sweep();

      final published = verify(
        () => mockNostr.publishEvent(captureAny()),
      ).captured;
      expect(
        published,
        hasLength(1),
        reason: 'every queued view event must reach the relay',
      );
      expect((published.single as Event).kind, equals(viewEventKind));
      expect(
        drops,
        isEmpty,
        reason: 'a well-formed queue row must not be dropped',
      );
      expect(
        await dao.getById('queued-view'),
        isNull,
        reason: 'a delivered row is removed from the queue',
      );
    });

    test('carries the addressable a tag the relay indexes views by', () async {
      final service = ViewEventRetryService(
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
        userPubkey: userPubkey,
        appForegroundStream: const Stream<bool>.empty(),
      );

      await service.sweep();

      final event =
          verify(() => mockNostr.publishEvent(captureAny())).captured.single
              as Event;
      final aTag = event.tags.firstWhere((tag) => tag.first == 'a');
      expect(aTag[1], endsWith(':vine-id-from-queue-row'));
    });

    test(
      'drops a queued event-id fallback instead of fabricating an a tag',
      () async {
        await dao.deleteById('queued-view');
        await dao.enqueue(
          PendingViewEvent(
            id: 'queued-view-without-d',
            videoId: 'b' * 64,
            videoPubkey: videoPubkey,
            // vine id == video id is the event-id fallback shape, so the v4
            // backfill leaves the d tag null and there is nothing to address.
            videoVineId: 'b' * 64,
            userPubkey: userPubkey,
            watchDurationMs: 6000,
            totalDurationMs: 6000,
            loopCount: 1,
            trafficSource: 'home',
            status: PendingViewEventStatus.pending,
            createdAt: DateTime.utc(2026, 8, 12),
          ),
        );
        final service = ViewEventRetryService(
          viewEventPublisher: publisher,
          pendingViewEventsDao: dao,
          userPubkey: userPubkey,
          appForegroundStream: const Stream<bool>.empty(),
        );

        await service.sweep();

        verifyNever(() => mockNostr.publishEvent(any()));
        expect(drops, [ViewEventDropReason.missingAddressableDTag]);
        expect(await dao.getById('queued-view-without-d'), isNull);
      },
    );
  });
}
