import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _FakeEvent extends Fake implements Event {}

const int _commentKind = EventKind.comment;
const int _rootEventKind = EventKind.videoVertical;

void main() {
  // A published NIP-09 deletion does not reach every read source at once: a
  // relay that has not stored the comment yet applies the deletion only in a
  // later sweep, and the edge-cached REST list is not purged. Until then the
  // sources still return the deleted comment, which after an edit shows the
  // old text beside the new one (#9643).
  group('CommentsRepository deleted-comment filter (#9643)', () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcakeClient;
    late CommentsRepository repository;

    const rootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const rootAuthorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const userPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const deletedId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const keptId =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
      registerFallbackValue(_FakeEvent());
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcakeClient = _MockFunnelcakeApiClient();
      when(() => nostrClient.publicKey).thenReturn(userPubkey);
      when(() => nostrClient.publishEvent(any())).thenAnswer((inv) async {
        final event = inv.positionalArguments.first as Event;
        return PublishSuccess(event: event);
      });
      when(
        () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => <Event>[]);
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

    VideoComment restComment(String id, {String content = 'rest'}) =>
        VideoComment(
          id: id,
          pubkey: userPubkey,
          createdAt: 1000,
          kind: _commentKind,
          content: content,
          sig: 'sig',
          tags: commentTags(),
        );

    Event relayComment(String id) =>
        Event(userPubkey, _commentKind, commentTags(), 'relay', createdAt: 1000)
          ..id = id;

    Future<void> deleteOne(String commentId) {
      return repository.deleteComment(
        commentId: commentId,
        rootEventId: rootEventId,
      );
    }

    Future<CommentThread> load() {
      return repository.loadComments(
        rootEventId: rootEventId,
        rootEventKind: _rootEventKind,
      );
    }

    group('loadComments', () {
      test(
        'drops a deleted comment the REST index still returns and counts '
        'without it',
        () async {
          stubRest([restComment(deletedId), restComment(keptId)]);
          final beforeDelete = await load();
          expect(beforeDelete.commentCache.keys, contains(deletedId));

          await deleteOne(deletedId);
          final thread = await load();

          expect(thread.commentCache.keys, equals([keptId]));
          expect(thread.totalCount, equals(1));
          expect(await repository.getCommentsCount(rootEventId), equals(1));
        },
      );

      test('shows only the edited text after an edit', () async {
        final original = await repository.postComment(
          content: 'Original text',
          rootEventId: rootEventId,
          rootEventKind: _rootEventKind,
          rootEventAuthorPubkey: rootAuthorPubkey,
        );
        await deleteOne(original.id);
        await repository.postComment(
          content: 'Edited text',
          rootEventId: rootEventId,
          rootEventKind: _rootEventKind,
          rootEventAuthorPubkey: rootAuthorPubkey,
        );
        // The index stored the original but has not applied its deletion,
        // and has not ingested the edit yet.
        stubRest([restComment(original.id, content: 'Original text')]);

        final thread = await load();

        expect(
          thread.comments.map((comment) => comment.content),
          equals(['Edited text']),
        );
        expect(thread.totalCount, equals(1));
      });

      test('drops a deleted comment a relay still returns', () async {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [relayComment(deletedId), relayComment(keptId)],
        );
        final beforeDelete = await load();
        expect(beforeDelete.commentCache.keys, contains(deletedId));

        await deleteOne(deletedId);
        final thread = await load();

        expect(thread.commentCache.keys, equals([keptId]));
        expect(thread.totalCount, equals(1));
      });
    });

    group('watchComments', () {
      test('does not emit a comment deleted after subscribing', () async {
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

        await deleteOne(deletedId);
        controller
          ..add(relayComment(deletedId))
          ..add(relayComment(keptId));
        await pumpEventQueue();

        expect(received, equals([keptId]));
      });
    });

    group('loadCommentsByAuthor', () {
      test('drops a deleted comment a relay still returns', () async {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [relayComment(deletedId), relayComment(keptId)],
        );
        final beforeDelete = await repository.loadCommentsByAuthor(
          authorPubkey: userPubkey,
        );
        expect(beforeDelete.map((comment) => comment.id), contains(deletedId));

        await deleteOne(deletedId);
        final comments = await repository.loadCommentsByAuthor(
          authorPubkey: userPubkey,
        );

        expect(comments.map((comment) => comment.id), equals([keptId]));
      });
    });
  });
}
