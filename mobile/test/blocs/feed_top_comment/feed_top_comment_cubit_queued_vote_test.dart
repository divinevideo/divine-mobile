// ABOUTME: Regression test for #10922: the feed's top comment ranks with the
// ABOUTME: viewer's queued vote, as the comments sheet does. Drives the cubit
// ABOUTME: over a real LikesRepository and an in-memory relay.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockCommentModerationRepository extends Mock
    implements CommentModerationRepository {}

String _hex(String suffix) => suffix.codeUnits
    .map((c) => c.toRadixString(16).padLeft(2, '0'))
    .join()
    .padLeft(64, '0');

final String _me = _hex('me');
final String _other = _hex('other');
final String _creator = _hex('creator');
final String _root = _hex('root');
final String _newer = _hex('newer');
final String _older = _hex('older');
final DateTime _now = DateTime(2026, 11, 13, 12);

Comment _comment(String id, {required Duration age}) => Comment(
  id: id,
  content: 'hello',
  authorPubkey: _other,
  createdAt: _now.subtract(age),
  rootEventId: _root,
  rootAuthorPubkey: _creator,
);

Event _upvote(String pubkey, String target) => Event(
  pubkey,
  EventKind.reaction,
  [
    ['e', target],
  ],
  '+',
  createdAt: 1700000000,
);

bool _matches(Filter filter, Event event) {
  final kinds = filter.kinds;
  if (kinds != null && !kinds.contains(event.kind)) return false;
  final e = filter.e;
  if (e == null) return true;
  return event.tags.any((t) => t.length > 1 && t[0] == 'e' && e.contains(t[1]));
}

void main() {
  group('$FeedTopCommentCubit with a queued vote (#10922)', () {
    late List<Event> relay;
    late List<QueuedLikeAction> queue;
    late LikesRepository likes;
    late _MockCommentsRepository comments;
    late _MockCommentModerationRepository moderation;

    setUpAll(() => registerFallbackValue(<Filter>[]));

    setUp(() {
      final client = _MockNostrClient();
      when(() => client.publicKey).thenReturn(_me);
      when(client.resolvePublicKey).thenAnswer((_) async => _me);
      when(() => client.queryEvents(any())).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments.first as List;
        return [
          for (final event in relay)
            if (filters.cast<Filter>().any((f) => _matches(f, event))) event,
        ];
      });
      // Both comments hold one vote, so the newer one is on top.
      relay = [_upvote(_other, _newer), _upvote(_other, _older)];
      queue = [];
      likes = LikesRepository(
        nostrClient: client,
        queuedLikeActions: () async => queue,
      );

      comments = _MockCommentsRepository();
      when(
        () => comments.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => CommentThread(
          rootEventId: _root,
          comments: [
            _comment(_newer, age: const Duration(hours: 1)),
            _comment(_older, age: const Duration(hours: 2)),
          ],
        ),
      );
      when(
        () => comments.findAuthorDeletedComments(any()),
      ).thenAnswer((_) async => <String>{});
      moderation = _MockCommentModerationRepository();
    });

    tearDown(() => likes.dispose());

    Future<String?> topCommentId() async {
      final cubit = FeedTopCommentCubit(
        commentsRepository: comments,
        likesRepository: likes,
        commentModerationRepository: moderation,
        rootEventId: _root,
        rootEventKind: EventKind.videoVertical,
        rootAuthorPubkey: _creator,
        loopCompletions: const Stream.empty(),
        viewerPubkey: _me,
        now: () => _now,
      );
      addTearDown(cubit.close);
      await cubit.load();
      return cubit.state.topComment?.id;
    }

    test('control: the newer comment wins a tie', () async {
      expect(await topCommentId(), equals(_newer));
    });

    test('a queued like lifts the older comment to the top', () async {
      queue.add((eventId: _older, isLike: true));

      expect(await topCommentId(), equals(_older));
    });
  });
}
