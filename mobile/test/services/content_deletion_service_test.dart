// ABOUTME: Tests for NIP-09 content deletion service
// ABOUTME: Verifies kind 5 event creation, relay OK confirmation, and
// ABOUTME: local history bookkeeping.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(const Duration(seconds: 1));
  });

  group(ContentDeletionService, () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late _MockProfileStatsDao mockProfileStatsDao;
    late ContentDeletionService service;
    late SharedPreferences prefs;
    late String testPublicKey;

    Event createTestEvent({
      required String pubkey,
      required int kind,
      required List<List<String>> tags,
      required String content,
    }) {
      final event = Event(
        pubkey,
        kind,
        tags,
        content,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'test_event_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return event;
    }

    PublishOutcome accepted(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const ['wss://relay.test'],
      rejectedBy: const {},
      noResponseFrom: const [],
    );

    PublishOutcome rejected(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const [],
      rejectedBy: const {'wss://relay.test': 'blocked: policy'},
      noResponseFrom: const [],
    );

    PublishOutcome timedOut(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const [],
      rejectedBy: const {},
      noResponseFrom: const ['wss://relay.test'],
    );

    PublishOutcome rejectedAndTimedOut(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const [],
      rejectedBy: const {'wss://relay.test': 'blocked: policy'},
      noResponseFrom: const ['wss://backup-relay.test'],
    );

    /// One relay took the deletion and another refused it, so the video is
    /// gone from part of the network and still live on the rest.
    PublishOutcome partiallyAccepted(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const ['wss://relay.test'],
      rejectedBy: const {'wss://backup-relay.test': 'blocked: policy'},
      noResponseFrom: const [],
    );

    /// One relay took the deletion and a second target was never reached.
    PublishOutcome acceptedWithUnreachableTarget(String eventId) =>
        PublishOutcome(
          eventId: eventId,
          acceptedBy: const ['wss://relay.test'],
          rejectedBy: const {},
          noResponseFrom: const [],
          unreachableTargets: const ['wss://offline-relay.test'],
        );

    test('parseDeletionHistory reads persisted deletion records', () {
      final deletedAt = DateTime.utc(2026);
      final historyJson = jsonEncode([
        {
          'deleteEventId': 'delete-event-id',
          'originalEventId': 'original-event-id',
          'addressableId': '34236:$testPublicKey:shared-vine-id',
          'reason': 'Personal choice',
          'deletedAt': deletedAt.toIso8601String(),
          'additionalContext': 'Quick delete: personalChoice',
        },
      ]);

      final history = ContentDeletionService.parseDeletionHistory(historyJson);

      expect(history, hasLength(1));
      expect(history.single.deleteEventId, 'delete-event-id');
      expect(history.single.originalEventId, 'original-event-id');
      expect(
        history.single.addressableId,
        '34236:$testPublicKey:shared-vine-id',
      );
      expect(history.single.deletedAt, deletedAt);
      expect(history.single.additionalContext, 'Quick delete: personalChoice');
    });

    setUp(() async {
      final testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();
      mockProfileStatsDao = _MockProfileStatsDao();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockNostrService.defaultRelayUrl,
      ).thenReturn('wss://relay.example.com');
      when(
        () => mockProfileStatsDao.deleteStats(any()),
      ).thenAnswer((_) async => 1);

      service = ContentDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
        profileStatsDao: mockProfileStatsDao,
      );

      await service.initialize();
    });

    VideoEvent createTestVideoEvent(
      String pubkey, {
      String? dTag = 'test-vine-id',
    }) {
      final event = Event(
        pubkey,
        34236,
        [
          ['title', 'Test Video'],
          if (dTag != null) ['d', dTag],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'test_event_id_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return VideoEvent.fromNostrEvent(event);
    }

    VideoEvent createRestShapedVideoEvent(String pubkey) {
      return VideoEvent(
        id: 'rest_event_id',
        pubkey: pubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        vineId: 'rest-vine-id',
        addressableDTag: 'rest-vine-id',
      );
    }

    VideoEvent createRawDTagVideoEvent(
      String pubkey, {
      String dTag = 'raw-d-tag',
    }) {
      return VideoEvent(
        id: 'raw_d_tag_event_id',
        pubkey: pubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        rawTags: {'d': dTag},
        addressableDTag: dTag,
      );
    }

    group('deleteContent', () {
      test(
        'creates a NIP-09 kind 5 delete event and saves it to history when at '
        'least one relay confirms',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', video.addressableId!],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          final result = await service.deleteContent(
            video: video,
            reason: 'Personal choice',
          );

          expect(result.success, isTrue);
          expect(result.acceptance, equals(DeleteAcceptance.everyRelay));
          expect(result.deleteEventId, equals(deleteEvent.id));
          expect(result.deleteEvent, same(deleteEvent));
          expect(service.hasBeenDeleted(video.id), isTrue);
          expect(
            service.hasBeenDeleted(
              'replacement-event-id',
              addressableId: video.addressableId,
            ),
            isTrue,
          );

          verify(
            () => mockAuthService.createAndSignEvent(
              kind: 5,
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).called(1);
          verify(
            () => mockProfileStatsDao.deleteStats(testPublicKey),
          ).called(1);
        },
      );

      test(
        'does not fail a confirmed delete when profile stats invalidation fails',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', video.addressableId!],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockProfileStatsDao.deleteStats(testPublicKey),
          ).thenThrow(Exception('database unavailable'));
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          final result = await service.deleteContent(
            video: video,
            reason: 'Personal choice',
          );

          expect(result.success, isTrue);
          expect(service.hasBeenDeleted(video.id), isTrue);
          verify(
            () => mockProfileStatsDao.deleteStats(testPublicKey),
          ).called(1);
        },
      );

      test(
        'fails with relayRejected and does NOT save locally when every relay '
        'rejects the publish',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', video.addressableId!],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => rejected(deleteEvent.id));

          final result = await service.deleteContent(
            video: video,
            reason: 'Personal choice',
          );

          expect(result.success, isFalse);
          expect(result.failureKind, equals(DeleteFailureKind.relayRejected));
          expect(result.error, contains('blocked: policy'));
          expect(service.hasBeenDeleted(video.id), isFalse);
          expect(service.deletionHistory, isEmpty);
          verifyNever(() => mockProfileStatsDao.deleteStats(any()));
        },
      );

      test('classifies an explicit account restriction separately', () async {
        final video = createTestVideoEvent(testPublicKey);
        final deleteEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', video.id],
            ['a', video.addressableId!],
            ['k', '34236'],
          ],
          content: 'CONTENT DELETION',
        );
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => deleteEvent);
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: deleteEvent.id,
            acceptedBy: const [],
            rejectedBy: const {
              'wss://relay.example.com': 'blocked: pubkey is suspended',
            },
            noResponseFrom: const [],
          ),
        );

        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        expect(result.failureKind, DeleteFailureKind.accountRestricted);
        expect(service.deletionHistory, isEmpty);
      });

      test('fails with relayNoResponse and does NOT save locally when no relay '
          'answers before timeout', () async {
        final video = createTestVideoEvent(testPublicKey);
        final deleteEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', video.id],
            ['a', video.addressableId!],
            ['k', '34236'],
          ],
          content: 'CONTENT DELETION',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => timedOut(deleteEvent.id));

        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        expect(result.success, isFalse);
        expect(result.failureKind, equals(DeleteFailureKind.relayNoResponse));
        expect(service.hasBeenDeleted(video.id), isFalse);
        expect(service.deletionHistory, isEmpty);
      });

      test(
        'fails with relayRejected when some relays reject and others time out',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', video.addressableId!],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => rejectedAndTimedOut(deleteEvent.id));

          final result = await service.deleteContent(
            video: video,
            reason: 'Personal choice',
          );

          expect(result.success, isFalse);
          expect(result.failureKind, equals(DeleteFailureKind.relayRejected));
          expect(result.error, contains('blocked: policy'));
          expect(service.hasBeenDeleted(video.id), isFalse);
          expect(service.deletionHistory, isEmpty);
        },
      );

      test('saves locally and reports someRelays when one relay accepts and '
          'another rejects', () async {
        final video = createTestVideoEvent(testPublicKey);
        final deleteEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', video.id],
            ['a', video.addressableId!],
            ['k', '34236'],
          ],
          content: 'CONTENT DELETION',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => partiallyAccepted(deleteEvent.id));

        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        // The tombstone exists on a relay, so the video leaves this device's
        // library. Retrying would only re-ask the relay that refused, which
        // answers the same way.
        expect(result.success, isTrue);
        expect(result.acceptance, equals(DeleteAcceptance.someRelays));
        expect(service.hasBeenDeleted(video.id), isTrue);
        expect(service.deletionHistory, hasLength(1));
        verify(() => mockProfileStatsDao.deleteStats(testPublicKey)).called(1);
      });

      test(
        'saves locally and reports someRelays when a targeted relay was never '
        'reached',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', video.addressableId!],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async => acceptedWithUnreachableTarget(deleteEvent.id),
          );

          final result = await service.deleteContent(
            video: video,
            reason: 'Personal choice',
          );

          // The unreachable relay is the case that used to strand the user:
          // a pool member the client never connected to stays in the target
          // set on every retry, so gating on all-of-them made the video
          // permanently undeletable.
          expect(result.success, isTrue);
          expect(result.acceptance, equals(DeleteAcceptance.someRelays));
          expect(service.hasBeenDeleted(video.id), isTrue);
        },
      );

      test(
        'includes e, a, and k tags for addressable videos per NIP-09',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', video.addressableId!],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          await service.deleteContent(video: video, reason: 'Personal choice');

          final captured = verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured.first as List<List<String>>;
          expect(tags, contains(equals(['e', video.id])));
          expect(tags, contains(equals(['a', video.addressableId])));
          final kTag = tags.firstWhere(
            (tag) => tag.isNotEmpty && tag[0] == 'k',
            orElse: () => <String>[],
          );

          expect(kTag, isNotEmpty);
          expect(kTag[1], equals('34236'));
        },
      );

      test(
        'does not include synthetic a tag when the video has no real d tag',
        () async {
          final video = createTestVideoEvent(testPublicKey, dTag: null);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          await service.deleteContent(video: video, reason: 'Personal choice');

          final captured = verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured.first as List<List<String>>;
          expect(tags, contains(equals(['e', video.id])));
          expect(tags.any((tag) => tag.isNotEmpty && tag[0] == 'a'), isFalse);
          expect(tags, contains(equals(['k', '34236'])));
        },
      );

      test(
        'does not include a tag when vine_id exists without a real d tag',
        () async {
          final event = Event(
            testPublicKey,
            34236,
            [
              ['title', 'Test Video'],
              ['vine_id', 'legacy-vine-id'],
              ['url', 'https://example.com/video.mp4'],
            ],
            'Test video content',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          event.id = 'vine_id_only_event_id';
          event.sig = 'test_signature';
          final video = VideoEvent.fromNostrEvent(event);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          await service.deleteContent(video: video, reason: 'Personal choice');

          final captured = verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured.first as List<List<String>>;
          expect(video.vineId, equals('legacy-vine-id'));
          expect(video.addressableDTag, isNull);
          expect(tags, contains(equals(['e', video.id])));
          expect(tags.any((tag) => tag.isNotEmpty && tag[0] == 'a'), isFalse);
          expect(tags, contains(equals(['k', '34236'])));
        },
      );

      test(
        'includes a tag for REST-shaped videos with a real vine id',
        () async {
          final video = createRestShapedVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', video.addressableId!],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          await service.deleteContent(video: video, reason: 'Personal choice');

          final captured = verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured.first as List<List<String>>;
          expect(tags, contains(equals(['e', video.id])));
          expect(tags, contains(equals(['a', video.addressableId])));
          expect(tags, contains(equals(['k', '34236'])));
        },
      );

      test(
        'includes a tag when the raw d tag is present but vineId is null',
        () async {
          const dTag = 'raw:d:tag';
          final video = createRawDTagVideoEvent(testPublicKey, dTag: dTag);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['a', '34236:$testPublicKey:$dTag'],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          await service.deleteContent(video: video, reason: 'Personal choice');

          final captured = verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured.first as List<List<String>>;
          expect(tags, contains(equals(['e', video.id])));
          expect(tags, contains(equals(['a', '34236:$testPublicKey:$dTag'])));
          expect(tags, contains(equals(['k', '34236'])));
          expect(
            service.deletionHistory.single.addressableId,
            '34236:$testPublicKey:$dTag',
          );
        },
      );

      test('refuses with notOwner when deleting another user content before '
          'publishing', () async {
        final otherUserPubkey = getPublicKey(generatePrivateKey());
        final video = createTestVideoEvent(otherUserPubkey);

        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        expect(result.success, isFalse);
        expect(result.failureKind, equals(DeleteFailureKind.notOwner));

        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        verifyNever(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test(
        'fails with notInitialized when the service has not been initialized',
        () async {
          final uninitializedService = ContentDeletionService(
            nostrService: mockNostrService,
            authService: mockAuthService,
            prefs: prefs,
          );

          final video = createTestVideoEvent(testPublicKey);

          final result = await uninitializedService.deleteContent(
            video: video,
            reason: 'Test reason',
          );

          expect(result.success, isFalse);
          expect(result.failureKind, equals(DeleteFailureKind.notInitialized));
        },
      );
    });

    group('quickDelete', () {
      test('maps enum reason to the expected reason text', () async {
        final video = createTestVideoEvent(testPublicKey);
        final deleteEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', video.id],
            ['a', video.addressableId!],
            ['k', '34236'],
          ],
          content: 'CONTENT DELETION',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => accepted(deleteEvent.id));

        final result = await service.quickDelete(
          video: video,
          reason: DeleteReason.privacy,
        );

        expect(result.success, isTrue);
        final deletion = service.getDeletionForEvent(video.id);
        expect(deletion, isNotNull);
        expect(deletion!.reason, contains('Privacy concerns'));
      });
    });

    group('hasBeenDeleted', () {
      test('returns false for an id that was never deleted', () {
        expect(service.hasBeenDeleted('non_existent_event_id'), isFalse);
      });
    });

    group('getDeletionForEvent', () {
      test('returns null for an id that was never deleted', () {
        expect(service.getDeletionForEvent('non_existent_event_id'), isNull);
      });
    });
  });
}
