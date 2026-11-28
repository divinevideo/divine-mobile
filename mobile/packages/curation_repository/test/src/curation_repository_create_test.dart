// ABOUTME: Tests for CurationRepository.createCurationSet() method
// ABOUTME: Validates creation and publishing of NIP-51 video curation
// ABOUTME: sets to Nostr

import 'package:curation_repository/curation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'
    'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

void main() {
  group('CurationRepository.createCurationSet()', () {
    late _MockNostrClient mockNostrService;
    late _MockVideoEventCache mockVideoEventCache;
    late _MockLikesRepository mockLikesRepository;
    late _MockNostrSigner mockSigner;
    late CurationRepository curationRepository;

    setUpAll(() {
      registerFallbackValue(
        Event(_testPubkey, 30005, <List<String>>[], ''),
      );
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockVideoEventCache = _MockVideoEventCache();
      mockLikesRepository = _MockLikesRepository();
      mockSigner = _MockNostrSigner();

      // Setup default mock behaviors for constructor
      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => const LikeCounts(counts: {}));
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(
        () => mockSigner.getPublicKey(),
      ).thenAnswer((_) async => _testPubkey);
      when(
        () => mockSigner.signEvent(any()),
      ).thenAnswer((_) async => null);

      curationRepository = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [],
      );
    });

    test(
      'returns true when event is signed and published '
      'successfully',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        )..id = 'signed_event_id';

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn(['wss://relay']);

        final result = await curationRepository.createCurationSet(
          id: 'test_list',
          title: 'Test Curation List',
          videoIds: ['video1', 'video2', 'video3'],
          description: 'A test curation set',
          imageUrl: 'https://example.com/image.jpg',
        );

        expect(result, isTrue);
        verify(
          () => mockNostrService.publishEvent(any()),
        ).called(1);
      },
    );

    test(
      'builds event with kind 30005',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        )..id = 'event_id';

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
        when(() => mockNostrService.connectedRelays).thenReturn([]);

        await curationRepository.createCurationSet(
          id: 'test',
          title: 'Test',
          videoIds: ['video1'],
        );

        final captured = verify(
          () => mockSigner.signEvent(captureAny()),
        ).captured;

        final event = captured.single as Event;
        expect(event.kind, 30005);
      },
    );

    test('creates event with correct content tags before publish', () async {
      final signedEvent = Event(
        _testPubkey,
        30005,
        <List<String>>[],
        'test',
      )..id = 'event_id';

      when(
        () => mockSigner.signEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
      when(() => mockNostrService.connectedRelays).thenReturn([]);

      await curationRepository.createCurationSet(
        id: 'my_list',
        title: 'My List',
        videoIds: ['vid1', 'vid2'],
        description: 'Test description',
        imageUrl: 'https://example.com/img.jpg',
      );

      final captured = verify(
        () => mockSigner.signEvent(captureAny()),
      ).captured;

      final event = captured.single as Event;
      final tags = event.tags;

      // Verify d tag (identifier)
      final dTag = tags.firstWhere((tag) => tag[0] == 'd');
      expect(dTag[1], 'my_list');

      // Verify title tag
      final titleTag = tags.firstWhere((tag) => tag[0] == 'title');
      expect(titleTag[1], 'My List');

      // Verify description tag
      final descTag = tags.firstWhere(
        (tag) => tag[0] == 'description',
      );
      expect(descTag[1], 'Test description');

      // Verify image tag
      final imageTag = tags.firstWhere((tag) => tag[0] == 'image');
      expect(imageTag[1], 'https://example.com/img.jpg');

      // Client attribution is injected centrally during publish, not
      // in repository-specific tag construction.
      expect(tags.where((tag) => tag[0] == 'client'), isEmpty);

      // Verify video references as 'e' tags
      final eTags = tags.where((tag) => tag[0] == 'e').toList();
      expect(eTags, hasLength(2));
      expect(eTags[0][1], 'vid1');
      expect(eTags[1][1], 'vid2');
    });

    test('returns false when broadcast fails', () async {
      final signedEvent = Event(
        _testPubkey,
        30005,
        <List<String>>[],
        'test',
      );

      when(
        () => mockSigner.signEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => const PublishFailed());

      final result = await curationRepository.createCurationSet(
        id: 'test_list',
        title: 'Test List',
        videoIds: ['video1'],
      );

      expect(result, isFalse);
    });

    test(
      'returns false when event signing fails',
      () async {
        // signEvent returns null (signing failure)
        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => null);

        final result = await curationRepository.createCurationSet(
          id: 'test_list',
          title: 'Test List',
          videoIds: ['video1'],
        );

        expect(result, isFalse);
        verifyNever(
          () => mockNostrService.publishEvent(any()),
        );
      },
    );

    test(
      'returns false when publish throws exception',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        );

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenThrow(Exception('Network error'));

        final result = await curationRepository.createCurationSet(
          id: 'error_list',
          title: 'Error Test',
          videoIds: ['video1'],
        );

        expect(result, isFalse);
      },
    );

    test(
      'creates curation set with empty video list',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        )..id = 'event_id';

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
        when(() => mockNostrService.connectedRelays).thenReturn([]);

        final result = await curationRepository.createCurationSet(
          id: 'empty_list',
          title: 'Empty List',
          videoIds: [],
        );

        expect(result, isTrue);

        // Verify no 'e' tags were added
        final captured = verify(
          () => mockSigner.signEvent(captureAny()),
        ).captured;

        final event = captured.single as Event;
        final eTags = event.tags.where((tag) => tag[0] == 'e').toList();
        expect(eTags, isEmpty);
      },
    );

    test(
      'creates curation set with minimal parameters',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        )..id = 'event_id';

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
        when(() => mockNostrService.connectedRelays).thenReturn([]);

        final result = await curationRepository.createCurationSet(
          id: 'minimal',
          title: 'Minimal',
          videoIds: ['video1'],
        );

        expect(result, isTrue);

        // Verify no description or image tags
        final captured = verify(
          () => mockSigner.signEvent(captureAny()),
        ).captured;

        final event = captured.single as Event;
        final descTags = event.tags.where((tag) => tag[0] == 'description');
        final imageTags = event.tags.where((tag) => tag[0] == 'image');
        expect(descTags, isEmpty);
        expect(imageTags, isEmpty);
      },
    );

    test(
      'updates publish status on successful publish',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        )..id = 'published_event_id';

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn(['wss://relay']);

        await curationRepository.createCurationSet(
          id: 'status_test',
          title: 'Status Test',
          videoIds: ['video1'],
        );

        final status = curationRepository.getCurationPublishStatus(
          'status_test',
        );
        expect(status.isPublished, isTrue);
        expect(status.isPublishing, isFalse);
        expect(
          status.publishedEventId,
          'published_event_id',
        );
      },
    );

    test(
      'updates publish status on failed publish',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        );

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        await curationRepository.createCurationSet(
          id: 'fail_status',
          title: 'Fail Status Test',
          videoIds: ['video1'],
        );

        final status = curationRepository.getCurationPublishStatus(
          'fail_status',
        );
        expect(status.isPublished, isFalse);
        expect(status.isPublishing, isFalse);
        expect(status.failedAttempts, 1);
      },
    );

    test(
      'uses content from description or title',
      () async {
        final signedEvent = Event(
          _testPubkey,
          30005,
          <List<String>>[],
          'test',
        )..id = 'event_id';

        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
        when(() => mockNostrService.connectedRelays).thenReturn([]);

        // With description
        await curationRepository.createCurationSet(
          id: 'with_desc',
          title: 'Title',
          videoIds: ['video1'],
          description: 'My description',
        );

        final capturedWithDesc = verify(
          () => mockSigner.signEvent(captureAny()),
        ).captured;

        final eventWithDesc = capturedWithDesc.single as Event;
        expect(eventWithDesc.content, 'My description');

        // Without description - uses title
        reset(mockSigner);
        when(
          () => mockSigner.getPublicKey(),
        ).thenAnswer((_) async => _testPubkey);
        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) async => signedEvent);

        await curationRepository.createCurationSet(
          id: 'no_desc',
          title: 'Just Title',
          videoIds: ['video1'],
        );

        final capturedNoDesc = verify(
          () => mockSigner.signEvent(captureAny()),
        ).captured;

        final eventNoDesc = capturedNoDesc.single as Event;
        expect(eventNoDesc.content, 'Just Title');
      },
    );
  });
}
