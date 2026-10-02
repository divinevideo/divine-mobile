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
      registerFallbackValue(Duration.zero);
      registerFallbackValue(Event(authorPubkey, _commentKind, const [], ''));
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcakeClient = _MockFunnelcakeApiClient();
      relayComments = [];
      deletionRequests = [];
      deletionLookups = [];
      // Comment reads get relayComments; the kind-5 lookup gets
      // deletionRequests and is recorded so a test can inspect its filter.
      when(
        () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((invocation) async {
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

    Event relayComment(String id, {int createdAt = 1000}) => Event(
      authorPubkey,
      _commentKind,
      commentTags(),
      'relay',
      createdAt: createdAt,
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
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async {
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

      test('looks up at most 50 comments per query', () async {
        final comments = [
          for (var i = 0; i < 120; i++)
            comment(i.toRadixString(16).padLeft(64, '0')),
        ];

        await repository.findAuthorDeletedComments(comments);

        expect(
          deletionLookups.map((filter) => filter.e!.length),
          equals([50, 50, 20]),
        );
        expect(
          deletionLookups.expand((filter) => filter.e!).toSet(),
          hasLength(120),
        );
      });

      test('keeps what one batch found when another batch fails', () async {
        final comments = [
          for (var i = 0; i < 60; i++)
            comment(i.toRadixString(16).padLeft(64, '0')),
        ];
        final lastId = comments.last.id;
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments.first as List<Filter>;
          if (filters.first.e!.contains(lastId)) {
            return [
              deletionRequest(by: authorPubkey, ids: [lastId]),
            ];
          }
          throw Exception('relay closed the connection');
        });

        final deleted = await repository.findAuthorDeletedComments(comments);

        expect(deleted, equals({lastId}));
      });

      test('still reports a comment it found deleted before', () async {
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];
        await repository.findAuthorDeletedComments([comment(deletedId)]);
        deletionRequests = [];

        final deleted = await repository.findAuthorDeletedComments([
          comment(deletedId),
          comment(keptId),
        ]);

        expect(deleted, equals({deletedId}));
      });

      test('asks about one batch at a time', () async {
        var inFlight = 0;
        var mostInFlight = 0;
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async {
          inFlight++;
          if (inFlight > mostInFlight) mostInFlight = inFlight;
          await pumpEventQueue();
          inFlight--;
          return <Event>[];
        });

        await repository.findAuthorDeletedComments([
          for (var i = 0; i < 120; i++)
            comment(i.toRadixString(16).padLeft(64, '0')),
        ]);

        expect(mostInFlight, equals(1));
      });

      test('matches a comment author written in another case', () async {
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];

        final deleted = await repository.findAuthorDeletedComments([
          comment(deletedId, author: authorPubkey.toUpperCase()),
        ]);

        expect(deleted, equals({deletedId}));
        expect(deletionLookups.single.authors, equals([authorPubkey]));
      });

      test('waits at most two seconds for relays', () async {
        await repository.findAuthorDeletedComments([comment(deletedId)]);

        verify(
          () => nostrClient.queryEvents(
            any(),
            timeout: const Duration(seconds: 2),
          ),
        ).called(1);
      });

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

        final page = await repository.loadCommentsByAuthor(
          authorPubkey: authorPubkey,
        );

        expect(page.comments.map((comment) => comment.id), equals([keptId]));
        expect(deletionLookups.single.authors, equals([authorPubkey]));
      });

      test(
        'continues from the oldest fetched comment when a full page held a '
        'deleted one',
        () async {
          relayComments = [
            relayComment(keptId, createdAt: 2000),
            relayComment(deletedId),
          ];
          deletionRequests = [
            deletionRequest(by: authorPubkey, ids: [deletedId]),
          ];

          final page = await repository.loadCommentsByAuthor(
            authorPubkey: authorPubkey,
            limit: 2,
          );

          expect(
            page.comments.map((comment) => comment.id),
            equals([keptId]),
          );
          expect(page.hasMore, isTrue);
          expect(
            page.nextCursor,
            equals(
              DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
            ),
          );
        },
      );

      test(
        'continues past a full page whose comments were all deleted',
        () async {
          relayComments = [relayComment(deletedId)];
          deletionRequests = [
            deletionRequest(by: authorPubkey, ids: [deletedId]),
          ];

          final page = await repository.loadCommentsByAuthor(
            authorPubkey: authorPubkey,
            limit: 1,
          );

          expect(page.comments, isEmpty);
          expect(
            page.nextCursor,
            equals(
              DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
            ),
          );
        },
      );

      test('ends when the relay returned less than a full page', () async {
        relayComments = [relayComment(keptId)];

        final page = await repository.loadCommentsByAuthor(
          authorPubkey: authorPubkey,
          limit: 2,
        );

        expect(page.hasMore, isFalse);
        expect(page.nextCursor, isNull);
      });
    });

    group('watchCommentDeletions', () {
      late StreamController<Event> relayStream;
      late List<Filter> subscribedFilters;
      String? subscribedId;
      bool? subscribedHandlesDeletions;
      const nowMillis = 1000000000;

      setUp(() {
        relayStream = StreamController<Event>.broadcast();
        addTearDown(relayStream.close);
        subscribedFilters = [];
        subscribedId = null;
        subscribedHandlesDeletions = null;
        when(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            handleDeletionRequests: any(named: 'handleDeletionRequests'),
          ),
        ).thenAnswer((invocation) {
          subscribedFilters =
              invocation.positionalArguments.first as List<Filter>;
          subscribedId = invocation.namedArguments[#subscriptionId] as String?;
          subscribedHandlesDeletions =
              invocation.namedArguments[#handleDeletionRequests] as bool?;
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

      test("keeps other accounts' requests out of the shared event cache", () {
        repository.watchCommentDeletions(rootEventId: rootEventId);

        expect(subscribedHandlesDeletions, isFalse);
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

    // A relay that replays stored events after a reconnect, or a second relay,
    // can deliver the request before the comment it names.
    group('deletion requests seen before their comment', () {
      late StreamController<Event> deletionStream;
      late StreamController<Event> commentStream;

      setUp(() {
        deletionStream = StreamController<Event>.broadcast();
        commentStream = StreamController<Event>.broadcast();
        addTearDown(deletionStream.close);
        addTearDown(commentStream.close);
        when(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            handleDeletionRequests: any(named: 'handleDeletionRequests'),
          ),
        ).thenAnswer((invocation) {
          final id = invocation.namedArguments[#subscriptionId] as String?;
          return (id ?? '').startsWith('comment_deletions_watch')
              ? deletionStream.stream
              : commentStream.stream;
        });
      });

      Future<void> seeDeletionRequest({
        required String by,
        required String commentId,
      }) async {
        final subscription = repository
            .watchCommentDeletions(rootEventId: rootEventId)
            .listen((_) {});
        addTearDown(subscription.cancel);
        deletionStream.add(deletionRequest(by: by, ids: [commentId]));
        await pumpEventQueue();
      }

      Future<List<String>> watchArrivals(List<Event> comments) async {
        final received = <String>[];
        final subscription = repository
            .watchComments(
              rootEventId: rootEventId,
              rootEventKind: _rootEventKind,
            )
            .listen((comment) => received.add(comment.id));
        addTearDown(subscription.cancel);
        comments.forEach(commentStream.add);
        await pumpEventQueue();
        return received;
      }

      test('hides a live comment whose author asked first', () async {
        await seeDeletionRequest(by: authorPubkey, commentId: deletedId);

        final received = await watchArrivals([
          relayComment(deletedId),
          relayComment(keptId),
        ]);

        expect(received, equals([keptId]));
      });

      test('keeps a live comment when someone else asked first', () async {
        await seeDeletionRequest(by: otherPubkey, commentId: deletedId);

        final received = await watchArrivals([relayComment(deletedId)]);

        expect(received, equals([deletedId]));
      });

      test('hides a loaded comment whose author asked first', () async {
        stubRest([restComment(deletedId), restComment(keptId)]);
        await seeDeletionRequest(by: authorPubkey, commentId: deletedId);

        final thread = await load();

        expect(thread.commentCache.keys, equals([keptId]));
        expect(thread.totalCount, equals(1));
      });

      test(
        'hides an author-page comment whose author asked first, even when '
        'the lookup finds nothing',
        () async {
          relayComments = [relayComment(deletedId), relayComment(keptId)];
          await seeDeletionRequest(by: authorPubkey, commentId: deletedId);

          final page = await repository.loadCommentsByAuthor(
            authorPubkey: authorPubkey,
          );

          expect(deletionLookups, hasLength(1));
          expect(page.comments.map((comment) => comment.id), equals([keptId]));
        },
      );

      test('matches a requester written in another case', () async {
        await seeDeletionRequest(
          by: authorPubkey.toUpperCase(),
          commentId: deletedId,
        );

        final received = await watchArrivals([relayComment(deletedId)]);

        expect(received, isEmpty);
      });

      test('matches a comment author written in another case', () async {
        stubRest([
          VideoComment(
            id: deletedId,
            pubkey: authorPubkey.toUpperCase(),
            createdAt: 1000,
            kind: _commentKind,
            content: 'rest',
            sig: 'sig',
            tags: commentTags(),
          ),
        ]);
        await seeDeletionRequest(by: authorPubkey, commentId: deletedId);

        final thread = await load();

        expect(thread.commentCache, isEmpty);
      });

      test('keeps at most 8 requesters per comment, oldest first', () async {
        String key(int i) => (i + 1).toRadixString(16).padLeft(64, '0');
        final subscription = repository
            .watchCommentDeletions(rootEventId: rootEventId)
            .listen((_) {});
        addTearDown(subscription.cancel);
        // The author asks first; eight other keys then name the same comment.
        deletionStream.add(deletionRequest(by: authorPubkey, ids: [deletedId]));
        for (var i = 0; i < 8; i++) {
          deletionStream.add(deletionRequest(by: key(i), ids: [deletedId]));
        }
        await pumpEventQueue();

        final received = await watchArrivals([relayComment(deletedId)]);

        expect(received, equals([deletedId]));
      });

      test('keeps an author who asks again among the eight newest', () async {
        String key(int i) => (i + 1).toRadixString(16).padLeft(64, '0');
        final subscription = repository
            .watchCommentDeletions(rootEventId: rootEventId)
            .listen((_) {});
        addTearDown(subscription.cancel);
        deletionStream.add(deletionRequest(by: authorPubkey, ids: [deletedId]));
        for (var i = 0; i < 7; i++) {
          deletionStream.add(deletionRequest(by: key(i), ids: [deletedId]));
        }
        // Asking again makes the author the newest of the eight kept.
        deletionStream
          ..add(deletionRequest(by: authorPubkey, ids: [deletedId]))
          ..add(deletionRequest(by: key(7), ids: [deletedId]));
        await pumpEventQueue();

        final received = await watchArrivals([relayComment(deletedId)]);

        expect(received, isEmpty);
      });

      test('forgets the oldest of more than 2000 requests', () async {
        String id(int i) => i.toRadixString(16).padLeft(64, '0');
        final subscription = repository
            .watchCommentDeletions(rootEventId: rootEventId)
            .listen((_) {});
        addTearDown(subscription.cancel);
        for (var i = 0; i <= 2000; i++) {
          deletionStream.add(deletionRequest(by: authorPubkey, ids: [id(i)]));
        }
        await pumpEventQueue();

        final received = await watchArrivals([
          relayComment(id(0)),
          relayComment(id(2000)),
        ]);

        expect(received, equals([id(0)]));
      });
    });

    // A comment posted on this device and deleted from another one is still
    // in the just-posted list that keeps it visible while REST catches up.
    group('a just-posted comment deleted from another device', () {
      test('stays hidden when the page reloads', () async {
        when(() => nostrClient.publicKey).thenReturn(authorPubkey);
        when(() => nostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event
            ..id = deletedId;
          return PublishSuccess(event: event);
        });
        await repository.postComment(
          content: 'posted here, deleted elsewhere',
          rootEventId: rootEventId,
          rootEventKind: _rootEventKind,
          rootEventAuthorPubkey: rootAuthorPubkey,
        );
        deletionRequests = [
          deletionRequest(by: authorPubkey, ids: [deletedId]),
        ];
        // The first page has not caught up, so the comment shows from the
        // just-posted list, and the lookup finds its author's request.
        final firstPage = await load();
        expect(firstPage.commentCache.keys, equals([deletedId]));
        await repository.findAuthorDeletedComments(firstPage.comments);
        relayComments = [relayComment(deletedId)];

        final thread = await load();

        expect(thread.commentCache, isEmpty);
        expect(thread.totalCount, equals(0));
      });
    });
  });
}
