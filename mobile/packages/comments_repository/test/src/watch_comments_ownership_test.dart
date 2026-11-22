// ABOUTME: Pins that each comments watch owns its relay subscription: its own
// ABOUTME: stored comments and EOSE, and ending it leaves others live (#9690).

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

import '../helpers/in_memory_relay.dart';

/// Loopback with nothing listening, so the relay information lookup the
/// client makes on connect fails at once instead of reaching the network.
const _relayUrl = 'ws://127.0.0.1:1';

const _videoKind = 34236;

/// Bounds every wait, so a regression fails here instead of hanging.
const _timeout = Duration(seconds: 5);

Never _neverToldStoredEnded() =>
    fail('The watch was never told its stored comments ended');

/// A video comments are posted on.
class _Video {
  _Video()
    : id = generatePrivateKey(),
      authorPubkey = getPublicKey(generatePrivateKey());

  final String id;
  final String authorPubkey;
}

/// Someone commenting from another client, straight onto the relay.
class _Commenter {
  _Commenter() : _privateKey = generatePrivateKey();

  final String _privateKey;

  String get pubkey => getPublicKey(_privateKey);

  /// A NIP-22 top-level comment on [video].
  Event comment(_Video video, String text) => Event(pubkey, 1111, [
    ['E', video.id, '', video.authorPubkey],
    ['K', '$_videoKind'],
    ['P', video.authorPubkey],
    ['e', video.id, '', video.authorPubkey],
    ['k', '$_videoKind'],
    ['p', video.authorPubkey],
  ], text)..sign(_privateKey);

  /// A NIP-09 request to delete the comment [commentId].
  Event deletion(String commentId) => Event(pubkey, 5, [
    ['e', commentId],
    ['k', '1111'],
  ], '')..sign(_privateKey);
}

/// Records what a watch has delivered, so a test can wait for one item.
class _Received<T> {
  _Received(Stream<T> stream, this._idOf) {
    _subscription = stream.listen((item) {
      final id = _idOf(item);
      ids.add(id);
      _arrivals.add(id);
    });
  }

  final String Function(T item) _idOf;
  final Set<String> ids = {};
  final StreamController<String> _arrivals = StreamController.broadcast();
  late final StreamSubscription<T> _subscription;

  /// Completes once the watch has delivered the item [id].
  Future<void> waitFor(String id) => ids.contains(id)
      ? Future.value()
      : _arrivals.stream
            .firstWhere((arrived) => arrived == id)
            .timeout(_timeout, onTimeout: () => fail('Never delivered $id'));

  /// Stops listening to the watch, which ends it.
  Future<void> cancel() async {
    await _subscription.cancel();
    await _arrivals.close();
  }
}

void main() {
  group(CommentsRepository, () {
    late InMemoryRelay relay;
    late NostrClient client;
    late CommentsRepository repository;
    late _Commenter commenter;

    setUp(() async {
      relay = InMemoryRelay();
      client = NostrClient(
        config: NostrClientConfig(
          signer: LocalNostrSigner(generatePrivateKey()),
          webSocketChannelFactory: relay,
        ),
        relayManagerConfig: RelayManagerConfig(
          defaultRelayUrl: _relayUrl,
          storage: InMemoryRelayStorage(),
          webSocketChannelFactory: relay,
        ),
      );
      await client.initialize();
      repository = CommentsRepository(nostrClient: client);
      commenter = _Commenter();
    });

    tearDown(() => client.dispose());

    /// Opens a comments watch on [video], reporting its own EOSE to [stored].
    _Received<Comment> watch(_Video video, {Completer<void>? stored}) =>
        _Received(
          repository.watchComments(
            rootEventId: video.id,
            rootEventKind: _videoKind,
            onEose: () {
              if (stored != null && !stored.isCompleted) stored.complete();
            },
          ),
          (comment) => comment.id,
        );

    /// Opens a comments watch on [video] and waits for its own EOSE.
    Future<_Received<Comment>> watchUntilStored(_Video video) async {
      final stored = Completer<void>();
      final received = watch(video, stored: stored);
      await stored.future.timeout(_timeout, onTimeout: _neverToldStoredEnded);
      return received;
    }

    /// Ends [watch] the way its owner does when its comments sheet closes.
    Future<void> endOwner(_Received<Object> watch) => watch.cancel();

    group('watchComments', () {
      test(
        'tells each watch of a video when its stored comments end',
        () async {
          final video = _Video();
          final first = await watchUntilStored(video);
          addTearDown(first.cancel);

          final secondStored = Completer<void>();
          final second = watch(video, stored: secondStored);
          addTearDown(second.cancel);

          await expectLater(
            secondStored.future.timeout(
              _timeout,
              onTimeout: _neverToldStoredEnded,
            ),
            completes,
          );
        },
      );

      test('delivers the stored comments to each watch of a video', () async {
        final video = _Video();
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
          final ended = await watchUntilStored(_Video());
          final endedId = relay.requests.single;
          final keptVideo = _Video();
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
          final video = _Video();
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
          final ended = await watchUntilStored(_Video());
          final endedId = relay.requests.single;

          await endOwner(ended);
          await pumpEventQueue();

          expect(relay.closes, equals([endedId]));
        });
      });
    });

    group('watchCommentDeletions', () {
      _Received<CommentDeletion> watchDeletions(_Video video) => _Received(
        repository.watchCommentDeletions(rootEventId: video.id),
        (deletion) => deletion.commentId,
      );

      group('when the owner of one watch ends it', () {
        test('keeps a deletion watch on another video live', () async {
          final keptVideo = _Video();
          final ended = watchDeletions(_Video());
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
          final video = _Video();
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
          final video = _Video();
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
