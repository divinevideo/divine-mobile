// ABOUTME: Tests for VideoEventPublisher.republishWithSubtitles method.
// ABOUTME: Verifies correct tag construction and event publishing.

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

// Fake fallback values for mocktail any() matchers
class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

const _deepEquals = DeepCollectionEquality();

/// Checks whether [tags] contains a tag that deeply equals [expected].
bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((t) => _deepEquals.equals(t, expected));
}

void main() {
  late _MockUploadManager mockUploadManager;
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockVideoEventService mockVideoEventService;
  late _MockPersonalEventCacheService mockPersonalEventCache;
  late VideoEventPublisher publisher;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockUploadManager = _MockUploadManager();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockVideoEventService = _MockVideoEventService();
    mockPersonalEventCache = _MockPersonalEventCacheService();

    publisher = VideoEventPublisher(
      uploadManager: mockUploadManager,
      nostrService: mockNostrClient,
      authService: mockAuthService,
      personalEventCache: mockPersonalEventCache,
      videoEventService: mockVideoEventService,
    );

    // Stub NostrClient properties used by publishViaWebSocket
    when(() => mockNostrClient.isInitialized).thenReturn(true);
    when(() => mockNostrClient.configuredRelayCount).thenReturn(1);
    when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
    when(
      () => mockNostrClient.configuredRelays,
    ).thenReturn(['wss://relay.divine.video']);
    when(
      () => mockNostrClient.connectedRelays,
    ).thenReturn(['wss://relay.divine.video']);
    when(() => mockPersonalEventCache.getEventById(any())).thenReturn(null);
    when(() => mockPersonalEventCache.cacheUserEvent(any())).thenReturn(null);
    when(() => mockVideoEventService.updateVideoEvent(any())).thenReturn(null);
  });

  group('republishWithSubtitles', () {
    final testPubkey = 'a' * 64;
    final existingTags = <List<String>>[
      ['d', 'test-vine-id'],
      ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
      ['title', 'Test Video'],
      ['published_at', '1700000000'],
      ['t', 'test'],
      Nip89ClientTag.tag,
    ];
    const rawEventCreatedAt = 4102444800;

    final existingEvent = VideoEvent(
      id: 'b' * 64,
      pubkey: testPubkey,
      createdAt: 1700000000,
      content: 'Test video description',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      title: 'Test Video',
      vineId: 'test-vine-id',
      nostrEventTags: existingTags,
      eventCreatedAt: rawEventCreatedAt,
    );

    final textTrackRef = '34236:$testPubkey:subtitle-event-id';

    Event createSignedEvent(List<List<String>> tags) {
      return Event(
        testPubkey,
        NIP71VideoKinds.getPreferredAddressableKind(),
        tags,
        existingEvent.content,
        createdAt: 1700000001,
      );
    }

    test(
      'creates event with original tags plus text-track tag and publishes',
      () async {
        late List<List<String>> capturedTags;

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
          return createSignedEvent(capturedTags);
        });

        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.first as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        when(
          () => mockVideoEventService.updateVideoEvent(any()),
        ).thenReturn(null);

        final result = await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        expect(result, isA<VideoEvent>());

        // Verify createAndSignEvent was called with correct kind
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: NIP71VideoKinds.getPreferredAddressableKind(),
            content: existingEvent.content,
            tags: any(named: 'tags'),
            createdAt: rawEventCreatedAt + 1,
          ),
        ).called(1);

        // Verify all original tags are preserved
        for (final tag in existingTags) {
          expect(
            _containsTag(capturedTags, tag),
            isTrue,
            reason: 'Missing original tag: $tag',
          );
        }

        // Verify text-track tag was added
        expect(
          _containsTag(capturedTags, [
            'text-track',
            textTrackRef,
            'wss://relay.divine.video',
            'captions',
            'en',
          ]),
          isTrue,
          reason: 'Missing text-track tag',
        );
      },
    );

    test('preserves all original tags from the event', () async {
      late List<List<String>> capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(capturedTags);
      });

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      // Every original tag should be present
      for (final tag in existingTags) {
        expect(
          _containsTag(capturedTags, tag),
          isTrue,
          reason: 'Missing original tag: $tag',
        );
      }
    });

    test('uses correct kind 34236', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => createSignedEvent(existingTags));

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      verify(
        () => mockAuthService.createAndSignEvent(
          kind: 34236,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: rawEventCreatedAt + 1,
        ),
      ).called(1);
    });

    test('publishes signed event to relays', () async {
      final signedEvent = createSignedEvent(existingTags);

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => signedEvent);

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      verify(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
    });

    test('returns null when signing fails', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => null);

      final result = await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      expect(result, isNull);
      verifyNever(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      );
    });

    test('does not duplicate text-track tag if one already exists', () async {
      final existingTextTrackTag = [
        'text-track',
        'old-ref',
        'wss://relay.divine.video',
        'captions',
        'en',
      ];
      final tagsWithTextTrack = <List<String>>[
        ...existingTags,
        existingTextTrackTag,
      ];

      final eventWithTextTrack = VideoEvent(
        id: 'c' * 64,
        pubkey: testPubkey,
        createdAt: 1700000000,
        content: 'Test video description',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        title: 'Test Video',
        vineId: 'test-vine-id',
        nostrEventTags: tagsWithTextTrack,
        textTrackRef: 'old-ref',
      );

      late List<List<String>> capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(capturedTags);
      });

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: eventWithTextTrack,
        textTrackRef: textTrackRef,
      );

      // Count text-track tags - should be exactly 1
      final textTrackTags = capturedTags
          .where((t) => t.first == 'text-track')
          .toList();
      expect(
        textTrackTags,
        hasLength(1),
        reason: 'Should have exactly one text-track tag',
      );

      // The new text-track tag should replace the old one
      expect(textTrackTags.first[1], equals(textTrackRef));
    });

    test('uses custom language parameter', () async {
      late List<List<String>> capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(capturedTags);
      });

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
        textTrackLang: 'es',
      );

      expect(
        _containsTag(capturedTags, [
          'text-track',
          textTrackRef,
          'wss://relay.divine.video',
          'captions',
          'es',
        ]),
        isTrue,
        reason: 'Missing text-track tag with language es',
      );
    });

    test('updates local cache after relay confirms acceptance', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => createSignedEvent(existingTags));

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      verify(() => mockVideoEventService.updateVideoEvent(any())).called(1);
      verify(() => mockPersonalEventCache.cacheUserEvent(any())).called(1);
    });

    test(
      'recovers original tags from personal cache when event tags are empty',
      () async {
        final taglessEvent = existingEvent.copyWith(nostrEventTags: const []);
        final cachedEvent = Event(
          testPubkey,
          NIP71VideoKinds.getPreferredAddressableKind(),
          existingTags,
          existingEvent.content,
          createdAt: existingEvent.createdAt,
        );
        late List<List<String>> capturedTags;

        when(
          () => mockPersonalEventCache.getEventById(taglessEvent.id),
        ).thenReturn(cachedEvent);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
          return createSignedEvent(capturedTags);
        });
        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.first as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final result = await publisher.republishWithSubtitles(
          existingEvent: taglessEvent,
          textTrackRef: textTrackRef,
        );

        expect(result, isA<VideoEvent>());
        expect(_containsTag(capturedTags, ['d', 'test-vine-id']), isTrue);
        expect(
          _containsTag(capturedTags, [
            'imeta',
            'url https://cdn.example.com/video.mp4',
            'm video/mp4',
          ]),
          isTrue,
        );
      },
    );

    test(
      'returns null without publishing when original d tag cannot be recovered',
      () async {
        final taglessEvent = existingEvent.copyWith(nostrEventTags: const []);

        final result = await publisher.republishWithSubtitles(
          existingEvent: taglessEvent,
          textTrackRef: textTrackRef,
        );

        expect(result, isNull);
        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        );
        verifyNever(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      },
    );

    test('does not update local cache when relay rejects republish', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => createSignedEvent(existingTags));

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const [],
          rejectedBy: const {
            'wss://relay.divine.video': 'blocked: event rejected by policy',
          },
          noResponseFrom: const [],
        ),
      );

      final result = await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      expect(result, isNull);
      verifyNever(() => mockVideoEventService.updateVideoEvent(any()));
    });

    test(
      'publishSubtitleEvent signs a 39307 with d=subtitles:<vineId>',
      () async {
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final tags = invocation.namedArguments[#tags] as List<List<String>>;
          return createSignedEvent(tags);
        });

        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.first as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final ref = await publisher.publishSubtitleEvent(
          video: existingEvent,
          vttContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
          blossomUrl: 'https://media.divine.video/abc123',
        );

        expect(ref, '39307:$testPubkey:subtitles:test-vine-id');

        final captured = verify(
          () => mockAuthService.createAndSignEvent(
            kind: captureAny(named: 'kind'),
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        expect(captured[0], equals(39307));
        final tags = (captured[2] as List).cast<List<String>>();
        expect(
          _containsTag(tags, ['d', 'subtitles:test-vine-id']),
          isTrue,
          reason: 'Missing d=subtitles:test-vine-id tag',
        );
        expect(
          _containsTag(tags, ['url', 'https://media.divine.video/abc123']),
          isTrue,
          reason: 'Missing url tag',
        );
        expect(
          _containsTag(tags, ['m', 'text/vtt']),
          isTrue,
          reason: 'Missing m=text/vtt tag',
        );
        expect(
          _containsTag(tags, ['l', 'en']),
          isTrue,
          reason: 'Missing default l=en language tag',
        );
      },
    );

    test('republishWithSubtitles emits one text-track tag per ref', () async {
      late List<List<String>> capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(capturedTags);
      });

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: 'https://media.divine.video/abc123',
        extraTextTrackRefs: ['39307:$testPubkey:subtitles:test-vine-id'],
      );

      final captured =
          verify(
                () => mockAuthService.createAndSignEvent(
                  kind: any(named: 'kind'),
                  content: any(named: 'content'),
                  tags: captureAny(named: 'tags'),
                  createdAt: any(named: 'createdAt'),
                ),
              ).captured.single
              as List;
      final tags = captured.cast<List<String>>();
      final trackTags = tags.where((t) => t.first == 'text-track').toList();
      expect(trackTags, hasLength(2));
      expect(trackTags[0][1], equals('https://media.divine.video/abc123'));
      expect(
        trackTags[1][1],
        equals('39307:$testPubkey:subtitles:test-vine-id'),
      );
    });

    test('publishSubtitleEvent returns null when vineId is empty', () async {
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

      final videoWithoutVineId = VideoEvent(
        id: 'd' * 64,
        pubkey: testPubkey,
        createdAt: 1700000000,
        content: 'Test video description',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        title: 'Test Video',
      );

      final ref = await publisher.publishSubtitleEvent(
        video: videoWithoutVineId,
        vttContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
        blossomUrl: 'https://media.divine.video/abc123',
      );

      expect(ref, isNull);
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test('publishSubtitleEvent returns null when publish fails', () async {
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(tags);
      });

      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const [],
          rejectedBy: const {
            'wss://relay.divine.video': 'blocked: event rejected by policy',
          },
          noResponseFrom: const [],
        ),
      );

      final ref = await publisher.publishSubtitleEvent(
        video: existingEvent,
        vttContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
        blossomUrl: 'https://media.divine.video/abc123',
      );

      expect(ref, isNull);
    });

    test(
      'publishSubtitleTrack publishes a 39307 without a published video',
      () async {
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final tags = invocation.namedArguments[#tags] as List<List<String>>;
          return createSignedEvent(tags);
        });

        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.first as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final ref = await publisher.publishSubtitleTrack(
          vineId: 'fresh-vine-id',
          vttContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
          blossomUrl: 'https://media.divine.video/def456',
          lang: 'de',
        );

        expect(ref, '39307:$testPubkey:subtitles:fresh-vine-id');

        final captured = verify(
          () => mockAuthService.createAndSignEvent(
            kind: captureAny(named: 'kind'),
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        final tags = (captured[2] as List).cast<List<String>>();
        expect(_containsTag(tags, ['d', 'subtitles:fresh-vine-id']), isTrue);
        expect(_containsTag(tags, ['l', 'de']), isTrue);
      },
    );
  });
}
