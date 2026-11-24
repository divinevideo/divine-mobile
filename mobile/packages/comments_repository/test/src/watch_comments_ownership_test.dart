// ABOUTME: Pins that each comments watch owns its relay subscription: its own
// ABOUTME: stored comments and EOSE, and ending it leaves others live (#9690).

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:test/test.dart';

import '../helpers/in_memory_relay.dart';
import '../helpers/relay_fixtures.dart';

Never _neverToldStoredEnded() =>
    fail('The watch was never told its stored comments ended');

void main() {
  group(CommentsRepository, () {
    late InMemoryRelay relay;
    late NostrClient client;
    late CommentsRepository repository;
    late TestCommenter commenter;

    setUp(() async {
      relay = InMemoryRelay();
      client = await connectTo(relay);
      repository = CommentsRepository(nostrClient: client);
      commenter = TestCommenter();
    });

    tearDown(() => client.dispose());

    /// Opens a comments watch on [video], reporting its own EOSE to [stored].
    Received<Comment> watch(TestVideo video, {Completer<void>? stored}) =>
        Received(
          repository.watchComments(
            rootEventId: video.id,
            rootEventKind: testVideoKind,
            onEose: () {
              if (stored != null && !stored.isCompleted) stored.complete();
            },
          ),
          (comment) => comment.id,
        );

    /// Opens a comments watch on [video] and waits for its own EOSE.
    Future<Received<Comment>> watchUntilStored(TestVideo video) async {
      final stored = Completer<void>();
      final received = watch(video, stored: stored);
      await stored.future.timeout(
        relayWaitTimeout,
        onTimeout: _neverToldStoredEnded,
      );
      return received;
    }

    /// Ends [watch] the way its owner does when its comments sheet closes.
    Future<void> endOwner(Received<Object> watch) => watch.cancel();

    group('watchComments', () {
      test(
        'tells each watch of a video when its stored comments end',
        () async {
          final video = TestVideo();
          final first = await watchUntilStored(video);
          addTearDown(first.cancel);

          final secondStored = Completer<void>();
          final second = watch(video, stored: secondStored);
          addTearDown(second.cancel);

          await expectLater(
            secondStored.future.timeout(
              relayWaitTimeout,
              onTimeout: _neverToldStoredEnded,
            ),
            completes,
          );
        },
      );

      test('delivers the stored comments to each watch of a video', () async {
        final video = TestVideo();
        final earlier = commenter.comment(video, 'posted before the watches');
        relay.publish(earlier);
        final first = await watchUntilStored(video);
        addTearDown(first.cancel);
        await expectLater(first.waitFor(earlier.id), completes);

        final second = watch(video);
        addTearDown(second.cancel);

        await expectLater(second.waitFor(earlier.id), completes);
      });

      group('when the owner of one watch ends it', () {
        test('keeps a watch on another video live', () async {
          final ended = await watchUntilStored(TestVideo());
          final endedId = relay.requests.single;
          final keptVideo = TestVideo();
          final kept = await watchUntilStored(keptVideo);
          addTearDown(kept.cancel);
          final before = commenter.comment(keptVideo, 'posted before');
          relay.publish(before);
          await expectLater(kept.waitFor(before.id), completes);

          await endOwner(ended);
          final later = commenter.comment(keptVideo, 'posted after');
          relay.publish(later);

          await expectLater(kept.waitFor(later.id), completes);
          expect(relay.closes, equals([endedId]));
        });

        test('keeps another watch of the same video live', () async {
          final video = TestVideo();
          final ended = await watchUntilStored(video);
          final endedId = relay.requests.single;
          final kept = watch(video);
          addTearDown(kept.cancel);
          final before = commenter.comment(video, 'posted before');
          relay.publish(before);
          await expectLater(kept.waitFor(before.id), completes);

          await endOwner(ended);
          final later = commenter.comment(video, 'posted after');
          relay.publish(later);

          await expectLater(kept.waitFor(later.id), completes);
          expect(relay.closes, equals([endedId]));
        });

        test('closes the relay subscription of the ended watch', () async {
          final ended = await watchUntilStored(TestVideo());
          final endedId = relay.requests.single;

          await endOwner(ended);
          await pumpEventQueue();

          expect(relay.closes, equals([endedId]));
        });
      });
    });

    group('watchCommentDeletions', () {
      Received<CommentDeletion> watchDeletions(TestVideo video) => Received(
        repository.watchCommentDeletions(
          rootEventId: video.id,
          commentAuthors: Stream.value({commenter.pubkey}),
        ),
        (deletion) => deletion.commentId,
      );

      group('when the owner of one watch ends it', () {
        test('keeps a deletion watch on another video live', () async {
          final keptVideo = TestVideo();
          final ended = watchDeletions(TestVideo());
          final kept = watchDeletions(keptVideo);
          addTearDown(kept.cancel);
          final before = commenter.comment(keptVideo, 'deleted before');
          relay.publish(commenter.deletion(before.id));
          await expectLater(kept.waitFor(before.id), completes);

          await endOwner(ended);
          final later = commenter.comment(keptVideo, 'deleted after');
          relay.publish(commenter.deletion(later.id));

          await expectLater(kept.waitFor(later.id), completes);
        });

        test('keeps another deletion watch of the same video live', () async {
          final video = TestVideo();
          final ended = watchDeletions(video);
          final kept = watchDeletions(video);
          addTearDown(kept.cancel);
          final before = commenter.comment(video, 'deleted before');
          relay.publish(commenter.deletion(before.id));
          await expectLater(kept.waitFor(before.id), completes);

          await endOwner(ended);
          final later = commenter.comment(video, 'deleted after');
          relay.publish(commenter.deletion(later.id));

          await expectLater(kept.waitFor(later.id), completes);
        });

        test('closes the relay subscription of the ended watch', () async {
          final video = TestVideo();
          final ended = watchDeletions(video);
          final comment = commenter.comment(video, 'deleted');
          relay.publish(commenter.deletion(comment.id));
          await expectLater(ended.waitFor(comment.id), completes);
          final endedId = relay.requests.single;

          await endOwner(ended);
          await pumpEventQueue();

          expect(relay.closes, equals([endedId]));
        });
      });
    });
  });
}
