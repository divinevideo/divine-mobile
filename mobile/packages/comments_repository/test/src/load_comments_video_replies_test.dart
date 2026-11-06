// ABOUTME: Tests for CommentsRepository.loadComments putting a video's video
// ABOUTME: replies on the funnelcake REST first page (#6744).

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _rootId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _rootAuthor =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _replyAuthor =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _rootAddressableId = '34236:$_rootAuthor:root-d';
const _rootKind = 34236;

/// A 64-hex id that [_label] reads back as [label].
String _hexId(String label) => label.codeUnits
    .map((c) => c.toRadixString(16).padLeft(2, '0'))
    .join()
    .padLeft(64, '0');

/// The label an id made by [_hexId] was made from; other ids as they are.
String _label(String id) {
  if (!RegExp(r'^0*([0-9a-f]{2})+$').hasMatch(id) || id.length != 64) return id;
  final bytes = [
    for (var i = 0; i < id.length; i += 2)
      int.parse(id.substring(i, i + 2), radix: 16),
  ];
  return String.fromCharCodes(bytes.where((byte) => byte != 0));
}

VideoComment _restComment(String id, int createdAt) => VideoComment(
  id: id,
  pubkey: _replyAuthor,
  createdAt: createdAt,
  kind: 1111,
  content: 'comment $id',
  sig: 'sig',
  tags: const [
    ['E', _rootId, '', _rootAuthor],
    ['A', _rootAddressableId, ''],
    ['K', '34236'],
    ['P', _rootAuthor],
    ['e', _rootId, '', _rootAuthor],
    ['a', _rootAddressableId, ''],
    ['k', '34236'],
    ['p', _rootAuthor],
  ],
);

VideoCommentsResponse _commentsPage(
  List<VideoComment> comments, {
  int? total,
  bool? hasMore,
}) => VideoCommentsResponse(
  comments: comments,
  total: total ?? comments.length,
  hasMore: hasMore,
);

/// A row of `GET /api/videos/{id}/responses`, as the server sends it.
Map<String, dynamic> _replyRow(
  String id,
  int createdAt, {
  String content = '',
}) => {
  'id': _hexId(id),
  'pubkey': _replyAuthor,
  'created_at': createdAt,
  'kind': 34236,
  'content': content,
  'video_url': 'https://media.divine.video/$id',
  'tags': [
    ['d', 'd-$id'],
    ['E', _rootId, '', _rootAuthor],
    ['A', _rootAddressableId, ''],
    ['K', '34236'],
    ['P', _rootAuthor],
    ['e', _rootId, '', _rootAuthor],
    ['a', _rootAddressableId, ''],
    ['k', '34236'],
    ['p', _rootAuthor],
    ['imeta', 'url https://media.divine.video/$id', 'm video/mp4'],
    ['title', 'Reply title'],
    ['summary', 'Reply summary'],
  ],
};

