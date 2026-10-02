import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Kind 1111 is the NIP-22 comment kind.
const int _commentKind = EventKind.comment;

/// Example kind for a video event (Kind 34236 for NIP-71).
const int _testRootEventKind = EventKind.videoVertical;

void main() {
  group('loadCommentsByAuthor', () {
    late _MockNostrClient mockNostrClient;
    late CommentsRepository repository;

    const testAuthorPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testRootEventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testRootAuthorPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      when(() => mockNostrClient.publicKey).thenReturn(testAuthorPubkey);
      repository = CommentsRepository(nostrClient: mockNostrClient);
    });

    test('returns empty list when no comments found', () async {
      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => []);

      final result = await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
      );

      expect(result, isEmpty);
    });

    test('queries text comments only by default', () async {
      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => []);

      await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
        limit: 25,
      );

      final captured = verify(
        () => mockNostrClient.queryEvents(captureAny()),
      ).captured;

      final filters = captured.first as List<Filter>;
      expect(filters, hasLength(1));
      expect(filters.first.kinds, equals(const [_commentKind]));
      expect(filters.first.authors, contains(testAuthorPubkey));
      expect(filters.first.limit, equals(25));
      expect(filters.first.until, isNull);
    });

    test('includes video replies when includeVideoReplies is true', () async {
      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => []);

      await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
        includeVideoReplies: true,
      );

      final captured = verify(
        () => mockNostrClient.queryEvents(captureAny()),
      ).captured;

      final filters = captured.first as List<Filter>;
      expect(filters.first.kinds, contains(_commentKind));
      expect(filters.first.kinds, contains(EventKind.videoVertical));
    });

    test('applies pagination cursor via until parameter', () async {
      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => []);

      final before = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
      await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
        before: before,
      );

      final captured = verify(
        () => mockNostrClient.queryEvents(captureAny()),
      ).captured;

      final filters = captured.first as List<Filter>;
      expect(filters.first.until, equals(1700000000));
    });

    test('returns text comments with correct fields', () async {
      final event = _createCommentEvent(
        id: 'comment1',
        content: 'Great video!',
        pubkey: testAuthorPubkey,
        rootEventId: testRootEventId,
        rootAuthorPubkey: testRootAuthorPubkey,
        rootEventKind: _testRootEventKind,
        createdAt: 1700000000,
      );

      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => [event]);

      final result = await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
        includeVideoReplies: true,
      );

      expect(result, hasLength(1));
      expect(result.first.content, equals('Great video!'));
      expect(result.first.authorPubkey, equals(testAuthorPubkey));
      expect(result.first.rootEventId, equals(testRootEventId));
      expect(result.first.hasVideo, isFalse);
    });

    test('returns video comments with imeta fields', () async {
      final event = _createCommentEvent(
        id: 'video_comment1',
        content: 'Check this out https://example.com/reply.mp4',
        pubkey: testAuthorPubkey,
        rootEventId: testRootEventId,
        rootAuthorPubkey: testRootAuthorPubkey,
        rootEventKind: _testRootEventKind,
        createdAt: 1700000000,
        imetaEntries: [
          'url https://example.com/reply.mp4',
          'm video/mp4',
          'dim 720x1280',
          'image https://example.com/thumb.jpg',
          'blurhash LEHV6nWB2yk8',
          'duration 6',
        ],
      );

      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => [event]);

      final result = await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
        includeVideoReplies: true,
      );

      expect(result, hasLength(1));
      expect(result.first.hasVideo, isTrue);
      expect(
        result.first.videoUrl,
        equals('https://example.com/reply.mp4'),
      );
      expect(
        result.first.thumbnailUrl,
        equals('https://example.com/thumb.jpg'),
      );
      expect(result.first.videoDimensions, equals('720x1280'));
      expect(result.first.videoDuration, equals(6));
      expect(result.first.videoBlurhash, equals('LEHV6nWB2yk8'));
    });

    test(
      'returns mixed text and video comments sorted newest first',
      () async {
        final textComment = _createCommentEvent(
          id: 'text1',
          content: 'Text comment',
          pubkey: testAuthorPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          createdAt: 1700000000,
        );

        final videoComment = _createCommentEvent(
          id: 'video1',
          content: 'Video reply',
          pubkey: testAuthorPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          createdAt: 1700001000,
          imetaEntries: [
            'url https://example.com/reply.mp4',
            'm video/mp4',
          ],
        );

        final olderTextComment = _createCommentEvent(
          id: 'text2',
          content: 'Older comment',
          pubkey: testAuthorPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          createdAt: 1699999000,
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [olderTextComment, videoComment, textComment],
        );

        final result = await repository.loadCommentsByAuthor(
          authorPubkey: testAuthorPubkey,
          includeVideoReplies: true,
        );

        expect(result, hasLength(3));
        // Newest first
        expect(result[0].id, equals('video1'));
        expect(result[1].id, equals('text1'));
        expect(result[2].id, equals('text2'));
      },
    );

    test('skips malformed events missing E tag', () async {
      // Event with K tag but no E tag
      final malformedEvent = Event(
        testAuthorPubkey,
        _commentKind,
        <List<String>>[
          ['K', _testRootEventKind.toString()],
        ],
        'Missing E tag',
        createdAt: 1700000000,
      )..id = 'malformed1';

      final validEvent = _createCommentEvent(
        id: 'valid1',
        content: 'Valid comment',
        pubkey: testAuthorPubkey,
        rootEventId: testRootEventId,
        rootAuthorPubkey: testRootAuthorPubkey,
        rootEventKind: _testRootEventKind,
        createdAt: 1700000000,
      );

      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => [malformedEvent, validEvent]);

      final result = await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
      );

      expect(result, hasLength(1));
      expect(result.first.id, equals('valid1'));
    });

    test('skips malformed events missing K tag', () async {
      // Event with E tag but no K tag
      final malformedEvent = Event(
        testAuthorPubkey,
        _commentKind,
        <List<String>>[
          ['E', testRootEventId, '', testRootAuthorPubkey],
        ],
        'Missing K tag',
        createdAt: 1700000000,
      )..id = 'malformed2';

      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => [malformedEvent]);

      final result = await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
      );

      expect(result, isEmpty);
    });

    test('skips events with no tags at all', () async {
      final malformedEvent = Event(
        testAuthorPubkey,
        _commentKind,
        <List<String>>[],
        'No tags',
        createdAt: 1700000000,
      )..id = 'malformed3';

      when(
        () =>
            mockNostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => [malformedEvent]);

      final result = await repository.loadCommentsByAuthor(
        authorPubkey: testAuthorPubkey,
      );

      expect(result, isEmpty);
    });

    test(
      'throws LoadCommentsByAuthorFailedException on query failure',
      () async {
        when(
          () => mockNostrClient.queryEvents(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.loadCommentsByAuthor(
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LoadCommentsByAuthorFailedException>()),
        );
      },
    );
  });
}

/// Helper to create a NIP-22 comment event for testing.
Event _createCommentEvent({
  required String id,
  required String content,
  required String pubkey,
  required String rootEventId,
  required String rootAuthorPubkey,
  required int rootEventKind,
  String? replyToEventId,
  String? replyToAuthorPubkey,
  List<String>? imetaEntries,
  int createdAt = 1000,
}) {
  final tags = <List<String>>[
    ['E', rootEventId, '', rootAuthorPubkey],
    ['K', rootEventKind.toString()],
    ['P', rootAuthorPubkey],
    if (replyToEventId != null && replyToAuthorPubkey != null) ...[
      ['e', replyToEventId, '', replyToAuthorPubkey],
      ['k', _commentKind.toString()],
      ['p', replyToAuthorPubkey],
    ] else ...[
      ['e', rootEventId, '', rootAuthorPubkey],
      ['k', rootEventKind.toString()],
      ['p', rootAuthorPubkey],
    ],
    if (imetaEntries != null) ['imeta', ...imetaEntries],
  ];

  return Event(pubkey, _commentKind, tags, content, createdAt: createdAt)
    ..id = id;
}
