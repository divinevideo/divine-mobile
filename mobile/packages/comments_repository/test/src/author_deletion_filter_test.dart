import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const int _commentKind = EventKind.comment;
const int _rootEventKind = EventKind.videoVertical;

void main() {
  // A relay that receives a deletion request before it has indexed the comment
  // keeps serving the comment until a later batch, and so does every read
  // source built on it (#7048). NIP-09 has the client hide such a comment, but
  // only when the request's pubkey matches the comment's author.
  group('CommentsRepository NIP-09 author deletions (#7048)', () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcakeClient;
    late CommentsRepository repository;
    late List<Event> relayComments;
    late List<Event> deletionRequests;
    late List<Filter> deletionLookups;

    const rootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const rootAuthorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const authorPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const otherPubkey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    const deletedId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const keptId =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcakeClient = _MockFunnelcakeApiClient();
      relayComments = [];
      deletionRequests = [];
      deletionLookups = [];
      // Comment reads get relayComments; the kind-5 lookup gets
      // deletionRequests and is recorded so a test can inspect its filter.
      when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments.first as List<Filter>;
        if (filters.first.kinds?.contains(EventKind.eventDeletion) ?? false) {
          deletionLookups.add(filters.first);
          return deletionRequests;
        }
        return relayComments;
      });
      when(() => funnelcakeClient.isAvailable).thenReturn(false);
      repository = CommentsRepository(
        nostrClient: nostrClient,
        funnelcakeApiClient: funnelcakeClient,
      );
    });

    List<List<String>> commentTags() => [
      ['E', rootEventId, '', rootAuthorPubkey],
      ['K', _rootEventKind.toString()],
      ['P', rootAuthorPubkey],
      ['e', rootEventId, '', rootAuthorPubkey],
      ['k', _rootEventKind.toString()],
      ['p', rootAuthorPubkey],
    ];

    VideoComment restComment(String id) => VideoComment(
      id: id,
      pubkey: authorPubkey,
      createdAt: 1000,
      kind: _commentKind,
      content: 'rest',
      sig: 'sig',
      tags: commentTags(),
    );

    Event relayComment(String id) => Event(
      authorPubkey,
      _commentKind,
      commentTags(),
      'relay',
      createdAt: 1000,
    )..id = id;

    Comment comment(String id, {String author = authorPubkey}) => Comment(
      id: id,
      content: 'comment',
      authorPubkey: author,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000000),
      rootEventId: rootEventId,
      rootAuthorPubkey: rootAuthorPubkey,
    );

    Event deletionRequest({
      required String by,
      required List<String> ids,
      List<List<String>> extraTags = const [],
    }) => Event(
      by,
      EventKind.eventDeletion,
      [
        for (final id in ids) ['e', id],
        ['k', _commentKind.toString()],
        ...extraTags,
      ],
      '',
      createdAt: 2000,
    );

    void stubRest(List<VideoComment> comments) {
      when(() => funnelcakeClient.isAvailable).thenReturn(true);
      when(
        () => funnelcakeClient.getVideoComments(
          videoId: any(named: 'videoId'),
          sort: any(named: 'sort'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          cacheBustToken: any(named: 'cacheBustToken'),
        ),
      ).thenAnswer(
        (_) async =>
            VideoCommentsResponse(comments: comments, total: comments.length),
      );
    }

    Future<CommentThread> load({DateTime? before}) => repository.loadComments(
      rootEventId: rootEventId,
      rootEventKind: _rootEventKind,
      before: before,
    );

    group('findAuthorDeletedComments', () {
      test(
        'returns a comment whose author published a deletion request',
        () async {
          deletionRequests = [
            deletionRequest(by: authorPubkey, ids: [deletedId]),
          ];

          final deleted = await repository.findAuthorDeletedComments([
            comment(deletedId),
            comment(keptId),
          ]);

          expect(deleted, equals({deletedId}));
        },
      );

      test('ignores a request signed by someone else', () async {
        deletionRequests = [
          deletionRequest(by: otherPubkey, ids: [deletedId]),
        ];

        final deleted = await repository.findAuthorDeletedComments([
          comment(deletedId),
          comment(keptId),
        ]);

        expect(deleted, isEmpty);
      });

      test('matches the request pubkey case-insensitively', () async {
        deletionRequests = [
          deletionRequest(by: authorPubkey.toUpperCase(), ids: [deletedId]),
        ];

        final deleted = await repository.findAuthorDeletedComments([
          comment(deletedId),
        ]);

        expect(deleted, equals({deletedId}));
      });

      test('returns every comment one request names', () async {
        deletionRequests = [
          deletionRequest(
            by: authorPubkey,
            ids: [deletedId, keptId],
            extraTags: [
              [
                'client',
                'Divine',
                '31990:$rootAuthorPubkey:divine-mobile',
                'wss://relay.example.com',
              ],
            ],
          ),
        ];

        final deleted = await repository.findAuthorDeletedComments([
          comment(deletedId),
          comment(keptId),
        ]);

        expect(deleted, equals({deletedId, keptId}));
      });

      test('returns nothing when the lookup fails', () async {
        when(() => nostrClient.queryEvents(any())).thenAnswer((_) async {
          throw TimeoutException('no relay answered the deletion lookup');
        });

        final deleted = await repository.findAuthorDeletedComments([
          comment(deletedId),
        ]);

        expect(deleted, isEmpty);
      });

      test('ignores lookup results that are not deletion requests', () async {
        deletionRequests = [
          Event(
            authorPubkey,
            _commentKind,
            [
              ['e', deletedId],
            ],
            'a reply, not a deletion',
            createdAt: 2000,
          ),
        ];

        final deleted = await repository.findAuthorDeletedComments([
          comment(deletedId),
        ]);

        expect(deleted, isEmpty);
      });

      test(
        "asks for the comment authors' deletion requests naming the comments",
        () async {
          await repository.findAuthorDeletedComments([
            comment(deletedId),
            comment(keptId, author: otherPubkey),
          ]);

          expect(deletionLookups, hasLength(1));
          final lookup = deletionLookups.single;
          expect(lookup.kinds, equals([EventKind.eventDeletion]));
          expect(lookup.authors, unorderedEquals([authorPubkey, otherPubkey]));
          expect(lookup.e, unorderedEquals([deletedId, keptId]));
        },
      );

      test('does not look anything up for no comments', () async {
        final deleted = await repository.findAuthorDeletedComments([]);

        expect(deleted, isEmpty);
        expect(deletionLookups, isEmpty);
      });

      test('does not look up a comment it already found deleted', () async {
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];
        await repository.findAuthorDeletedComments([comment(deletedId)]);

        await repository.findAuthorDeletedComments([
          comment(deletedId),
          comment(keptId),
        ]);

        expect(deletionLookups, hasLength(2));
        expect(deletionLookups.last.e, equals([keptId]));
      });
    });

    group('loadComments', () {
      test('does not wait for a deletion lookup', () async {
        stubRest([restComment(deletedId), restComment(keptId)]);
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];

        final thread = await load();

        expect(thread.commentCache.keys, unorderedEquals([deletedId, keptId]));
        expect(deletionLookups, isEmpty);
      });

      test('hides a REST comment a lookup found deleted', () async {
        stubRest([restComment(deletedId), restComment(keptId)]);
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];
        final firstPage = await load();
        expect(firstPage.commentCache.keys, contains(deletedId));
        await repository.findAuthorDeletedComments(firstPage.comments);

        final thread = await load();

        expect(thread.commentCache.keys, equals([keptId]));
        expect(thread.totalCount, equals(1));
      });

      test('hides a relay comment a lookup found deleted', () async {
        relayComments = [relayComment(deletedId), relayComment(keptId)];
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];
        final firstPage = await load(before: DateTime(2026));
        expect(firstPage.commentCache.keys, contains(deletedId));
        await repository.findAuthorDeletedComments(firstPage.comments);

        final thread = await load(before: DateTime(2026));

        expect(thread.commentCache.keys, equals([keptId]));
      });
    });

    group('watchComments', () {
      test('does not re-emit a comment a lookup found deleted', () async {
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];
        await repository.findAuthorDeletedComments([comment(deletedId)]);
        final controller = StreamController<Event>.broadcast();
        addTearDown(controller.close);
        when(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);
        final received = <String>[];
        final subscription = repository
            .watchComments(
              rootEventId: rootEventId,
              rootEventKind: _rootEventKind,
            )
            .listen((comment) => received.add(comment.id));
        addTearDown(subscription.cancel);

        controller
          ..add(relayComment(deletedId))
          ..add(relayComment(keptId));
        await pumpEventQueue();

        expect(received, equals([keptId]));
      });
    });

    group('loadCommentsByAuthor', () {
      test('hides a comment its author deleted', () async {
        relayComments = [relayComment(deletedId), relayComment(keptId)];
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];

        final comments = await repository.loadCommentsByAuthor(
          authorPubkey: authorPubkey,
        );

        expect(comments.map((comment) => comment.id), equals([keptId]));
        expect(deletionLookups.single.authors, equals([authorPubkey]));
      });
    });

    group('watchCommentDeletions', () {
      late StreamController<Event> relayStream;
      late List<Filter> subscribedFilters;
      String? subscribedId;
      const nowMillis = 1000000000;

      setUp(() {
        relayStream = StreamController<Event>.broadcast();
        addTearDown(relayStream.close);
        subscribedFilters = [];
        subscribedId = null;
        when(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((invocation) {
          subscribedFilters =
              invocation.positionalArguments.first as List<Filter>;
          subscribedId = invocation.namedArguments[#subscriptionId] as String?;
          return relayStream.stream;
        });
        when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
        repository = CommentsRepository(
          nostrClient: nostrClient,
          clock: () => DateTime.fromMillisecondsSinceEpoch(nowMillis),
        );
      });

      test('subscribes to comment deletion requests from a minute ago', () {
        repository.watchCommentDeletions(rootEventId: rootEventId);

        final filter = subscribedFilters.single;
        expect(filter.kinds, equals([EventKind.eventDeletion]));
        expect(filter.k, equals([_commentKind.toString()]));
        expect(filter.since, equals(nowMillis ~/ 1000 - 60));
        expect(subscribedId, startsWith('comment_deletions_watch'));
      });

      test('also watches video-reply deletions when video replies are on', () {
        repository.watchCommentDeletions(
          rootEventId: rootEventId,
          includeVideoReplies: true,
        );

        expect(
          subscribedFilters.single.k,
          equals([_commentKind.toString(), _rootEventKind.toString()]),
        );
      });

      test('emits one deletion per named comment', () async {
        final received = <CommentDeletion>[];
        final subscription = repository
            .watchCommentDeletions(rootEventId: rootEventId)
            .listen(received.add);
        addTearDown(subscription.cancel);

        relayStream.add(
          deletionRequest(
            by: authorPubkey,
            ids: [deletedId, keptId],
            extraTags: [
              [
                'client',
                'Divine',
                '31990:$rootAuthorPubkey:divine-mobile',
                'wss://relay.example.com',
              ],
            ],
          ),
        );
        await pumpEventQueue();

        expect(
          received,
          equals([
            const CommentDeletion(
              commentId: deletedId,
              requesterPubkey: authorPubkey,
            ),
            const CommentDeletion(
              commentId: keptId,
              requesterPubkey: authorPubkey,
            ),
          ]),
        );
      });

      test('drops events that are not deletion requests', () async {
        final received = <CommentDeletion>[];
        final subscription = repository
            .watchCommentDeletions(rootEventId: rootEventId)
            .listen(received.add);
        addTearDown(subscription.cancel);

        relayStream.add(relayComment(deletedId));
        await pumpEventQueue();

        expect(received, isEmpty);
      });

      test('stopWatchingComments closes the deletion subscription', () async {
        repository.watchCommentDeletions(rootEventId: rootEventId);
        expect(subscribedId, isNotNull);

        await repository.stopWatchingComments();

        verify(() => nostrClient.unsubscribe(subscribedId!)).called(1);
      });
    });
  });
}
