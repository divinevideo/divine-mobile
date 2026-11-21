// ABOUTME: Tests for VideoEventPublisher.republishWithSubtitles method.
// ABOUTME: Verifies tag construction, publishing, and that the republish is
// ABOUTME: built from the relays' newest revision (#11250).

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
import 'package:videos_repository/videos_repository.dart'
    show
        LatestVideoRevision,
        LatestVideoRevisionAbsent,
        LatestVideoRevisionFound,
        LatestVideoRevisionUnknown,
        VideosRepository;

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

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
  late _MockVideosRepository mockVideosRepository;
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
    mockVideosRepository = _MockVideosRepository();

    publisher = VideoEventPublisher(
      uploadManager: mockUploadManager,
      nostrService: mockNostrClient,
      authService: mockAuthService,
      personalEventCache: mockPersonalEventCache,
      videoEventService: mockVideoEventService,
      videosRepositoryGetter: () => mockVideosRepository,
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

    setUp(() {
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
    });

    void relaysAnswer(LatestVideoRevision revision) {
      when(
        () => mockVideosRepository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => revision);
    }

    /// Republishes [existingEvent] while the relays' newest revision is that
    /// same event, the common case.
    Future<VideoEvent?> republishMirrored({
      required VideoEvent existingEvent,
      required String textTrackRef,
      List<String> extraTextTrackRefs = const [],
      String textTrackLang = 'en',
    }) {
      relaysAnswer(
        LatestVideoRevisionFound(
          Event.fromJson({
            'id': existingEvent.id,
            'pubkey': existingEvent.pubkey,
            'created_at': existingEvent.nostrCreatedAt,
            'kind': existingEvent.eventKind ?? 34236,
            'tags': existingEvent.nostrEventTags,
            'content': existingEvent.content,
            'sig': '',
          }),
        ),
      );
      return publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
        extraTextTrackRefs: extraTextTrackRefs,
        textTrackLang: textTrackLang,
      );
    }

    Event createSignedEvent(
      List<List<String>> tags, {
      int kind = NIP71VideoKinds.addressableShortVideo,
    }) {
      return Event(
        testPubkey,
        kind,
        tags,
        existingEvent.content,
        createdAt: 1700000001,
      );
    }

    test('drops the original client tag before signing (#8176)', () async {
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

      await republishMirrored(
        existingEvent: existingEvent.copyWith(
          nostrEventTags: [...existingTags, Nip89ClientTag.tag],
        ),
        textTrackRef: textTrackRef,
      );

      expect(
        capturedTags.where((tag) => tag.isNotEmpty && tag.first == 'client'),
        isEmpty,
      );
      expect(_containsTag(capturedTags, ['d', 'test-vine-id']), isTrue);
    });

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

        final result = await republishMirrored(
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

      await republishMirrored(
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

      await republishMirrored(
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

      await republishMirrored(
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

      final result = await republishMirrored(
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

      await republishMirrored(
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

      await republishMirrored(
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

      await republishMirrored(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      verify(() => mockVideoEventService.updateVideoEvent(any())).called(1);
      verify(() => mockPersonalEventCache.cacheUserEvent(any())).called(1);
    });

    group('newest revision on the relays', () {
      late List<List<String>> capturedTags;
      late int capturedKind;
      late String capturedContent;
      late int capturedCreatedAt;

      setUp(() {
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
          capturedKind = invocation.namedArguments[#kind] as int;
          capturedContent = invocation.namedArguments[#content] as String;
          capturedCreatedAt = invocation.namedArguments[#createdAt] as int;
          return createSignedEvent(capturedTags, kind: capturedKind);
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
      });

      Event newest({
        List<List<String>> extraTags = const [],
        int kind = 34236,
        int createdAt = rawEventCreatedAt + 600,
        String content = 'Description from the other device',
      }) => Event.fromJson({
        'id': 'c' * 64,
        'pubkey': testPubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': [...existingTags, ...extraTags],
        'content': content,
        'sig': '',
      });

      test('reads the address of the video', () async {
        relaysAnswer(LatestVideoRevisionFound(newest()));

        await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        verify(
          () => mockVideosRepository.fetchLatestVideoRevision(
            '34236:$testPubkey:test-vine-id',
          ),
        ).called(1);
      });

      test('rebuilds from the newest revision, not the copy in hand', () async {
        relaysAnswer(
          LatestVideoRevisionFound(
            newest(
              extraTags: const [
                ['t', 'added-elsewhere'],
              ],
            ),
          ),
        );

        final result = await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        expect(result, isA<VideoEvent>());
        expect(_containsTag(capturedTags, ['t', 'added-elsewhere']), isTrue);
        expect(capturedContent, 'Description from the other device');
        expect(capturedCreatedAt, rawEventCreatedAt + 601);
      });

      test('rebuilds from the raw tags the relays hold when the copy in hand '
          'has none', () async {
        relaysAnswer(LatestVideoRevisionFound(newest()));

        final result = await publisher.republishWithSubtitles(
          existingEvent: existingEvent.copyWith(nostrEventTags: const []),
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
      });

      test('keeps a caption track in another language', () async {
        const spanish = [
          'text-track',
          'https://cdn.example.com/subs-es.vtt',
          'wss://relay.divine.video',
          'captions',
          'es',
        ];
        const oldEnglish = [
          'text-track',
          'https://cdn.example.com/subs-en-old.vtt',
          'wss://relay.divine.video',
          ' Captions ',
          'EN',
        ];
        relaysAnswer(
          LatestVideoRevisionFound(
            newest(extraTags: const [spanish, oldEnglish]),
          ),
        );

        await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        final firstTrack = capturedTags.firstWhere(
          (tag) => tag.first == 'text-track',
        );
        expect(firstTrack[1], textTrackRef);
        expect(firstTrack[4], 'en');
        expect(_containsTag(capturedTags, spanish), isTrue);
        expect(_containsTag(capturedTags, oldEnglish), isFalse);
        expect(
          _containsTag(capturedTags, [
            'text-track',
            textTrackRef,
            'wss://relay.divine.video',
            'captions',
            'en',
          ]),
          isTrue,
        );
      });

      test('drops the subtitle address from a kept track in another '
          'language', () async {
        // One 39307 address serves every language, so after this edit it
        // holds the English captions and no longer the Spanish ones.
        final address = '39307:$testPubkey:subtitles:test-vine-id';
        const spanishFile = [
          'text-track',
          'https://cdn.example.com/subs-es.vtt',
          'wss://relay.divine.video',
          'captions',
          'es',
        ];
        final spanishAddress = [
          'text-track',
          address,
          'wss://relay.divine.video',
          'captions',
          'es',
        ];
        relaysAnswer(
          LatestVideoRevisionFound(
            newest(extraTags: [spanishFile, spanishAddress]),
          ),
        );

        await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
          extraTextTrackRefs: [address],
        );

        expect(_containsTag(capturedTags, spanishFile), isTrue);
        expect(_containsTag(capturedTags, spanishAddress), isFalse);
        expect(
          capturedTags.where(
            (tag) => tag.first == 'text-track' && tag[1] == address,
          ),
          [
            [
              'text-track',
              address,
              'wss://relay.divine.video',
              'captions',
              'en',
            ],
          ],
        );
      });

      test('keeps a chapters track in the edited language', () async {
        const chapters = [
          'text-track',
          'https://cdn.example.com/chapters-en.vtt',
          'wss://relay.divine.video',
          'chapters',
          'en',
        ];
        relaysAnswer(
          LatestVideoRevisionFound(newest(extraTags: const [chapters])),
        );

        await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        expect(_containsTag(capturedTags, chapters), isTrue);
      });

      test('replaces an untagged caption track', () async {
        const untagged = ['text-track', 'https://cdn.example.com/subs.vtt'];
        relaysAnswer(
          LatestVideoRevisionFound(newest(extraTags: const [untagged])),
        );

        await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        expect(_containsTag(capturedTags, untagged), isFalse);
      });

      test('publishes under the address kind of the video', () async {
        relaysAnswer(LatestVideoRevisionFound(newest(kind: 34235)));

        final result = await publisher.republishWithSubtitles(
          existingEvent: existingEvent.copyWith(eventKind: 34235),
          textTrackRef: textTrackRef,
        );

        verify(
          () => mockVideosRepository.fetchLatestVideoRevision(
            '34235:$testPubkey:test-vine-id',
          ),
        ).called(1);
        expect(capturedKind, 34235);
        expect(result?.eventKind, 34235);
        verify(() => mockVideoEventService.updateVideoEvent(result!)).called(1);
      });

      for (final (name, revision) in [
        ('cannot tell', const LatestVideoRevisionUnknown()),
        ('hold none', const LatestVideoRevisionAbsent()),
      ]) {
        test('returns null without publishing when the relays $name what '
            'the newest revision is', () async {
          relaysAnswer(revision);

          final result = await publisher.republishWithSubtitles(
            existingEvent: existingEvent,
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
        });
      }

      test('returns null without publishing when the relays answer with a '
          'revision older than the one passed in', () async {
        relaysAnswer(
          LatestVideoRevisionFound(newest(createdAt: rawEventCreatedAt - 1)),
        );

        final result = await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
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
      });

      test('returns null for a video the account does not own', () async {
        when(() => mockAuthService.currentPublicKeyHex).thenReturn('f' * 64);
        relaysAnswer(LatestVideoRevisionFound(newest()));

        final result = await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        expect(result, isNull);
        verifyNever(
          () => mockVideosRepository.fetchLatestVideoRevision(any()),
        );
        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        );
      });
    });

    for (final parentWrite in [true, false]) {
      test(
        'rejects a mismatched signer for ${parentWrite ? 'video' : 'fallback'}',
        () async {
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((_) async => Event('f' * 64, 34236, [], 'Wrong author'));

          final result = parentWrite
              ? await republishMirrored(
                  existingEvent: existingEvent,
                  textTrackRef: textTrackRef,
                )
              : await publisher.publishSubtitleEvent(
                  video: existingEvent,
                  vttContent: 'WEBVTT',
                  blossomUrl: 'https://cdn.example.com/captions',
                );

          expect(result, isNull);
          verifyNever(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
          verifyNever(() => mockPersonalEventCache.cacheUserEvent(any()));
          verifyNever(() => mockVideoEventService.updateVideoEvent(any()));
        },
      );
    }

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

      final result = await republishMirrored(
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
            createdAt: any(named: 'createdAt'),
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
          video: existingEvent.copyWith(eventKind: 34235),
          vttContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
          blossomUrl: 'https://media.divine.video/abc123',
        );

        expect(ref, '39307:$testPubkey:subtitles:test-vine-id');

        final captured = verify(
          () => mockAuthService.createAndSignEvent(
            kind: captureAny(named: 'kind'),
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).captured;
        expect(captured[0], equals(39307));
        final tags = (captured[2] as List).cast<List<String>>();
        expect(tags, contains(equals(['a', '34235:$testPubkey:test-vine-id'])));
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

      await republishMirrored(
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

    test(
      "publishSubtitleEvent stamps the 39307 with the video's own timestamp",
      () async {
        // The republished video is stamped after every earlier revision, so
        // its subtitle event replaces any one those revisions referenced,
        // even when two saves land in the same second.
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer(
          (invocation) async => createSignedEvent(
            invocation.namedArguments[#tags] as List<List<String>>,
          ),
        );
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

        await publisher.publishSubtitleEvent(
          video: existingEvent,
          vttContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
          blossomUrl: 'https://media.divine.video/abc123',
        );

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: 39307,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: rawEventCreatedAt,
          ),
        ).called(1);
      },
    );

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
          createdAt: any(named: 'createdAt'),
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
