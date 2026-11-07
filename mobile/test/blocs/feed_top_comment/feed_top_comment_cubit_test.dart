// ABOUTME: Tests for FeedTopCommentCubit — top-comment selection with the Top
// ABOUTME: ordering, the empty case, failures, and overlay visibility.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentModerationRepository extends Mock
    implements CommentModerationRepository {}

const _rootId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _creator =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _alice =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _bob = '4444444444444444444444444444444444444444444444444444444444444444';

final _now = DateTime(2026, 10, 28, 12);

Comment _comment(
  String id, {
  String content = 'hello',
  String author = _alice,
  Duration age = const Duration(hours: 1),
  String? replyToEventId,
  String? replyToAuthorPubkey,
  String? videoUrl,
  String? addressableId,
}) => Comment(
  id: id,
  addressableId: addressableId,
  content: content,
  authorPubkey: author,
  createdAt: _now.subtract(age),
  rootEventId: _rootId,
  rootAuthorPubkey: _creator,
  replyToEventId: replyToEventId,
  replyToAuthorPubkey: replyToAuthorPubkey,
  videoUrl: videoUrl,
);

void main() {
  group(FeedTopCommentCubit, () {
    late _MockCommentsRepository commentsRepository;
    late _MockLikesRepository likesRepository;
    late _MockCommentModerationRepository moderationRepository;
    late StreamController<void> loops;

    void stubModeration(CommentModeration moderation, {int revision = 0}) {
      when(
        () => moderationRepository.loadModeration(
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenAnswer((_) async => moderation);
      when(
        () => moderationRepository.knownModeration(
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenReturn((moderation: moderation, revision: revision));
    }

    setUp(() {
      commentsRepository = _MockCommentsRepository();
      likesRepository = _MockLikesRepository();
      moderationRepository = _MockCommentModerationRepository();
      stubModeration(CommentModeration.empty);
      loops = StreamController<void>.broadcast();
    });

    tearDown(() => loops.close());

    void stubComments(List<Comment> comments) {
      when(
        () => commentsRepository.findAuthorDeletedComments(any()),
      ).thenAnswer((_) async => <String>{});
      when(
        () => commentsRepository.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => CommentThread(rootEventId: _rootId, comments: comments),
      );
    }

    void stubUpvotes(Map<String, int> upvotes) {
      when(
        () => likesRepository.getVoteCounts(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer(
        (_) async => (upvotes: upvotes, downvotes: const <String, int>{}),
      );
    }

    FeedTopCommentCubit buildCubit({
      String? rootAddressableId,
      String? viewerPubkey,
      Set<String> viewerBlockedAuthors = const {},
    }) => FeedTopCommentCubit(
      commentsRepository: commentsRepository,
      likesRepository: likesRepository,
      commentModerationRepository: moderationRepository,
      viewerPubkey: viewerPubkey,
      viewerBlockedAuthors: viewerBlockedAuthors,
      rootEventId: _rootId,
      rootEventKind: 34236,
      rootAuthorPubkey: _creator,
      rootAddressableId: rootAddressableId,
      loopCompletions: loops.stream,
      now: () => _now,
    );

    group('load', () {
      group('creator moderation', () {
        const root = '34236:$_creator:root';

        test('ranks only the default-visible comments', () async {
          stubComments([_comment(_alice), _comment(_bob, author: _bob)]);
          stubUpvotes({_alice: 20, _bob: 1});
          stubModeration(const CommentModeration(hiddenCommentIds: {_alice}));
          final cubit = buildCubit(rootAddressableId: root);
          addTearDown(cubit.close);
          await cubit.load();
          expect(cubit.state.topComment?.id, _bob);
          verify(
            () => likesRepository.getVoteCounts([
              _alice,
              _bob,
            ], addressableIds: any(named: 'addressableIds')),
          ).called(1);
        });

        test('keeps an explicitly restored comment eligible', () async {
          stubComments([_comment(_alice), _comment(_bob, author: _bob)]);
          stubUpvotes({_alice: 20, _bob: 1});
          stubModeration(
            const CommentModeration(
              autoHiddenAuthors: {_alice},
              restoredCommentIds: {_alice},
            ),
          );
          final cubit = buildCubit(rootAddressableId: root);
          addTearDown(cubit.close);
          await cubit.load();
          expect(cubit.state.topComment?.id, _alice);
        });

        test(
          'keeps the author view consistent with the comment sheet',
          () async {
            stubComments([_comment(_alice)]);
            stubUpvotes({_alice: 20});
            stubModeration(const CommentModeration(hiddenCommentIds: {_alice}));
            final cubit = buildCubit(
              rootAddressableId: root,
              viewerPubkey: _alice,
            );
            addTearDown(cubit.close);
            await cubit.load();
            expect(cubit.state.topComment?.id, _alice);
          },
        );

        test(
          'does not count hidden replies toward visible engagement',
          () async {
            final hiddenId = '5' * 64;
            stubComments([
              _comment(_alice),
              _comment(hiddenId, content: '', replyToEventId: _alice),
              _comment(_bob, author: _bob),
            ]);
            stubUpvotes({_bob: 1});
            stubModeration(CommentModeration(hiddenCommentIds: {hiddenId}));
            final cubit = buildCubit(rootAddressableId: root);
            addTearDown(cubit.close);
            await cubit.load();
            expect(cubit.state.topComment?.id, _bob);
          },
        );

        test(
          'applies a scoped change received while vote counts are loading',
          () async {
            stubComments([_comment(_alice), _comment(_bob, author: _bob)]);
            final started = Completer<void>();
            final counts =
                Completer<
                  ({Map<String, int> upvotes, Map<String, int> downvotes})
                >();
            when(
              () => likesRepository.getVoteCounts(
                any(),
                addressableIds: any(named: 'addressableIds'),
              ),
            ).thenAnswer((_) {
              started.complete();
              return counts.future;
            });
            final cubit = buildCubit(rootAddressableId: root);
            addTearDown(cubit.close);
            final loading = cubit.load();
            await started.future;
            when(
              () =>
                  moderationRepository.knownModeration(rootAddressableId: root),
            ).thenReturn((
              moderation: const CommentModeration(hiddenCommentIds: {_alice}),
              revision: 1,
            ));
            counts.complete((
              upvotes: {_alice: 20, _bob: 1},
              downvotes: <String, int>{},
            ));
            await loading;
            expect(cubit.state.topComment?.id, _bob);
            expect(cubit.state.moderationRevision, 1);
          },
        );

        test(
          'skips vote lookup when every eligible comment is hidden',
          () async {
            stubComments([_comment(_alice)]);
            stubModeration(
              const CommentModeration(hiddenCommentIds: {_alice}),
              revision: 1,
            );
            final cubit = buildCubit(rootAddressableId: root);
            addTearDown(cubit.close);
            await cubit.load();
            expect(cubit.state.status, FeedTopCommentStatus.empty);
            expect(cubit.state.moderationRevision, 1);
            verifyNever(
              () => likesRepository.getVoteCounts(
                any(),
                addressableIds: any(named: 'addressableIds'),
              ),
            );
          },
        );

        test('stops loading after close during the moderation read', () async {
          final read = Completer<CommentModeration>();
          stubComments([_comment(_alice)]);
          stubUpvotes({_alice: 20});
          when(
            () => moderationRepository.loadModeration(rootAddressableId: root),
          ).thenAnswer((_) => read.future);
          final cubit = buildCubit(rootAddressableId: root);
          final loading = cubit.load();
          await pumpEventQueue();
          await cubit.close();
          read.complete(CommentModeration.empty);
          await loading;
          verifyNever(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          );
          expect(cubit.state.status, FeedTopCommentStatus.loading);
        });
      });

      group('author deletions', () {
        const deletedId =
            '5555555555555555555555555555555555555555555555555555555555555555';
        const keptId =
            '6666666666666666666666666666666666666666666666666666666666666666';

        blocTest<FeedTopCommentCubit, FeedTopCommentState>(
          'does not feature an author-deleted comment from a stale read',
          setUp: () {
            stubComments([_comment(deletedId), _comment(keptId)]);
            stubUpvotes({deletedId: 20, keptId: 1});
            when(
              () => commentsRepository.findAuthorDeletedComments(any()),
            ).thenAnswer((_) async => {deletedId});
          },
          build: buildCubit,
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            isA<FeedTopCommentState>()
                .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
                .having((s) => s.topComment?.id, 'topComment', keptId),
          ],
        );

        blocTest<FeedTopCommentCubit, FeedTopCommentState>(
          'is empty when every candidate was author-deleted',
          setUp: () {
            stubComments([_comment(deletedId)]);
            stubUpvotes({deletedId: 20});
            when(
              () => commentsRepository.findAuthorDeletedComments(any()),
            ).thenAnswer((_) async => {deletedId});
          },
          build: buildCubit,
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            isA<FeedTopCommentState>()
                .having((s) => s.status, 'status', FeedTopCommentStatus.empty)
                .having((s) => s.topComment, 'topComment', isNull),
          ],
        );

        blocTest<FeedTopCommentCubit, FeedTopCommentState>(
          'does not count an author-deleted reply toward engagement',
          setUp: () {
            stubComments([
              _comment(keptId),
              _comment(
                deletedId,
                content: '',
                replyToEventId: keptId,
              ),
              _comment(_bob),
            ]);
            stubUpvotes({_bob: 1});
            when(
              () => commentsRepository.findAuthorDeletedComments(any()),
            ).thenAnswer((_) async => {deletedId});
          },
          build: buildCubit,
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            isA<FeedTopCommentState>().having(
              (s) => s.topComment?.id,
              'topComment',
              _bob,
            ),
          ],
        );

        test('stops loading if closed during the deletion lookup', () async {
          final deletions = Completer<Set<String>>();
          stubComments([_comment(keptId)]);
          stubUpvotes({keptId: 1});
          when(
            () => commentsRepository.findAuthorDeletedComments(any()),
          ).thenAnswer((_) => deletions.future);
          final cubit = buildCubit();
          final loading = cubit.load();
          await pumpEventQueue();
          verify(
            () => commentsRepository.findAuthorDeletedComments(any()),
          ).called(1);
          await cubit.close();
          deletions.complete({});
          await loading;

          verifyNever(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          );
          expect(cubit.state.status, FeedTopCommentStatus.loading);
        });
      });

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'loads only once',
        setUp: () {
          stubComments([_comment('only')]);
          stubUpvotes({});
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.load();
        },
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.loading,
          ),
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.ready,
          ),
        ],
        verify: (_) {
          verify(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        "asks for the video's first page and its votes by id and coordinate",
        setUp: () {
          stubComments([_comment('a', addressableId: '1111:$_alice:a')]);
          stubUpvotes({});
        },
        build: () => buildCubit(rootAddressableId: '34236:$_creator:loop'),
        act: (cubit) => cubit.load(),
        verify: (_) {
          verify(
            () => commentsRepository.loadComments(
              rootEventId: _rootId,
              rootEventKind: 34236,
              rootAddressableId: '34236:$_creator:loop',
              limit: FeedTopCommentCubit.commentPageSize,
            ),
          ).called(1);
          verify(
            () => likesRepository.getVoteCounts(
              ['a'],
              addressableIds: {'a': '1111:$_alice:a'},
            ),
          ).called(1);
        },
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'selects the most upvoted comment',
        setUp: () {
          stubComments([_comment('a'), _comment('b', content: 'Wanna know')]);
          stubUpvotes({'a': 1, 'b': 9});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
              .having((s) => s.topComment?.id, 'topComment', 'b'),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'can select a reply',
        setUp: () {
          stubComments([
            _comment('parent', content: 'Who made this?', author: _bob),
            _comment(
              'reply',
              replyToEventId: 'parent',
              replyToAuthorPubkey: _bob,
            ),
          ]);
          stubUpvotes({'reply': 5});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.topComment?.id,
            'topComment',
            'reply',
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'counts replies toward a comment like the Top ordering does',
        setUp: () {
          stubComments([
            _comment('quiet'),
            _comment('discussed'),
            _comment(
              'answer',
              content: '',
              replyToEventId: 'discussed',
              replyToAuthorPubkey: _alice,
            ),
          ]);
          stubUpvotes({'quiet': 1});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.topComment?.id,
            'topComment',
            'discussed',
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'breaks a tie in favour of the newer comment',
        // Age is scored in whole minutes, so equal votes within one minute
        // tie and only the tie-break orders them.
        setUp: () {
          stubComments([
            _comment('older', age: const Duration(hours: 2, seconds: 40)),
            _comment('newer', age: const Duration(hours: 2, seconds: 10)),
          ]);
          stubUpvotes({'older': 1, 'newer': 1});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.topComment?.id,
            'topComment',
            'newer',
          ),
        ],
      );

      group('a comment dated in the future', () {
        // Newest first, as the repository returns a page.
        for (final (ahead, label) in [
          (const Duration(minutes: 6), 'just past the clock-skew allowance'),
          (const Duration(hours: 2), 'two hours'),
          (const Duration(days: 365), 'a year'),
        ]) {
          blocTest<FeedTopCommentCubit, FeedTopCommentState>(
            'is not a candidate when $label ahead',
            setUp: () {
              stubComments([
                _comment('future', age: -ahead),
                _comment('older', age: const Duration(days: 1)),
              ]);
              stubUpvotes({'future': 1});
            },
            build: buildCubit,
            act: (cubit) => cubit.load(),
            skip: 1,
            expect: () => [
              isA<FeedTopCommentState>().having(
                (s) => s.topComment?.id,
                'topComment',
                'older',
              ),
            ],
          );
        }

        blocTest<FeedTopCommentCubit, FeedTopCommentState>(
          'is a candidate within the clock-skew allowance',
          setUp: () {
            stubComments([
              _comment('skewed', age: const Duration(minutes: -4)),
              _comment('older'),
            ]);
            stubUpvotes({});
          },
          build: buildCubit,
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            isA<FeedTopCommentState>().having(
              (s) => s.topComment?.id,
              'topComment',
              'skewed',
            ),
          ],
        );

        blocTest<FeedTopCommentCubit, FeedTopCommentState>(
          'leaves nothing to show when it is the only comment',
          setUp: () => stubComments([
            _comment('future', age: const Duration(hours: -3)),
          ]),
          build: buildCubit,
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            isA<FeedTopCommentState>().having(
              (s) => s.status,
              'status',
              FeedTopCommentStatus.empty,
            ),
          ],
        );
      });

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'is empty when only video replies and blank comments exist',
        setUp: () {
          stubComments([
            _comment('video', videoUrl: 'https://media.example/v.mp4'),
            _comment('blank', content: '   '),
          ]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.loading,
          ),
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.empty)
              .having((s) => s.topComment, 'topComment', isNull),
        ],
        verify: (_) {
          verifyNever(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          );
        },
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'shows the most recent comment when none has an upvote or a reply',
        setUp: () {
          stubComments([
            _comment('older', age: const Duration(hours: 5)),
            _comment('newest', age: const Duration(minutes: 5)),
            _comment('middle', age: const Duration(hours: 2)),
          ]);
          stubUpvotes({});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
              .having((s) => s.topComment?.id, 'topComment', 'newest'),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        "never picks the creator's own comment",
        setUp: () {
          stubComments([
            _comment('creator', author: _creator),
            _comment('viewer', author: _bob),
          ]);
          stubUpvotes({'creator': 50, 'viewer': 1});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.topComment?.id,
            'topComment',
            'viewer',
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'is empty when only the creator commented',
        setUp: () => stubComments([_comment('creator', author: _creator)]),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.empty,
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'shows a lone comment without votes',
        setUp: () {
          stubComments([_comment('only')]);
          stubUpvotes({});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
              .having((s) => s.topComment?.id, 'topComment', 'only'),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'still ranks by replies when vote counts fail',
        setUp: () {
          stubComments([
            _comment('discussed', age: const Duration(hours: 2)),
            _comment(
              'answer',
              content: '',
              replyToEventId: 'discussed',
              replyToAuthorPubkey: _alice,
            ),
            _comment('newer', age: const Duration(minutes: 5)),
          ]);
          when(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          ).thenThrow(const LikesRepositoryException('offline'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        errors: () => [isA<LikesRepositoryException>()],
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
              .having((s) => s.topComment?.id, 'topComment', 'discussed'),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'reports an unexpected vote-count failure and still shows a comment',
        setUp: () {
          stubComments([_comment('only')]);
          when(
            () => likesRepository.getVoteCounts(
              any(),
              addressableIds: any(named: 'addressableIds'),
            ),
          ).thenThrow(StateError('invariant'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        expect: () => [
          isA<FeedTopCommentState>()
              .having((s) => s.status, 'status', FeedTopCommentStatus.ready)
              .having((s) => s.topComment?.id, 'topComment', 'only'),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'fails without reporting when comments cannot load',
        setUp: () {
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(const LoadCommentsFailedException('boom'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        errors: () => [isA<LoadCommentsFailedException>()],
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.failure,
          ),
        ],
      );

      blocTest<FeedTopCommentCubit, FeedTopCommentState>(
        'reports an unexpected load failure',
        setUp: () {
          when(
            () => commentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(StateError('invariant'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        errors: () => [isA<Reportable<Object>>()],
        expect: () => [
          isA<FeedTopCommentState>().having(
            (s) => s.status,
            'status',
            FeedTopCommentStatus.failure,
          ),
        ],
      );
    });

    group('isOverlayVisible', () {
      setUp(() {
        stubComments([_comment('only')]);
        stubUpvotes({'only': 1});
      });

      test('stays hidden until the first loop finishes', () async {
        final cubit = buildCubit();
        await cubit.load();
        expect(cubit.state.status, FeedTopCommentStatus.ready);
        expect(cubit.state.isOverlayVisible, isFalse);

        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.isOverlayVisible, isTrue);
        await cubit.close();
      });

      test('shows once loaded when the loop finished first', () async {
        final cubit = buildCubit();
        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.hasCompletedLoop, isTrue);
        expect(cubit.state.isOverlayVisible, isFalse);

        await cubit.load();
        expect(cubit.state.isOverlayVisible, isTrue);
        await cubit.close();
      });

      test('stays hidden after dismiss, across later loops', () async {
        final cubit = buildCubit();
        await cubit.load();
        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.isOverlayVisible, isTrue);

        cubit.dismiss();
        loops.add(null);
        await pumpEventQueue();
        expect(cubit.state.isOverlayVisible, isFalse);
        await cubit.close();
      });
    });
  });
}
