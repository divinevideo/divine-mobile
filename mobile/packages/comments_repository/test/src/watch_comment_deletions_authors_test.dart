// ABOUTME: Pins that the live deletion watch asks the relay only for requests
// ABOUTME: by the authors of the listed comments, as that list grows.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:test/test.dart';

import '../helpers/in_memory_relay.dart';
import '../helpers/relay_fixtures.dart';

void main() {
  group(CommentsRepository, () {
    late InMemoryRelay relay;
    late NostrClient client;
    late CommentsRepository repository;
    late TestVideo video;
    late StreamController<Set<String>> commentAuthors;

    setUp(() async {
      relay = InMemoryRelay();
      client = await connectTo(relay);
      repository = CommentsRepository(nostrClient: client);
      video = TestVideo();
      commentAuthors = StreamController<Set<String>>();
    });

    tearDown(() async {
      await client.dispose();
      // Not awaited: a controller nothing ever listened to never finishes
      // closing.
      unawaited(commentAuthors.close());
    });

    Received<CommentDeletion> watchDeletions() => Received(
      repository.watchCommentDeletions(
        rootEventId: video.id,
        commentAuthors: commentAuthors.stream,
      ),
      (deletion) => deletion.commentId,
    );

    /// Publishes [author]'s request to delete a comment of theirs.
    ({String commentId, String requestId}) deleteCommentOf(
      TestCommenter author,
    ) {
      final comment = author.comment(video, 'deleted');
      final request = author.deletion(comment.id);
      relay.publish(request);
      return (commentId: comment.id, requestId: request.id);
    }

    group('watchCommentDeletions', () {
      test('asks the relay nothing while no comment is listed', () async {
        final author = TestCommenter();
        final deletions = watchDeletions();
        addTearDown(deletions.cancel);

        commentAuthors.add({});
        await pumpEventQueue();
        expect(relay.requests, isEmpty);

        commentAuthors.add({author.pubkey});
        await expectLater(
          deletions.waitFor(deleteCommentOf(author).commentId),
          completes,
        );
        expect(relay.requests, hasLength(1));
      });

      test(
        "delivers an author's requests once their comment is listed",
        () async {
          final listed = TestCommenter();
          final unlisted = TestCommenter();
          final deletions = watchDeletions();
          addTearDown(deletions.cancel);
          commentAuthors.add({listed.pubkey});
          await expectLater(
            deletions.waitFor(deleteCommentOf(listed).commentId),
            completes,
          );

          final earlier = deleteCommentOf(unlisted);
          expect(relay.sentEventIds, isNot(contains(earlier.requestId)));

          commentAuthors.add({listed.pubkey, unlisted.pubkey});

          await expectLater(deletions.waitFor(earlier.commentId), completes);
        },
      );

      test('delivers the requests of an author listed in upper case', () async {
        final author = TestCommenter();
        final deletions = watchDeletions();
        addTearDown(deletions.cancel);

        commentAuthors.add({author.pubkey.toUpperCase()});

        await expectLater(
          deletions.waitFor(deleteCommentOf(author).commentId),
          completes,
        );
      });

      test('keeps one relay subscription open as authors are listed', () async {
        final first = TestCommenter();
        final second = TestCommenter();
        final deletions = watchDeletions();
        addTearDown(deletions.cancel);
        commentAuthors.add({first.pubkey});
        await expectLater(
          deletions.waitFor(deleteCommentOf(first).commentId),
          completes,
        );

        commentAuthors.add({first.pubkey, second.pubkey});
        await expectLater(
          deletions.waitFor(deleteCommentOf(second).commentId),
          completes,
        );
        await pumpEventQueue();

        expect(relay.openSubscriptions, hasLength(1));
      });

      test(
        'retains the accepted watch if the relay refuses its replacement',
        () async {
          final first = TestCommenter();
          final second = TestCommenter();
          final third = TestCommenter();
          final errors = <Object>[];
          final seen = <String>[];
          final watch = repository
              .watchCommentDeletions(
                rootEventId: video.id,
                commentAuthors: commentAuthors.stream,
              )
              .listen(
                (deletion) => seen.add(deletion.commentId),
                onError: errors.add,
              );
          addTearDown(watch.cancel);
          commentAuthors.add({first.pubkey});
          await pumpEventQueue();
          final original = relay.openSubscriptions.single;

          relay.refuse = (filters) => filters.any(
            (filter) => (filter['authors'] as List<dynamic>).length > 1,
          );
          commentAuthors.add({first.pubkey, second.pubkey});
          await pumpEventQueue();
          expect(relay.requests, hasLength(2));
          expect(relay.openSubscriptions, {original});
          expect(errors, [isA<WatchCommentsFailedException>()]);
          final firstDeletion = deleteCommentOf(first);
          await pumpEventQueue();
          expect(seen, contains(firstDeletion.commentId));

          relay.refuse = null;
          commentAuthors.add({first.pubkey, second.pubkey});
          await pumpEventQueue();
          expect(relay.requests, hasLength(2));
          commentAuthors.add({first.pubkey, second.pubkey, third.pubkey});
          await pumpEventQueue();
          expect(relay.requests, hasLength(3));
          expect(relay.openSubscriptions, {relay.requests.last});
          final secondDeletion = deleteCommentOf(second);
          await pumpEventQueue();
          expect(seen, contains(secondDeletion.commentId));
        },
      );
    });
  });
}
