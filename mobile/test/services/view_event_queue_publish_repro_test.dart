// ABOUTME: End-to-end guard for the kind-22236 view-event outage in 1.0.19.
// ABOUTME: Sweeps a real queue row through the real publisher to the relay.

import 'dart:io';

import 'package:comments_repository/comments_repository.dart' show Comment;
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/models/view_event_drop_reason.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/screens/comments/comment_synthetic_video_event.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/view_event_retry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

const _userPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _videoPubkey =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

/// Signs whatever it is handed and reports every publish as delivered.
void _stubSigningAndPublishing(_MockAuthService auth, _MockNostrClient nostr) {
  when(() => auth.isAuthenticated).thenReturn(true);
  when(() => auth.canPublishNostrWritesNow).thenReturn(true);
  when(() => auth.currentPublicKeyHex).thenReturn(_userPubkey);
  when(() => nostr.connectedRelays).thenReturn([]);
  when(
    () => auth.createAndSignEvent(
      kind: any(named: 'kind'),
      content: any(named: 'content'),
      tags: any(named: 'tags'),
    ),
  ).thenAnswer(
    (invocation) async => Event.fromJson({
      'id': 'c' * 64,
      'pubkey': _userPubkey,
      'created_at': 1786587097,
      'kind': invocation.namedArguments[#kind] as int,
      'tags': invocation.namedArguments[#tags],
      'content': '',
      'sig': 'sig',
    }),
  );
  when(() => nostr.publishEvent(any())).thenAnswer(
    (invocation) async =>
        PublishSuccess(event: invocation.positionalArguments.first as Event),
  );
}

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

    const userPubkey = _userPubkey;
    const videoPubkey = _videoPubkey;

    setUp(() async {
      drops.clear();
      tempDir = Directory.systemTemp.createTempSync('view_event_queue_repro_');
      database = AppDatabase.test(
        NativeDatabase(File('${tempDir.path}/test.db')),
      );
      dao = database.pendingViewEventsDao;

      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();
      _stubSigningAndPublishing(mockAuth, mockNostr);

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
      )..setPublishingEnabled(true);

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
      )..setPublishingEnabled(true);

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
        )..setPublishingEnabled(true);

        await service.sweep();

        verifyNever(() => mockNostr.publishEvent(any()));
        expect(drops, [ViewEventDropReason.missingAddressableDTag]);
        expect(await dao.getById('queued-view-without-d'), isNull);
      },
    );
  });

  // The healthy path flushes a row the moment it is queued, so the published
  // version normally matches the recording build. A failed row can outlive an
  // app update, and before #9077 the sweep tagged it with whichever build
  // replayed it — crediting the release that restored publishing with a view
  // the previous release recorded.
  group('a queued view event keeps its recording version', () {
    late AppDatabase database;
    late PendingViewEventsDao dao;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late Directory tempDir;

    const recordingVersion = '1.0.22';
    const replayingVersion = '1.0.23';

    ViewEventPublisher publisherFor(String appVersion) => ViewEventPublisher(
      nostrService: mockNostr,
      authService: mockAuth,
      appVersion: appVersion,
    );

    Future<void> sweepWith(String appVersion) async {
      final service = ViewEventRetryService(
        viewEventPublisher: publisherFor(appVersion),
        pendingViewEventsDao: dao,
        userPubkey: _userPubkey,
        appForegroundStream: const Stream<bool>.empty(),
      )..setPublishingEnabled(true);
      await service.sweep();
    }

    Iterable<List<String>> versionTags(Event event) => event.tags
        .where((tag) => tag.first == 'version')
        .map((tag) => tag.cast<String>());

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync(
        'view_event_recording_version_',
      );
      database = AppDatabase.test(
        NativeDatabase(File('${tempDir.path}/test.db')),
      );
      dao = database.pendingViewEventsDao;

      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();
      _stubSigningAndPublishing(mockAuth, mockNostr);
    });

    tearDown(() async {
      await database.close();
      tempDir.deleteSync(recursive: true);
    });

    test(
      'replays with the version that recorded the view, not the one '
      'replaying it',
      () async {
        // The recording build queues the view. No flush is wired, which
        // stands in for a relay outage that lasts across the update.
        final recordingBuild = AnalyticsService(
          backgroundActivityManager: BackgroundActivityManager(),
          viewEventPublisher: publisherFor(recordingVersion),
          pendingViewEventsDao: dao,
        );
        addTearDown(recordingBuild.dispose);
        await recordingBuild.initialize();
        await recordingBuild.trackDetailedVideoViewWithUser(
          VideoEvent(
            id: 'a' * 64,
            pubkey: _videoPubkey,
            createdAt: 1786587000,
            content: '',
            timestamp: DateTime.utc(2026, 9, 12),
            vineId: 'vine-id-from-queue-row',
            addressableDTag: 'vine-id-from-queue-row',
            eventKind: NIP71VideoKinds.addressableShortVideo,
          ),
          userId: _userPubkey,
          source: 'mobile',
          eventType: 'view_start',
          sessionToken: 'mount-1',
          trafficSource: ViewTrafficSource.home,
        );
        final queued = await dao.getRetryableForUser(userPubkey: _userPubkey);
        expect(queued.single.appVersion, recordingVersion);

        await sweepWith(replayingVersion);

        final event =
            verify(() => mockNostr.publishEvent(captureAny())).captured.single
                as Event;
        expect(versionTags(event), [
          ['version', recordingVersion],
        ]);
        expect(await dao.getRetryableForUser(userPubkey: _userPubkey), isEmpty);
      },
    );

    test(
      'replays a row queued before the version column with no version tag',
      () async {
        // Nothing on a pre-v14 row says which build recorded it, and the
        // build replaying it is by construction a later one, so the replay
        // omits the tag; Funnelcake groups that with pre-version clients.
        await dao.enqueue(
          PendingViewEvent(
            id: 'queued-before-v14',
            videoId: 'a' * 64,
            videoPubkey: _videoPubkey,
            videoVineId: 'vine-id-from-queue-row',
            videoAddressableDTag: 'vine-id-from-queue-row',
            userPubkey: _userPubkey,
            watchDurationMs: 0,
            trafficSource: 'home',
            status: PendingViewEventStatus.pending,
            createdAt: DateTime.utc(2026, 9, 12),
            phase: 'start',
          ),
        );

        await sweepWith(replayingVersion);

        final event =
            verify(() => mockNostr.publishEvent(captureAny())).captured.single
                as Event;
        expect(versionTags(event), isEmpty);
        expect(await dao.getById('queued-before-v14'), isNull);
      },
    );
  });

  // A video opened from the comments sheet is played from a synthetic
  // VideoEvent built from the Comment. Before this guard a plain Kind 1111
  // video comment reached the publisher with no kind and no d tag, which it
  // read as a Divine Kind 34236 video that had lost its d tag and reported as
  // a structural defect, although a regular event has no address to count a
  // view under.
  group('a view of a video opened from the comments sheet', () {
    late AppDatabase database;
    late PendingViewEventsDao dao;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late Directory tempDir;
    late AnalyticsService analytics;
    final drops = <ViewEventDropReason>[];

    const commenterPubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';

    Comment videoComment({int? eventKind, String? addressableId}) => Comment(
      id: 'c' * 64,
      content: 'video comment',
      authorPubkey: commenterPubkey,
      createdAt: DateTime.utc(2026, 11, 13),
      rootEventId: 'a' * 64,
      rootAuthorPubkey: _videoPubkey,
      rootAddressableId: '34236:$_videoPubkey:root-video',
      eventKind: eventKind,
      addressableId: addressableId,
      videoUrl: 'https://media.divine.video/comment-video',
    );

    Future<void> trackStart(VideoEvent video) =>
        analytics.trackDetailedVideoViewWithUser(
          video,
          userId: _userPubkey,
          source: 'mobile',
          eventType: 'view_start',
          sessionToken: 'mount-1',
        );

    setUp(() async {
      drops.clear();
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync(
        'view_event_comment_video_',
      );
      database = AppDatabase.test(
        NativeDatabase(File('${tempDir.path}/test.db')),
      );
      dao = database.pendingViewEventsDao;

      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();
      _stubSigningAndPublishing(mockAuth, mockNostr);

      final publisher = ViewEventPublisher(
        nostrService: mockNostr,
        authService: mockAuth,
        appVersion: '1.0.29',
        onDrop: (reason, {required String videoId, required String method}) =>
            drops.add(reason),
      );
      // The immediate flush after enqueueing is the path the reports carry:
      // _enqueuePendingViewEvent -> ViewEventRetryService.sweep -> publish.
      final retryService = ViewEventRetryService(
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
        userPubkey: _userPubkey,
        appForegroundStream: const Stream<bool>.empty(),
      );
      analytics = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        viewEventPublisher: publisher,
        pendingViewEventsDao: dao,
        viewEventRetryService: retryService,
      );
      await analytics.initialize();
      retryService.setPublishingEnabled(true);
    });

    tearDown(() async {
      analytics.dispose();
      await database.close();
      tempDir.deleteSync(recursive: true);
    });

    test('does not report a plain Kind 1111 video comment as a video that '
        'lost its d tag', () async {
      await trackStart(
        videoComment(eventKind: EventKind.comment).toSyntheticVideoEvent(),
      );

      expect(
        drops,
        isNot(contains(ViewEventDropReason.missingAddressableDTag)),
        reason: 'a regular event has no address, which is not a defect',
      );
      expect(await dao.getRetryableForUser(userPubkey: _userPubkey), isEmpty);
      verifyNever(() => mockNostr.publishEvent(any()));
    });

    test(
      'does not report a comment row that arrived without its kind',
      () async {
        // Funnelcake's comment rows can omit the kind, which Comment keeps as
        // null; those rows are Kind 1111 comments.
        await trackStart(videoComment().toSyntheticVideoEvent());

        expect(
          drops,
          isNot(contains(ViewEventDropReason.missingAddressableDTag)),
        );
        expect(await dao.getRetryableForUser(userPubkey: _userPubkey), isEmpty);
        verifyNever(() => mockNostr.publishEvent(any()));
      },
    );

    test(
      'publishes a Kind 34236 video reply under its own coordinate',
      () async {
        const replyCoordinate = '34236:$commenterPubkey:reply-d-tag';

        await trackStart(
          videoComment(
            eventKind: EventKind.videoVertical,
            addressableId: replyCoordinate,
          ).toSyntheticVideoEvent(),
        );

        final event =
            verify(() => mockNostr.publishEvent(captureAny())).captured.single
                as Event;
        final aTag = event.tags.firstWhere((tag) => tag.first == 'a');
        expect(aTag[1], equals(replyCoordinate));
        expect(drops, isEmpty);
      },
    );
  });
}
