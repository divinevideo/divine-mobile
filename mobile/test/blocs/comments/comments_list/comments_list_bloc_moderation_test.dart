// ABOUTME: Tests the video owner's comment moderation in CommentsListBloc
// ABOUTME: (#5044): hidden comments, the reveal toggle, and hide/restore.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockCommentModerationRepository extends Mock
    implements CommentModerationRepository {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _viewer =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _harasser =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _friend =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _rootId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _coordinate = '34236:$_owner:video-dtag';

Comment _comment(
  String id, {
  String authorPubkey = _friend,
  String? replyToEventId,
  String? replyToAuthorPubkey,
  DateTime? createdAt,
}) => Comment(
  id: id,
  content: 'comment $id',
  authorPubkey: authorPubkey,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 12),
  rootEventId: _rootId,
  rootAuthorPubkey: _owner,
  rootAddressableId: _coordinate,
  replyToEventId: replyToEventId,
  replyToAuthorPubkey: replyToAuthorPubkey,
);

void main() {
  group('$CommentsListBloc moderation', () {
    late _MockCommentsRepository commentsRepository;
    late _MockCommentModerationRepository moderationRepository;
    late StreamController<Comment> liveComments;

    final harassment = _comment('harassment', authorPubkey: _harasser);
    final kind = _comment('kind');
    final replyToHarassment = _comment(
      'reply',
      replyToEventId: 'harassment',
      createdAt: DateTime.utc(2026, 1, 1, 13),
    );

    setUp(() {
      commentsRepository = _MockCommentsRepository();
      moderationRepository = _MockCommentModerationRepository();
      liveComments = StreamController<Comment>.broadcast();
      when(
        () => commentsRepository.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => CommentThread(
          rootEventId: _rootId,
          comments: [harassment, kind, replyToHarassment],
          totalCount: 3,
        ),
      );
      when(
        () => commentsRepository.watchComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        final onEose = invocation.namedArguments[#onEose] as void Function()?;
        scheduleMicrotask(() => onEose?.call());
        return liveComments.stream;
      });
      when(
        () => commentsRepository.watchCommentDeletions(
          rootEventId: any(named: 'rootEventId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer((_) => const Stream<CommentDeletion>.empty());
      when(
        () => commentsRepository.findAuthorDeletedComments(any()),
      ).thenAnswer((_) async => <String>{});
      when(commentsRepository.stopWatchingComments).thenAnswer((_) async {});
      when(
        () => moderationRepository.loadModeration(
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenAnswer((_) async => CommentModeration.empty);
    });

    setUpAll(() {
      registerFallbackValue(<Comment>[]);
      registerFallbackValue(_comment('fallback'));
    });

    tearDown(() => liveComments.close());

    CommentsListBloc buildBloc({
      String? viewerPubkey = _viewer,
      Set<String> viewerBlockedAuthors = const {},
      Stream<Set<String>>? viewerBlockedAuthorsChanges,
      String? rootAddressableId = _coordinate,
      bool withModeration = true,
    }) => CommentsListBloc(
      commentsRepository: commentsRepository,
      rootEventId: _rootId,
      rootEventKind: 34236,
      rootAuthorPubkey: _owner,
      rootAddressableId: rootAddressableId,
      commentModerationRepository: withModeration ? moderationRepository : null,
      viewerPubkey: viewerPubkey,
      viewerBlockedAuthors: viewerBlockedAuthors,
      viewerBlockedAuthorsChanges: viewerBlockedAuthorsChanges,
    );

    void ownerHid(CommentModeration moderation) {
      when(
        () =>
            moderationRepository.loadModeration(rootAddressableId: _coordinate),
      ).thenAnswer((_) async => moderation);
    }

    Future<CommentsListBloc> loaded(CommentsListBloc bloc) async {
      bloc.add(const CommentsLoadRequested());
      await bloc.stream.firstWhere((s) => s.status == CommentsStatus.success);
      return bloc;
    }

    List<String> shownIds(CommentsListState state) => [
      for (final node in state.displayCommentsWith()) node.comment.id,
    ];

    group('block snapshots', () {
      test(
        'retains a block snapshot received during the initial read',
        () async {
          final blocks = StreamController<Set<String>>.broadcast();
          addTearDown(blocks.close);
          final read = Completer<CommentModeration>();
          when(
            () => moderationRepository.loadModeration(
              rootAddressableId: _coordinate,
            ),
          ).thenAnswer((_) => read.future);
          final bloc = buildBloc(
            viewerPubkey: _owner,
            viewerBlockedAuthorsChanges: blocks.stream,
          );
          addTearDown(bloc.close);
          bloc.add(const CommentsLoadRequested());
          await bloc.stream.firstWhere(
            (s) => s.status == CommentsStatus.loading,
          );
          final hydrated = bloc.stream.firstWhere(
            (s) => s.viewerBlockedAuthors.contains(_harasser),
          );
          blocks.add({_harasser});
          await hydrated;
          final success = bloc.stream.firstWhere(
            (s) => s.status == CommentsStatus.success,
          );
          read.complete(CommentModeration.empty);
          await success;
          expect(bloc.state.isHiddenByOwner(harassment), isTrue);
        },
      );

      test('hides late blocks without reopening the owner thread', () async {
        final blocks = StreamController<Set<String>>.broadcast();
        addTearDown(blocks.close);
        final bloc = await loaded(
          buildBloc(
            viewerPubkey: _owner,
            viewerBlockedAuthorsChanges: blocks.stream,
          ),
        );
        addTearDown(bloc.close);
        expect(bloc.state.isHiddenByOwner(harassment), isFalse);
        final changed = bloc.stream.firstWhere(
          (s) => s.hiddenCommentCount == 1,
        );
        blocks.add({_harasser});
        await changed;
        expect(bloc.state.isHiddenByOwner(harassment), isTrue);
      });

      for (final fails in [false, true]) {
        test(
          'keeps an unblock across a pending hide; failure: $fails',
          () async {
            final blocks = StreamController<Set<String>>.broadcast();
            addTearDown(blocks.close);
            final save = Completer<void>();
            when(
              () => moderationRepository.hideComment(
                rootAddressableId: any(named: 'rootAddressableId'),
                comment: any(named: 'comment'),
              ),
            ).thenAnswer((_) => save.future);
            ownerHid(const CommentModeration(autoHiddenAuthors: {_harasser}));
            final bloc = await loaded(
              buildBloc(
                viewerPubkey: _owner,
                viewerBlockedAuthors: {_harasser},
                viewerBlockedAuthorsChanges: blocks.stream,
              ),
            );
            addTearDown(bloc.close);
            expect(bloc.state.isHiddenByOwner(harassment), isTrue);
            final hidden = bloc.stream.firstWhere(
              (s) => s.isHiddenByOwner(kind),
            );
            bloc.add(CommentModerationRequested(kind, hide: true));
            await hidden;
            final unblocked = bloc.stream.firstWhere(
              (s) => s.viewerBlockedAuthors.isEmpty,
            );
            blocks.add({});
            await unblocked;
            if (fails) {
              save.completeError(
                const CommentModerationFailedException('synthetic'),
              );
            } else {
              save.complete();
            }
            await pumpEventQueue();
            expect(bloc.state.isHiddenByOwner(harassment), isFalse);
            expect(bloc.state.isHiddenByOwner(kind), !fails);
          },
        );
      }
    });

    group('CommentsLoadRequested', () {
      test(
        'leaves out comments the owner hid and keeps replies to them',
        () async {
          ownerHid(const CommentModeration(autoHiddenAuthors: {_harasser}));
          final bloc = await loaded(buildBloc());
          addTearDown(bloc.close);

          expect(bloc.state.hiddenCommentCount, 1);
          expect(bloc.state.commentsById, hasLength(3));
          expect(shownIds(bloc.state), unorderedEquals(['kind', 'reply']));
          // The orphaned reply is promoted to the top level.
          expect(
            bloc.state.displayCommentsWith().map((node) => node.depth),
            everyElement(0),
          );
        },
      );

      test('shows everything when the owner hid nothing', () async {
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);

        expect(bloc.state.hiddenCommentCount, 0);
        expect(
          shownIds(bloc.state),
          unorderedEquals(['harassment', 'reply', 'kind']),
        );
      });

      test('never hides a comment from its own author', () async {
        ownerHid(const CommentModeration(autoHiddenAuthors: {_harasser}));
        final bloc = await loaded(buildBloc(viewerPubkey: _harasser));
        addTearDown(bloc.close);

        expect(bloc.state.hiddenCommentCount, 0);
        expect(shownIds(bloc.state), contains('harassment'));
      });

      test(
        'hides the comments of people the owner blocked, for the owner',
        () async {
          final bloc = await loaded(
            buildBloc(viewerPubkey: _owner, viewerBlockedAuthors: {_harasser}),
          );
          addTearDown(bloc.close);

          expect(bloc.state.isViewerRootAuthor, isTrue);
          expect(bloc.state.isHiddenByOwner(harassment), isTrue);
          expect(shownIds(bloc.state), isNot(contains('harassment')));
        },
      );

      test("ignores a viewer's blocks on someone else's video", () async {
        final bloc = await loaded(
          buildBloc(viewerBlockedAuthors: {_harasser}),
        );
        addTearDown(bloc.close);

        expect(bloc.state.isHiddenByOwner(harassment), isFalse);
      });

      test('skips the moderation read without a video coordinate', () async {
        final bloc = await loaded(
          buildBloc(
            viewerPubkey: _owner,
            viewerBlockedAuthors: {_harasser},
            rootAddressableId: null,
          ),
        );
        addTearDown(bloc.close);

        verifyNever(
          () => moderationRepository.loadModeration(
            rootAddressableId: any(named: 'rootAddressableId'),
          ),
        );
        expect(bloc.state.isHiddenByOwner(harassment), isTrue);
      });

      test('works without a moderation repository', () async {
        final bloc = await loaded(buildBloc(withModeration: false));
        addTearDown(bloc.close);

        expect(bloc.state.moderation, CommentModeration.empty);
        expect(bloc.state.hiddenCommentCount, 0);
      });
    });

    group('HiddenCommentsVisibilityToggled', () {
      test('shows the hidden comments and hides them again', () async {
        ownerHid(const CommentModeration(hiddenCommentIds: {'harassment'}));
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);

        bloc.add(const HiddenCommentsVisibilityToggled());
        await pumpEventQueue();
        expect(bloc.state.showHiddenComments, isTrue);
        expect(shownIds(bloc.state), contains('harassment'));
        // The reply nests under its parent again in Recent.
        bloc.add(const CommentsSortModeChanged(CommentsSortMode.newest));
        await pumpEventQueue();
        expect(
          bloc.state.displayCommentsWith().singleWhere(
            (node) => node.comment.id == 'reply',
          ),
          isA<CommentNode>().having((node) => node.depth, 'depth', 1),
        );

        bloc.add(const HiddenCommentsVisibilityToggled());
        await pumpEventQueue();
        expect(bloc.state.showHiddenComments, isFalse);
        expect(shownIds(bloc.state), isNot(contains('harassment')));
      });
    });

    group('CommentModerationRequested', () {
      test('hides the comment at once and saves it', () async {
        when(
          () => moderationRepository.hideComment(
            rootAddressableId: any(named: 'rootAddressableId'),
            comment: any(named: 'comment'),
          ),
        ).thenAnswer((_) async {});
        final bloc = await loaded(buildBloc(viewerPubkey: _owner));
        addTearDown(bloc.close);

        bloc.add(CommentModerationRequested(kind, hide: true));
        await pumpEventQueue();

        expect(bloc.state.isHiddenByOwner(kind), isTrue);
        verify(
          () => moderationRepository.hideComment(
            rootAddressableId: _coordinate,
            comment: kind,
          ),
        ).called(1);
      });

      test('restores a comment by someone the owner blocked', () async {
        when(
          () => moderationRepository.restoreComment(
            rootAddressableId: any(named: 'rootAddressableId'),
            comment: any(named: 'comment'),
            authorAutoHidden: any(named: 'authorAutoHidden'),
          ),
        ).thenAnswer((_) async {});
        final bloc = await loaded(
          buildBloc(viewerPubkey: _owner, viewerBlockedAuthors: {_harasser}),
        );
        addTearDown(bloc.close);

        bloc.add(CommentModerationRequested(harassment, hide: false));
        await pumpEventQueue();

        expect(bloc.state.isHiddenByOwner(harassment), isFalse);
        verify(
          () => moderationRepository.restoreComment(
            rootAddressableId: _coordinate,
            comment: harassment,
            authorAutoHidden: true,
          ),
        ).called(1);
      });

      test('takes the hide back and reports a failed save', () async {
        when(
          () => moderationRepository.hideComment(
            rootAddressableId: any(named: 'rootAddressableId'),
            comment: any(named: 'comment'),
          ),
        ).thenThrow(const CommentModerationFailedException('offline'));
        final bloc = await loaded(buildBloc(viewerPubkey: _owner));
        addTearDown(bloc.close);

        bloc.add(CommentModerationRequested(kind, hide: true));
        await pumpEventQueue();

        expect(bloc.state.isHiddenByOwner(kind), isFalse);
        expect(bloc.state.error, CommentsListError.moderationFailed);
      });

      test('takes the hide back after an unexpected failure', () async {
        when(
          () => moderationRepository.hideComment(
            rootAddressableId: any(named: 'rootAddressableId'),
            comment: any(named: 'comment'),
          ),
        ).thenThrow(StateError('No public key available'));
        final bloc = await loaded(buildBloc(viewerPubkey: _owner));
        addTearDown(bloc.close);

        bloc.add(CommentModerationRequested(kind, hide: true));
        await pumpEventQueue();

        expect(bloc.state.isHiddenByOwner(kind), isFalse);
        expect(bloc.state.error, CommentsListError.moderationFailed);
      });

      test('puts the hidden comments away after a new hide', () async {
        when(
          () => moderationRepository.hideComment(
            rootAddressableId: any(named: 'rootAddressableId'),
            comment: any(named: 'comment'),
          ),
        ).thenAnswer((_) async {});
        ownerHid(const CommentModeration(hiddenCommentIds: {'reply'}));
        final bloc = await loaded(buildBloc(viewerPubkey: _owner));
        addTearDown(bloc.close);
        bloc.add(const HiddenCommentsVisibilityToggled());
        await pumpEventQueue();
        expect(bloc.state.showHiddenComments, isTrue);

        bloc.add(CommentModerationRequested(kind, hide: true));
        await pumpEventQueue();

        expect(bloc.state.showHiddenComments, isFalse);
        expect(shownIds(bloc.state), ['harassment']);
      });

      test('resets the toggle once nothing is hidden', () async {
        when(
          () => moderationRepository.restoreComment(
            rootAddressableId: any(named: 'rootAddressableId'),
            comment: any(named: 'comment'),
            authorAutoHidden: any(named: 'authorAutoHidden'),
          ),
        ).thenAnswer((_) async {});
        ownerHid(const CommentModeration(hiddenCommentIds: {'kind'}));
        final bloc = await loaded(buildBloc(viewerPubkey: _owner));
        addTearDown(bloc.close);
        bloc.add(const HiddenCommentsVisibilityToggled());
        await pumpEventQueue();
        expect(bloc.state.showHiddenComments, isTrue);

        bloc.add(CommentModerationRequested(kind, hide: false));
        await pumpEventQueue();

        expect(bloc.state.hiddenCommentCount, 0);
        expect(bloc.state.showHiddenComments, isFalse);
      });

      test('lets only the owner moderate', () async {
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);

        bloc.add(CommentModerationRequested(kind, hide: true));
        await pumpEventQueue();

        expect(bloc.state.isHiddenByOwner(kind), isFalse);
        verifyNever(
          () => moderationRepository.hideComment(
            rootAddressableId: any(named: 'rootAddressableId'),
            comment: any(named: 'comment'),
          ),
        );
      });
    });

    group('shownAuthorPubkeys', () {
      test('suggests no author whose comments the owner hid', () async {
        ownerHid(const CommentModeration(autoHiddenAuthors: {_harasser}));
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);

        expect(bloc.state.shownAuthorPubkeys, isNot(contains(_harasser)));
        expect(bloc.state.shownAuthorPubkeys, contains(_friend));
      });
    });

    group('repliesToHiddenComment', () {
      test("leaves out a hidden comment's author until it is shown", () async {
        ownerHid(const CommentModeration(autoHiddenAuthors: {_harasser}));
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);

        expect(bloc.state.repliesToHiddenComment(replyToHarassment), isTrue);
        expect(
          bloc.state.repliesToHiddenComment(
            _comment('to-kind', replyToEventId: 'kind'),
          ),
          isFalse,
        );

        bloc.add(const HiddenCommentsVisibilityToggled());
        await pumpEventQueue();

        expect(bloc.state.repliesToHiddenComment(replyToHarassment), isFalse);
      });

      test('leaves out a hidden author whose comment is not loaded', () async {
        ownerHid(const CommentModeration(autoHiddenAuthors: {_harasser}));
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);

        expect(
          bloc.state.repliesToHiddenComment(
            _comment(
              'to-missing',
              replyToEventId: 'missing',
              replyToAuthorPubkey: _harasser,
            ),
          ),
          isTrue,
        );
        expect(
          bloc.state.repliesToHiddenComment(
            _comment(
              'to-missing-friend',
              replyToEventId: 'missing',
              replyToAuthorPubkey: _friend,
            ),
          ),
          isFalse,
        );
      });
    });

    group('CommentsRemovedByAuthorFromStore', () {
      test(
        "hides a blocked author's comments on the owner's own video",
        () async {
          final bloc = await loaded(buildBloc(viewerPubkey: _owner));
          addTearDown(bloc.close);

          bloc.add(const CommentsRemovedByAuthorFromStore(_harasser));
          await pumpEventQueue();

          expect(bloc.state.commentsById, contains('harassment'));
          expect(bloc.state.isHiddenByOwner(harassment), isTrue);
        },
      );

      test(
        'leaves the thread clean while hidden comments were shown',
        () async {
          ownerHid(const CommentModeration(hiddenCommentIds: {'kind'}));
          final bloc = await loaded(buildBloc(viewerPubkey: _owner));
          addTearDown(bloc.close);
          bloc.add(const HiddenCommentsVisibilityToggled());
          await pumpEventQueue();

          bloc.add(const CommentsRemovedByAuthorFromStore(_harasser));
          await pumpEventQueue();

          expect(bloc.state.showHiddenComments, isFalse);
          expect(shownIds(bloc.state), isNot(contains('harassment')));
        },
      );

      test("removes them on someone else's video", () async {
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);

        bloc.add(const CommentsRemovedByAuthorFromStore(_harasser));
        await pumpEventQueue();

        expect(bloc.state.commentsById, isNot(contains('harassment')));
      });

      test(
        'puts the hidden comments away once the last one is removed',
        () async {
          ownerHid(
            const CommentModeration(
              hiddenCommentIds: {'later'},
              autoHiddenAuthors: {_harasser},
            ),
          );
          final bloc = await loaded(buildBloc());
          addTearDown(bloc.close);
          await bloc.stream.firstWhere((s) => s.isBackfillComplete);
          bloc.add(const HiddenCommentsVisibilityToggled());
          await pumpEventQueue();
          expect(bloc.state.showHiddenComments, isTrue);

          // The viewer blocks the author of the only hidden comment.
          bloc.add(const CommentsRemovedByAuthorFromStore(_harasser));
          await pumpEventQueue();
          // A comment the owner hid arrives later.
          bloc.add(NewCommentsBatchReceived([_comment('later')]));
          await pumpEventQueue();

          expect(bloc.state.showHiddenComments, isFalse);
          expect(shownIds(bloc.state), isNot(contains('later')));
        },
      );
    });

    group('NewCommentsBatchReceived', () {
      test('does not announce a live comment the owner hid', () async {
        ownerHid(const CommentModeration(autoHiddenAuthors: {_harasser}));
        final bloc = await loaded(buildBloc());
        addTearDown(bloc.close);
        await bloc.stream.firstWhere((s) => s.isBackfillComplete);

        bloc.add(
          NewCommentsBatchReceived([
            _comment('hidden-live', authorPubkey: _harasser),
            _comment('visible-live'),
          ]),
        );
        await pumpEventQueue();

        expect(bloc.state.newCommentIds, {'visible-live'});
        expect(bloc.state.commentsById, contains('hidden-live'));
      });
    });
  });
}