VideoResponsesResponse _replies(
  List<Map<String, dynamic>> rows, {
  int? total,
  bool hasMore = false,
}) => VideoResponsesResponse(
  videos: const [],
  rows: rows,
  total: total ?? rows.length,
  hasMore: hasMore,
);

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(VideoResponseType.replies);
  });

  group('CommentsRepository.loadComments video replies on the REST page', () {
    late _MockNostrClient nostr;
    late _MockFunnelcakeApiClient funnel;
    late CommentsRepository repository;

    void stubComments(VideoCommentsResponse page) {
      when(
        () => funnel.getVideoComments(
          videoId: any(named: 'videoId'),
          sort: any(named: 'sort'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          cacheBustToken: any(named: 'cacheBustToken'),
        ),
      ).thenAnswer((_) async => page);
    }

    void stubReplies(VideoResponsesResponse page) {
      when(
        () => funnel.getVideoResponses(
          videoId: any(named: 'videoId'),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => page);
    }

    Future<CommentThread> load({
      bool includeVideoReplies = true,
      int limit = 50,
    }) => repository.loadComments(
      rootEventId: _rootId,
      rootEventKind: _rootKind,
      rootAddressableId: _rootAddressableId,
      limit: limit,
      includeVideoReplies: includeVideoReplies,
    );

    setUp(() {
      nostr = _MockNostrClient();
      funnel = _MockFunnelcakeApiClient();
      when(() => funnel.isAvailable).thenReturn(true);
      when(() => nostr.publicKey).thenReturn(_replyAuthor);
      repository = CommentsRepository(
        nostrClient: nostr,
        funnelcakeApiClient: funnel,
      );
    });

    test('puts the video reply on the first page beside the comment', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      stubReplies(_replies([_replyRow('reply', 2000)]));

      final thread = await load();

      expect(
        thread.comments.map((c) => _label(c.id)),
        unorderedEquals(['comment', 'reply']),
      );
      verifyNever(() => nostr.queryEvents(any()));
    });

    test('reads the reply the way the relay path reads it', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      stubReplies(_replies([_replyRow('reply', 2000)]));

      final reply = (await load()).comments.firstWhere(
        (c) => c.id == _hexId('reply'),
      );

      expect(reply.eventKind, equals(EventKind.videoVertical));
      expect(
        reply.addressableId,
        equals('${EventKind.videoVertical}:$_replyAuthor:d-reply'),
      );
      expect(reply.hasVideo, isTrue);
      expect(reply.rootEventId, equals(_rootId));
      expect(reply.rootAddressableId, equals(_rootAddressableId));
      // The event's own content, not the `summary` tag the stats model falls
      // back to: the live watch reads the same event, and whichever copy
      // arrives first is the one that stays.
      expect(reply.content, isEmpty);
    });

    test('counts the replies in the total', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)], total: 4));
      stubReplies(_replies([_replyRow('reply', 2000)], total: 3));

      final thread = await load();

      expect(thread.totalCount, equals(7));
      expect(thread.hasExactTotal, isTrue);
    });

    test('retains the REST offset after merging a video reply', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      stubReplies(_replies([_replyRow('reply', 2000)]));

      final thread = await load();

      expect(thread.nextOffset, 1);
    });

    test('does not consume REST comments trimmed by the reply floor', () async {
      stubComments(
        _commentsPage([
          _restComment('newest', 300),
          _restComment('deferred', 100),
        ], hasMore: false),
      );
      stubReplies(
        _replies([_replyRow('reply', 200)], hasMore: true, total: 5),
      );

      final thread = await load();

      expect(thread.nextOffset, 1);
      expect(thread.hasMore, isTrue);
      expect(
        thread.comments.map((c) => _label(c.id)),
        unorderedEquals(['newest', 'reply']),
      );
    });

    test('pages replies by time while keeping comments on REST', () async {
      stubComments(_commentsPage([_restComment('older-comment', 100)]));
      when(
        () => nostr.queryEventsDetailed(
          any(),
        ),
      ).thenAnswer(
        (_) async => (
          events: [Event.fromJson(_replyRow('older-reply', 150))],
          timedOut: false,
          noRelays: false,
        ),
      );

      final thread = await repository.loadComments(
        rootEventId: _rootId,
        rootEventKind: _rootKind,
        rootAddressableId: _rootAddressableId,
        before: DateTime.fromMillisecondsSinceEpoch(200000),
        offset: 10,
        includeVideoReplies: true,
      );

      expect(
        thread.comments.map((c) => _label(c.id)),
        unorderedEquals(['older-comment', 'older-reply']),
      );
      expect(thread.nextOffset, 11);
      expect(thread.hasExactTotal, isFalse);
      final filters =
          verify(
                () => nostr.queryEventsDetailed(
                  captureAny(),
                ),
              ).captured.single
              as List<Filter>;
      expect(filters, hasLength(2));
      expect(filters.every((f) => f.kinds!.single == 34236), isTrue);
      expect(filters.every((f) => f.until == 200), isTrue);
      verifyNever(
        () => funnel.getVideoResponses(
          videoId: any(named: 'videoId'),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test(
      'keeps REST paging when the first reply window consumed no comments',
      () async {
        stubComments(
          _commentsPage([_restComment('deferred', 100)], hasMore: false),
        );
        stubReplies(
          _replies([_replyRow('first-reply', 200)], hasMore: true, total: 2),
        );
        final first = await load();
        expect(first.nextOffset, 0);
        expect(first.comments.map((c) => _label(c.id)), ['first-reply']);
        when(
          () => nostr.queryEventsDetailed(
            any(),
          ),
        ).thenAnswer(
          (_) async => (
            events: [Event.fromJson(_replyRow('last-reply', 150))],
            timedOut: false,
            noRelays: false,
          ),
        );

        final next = await repository.loadComments(
          rootEventId: _rootId,
          rootEventKind: _rootKind,
          rootAddressableId: _rootAddressableId,
          before: first.comments.single.createdAt,
          offset: first.nextOffset!,
          includeVideoReplies: true,
        );

        expect(
          next.comments.map((c) => _label(c.id)),
          unorderedEquals(['deferred', 'last-reply']),
        );
        expect(next.nextOffset, 1);
        expect(next.hasMore, isFalse);
      },
    );

    test('asks for no more replies than the page holds', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      stubReplies(_replies(const []));

      await load();
      await load(limit: 500);

      final limits = verify(
        () => funnel.getVideoResponses(
          videoId: _rootId,
          type: VideoResponseType.replies,
          limit: captureAny(named: 'limit'),
        ),
      ).captured;
      // The first is the page size; the second is what the server allows.
      expect(limits, equals([50, 100]));
    });

    test('waits beyond the bootstrap grace for an older reply page', () async {
      repository = CommentsRepository(
        nostrClient: nostr,
        funnelcakeApiClient: funnel,
        videoRepliesBootstrapGrace: Duration.zero,
      );
      stubComments(_commentsPage([_restComment('comment', 100)]));
      final replies =
          Completer<({List<Event> events, bool timedOut, bool noRelays})>();
      when(
        () => nostr.queryEventsDetailed(
          any(),
        ),
      ).thenAnswer((_) => replies.future);
      var completed = false;
      final pending = repository
          .loadComments(
            rootEventId: _rootId,
            rootEventKind: _rootKind,
            before: DateTime.fromMillisecondsSinceEpoch(200000),
            offset: 10,
            includeVideoReplies: true,
          )
          .then((thread) {
            completed = true;
            return thread;
          });

      await pumpEventQueue();
      final completedBeforeReplies = completed;
      replies.complete((
        events: [Event.fromJson(_replyRow('reply', 150))],
        timedOut: false,
        noRelays: false,
      ));
      final thread = await pending;

      expect(completedBeforeReplies, isFalse);
      expect(
        thread.comments.map((c) => _label(c.id)),
        unorderedEquals(['comment', 'reply']),
      );
    });

    test(
      'fails an unread older reply page so the same window can retry',
      () async {
        stubComments(_commentsPage([_restComment('comment', 100)]));
        var attempts = 0;
        when(
          () => nostr.queryEventsDetailed(
            any(),
          ),
        ).thenAnswer((_) async {
          if (attempts++ == 0) {
            throw TimeoutException('relay did not reach EOSE');
          }
          return (
            events: [Event.fromJson(_replyRow('reply', 150))],
            timedOut: false,
            noRelays: false,
          );
        });
        Future<CommentThread> loadOlder() => repository.loadComments(
          rootEventId: _rootId,
          rootEventKind: _rootKind,
          before: DateTime.fromMillisecondsSinceEpoch(200000),
          offset: 10,
          includeVideoReplies: true,
        );

        await expectLater(
          loadOlder(),
          throwsA(isA<LoadCommentsFailedException>()),
        );
        final retried = await loadOlder();

        expect(retried.nextOffset, 11);
        expect(
          retried.comments.map((c) => _label(c.id)),
          unorderedEquals(['comment', 'reply']),
        );
      },
    );

    test('asks nothing about video replies while they are off', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));

      final thread = await load(includeVideoReplies: false);

      expect(thread.comments.map((c) => _label(c.id)), equals(['comment']));
      verifyNever(
        () => funnel.getVideoResponses(
          videoId: any(named: 'videoId'),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test(
      'accepts an empty page from answering relays without an all-relays veto',
      () async {
        stubComments(
          _commentsPage([_restComment('comment', 100)], hasMore: false),
        );
        when(
          () => nostr.queryEventsDetailed(
            any(),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: false),
        );

        final thread = await repository.loadComments(
          rootEventId: _rootId,
          rootEventKind: _rootKind,
          before: DateTime.fromMillisecondsSinceEpoch(200000),
          offset: 10,
          includeVideoReplies: true,
        );

        expect(thread.comments.map((c) => _label(c.id)), ['comment']);
        expect(thread.nextOffset, 11);
        expect(thread.hasMore, isFalse);
      },
    );

    for (final scenario in [
      (
        name: 'timed-out empty',
        timedOut: true,
        noRelays: false,
        partial: false,
      ),
      (
        name: 'timed-out partial',
        timedOut: true,
        noRelays: false,
        partial: true,
      ),
      (
        name: 'relay-less cached',
        timedOut: false,
        noRelays: true,
        partial: true,
      ),
    ]) {
      test('does not consume a ${scenario.name} older reply page', () async {
        stubComments(_commentsPage([_restComment('comment', 100)]));
        final events = <Event>[
          if (scenario.partial) Event.fromJson(_replyRow('partial', 175)),
        ];
        // The list-only API returns partial/cache rows without a failure.
        when(() => nostr.queryEvents(any())).thenAnswer((_) async => events);
        when(
          () => nostr.queryEventsDetailed(
            any(),
          ),
        ).thenAnswer(
          (_) async => (
            events: events,
            timedOut: scenario.timedOut,
            noRelays: scenario.noRelays,
          ),
        );

        await expectLater(
          repository.loadComments(
            rootEventId: _rootId,
            rootEventKind: _rootKind,
            before: DateTime.fromMillisecondsSinceEpoch(200000),
            offset: 10,
            includeVideoReplies: true,
          ),
          throwsA(isA<LoadCommentsFailedException>()),
        );
      });
    }

    test('shows the comments without waiting for slow video replies', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      final neverAnswers = Completer<VideoResponsesResponse>();
      when(
        () => funnel.getVideoResponses(
          videoId: any(named: 'videoId'),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => neverAnswers.future);
      repository = CommentsRepository(
        nostrClient: nostr,
        funnelcakeApiClient: funnel,
        videoRepliesBootstrapGrace: const Duration(milliseconds: 1),
      );

      final thread = await load().timeout(const Duration(seconds: 5));

      expect(thread.comments.map((c) => _label(c.id)), equals(['comment']));
      verifyNever(() => nostr.queryEvents(any()));
    });

    test('keeps the comments when the replies cannot be read', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      when(
        () => funnel.getVideoResponses(
          videoId: any(named: 'videoId'),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(
        FunnelcakeNotFoundException(
          resource: 'Video responses',
          url: 'https://api.example/responses',
        ),
      );

      final thread = await load();

      expect(thread.comments.map((c) => _label(c.id)), equals(['comment']));
      expect(thread.totalCount, equals(1));
      verifyNever(() => nostr.queryEvents(any()));
    });

    test(
      'leaves out replies older than the comments when more comments wait',
      () async {
        stubComments(
          _commentsPage(
            [_restComment('newest', 100), _restComment('oldest', 90)],
            total: 5,
            hasMore: true,
          ),
        );
        stubReplies(
          _replies([_replyRow('inside', 95), _replyRow('beyond', 50)]),
        );

        final thread = await load();

        // Paging resumes from the oldest comment loaded, so a reply older
        // than it would be skipped for good if it were shown now.
        expect(
          thread.comments.map((c) => _label(c.id)),
          unorderedEquals(['newest', 'inside', 'oldest']),
        );
        expect(thread.hasMore, isTrue);
      },
    );

    test(
      'ends the page at the later limit when both sources have more',
      () async {
        stubComments(
          _commentsPage(
            [_restComment('newest', 300), _restComment('stale', 150)],
            total: 9,
            hasMore: true,
          ),
        );
        stubReplies(
          _replies(
            [_replyRow('r1', 200), _replyRow('r2', 190)],
            total: 5,
            hasMore: true,
          ),
        );

        final thread = await load();

        // Replies are known down to 190, comments only down to 150: nothing
        // is known to be complete below 190.
        expect(
          thread.comments.map((c) => _label(c.id)),
          unorderedEquals(['newest', 'r1', 'r2']),
        );
        expect(thread.hasMore, isTrue);
      },
    );

    test('keeps the comments limit when it is the later one', () async {
      stubComments(
        _commentsPage(
          [_restComment('newest', 300), _restComment('floor', 250)],
          total: 9,
          hasMore: true,
        ),
      );
      stubReplies(
        _replies(
          [_replyRow('r1', 200), _replyRow('r2', 190)],
          total: 5,
          hasMore: true,
        ),
      );

      final thread = await load();

      expect(
        thread.comments.map((c) => _label(c.id)),
        unorderedEquals(['newest', 'floor']),
      );
      expect(thread.hasMore, isTrue);
    });

    // The rows are the server's word, not a signed event: anything that
    // could not have come from a reply to this video is left out, and none
    // of it may fail the page.
    final badRows = <String, Map<String, dynamic>>{
      'no id': {..._replyRow('bad', 2100), 'id': null},
      'an id that is not 64 hex characters': {
        ..._replyRow('bad', 2100),
        'id': 'not-hex',
      },
      'a pubkey that is not 64 hex characters': {
        ..._replyRow('bad', 2100),
        'pubkey': 'z' * 64,
      },
      'an id of codes that are not text': {
        ..._replyRow('bad', 2100),
        'id': [1114112],
      },
      'an id of codes that are not numbers': {
        ..._replyRow('bad', 2100),
        'id': ['x'],
      },
      'a time that is not a number': {
        ..._replyRow('bad', 2100),
        'created_at': 'soon',
      },
      'a time that is not finite': {
        ..._replyRow('bad', 2100),
        'created_at': double.infinity,
      },
      'a time beyond what a date can hold': {
        ..._replyRow('bad', 2100),
        'created_at': 1e13,
      },
      'a kind that is not a video': {..._replyRow('bad', 2100), 'kind': 1},
      'a kind that is not a number': {..._replyRow('bad', 2100), 'kind': 'x'},
      'tags that are not a list': {..._replyRow('bad', 2100), 'tags': 'none'},
      'another video as its root': {
        ..._replyRow('bad', 2100),
        'tags': [
          ['E', 'f' * 64, '', _rootAuthor],
          ['A', '34236:$_rootAuthor:elsewhere', ''],
          ['K', '34236'],
          ['d', 'd-bad'],
          ['imeta', 'url https://media.divine.video/bad'],
        ],
      },
    };

    for (final MapEntry(key: reason, value: row) in badRows.entries) {
      test('skips a row with $reason and keeps the rest', () async {
        stubComments(_commentsPage([_restComment('comment', 1000)]));
        stubReplies(_replies([_replyRow('good', 2000), row]));

        final thread = await load();

        expect(
          thread.comments.map((c) => _label(c.id)),
          unorderedEquals(['comment', 'good']),
        );
      });
    }

    test('reads an id and pubkey sent as ASCII codes, in lowercase', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      stubReplies(
        _replies([
          {
            ..._replyRow('x', 2000),
            'id': _hexId('replyid').toUpperCase().codeUnits,
            'pubkey': _replyAuthor.toUpperCase().codeUnits,
          },
        ]),
      );

      final reply = (await load()).comments.firstWhere(
        (c) => c.id != 'comment',
      );

      expect(reply.id, equals(_hexId('replyid')));
      expect(reply.authorPubkey, equals(_replyAuthor));
    });

    test('keeps a reply that names the video by its address only', () async {
      stubComments(_commentsPage([_restComment('comment', 1000)]));
      stubReplies(
        _replies([
          {
            ..._replyRow('revised', 2000),
            // Written against an earlier edit of the video: the event id
            // differs, the address is the video's.
            'tags': [
              ['E', 'e' * 64, '', _rootAuthor],
              ['A', _rootAddressableId, ''],
              ['K', '34236'],
              ['d', 'd-revised'],
              ['imeta', 'url https://media.divine.video/revised'],
            ],
          },
        ]),
      );

      final thread = await load();

      expect(
        thread.comments.map((c) => _label(c.id)),
        unorderedEquals(['comment', 'revised']),
      );
    });

    test(
      'leaves out comments older than the replies when more replies wait',
      () async {
        stubComments(
          _commentsPage(
            [_restComment('newest', 300), _restComment('stale', 150)],
            hasMore: false,
          ),
        );
        stubReplies(
          _replies(
            [_replyRow('r1', 200), _replyRow('r2', 190)],
            total: 5,
            hasMore: true,
          ),
        );

        final thread = await load();

        expect(
          thread.comments.map((c) => _label(c.id)),
          unorderedEquals(['newest', 'r1', 'r2']),
        );
        expect(thread.hasMore, isTrue);
      },
    );
  });
}
