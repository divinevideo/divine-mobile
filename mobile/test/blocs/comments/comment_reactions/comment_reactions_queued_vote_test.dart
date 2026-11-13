// ABOUTME: Regression tests for #10922: a comment vote the repository queued
// ABOUTME: instead of publishing must stay in the displayed vote total. Drives
// ABOUTME: CommentReactionsBloc over a real LikesRepository and a fake relay.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

String _hex(String suffix) => suffix.codeUnits
    .map((c) => c.toRadixString(16).padLeft(2, '0'))
    .join()
    .padLeft(64, '0');

final String _me = _hex('me');
final String _other = _hex('other');
final String _otherTwo = _hex('other2');
final String _author = _hex('author');
final String _comment = _hex('comment');

/// How the relay check behind [LikesRepository.likeEvent] ends.
enum _Check { conclusive, inconclusive }

/// A relay held in memory, reached through a mocked [NostrClient].
class _Relay {
  _Relay(this.client) {
    when(() => client.publicKey).thenReturn(_me);
    when(() => client.hasKeys).thenReturn(true);
    when(client.resolvePublicKey).thenAnswer((_) async => _me);
    when(
      () => client.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(() => client.unsubscribe(any())).thenAnswer((_) async {});
    when(() => client.queryEvents(any())).thenAnswer(
      (invocation) => _query(invocation.positionalArguments.first as List),
    );
    when(
      () => client.readEvents(
        any(),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((invocation) async {
      final filters = invocation.positionalArguments.first as List;
      return QueryResult(
        events: _matching(filters.cast<Filter>()),
        endedBy: check == _Check.conclusive
            ? QueryEnd.complete
            : QueryEnd.deadline,
      );
    });
    when(
      () => client.sendLike(
        any(),
        content: any(named: 'content'),
        addressableId: any(named: 'addressableId'),
        targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
        targetKind: any(named: 'targetKind'),
      ),
    ).thenAnswer((invocation) async {
      if (publishFails) throw Exception('relay pool unavailable');
      final reaction = _reaction(
        _me,
        invocation.positionalArguments.first as String,
        content: invocation.namedArguments[#content] as String,
      );
      events.add(reaction);
      return reaction;
    });
    when(() => client.deleteEvent(any())).thenAnswer((invocation) async {
      if (publishFails) throw Exception('relay pool unavailable');
      final deletion = Event(_me, EventKind.eventDeletion, [
        ['e', invocation.positionalArguments.first as String],
      ], '');
      events.add(deletion);
      return deletion;
    });
  }

  final _MockNostrClient client;
  final List<Event> events = <Event>[];
  _Check check = _Check.conclusive;
  bool publishFails = false;

  /// When set, every read of one account's own reactions fails.
  bool failViewerReads = false;

  /// When set, the viewer's own reaction read waits for it.
  Completer<void>? holdViewerRead;

  /// When set, the read of every account's reactions waits for it.
  Completer<void>? holdCountRead;

  var _createdAt = 1700000000;

  Event _reaction(String pubkey, String target, {String content = '+'}) =>
      Event(
        pubkey,
        EventKind.reaction,
        [
          ['e', target],
          ['p', _author],
          ['k', '${EventKind.comment}'],
        ],
        content,
        createdAt: _createdAt++,
      );

  void seedUpvote(String pubkey) => events.add(_reaction(pubkey, _comment));

  void seedDownvote(String pubkey) =>
      events.add(_reaction(pubkey, _comment, content: '-'));

  /// Reaction reads that asked about [_comment].
  int commentReads = 0;

  Future<List<Event>> _query(List<dynamic> filters) async {
    final typed = filters.cast<Filter>();
    if (typed.any(
      (f) =>
          (f.kinds ?? const []).contains(EventKind.reaction) &&
          (f.e?.contains(_comment) ?? false),
    )) {
      commentReads++;
    }
    final reactionRead = typed.any(
      (f) => (f.kinds ?? const []).contains(EventKind.reaction),
    );
    final viewerRead = typed.any((f) => f.authors?.isNotEmpty ?? false);
    if (viewerRead && failViewerReads) throw Exception('relay timed out');
    final hold = !reactionRead
        ? null
        : viewerRead
        ? holdViewerRead
        : holdCountRead;
    if (hold != null) await hold.future;
    return _matching(typed);
  }

  List<Event> _matching(List<Filter> filters) => [
    for (final event in events)
      if (filters.any((f) => _matches(f, event))) event,
  ];

  static bool _matches(Filter filter, Event event) {
    final kinds = filter.kinds;
    if (kinds != null && !kinds.contains(event.kind)) return false;
    final authors = filter.authors;
    if (authors != null && !authors.contains(event.pubkey)) return false;
    final e = filter.e;
    if (e != null) {
      final tagged = event.tags
          .where((t) => t.length > 1 && t[0] == 'e')
          .map((t) => t[1]);
      if (!tagged.any(e.contains)) return false;
    }
    return true;
  }
}

void main() {
  group('CommentReactionsBloc with a queued vote (#10922)', () {
    late _Relay relay;
    late LikesRepository likes;
    late _MockAuthService auth;
    late bool online;
    late List<bool> queued;
    late List<QueuedLikeAction> queue;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      relay = _Relay(_MockNostrClient());
      online = true;
      queued = [];
      queue = [];
      likes = LikesRepository(
        nostrClient: relay.client,
        isOnline: () => online,
        // Mirrors PendingActionService.queueAction: an action cancels the
        // opposite one still waiting on the same target.
        queueOfflineAction:
            ({
              required isLike,
              required eventId,
              required authorPubkey,
              addressableId,
              targetKind,
            }) async {
              queued.add(isLike);
              final opposite = queue.indexWhere(
                (a) => a.eventId == eventId && a.isLike != isLike,
              );
              if (opposite >= 0) {
                queue.removeAt(opposite);
              } else {
                queue.add((eventId: eventId, isLike: isLike));
              }
            },
        queuedLikeActions: () async => List.of(queue),
      );
      auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_me);
    });

    tearDown(() => likes.dispose());

    CommentReactionsBloc openSheet() => CommentReactionsBloc(
      authService: auth,
      likesRepository: likes,
      commentsRepository: _MockCommentsRepository(),
      contentBlocklistRepository: _MockContentBlocklistRepository(),
      rootEventId: _hex('root'),
    );

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
      }
    }

    /// Loads the totals, then holds the viewer-vote read so it overlaps the
    /// tap: the totals are known, and the read is still in flight.
    Future<CommentReactionsBloc> openWithOverlappingRead() async {
      final bloc = openSheet();
      relay.holdViewerRead = Completer<void>();
      bloc.add(const CommentVoteCountsFetchRequested([]));
      bloc.add(CommentVoteCountsFetchRequested([_comment]));
      await settle();
      return bloc;
    }

    void upvote(CommentReactionsBloc bloc) => bloc.add(
      CommentVoteToggled(
        commentId: _comment,
        authorPubkey: _author,
        vote: Vote.up,
      ),
    );

    Future<void> releaseRead() async {
      relay.holdViewerRead?.complete();
      relay.holdViewerRead = null;
      relay.holdCountRead?.complete();
      relay.holdCountRead = null;
      await settle();
    }

    void expectShown(
      CommentReactionsBloc bloc, {
      required bool upvoted,
      required int count,
    }) {
      expect(
        bloc.state.upvotedCommentIds.contains(_comment),
        upvoted,
        reason: 'arrow',
      );
      expect(bloc.state.commentUpvoteCounts[_comment], count, reason: 'count');
    }

    group('like', () {
      setUp(() {
        relay
          ..seedUpvote(_other)
          ..seedUpvote(_otherTwo);
      });

      test('control: a published like stays in the refreshed total', () async {
        final bloc = await openWithOverlappingRead();
        expect(bloc.state.commentUpvoteCounts[_comment], 2);

        upvote(bloc);
        await settle();
        await releaseRead();

        expect(queued, isEmpty);
        expectShown(bloc, upvoted: true, count: 3);
        await bloc.close();
      });

      test('queued offline, read overlapping the tap', () async {
        final bloc = await openWithOverlappingRead();
        expect(bloc.state.commentUpvoteCounts[_comment], 2);
        online = false;

        upvote(bloc);
        await settle();
        await releaseRead();

        expect(queued, [true]);
        expectShown(bloc, upvoted: true, count: 3);
        await bloc.close();
      });

      test('queued offline, total unknown at the tap', () async {
        final bloc = openSheet();
        online = false;

        upvote(bloc);
        await settle();

        expect(queued, [true]);
        expectShown(bloc, upvoted: true, count: 3);
        await bloc.close();
      });

      test('control: published, total unknown at the tap', () async {
        final bloc = openSheet();

        upvote(bloc);
        await settle();

        expect(queued, isEmpty);
        expectShown(bloc, upvoted: true, count: 3);
        await bloc.close();
      });

      test('queued after an inconclusive relay check', () async {
        final bloc = await openWithOverlappingRead();
        relay.check = _Check.inconclusive;

        upvote(bloc);
        await settle();
        await releaseRead();

        expect(queued, [true]);
        expectShown(bloc, upvoted: true, count: 3);
        await bloc.close();
      });

      test('queued after the online publish failed', () async {
        final bloc = await openWithOverlappingRead();
        relay.publishFails = true;

        upvote(bloc);
        await settle();
        await releaseRead();

        expect(queued, [true]);
        expectShown(bloc, upvoted: true, count: 3);
        await bloc.close();
      });

      test('reopening the sheet while the like is queued', () async {
        final first = openSheet();
        online = false;
        upvote(first);
        await settle();
        await first.close();
        expect(queued, [true]);

        final reopened = openSheet();
        reopened.add(CommentVoteCountsFetchRequested([_comment]));
        await settle();

        expectShown(reopened, upvoted: true, count: 3);
        await reopened.close();
      });

      test('control: reopening the sheet after the like published', () async {
        final first = openSheet();
        upvote(first);
        await settle();
        await first.close();

        final reopened = openSheet();
        reopened.add(CommentVoteCountsFetchRequested([_comment]));
        await settle();

        expectShown(reopened, upvoted: true, count: 3);
        await reopened.close();
      });
    });

    group('unlike', () {
      setUp(() {
        relay.seedUpvote(_other);
      });

      /// Likes online so the repository holds a published record, then opens
      /// a fresh sheet whose arrow has loaded while its totals read is still
      /// in flight at the next tap.
      Future<CommentReactionsBloc> likedThenReopened() async {
        final first = openSheet();
        upvote(first);
        await settle();
        await first.close();
        final bloc = openSheet();
        relay.holdCountRead = Completer<void>();
        bloc.add(CommentVoteCountsFetchRequested([_comment]));
        await settle();
        expect(bloc.state.upvotedCommentIds, contains(_comment));
        expect(bloc.state.commentUpvoteCounts[_comment], isNull);
        return bloc;
      }

      test('control: a published unlike leaves the refreshed total', () async {
        final bloc = await likedThenReopened();

        upvote(bloc);
        await settle();
        await releaseRead();

        expect(queued, isEmpty);
        expectShown(bloc, upvoted: false, count: 1);
        await bloc.close();
      });

      test('queued offline, read overlapping the tap', () async {
        final bloc = await likedThenReopened();
        online = false;

        upvote(bloc);
        await settle();
        await releaseRead();

        expect(queued, [false]);
        expectShown(bloc, upvoted: false, count: 1);
        await bloc.close();
      });

      test('queued after the online publish failed', () async {
        final bloc = await likedThenReopened();
        relay.publishFails = true;

        upvote(bloc);
        await settle();
        await releaseRead();

        expect(queued, [false]);
        expectShown(bloc, upvoted: false, count: 1);
        await bloc.close();
      });
    });

    group('when the queue gives up on the vote', () {
      setUp(() => relay.seedUpvote(_other));

      Future<CommentReactionsBloc> openLoaded() async {
        final bloc = openSheet()
          ..add(CommentVoteCountsFetchRequested([_comment]));
        await settle();
        return bloc;
      }

      test('the open sheet drops a like that never published', () async {
        final bloc = await openLoaded();
        online = false;
        upvote(bloc);
        await settle();
        expectShown(bloc, upvoted: true, count: 2);

        queue.clear();
        await likes.abandonLikeAction(_comment);
        await settle();

        expectShown(bloc, upvoted: false, count: 1);
        await bloc.close();
      });

      test(
        'the open sheet restores a like whose unlike never published',
        () async {
          final first = openSheet();
          upvote(first);
          await settle();
          await first.close();
          final bloc = await openLoaded();
          online = false;
          upvote(bloc);
          await settle();
          expectShown(bloc, upvoted: false, count: 1);

          queue.clear();
          await likes.abandonUnlikeAction(_comment);
          await settle();

          expectShown(bloc, upvoted: true, count: 2);
          await bloc.close();
        },
      );

      test(
        'control: a vote the sheet itself casts is not read again',
        () async {
          final bloc = await openLoaded();
          final readsBefore = relay.commentReads;
          expect(readsBefore, greaterThan(0));
          online = false;

          upvote(bloc);
          await settle();

          expectShown(bloc, upvoted: true, count: 2);
          expect(relay.commentReads, equals(readsBefore));
          await bloc.close();
        },
      );

      test('control: liking something else does not read the sheet', () async {
        final bloc = await openLoaded();
        final readsBefore = relay.commentReads;
        expect(readsBefore, greaterThan(0));

        await likes.likeEvent(eventId: _hex('video'), authorPubkey: _author);
        await settle();

        expect(relay.commentReads, equals(readsBefore));
        await bloc.close();
      });
    });

    group('a tap on a vote the sheet did not load', () {
      /// Opens a sheet whose read of the viewer's own votes failed, so the
      /// arrows are empty while the totals are known.
      Future<CommentReactionsBloc> openWithoutViewerVotes() async {
        relay.failViewerReads = true;
        final bloc = openSheet()
          ..add(CommentVoteCountsFetchRequested([_comment]));
        await settle();
        relay.failViewerReads = false;
        return bloc;
      }

      void downvote(CommentReactionsBloc bloc) => bloc.add(
        CommentVoteToggled(
          commentId: _comment,
          authorPubkey: _author,
          vote: Vote.down,
        ),
      );

      test('counts an upvote the relay already holds once', () async {
        relay
          ..seedUpvote(_other)
          ..seedUpvote(_me);
        final bloc = await openWithoutViewerVotes();
        expectShown(bloc, upvoted: false, count: 2);

        upvote(bloc);
        await settle();

        expectShown(bloc, upvoted: true, count: 2);
        await bloc.close();
      });

      test(
        'takes the extra upvote back before the total is read again',
        () async {
          relay
            ..seedUpvote(_other)
            ..seedUpvote(_me);
          final bloc = await openWithoutViewerVotes();
          relay.holdCountRead = Completer<void>();

          upvote(bloc);
          await settle();

          expectShown(bloc, upvoted: true, count: 2);
          await releaseRead();
          expectShown(bloc, upvoted: true, count: 2);
          await bloc.close();
        },
      );

      test(
        'reads the total again when the upvote landed after the sheet loaded',
        () async {
          relay.seedUpvote(_other);
          final bloc = await openWithoutViewerVotes();
          expectShown(bloc, upvoted: false, count: 1);
          relay.seedUpvote(_me);

          upvote(bloc);
          await settle();

          expectShown(bloc, upvoted: true, count: 2);
          await bloc.close();
        },
      );

      test('control: counts an upvote the relay did not hold', () async {
        relay.seedUpvote(_other);
        final bloc = await openWithoutViewerVotes();
        expectShown(bloc, upvoted: false, count: 1);

        upvote(bloc);
        await settle();

        expectShown(bloc, upvoted: true, count: 2);
        await bloc.close();
      });

      test('counts a downvote this device already holds once', () async {
        relay.seedDownvote(_other);
        final first = openSheet();
        downvote(first);
        await settle();
        await first.close();
        final bloc = await openWithoutViewerVotes();
        expect(bloc.state.downvotedCommentIds, isNot(contains(_comment)));
        expect(bloc.state.commentDownvoteCounts[_comment], 2);

        downvote(bloc);
        await settle();

        expect(bloc.state.downvotedCommentIds, contains(_comment));
        expect(bloc.state.commentDownvoteCounts[_comment], 2);
        await bloc.close();
      });

      test('control: counts a downvote the relay did not hold', () async {
        relay.seedDownvote(_other);
        final bloc = await openWithoutViewerVotes();
        expect(bloc.state.commentDownvoteCounts[_comment], 1);

        downvote(bloc);
        await settle();

        expect(bloc.state.downvotedCommentIds, contains(_comment));
        expect(bloc.state.commentDownvoteCounts[_comment], 2);
        await bloc.close();
      });
    });
  });
}
