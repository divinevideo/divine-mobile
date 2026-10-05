// ABOUTME: Tests for CommentsListBloc — load, paginate, sort, real-time stream,
// ABOUTME: and the six cross-bloc store-mutation events (Optimistic
// ABOUTME: Inserted/Confirmed/RolledBack, CommentReplacedInStore,
// ABOUTME: CommentRemovedFromStore, CommentsRemovedByAuthorFromStore).
// ABOUTME: Asserts #4478 cache-fix: rootAddressableId threaded into loadComments.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  group(CommentsListBloc, () {
    late _MockCommentsRepository mockCommentsRepository;

    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUpAll(() {
      registerFallbackValue(<Comment>[]);
    });

    setUp(() {
      mockCommentsRepository = _MockCommentsRepository();
      when(
        () => mockCommentsRepository.watchComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          since: any(named: 'since'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Comment>.empty());
      when(
        () => mockCommentsRepository.watchCommentDeletions(
          rootEventId: any(named: 'rootEventId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer((_) => const Stream<CommentDeletion>.empty());
      when(
        () => mockCommentsRepository.findAuthorDeletedComments(any()),
      ).thenAnswer((_) async => <String>{});
      when(
        () => mockCommentsRepository.stopWatchingComments(),
      ).thenAnswer((_) async {});
    });

    Comment makeComment(
      String id, {
      String? content,
      String? authorPubkey,
      DateTime? createdAt,
      String? replyToEventId,
      String? replyToAuthorPubkey,
      String? videoUrl,
      String? thumbnailUrl,
      String? videoDimensions,
      int? videoDuration,
      String? videoBlurhash,
    }) => Comment(
      id: id,
      content: content ?? 'hello',
      authorPubkey: authorPubkey ?? validId('commenter'),
      createdAt: createdAt ?? DateTime.now(),
      rootEventId: validId('root'),
      rootAuthorPubkey: validId('author'),
      replyToEventId: replyToEventId,
      replyToAuthorPubkey: replyToAuthorPubkey,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      videoDimensions: videoDimensions,
      videoDuration: videoDuration,
      videoBlurhash: videoBlurhash,
    );

    CommentsListBloc createBloc({
      String? rootAddressableId,
      int? initialTotalCount,
    }) => CommentsListBloc(
      commentsRepository: mockCommentsRepository,
      rootEventId: validId('root'),
      rootEventKind: 34236,
      rootAuthorPubkey: validId('author'),
      rootAddressableId: rootAddressableId,
      initialTotalCount: initialTotalCount,
    );

    test('initial state', () async {
      final bloc = createBloc();
      expect(bloc.state.status, CommentsStatus.initial);
      expect(bloc.state.commentsById, isEmpty);
      expect(bloc.state.rootEventId, validId('root'));
      await bloc.close();
    });

    group('CommentsLoadRequested', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'emits [loading, success] and threads rootAddressableId (#4478)',
        setUp: () {
          final comment = makeComment(validId('c1'), content: 'first');
          final thread = CommentThread(
            rootEventId: validId('root'),
            comments: [comment],
            totalCount: 1,
            commentCache: {comment.id: comment},
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => thread);
        },
        build: () => createBloc(rootAddressableId: 'fake-addr'),
        act: (b) => b.add(const CommentsLoadRequested()),
        expect: () => [
          isA<CommentsListState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsListState>()
              .having((s) => s.status, 'status', CommentsStatus.success)
              .having((s) => s.commentsById.length, 'count', 1),
        ],
        verify: (_) {
          verify(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: 'fake-addr',
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'emits [loading, failure] when load throws and store is empty',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(const LoadCommentsFailedException('boom'));
        },
        build: createBloc,
        act: (b) => b.add(const CommentsLoadRequested()),
        errors: () => [isA<LoadCommentsFailedException>()],
        expect: () => [
          isA<CommentsListState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsListState>()
              .having((s) => s.status, 'status', CommentsStatus.failure)
              .having((s) => s.error, 'error', CommentsListError.loadFailed),
        ],
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'emits failure when load throws and store has only placeholders',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(const LoadCommentsFailedException('boom'));
        },
        build: createBloc,
        seed: () {
          final placeholder = Comment(
            id: '${commentPlaceholderIdPrefix}1',
            content: 'uploading',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsListState(commentsById: {placeholder.id: placeholder});
        },
        act: (b) => b.add(const CommentsLoadRequested()),
        errors: () => [isA<LoadCommentsFailedException>()],
        expect: () => [
          isA<CommentsListState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsListState>()
              .having((s) => s.status, 'status', CommentsStatus.failure)
              .having((s) => s.error, 'error', CommentsListError.loadFailed),
        ],
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'noop when status is already loading',
        build: createBloc,
        seed: () => const CommentsListState(status: CommentsStatus.loading),
        act: (b) => b.add(const CommentsLoadRequested()),
        expect: () => isEmpty,
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'keeps pagination enabled when v2 REST has_more races with live '
        'backfill comments',
        setUp: () {
          final liveController = StreamController<Comment>();
          addTearDown(liveController.close);
          final loadCompleter = Completer<CommentThread>();
          final restComments = List.generate(
            50,
            (index) => makeComment(
              validId('c$index'),
              createdAt: DateTime.fromMillisecondsSinceEpoch(5000 - index),
            ),
          );

          when(
            () => mockCommentsRepository.watchComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              since: any(named: 'since'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => liveController.stream);
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => loadCompleter.future);

          scheduleMicrotask(() {
            liveController.add(makeComment(validId('live')));
            loadCompleter.complete(
              CommentThread(
                rootEventId: validId('root'),
                comments: restComments,
                totalCount: 50,
                hasMore: true,
                hasExactTotal: false,
                commentCache: {
                  for (final comment in restComments) comment.id: comment,
                },
              ),
            );
          });
        },
        build: createBloc,
        act: (b) => b.add(const CommentsLoadRequested()),
        verify: (b) {
          expect(b.state.commentsById.length, 51);
          expect(b.state.hasMoreContent, isTrue);
        },
      );

      test('starts live watch after initial load populates comments', () async {
        final loadCompleter = Completer<CommentThread>();
        final comment = makeComment(validId('c1'));
        when(
          () => mockCommentsRepository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => loadCompleter.future);

        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const CommentsLoadRequested());

        await expectLater(
          bloc.stream,
          emits(
            isA<CommentsListState>().having(
              (s) => s.status,
              'status',
              CommentsStatus.loading,
            ),
          ),
        );
        verifyNever(
          () => mockCommentsRepository.watchComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            since: any(named: 'since'),
            onEose: any(named: 'onEose'),
          ),
        );

        loadCompleter.complete(
          CommentThread(
            rootEventId: validId('root'),
            comments: [comment],
            totalCount: 1,
            commentCache: {comment.id: comment},
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            isA<CommentsListState>()
                .having((s) => s.status, 'status', CommentsStatus.success)
                .having((s) => s.commentsById.length, 'comment count', 1),
          ),
        );
        verify(
          () => mockCommentsRepository.watchComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            since: any(named: 'since'),
            onEose: any(named: 'onEose'),
          ),
        ).called(1);
      });
    });

    group('CommentsLoadMoreRequested', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'noop when status is not success',
        build: createBloc,
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        expect: () => isEmpty,
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'noop when commentsById is empty',
        build: createBloc,
        seed: () => const CommentsListState(status: CommentsStatus.success),
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        expect: () => isEmpty,
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'pages older comments, merges into store',
        setUp: () {
          final older = makeComment(
            validId('c0'),
            content: 'older',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          );
          final thread = CommentThread(
            rootEventId: validId('root'),
            comments: [older],
            totalCount: 2,
            commentCache: {older.id: older},
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => thread);
        },
        build: createBloc,
        seed: () {
          final existing = makeComment(
            validId('c1'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
          );
          return CommentsListState(
            status: CommentsStatus.success,
            commentsById: {existing.id: existing},
          );
        },
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        verify: (b) {
          expect(b.state.commentsById.length, 2);
          expect(b.state.isLoadingMore, isFalse);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'noop when isLoadingMore is already true (re-entry guard)',
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          isLoadingMore: true,
          commentsById: {validId('c1'): makeComment(validId('c1'))},
        ),
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        expect: () => isEmpty,
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'noop when hasMoreContent is false',
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          hasMoreContent: false,
          commentsById: {validId('c1'): makeComment(validId('c1'))},
        ),
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        expect: () => isEmpty,
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'emits loadFailed error and resets isLoadingMore when loadMore '
        'throws (#4595 regression — surface snackbar, not stuck spinner)',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const LoadCommentsFailedException('boom'));
        },
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {validId('c1'): makeComment(validId('c1'))},
        ),
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        errors: () => [isA<LoadCommentsFailedException>()],
        verify: (b) {
          expect(b.state.isLoadingMore, isFalse);
          expect(b.state.error, CommentsListError.loadFailed);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'cursor is the oldest non-placeholder createdAt, regardless of sortMode',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => CommentThread.empty(validId('root')));
        },
        build: createBloc,
        seed: () {
          final newer = makeComment(
            validId('newer'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(9000),
          );
          final older = makeComment(
            validId('older'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          );
          final placeholder = Comment(
            id: 'pending_comment_1',
            content: 'wip',
            authorPubkey: validId('me'),
            // Most recent timestamp, but placeholder filter must skip it.
            createdAt: DateTime.fromMillisecondsSinceEpoch(100000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsListState(
            status: CommentsStatus.success,
            sortMode: CommentsSortMode.oldest,
            commentsById: {
              newer.id: newer,
              older.id: older,
              placeholder.id: placeholder,
            },
          );
        },
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        verify: (_) {
          // Cursor must equal `older.createdAt` regardless of sortMode and
          // ignoring the placeholder at the newer timestamp.
          verify(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: DateTime.fromMillisecondsSinceEpoch(1000),
            ),
          ).called(1);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'noop when every comment is an optimistic placeholder (no cursor)',
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {
            'pending_comment_1': Comment(
              id: 'pending_comment_1',
              content: 'wip',
              authorPubkey: validId('me'),
              createdAt: DateTime.now(),
              rootEventId: validId('root'),
              rootAuthorPubkey: validId('author'),
            ),
          },
        ),
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        expect: () => isEmpty,
        verify: (_) {
          verifyNever(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'deduplicates overlapping ids returned by loadMore (Nostr `until` is '
        'inclusive)',
        setUp: () {
          // Repository returns the cursor comment again as part of the next
          // page. The Map must dedupe by id rather than producing duplicates.
          final overlap = makeComment(
            validId('c1'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
            content: 'shared boundary',
          );
          final extra = makeComment(
            validId('c0'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => CommentThread(
              rootEventId: validId('root'),
              comments: [overlap, extra],
              totalCount: 2,
              commentCache: {overlap.id: overlap, extra.id: extra},
            ),
          );
        },
        build: createBloc,
        seed: () {
          final existing = makeComment(
            validId('c1'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
          );
          return CommentsListState(
            status: CommentsStatus.success,
            commentsById: {existing.id: existing},
          );
        },
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        verify: (b) {
          // Two distinct ids only — overlap shouldn't appear twice.
          expect(b.state.commentsById.length, 2);
          expect(
            b.state.commentsById.keys,
            containsAll([validId('c1'), validId('c0')]),
          );
        },
      );
    });

    group('NewCommentReceived', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'adds new comment and bumps newCommentCount after backfill',
        build: createBloc,
        seed: () => const CommentsListState(status: CommentsStatus.success),
        act: (b) {
          b.add(const CommentsInitialBackfillCompleted());
          b.add(NewCommentReceived(makeComment(validId('c1'))));
        },
        verify: (b) {
          expect(b.state.commentsById.length, 1);
          expect(b.state.newCommentCount, 1);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'reconciles placeholder by author+content on relay echo',
        build: createBloc,
        seed: () {
          final placeholder = Comment(
            id: 'pending_comment_999',
            content: 'echo me',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsListState(
            status: CommentsStatus.success,
            commentsById: {placeholder.id: placeholder},
          );
        },
        act: (b) {
          b.add(const CommentsInitialBackfillCompleted());
          b.add(
            NewCommentReceived(
              makeComment(
                validId('confirmed'),
                content: 'echo me',
                authorPubkey: validId('me'),
              ),
            ),
          );
        },
        verify: (b) {
          expect(
            b.state.commentsById.containsKey('pending_comment_999'),
            isFalse,
          );
          expect(
            b.state.commentsById.containsKey(validId('confirmed')),
            isTrue,
          );
          // newCommentCount does NOT bump because this is a placeholder swap.
          expect(b.state.newCommentCount, 0);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'skips duplicate by id',
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {validId('c1'): makeComment(validId('c1'))},
        ),
        act: (b) => b.add(NewCommentReceived(makeComment(validId('c1')))),
        expect: () => isEmpty,
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'upgrades duplicate relay echo when it adds missing video metadata',
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {
            validId('c1'): makeComment(
              validId('c1'),
              content: 'REST video reply',
              replyToEventId: validId('parent'),
            ),
          },
        ),
        act: (b) => b.add(
          NewCommentReceived(
            makeComment(
              validId('c1'),
              content: 'REST video reply',
              videoUrl: 'https://media.divine.video/reply/12345',
              thumbnailUrl: 'https://media.divine.video/reply/12345.jpg',
              videoDimensions: '720x1280',
              videoDuration: 6,
              videoBlurhash: 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
            ),
          ),
        ),
        verify: (b) {
          final comment = b.state.commentsById[validId('c1')]!;
          expect(comment.hasVideo, isTrue);
          // Upgrade must merge in place, not replace with the echo: the
          // existing REST copy's threading (a field the echo lacks) survives.
          expect(comment.replyToEventId, equals(validId('parent')));
          expect(
            comment.videoUrl,
            equals('https://media.divine.video/reply/12345'),
          );
          expect(
            comment.thumbnailUrl,
            equals('https://media.divine.video/reply/12345.jpg'),
          );
          expect(comment.videoDimensions, equals('720x1280'));
          expect(comment.videoDuration, equals(6));
          expect(comment.videoBlurhash, equals('LKO2?U%2Tw=w]~RBVZRi};RPxuwH'));
          expect(b.state.newCommentCount, 0);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'does NOT bump newCommentCount for backlog comments (pre-EOSE)',
        build: createBloc,
        // Backfill not yet complete — these comments are part of the initial
        // relay sweep, not live updates the user hasn't seen yet.
        seed: () => const CommentsListState(status: CommentsStatus.success),
        act: (b) => b.add(NewCommentReceived(makeComment(validId('c1')))),
        verify: (b) {
          expect(b.state.commentsById.length, 1);
          expect(b.state.newCommentCount, 0);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'EOSE transition flips backlog→live: post-EOSE comments DO bump pill',
        build: createBloc,
        seed: () => const CommentsListState(status: CommentsStatus.success),
        act: (b) {
          // Pre-EOSE: backlog comment, no bump.
          b.add(NewCommentReceived(makeComment(validId('backlog'))));
          // EOSE.
          b.add(const CommentsInitialBackfillCompleted());
          // Post-EOSE: live comment, bumps the pill.
          b.add(NewCommentReceived(makeComment(validId('live'))));
        },
        verify: (b) {
          expect(b.state.commentsById.length, 2);
          expect(b.state.newCommentCount, 1);
          expect(b.state.isBackfillComplete, isTrue);
        },
      );
    });

    group('CommentsSortModeChanged', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'updates sortMode',
        build: createBloc,
        act: (b) =>
            b.add(const CommentsSortModeChanged(CommentsSortMode.oldest)),
        expect: () => [
          isA<CommentsListState>().having(
            (s) => s.sortMode,
            'sortMode',
            CommentsSortMode.oldest,
          ),
        ],
      );
    });

    group('NewCommentsAcknowledged', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'resets newCommentCount to 0',
        build: createBloc,
        seed: () => const CommentsListState(
          newCommentIds: {'c1', 'c2', 'c3', 'c4', 'c5'},
        ),
        act: (b) => b.add(const NewCommentsAcknowledged()),
        expect: () => [
          isA<CommentsListState>().having(
            (s) => s.newCommentCount,
            'newCommentCount',
            0,
          ),
        ],
      );
    });

    group('Cross-bloc store mutation events', () {
      blocTest<CommentsListBloc, CommentsListState>(
        'OptimisticCommentInserted adds a top-level placeholder without '
        'flagging it for scroll (#5854)',
        build: createBloc,
        act: (b) {
          final placeholder = Comment(
            id: 'pending_comment_1',
            content: 'wip',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          b.add(OptimisticCommentInserted(placeholder));
        },
        verify: (b) {
          expect(b.state.commentsById.containsKey('pending_comment_1'), isTrue);
          // A new top-level comment lands at the visible top, so it must not
          // trigger a scroll — only replies (which nest off-screen) do.
          expect(b.state.scrollToCommentId, isNull);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'OptimisticCommentInserted flags a reply for scroll-into-view (#5854)',
        build: createBloc,
        act: (b) {
          final placeholder = Comment(
            id: 'pending_comment_1',
            content: 'wip reply',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
            replyToEventId: validId('parent'),
            replyToAuthorPubkey: validId('parentauthor'),
          );
          b.add(OptimisticCommentInserted(placeholder));
        },
        verify: (b) {
          expect(b.state.commentsById.containsKey('pending_comment_1'), isTrue);
          // A reply nests under an (often older) parent and would render
          // off-screen, so the poster must be scrolled to it.
          expect(b.state.scrollToCommentId, equals('pending_comment_1'));
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'CommentsScrollHandled clears the scroll signal (#5854)',
        build: createBloc,
        seed: () =>
            const CommentsListState(scrollToCommentId: 'pending_comment_1'),
        act: (b) => b.add(const CommentsScrollHandled()),
        verify: (b) {
          expect(b.state.scrollToCommentId, isNull);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'OptimisticCommentConfirmed replaces placeholder with confirmed',
        build: createBloc,
        seed: () {
          final placeholder = Comment(
            id: 'pending_comment_1',
            content: 'wip',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsListState(commentsById: {placeholder.id: placeholder});
        },
        act: (b) => b.add(
          OptimisticCommentConfirmed(
            placeholderId: 'pending_comment_1',
            confirmed: makeComment(validId('confirmed')),
          ),
        ),
        verify: (b) {
          expect(
            b.state.commentsById.containsKey('pending_comment_1'),
            isFalse,
          );
          expect(
            b.state.commentsById.containsKey(validId('confirmed')),
            isTrue,
          );
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'OptimisticCommentConfirmed cleans up placeholder when relay echo already added confirmed',
        build: createBloc,
        seed: () {
          final placeholder = Comment(
            id: 'pending_comment_1',
            content: 'wip',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final confirmed = makeComment(validId('confirmed'));
          return CommentsListState(
            commentsById: {
              placeholder.id: placeholder,
              confirmed.id: confirmed,
            },
          );
        },
        act: (b) => b.add(
          OptimisticCommentConfirmed(
            placeholderId: 'pending_comment_1',
            confirmed: makeComment(validId('confirmed')),
          ),
        ),
        verify: (b) {
          expect(
            b.state.commentsById.containsKey('pending_comment_1'),
            isFalse,
          );
          expect(
            b.state.commentsById.containsKey(validId('confirmed')),
            isTrue,
          );
          expect(b.state.commentsById.length, 1);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'OptimisticCommentRolledBack removes placeholder',
        build: createBloc,
        seed: () {
          final placeholder = Comment(
            id: 'pending_comment_1',
            content: 'wip',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsListState(commentsById: {placeholder.id: placeholder});
        },
        act: (b) =>
            b.add(const OptimisticCommentRolledBack('pending_comment_1')),
        verify: (b) {
          expect(
            b.state.commentsById.containsKey('pending_comment_1'),
            isFalse,
          );
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'CommentReplacedInStore swaps old comment for new one (edit flow)',
        build: createBloc,
        seed: () {
          final original = makeComment(validId('original'));
          return CommentsListState(commentsById: {original.id: original});
        },
        act: (b) => b.add(
          CommentReplacedInStore(
            oldId: validId('original'),
            newComment: makeComment(validId('new'), content: 'edited'),
          ),
        ),
        verify: (b) {
          expect(
            b.state.commentsById.containsKey(validId('original')),
            isFalse,
          );
          expect(b.state.commentsById.containsKey(validId('new')), isTrue);
          expect(b.state.commentsById[validId('new')]!.content, 'edited');
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'CommentRemovedFromStore removes the comment',
        build: createBloc,
        seed: () => CommentsListState(
          commentsById: {validId('c1'): makeComment(validId('c1'))},
        ),
        act: (b) => b.add(CommentRemovedFromStore(validId('c1'))),
        verify: (b) {
          expect(b.state.commentsById.containsKey(validId('c1')), isFalse);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'CommentsRemovedByAuthorFromStore drops every comment by author',
        build: createBloc,
        seed: () {
          final blocked = makeComment(
            validId('c1'),
            authorPubkey: validId('blocked'),
          );
          final other = makeComment(
            validId('c2'),
            authorPubkey: validId('other'),
          );
          return CommentsListState(
            commentsById: {blocked.id: blocked, other.id: other},
          );
        },
        act: (b) => b.add(CommentsRemovedByAuthorFromStore(validId('blocked'))),
        verify: (b) {
          expect(b.state.commentsById.containsKey(validId('c1')), isFalse);
          expect(b.state.commentsById.containsKey(validId('c2')), isTrue);
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'CommentsRemovedByAuthorFromStore stops counting their new comments',
        build: createBloc,
        seed: () {
          final blocked = makeComment(
            validId('c1'),
            authorPubkey: validId('blocked'),
          );
          final other = makeComment(
            validId('c2'),
            authorPubkey: validId('other'),
          );
          return CommentsListState(
            commentsById: {blocked.id: blocked, other.id: other},
            newCommentIds: {blocked.id, other.id},
          );
        },
        act: (b) => b.add(CommentsRemovedByAuthorFromStore(validId('blocked'))),
        verify: (b) => expect(b.state.newCommentCount, equals(1)),
      );
    });

    group('threadedCommentsWith', () {
      test('sorts newest first by default', () {
        final older = makeComment(
          validId('c1'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        );
        final newer = makeComment(
          validId('c2'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        );
        final state = CommentsListState(
          commentsById: {older.id: older, newer.id: newer},
        );
        final threaded = state.threadedCommentsWith();
        expect(threaded.first.comment.id, validId('c2'));
        expect(threaded.last.comment.id, validId('c1'));
      });

      test('engagement sort uses provided upvote counts', () {
        final low = makeComment(validId('c1'), createdAt: DateTime.now());
        final high = makeComment(validId('c2'), createdAt: DateTime.now());
        final state = CommentsListState(
          commentsById: {low.id: low, high.id: high},
          sortMode: CommentsSortMode.topEngagement,
        );
        final threaded = state.threadedCommentsWith(
          upvoteCounts: {validId('c1'): 0, validId('c2'): 100},
        );
        expect(threaded.first.comment.id, validId('c2'));
      });

      test('threads replies under parents', () {
        final parent = makeComment(validId('p1'), createdAt: DateTime.now());
        final reply = makeComment(
          validId('r1'),
          createdAt: DateTime.now(),
          replyToEventId: parent.id,
          replyToAuthorPubkey: parent.authorPubkey,
        );
        final state = CommentsListState(
          commentsById: {parent.id: parent, reply.id: reply},
        );
        final threaded = state.threadedCommentsWith();
        expect(threaded.length, 2);
        expect(threaded[0].depth, 0);
        expect(threaded[1].depth, 1);
      });
    });

    group('engagementScore', () {
      test('newer + more upvoted scores higher', () {
        final now = DateTime.now();
        final hot = makeComment(
          validId('hot'),
          createdAt: now.subtract(const Duration(minutes: 5)),
        );
        final cold = makeComment(
          validId('cold'),
          createdAt: now.subtract(const Duration(hours: 50)),
        );
        final scoreHot = commentEngagementScore(
          comment: hot,
          now: now,
          likeCounts: {hot.id: 20},
          replyCounts: const {},
        );
        final scoreCold = commentEngagementScore(
          comment: cold,
          now: now,
          likeCounts: {cold.id: 20},
          replyCounts: const {},
        );
        expect(scoreHot > scoreCold, isTrue);
      });
    });

    group('real-time stream', () {
      test('starts watching after CommentsLoadRequested', () async {
        final streamController = StreamController<Comment>.broadcast();
        when(
          () => mockCommentsRepository.watchComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            since: any(named: 'since'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockCommentsRepository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => CommentThread.empty(validId('root')));

        final bloc = createBloc();
        bloc.add(const CommentsLoadRequested());
        await pumpEventQueue();

        verify(
          () => mockCommentsRepository.watchComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            since: any(named: 'since'),
            onEose: any(named: 'onEose'),
          ),
        ).called(1);

        await streamController.close();
        await bloc.close();
      });

      test('stopWatchingComments is awaited in close()', () async {
        when(
          () => mockCommentsRepository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => CommentThread.empty(validId('root')));

        final bloc = createBloc();
        bloc.add(const CommentsLoadRequested());
        await pumpEventQueue();

        await bloc.close();

        verify(() => mockCommentsRepository.stopWatchingComments()).called(1);
      });

      test(
        'streamed comments arriving after close() do not throw (isClosed guard)',
        () async {
          final streamController = StreamController<Comment>.broadcast();
          when(
            () => mockCommentsRepository.watchComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              since: any(named: 'since'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => streamController.stream);
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => CommentThread.empty(validId('root')));

          final bloc = createBloc();
          bloc.add(const CommentsLoadRequested());
          await pumpEventQueue();

          await bloc.close();

          // Emit AFTER close — the throttleListen onData wrapper guards on
          // !isClosed and silently drops. Must not throw "Cannot add events
          // after close" on the bloc.
          expect(() {
            streamController.add(makeComment(validId('late')));
          }, returnsNormally);

          await streamController.close();
        },
      );
    });

    // A comment its author deleted can still be served by every read source
    // while the relay has not applied the deletion (#7048).
    group('CommentDeletionReceived', () {
      final authored = makeComment(validId('c1'), authorPubkey: validId('a1'));
      final other = makeComment(validId('c2'));

      blocTest<CommentsListBloc, CommentsListState>(
        'removes a comment its author deleted',
        build: createBloc,
        seed: () => CommentsListState(
          commentsById: {authored.id: authored, other.id: other},
        ),
        act: (b) => b.add(
          CommentDeletionReceived(
            CommentDeletion(
              commentId: authored.id,
              requesterPubkey: validId('a1'),
            ),
          ),
        ),
        expect: () => [
          isA<CommentsListState>().having(
            (s) => s.commentsById.keys,
            'ids',
            [other.id],
          ),
        ],
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'stops counting a new comment its author deleted',
        build: createBloc,
        seed: () => CommentsListState(
          commentsById: {authored.id: authored, other.id: other},
          newCommentIds: {authored.id, other.id},
        ),
        act: (b) => b.add(
          CommentDeletionReceived(
            CommentDeletion(
              commentId: authored.id,
              requesterPubkey: validId('a1'),
            ),
          ),
        ),
        verify: (b) => expect(b.state.newCommentCount, equals(1)),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'keeps a comment when someone else signed the deletion',
        build: createBloc,
        seed: () => CommentsListState(commentsById: {authored.id: authored}),
        act: (b) => b.add(
          CommentDeletionReceived(
            CommentDeletion(
              commentId: authored.id,
              requesterPubkey: validId('someone-else'),
            ),
          ),
        ),
        expect: () => <CommentsListState>[],
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'ignores a deletion of a comment that is not loaded',
        build: createBloc,
        seed: () => CommentsListState(commentsById: {authored.id: authored}),
        act: (b) => b.add(
          CommentDeletionReceived(
            CommentDeletion(
              commentId: validId('missing'),
              requesterPubkey: validId('a1'),
            ),
          ),
        ),
        expect: () => <CommentsListState>[],
      );
    });

    group('live comment deletions', () {
      late StreamController<CommentDeletion> deletions;
      final authored = makeComment(validId('c1'), authorPubkey: validId('a1'));

      setUp(() {
        deletions = StreamController<CommentDeletion>.broadcast();
        addTearDown(deletions.close);
        when(
          () => mockCommentsRepository.watchCommentDeletions(
            rootEventId: any(named: 'rootEventId'),
            includeVideoReplies: any(named: 'includeVideoReplies'),
          ),
        ).thenAnswer((_) => deletions.stream);
        when(
          () => mockCommentsRepository.loadComments(
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootAddressableId: any(named: 'rootAddressableId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => CommentThread(
            rootEventId: validId('root'),
            comments: [authored],
            totalCount: 1,
            commentCache: {authored.id: authored},
          ),
        );
      });

      test('removes a comment when its author deletes it live', () async {
        final bloc = createBloc()..add(const CommentsLoadRequested());
        addTearDown(bloc.close);
        await pumpEventQueue();
        expect(bloc.state.commentsById.keys, equals([authored.id]));

        deletions.add(
          CommentDeletion(
            commentId: authored.id,
            requesterPubkey: validId('a1'),
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.commentsById, isEmpty);
      });

      test('stops watching deletions when closed', () async {
        final bloc = createBloc()..add(const CommentsLoadRequested());
        await pumpEventQueue();
        expect(deletions.hasListener, isTrue);

        await bloc.close();

        expect(deletions.hasListener, isFalse);
      });
    });

    group('author deletions found after loading', () {
      final deleted = makeComment(validId('deleted'));
      final kept = makeComment(validId('kept'));

      blocTest<CommentsListBloc, CommentsListState>(
        'removes them once the first page shows',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => CommentThread(
              rootEventId: validId('root'),
              comments: [deleted, kept],
              totalCount: 2,
              commentCache: {deleted.id: deleted, kept.id: kept},
            ),
          );
          when(
            () => mockCommentsRepository.findAuthorDeletedComments(any()),
          ).thenAnswer((_) async => {deleted.id});
        },
        build: createBloc,
        act: (b) => b.add(const CommentsLoadRequested()),
        expect: () => [
          isA<CommentsListState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsListState>()
              .having((s) => s.status, 'status', CommentsStatus.success)
              .having(
                (s) => s.commentsById.keys,
                'ids',
                unorderedEquals([deleted.id, kept.id]),
              ),
          isA<CommentsListState>().having(
            (s) => s.commentsById.keys,
            'ids',
            [kept.id],
          ),
        ],
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'removes them from a page loaded with load more',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => CommentThread(
              rootEventId: validId('root'),
              comments: [deleted],
              totalCount: 1,
              commentCache: {deleted.id: deleted},
            ),
          );
          when(
            () => mockCommentsRepository.findAuthorDeletedComments(any()),
          ).thenAnswer((_) async => {deleted.id});
        },
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {kept.id: kept},
        ),
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        verify: (b) {
          expect(b.state.commentsById.keys, equals([kept.id]));
        },
      );
    });

    // The comment watch backfills stored comments the first page may lack: a
    // CDN-cached REST page can be minutes behind the relay.
    group('author deletions found after a backfill', () {
      final kept = makeComment(validId('kept'));
      final backfilled = makeComment(validId('backfilled'));

      blocTest<CommentsListBloc, CommentsListState>(
        'stops counting a new comment the check finds deleted',
        setUp: () {
          when(
            () => mockCommentsRepository.findAuthorDeletedComments(any()),
          ).thenAnswer((_) async => {backfilled.id});
        },
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {kept.id: kept, backfilled.id: backfilled},
          newCommentIds: {kept.id, backfilled.id},
        ),
        act: (b) => b.add(const CommentsInitialBackfillCompleted()),
        verify: (b) => expect(b.state.newCommentCount, equals(1)),
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'removes a backfilled comment its author deleted',
        setUp: () {
          when(
            () => mockCommentsRepository.findAuthorDeletedComments(any()),
          ).thenAnswer((_) async => {backfilled.id});
        },
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {kept.id: kept, backfilled.id: backfilled},
        ),
        act: (b) => b.add(const CommentsInitialBackfillCompleted()),
        verify: (b) {
          expect(b.state.commentsById.keys, equals([kept.id]));
          expect(b.state.isBackfillComplete, isTrue);
          final checked =
              verify(
                    () => mockCommentsRepository.findAuthorDeletedComments(
                      captureAny(),
                    ),
                  ).captured.single
                  as Iterable<Comment>;
          expect(
            checked.map((c) => c.id),
            unorderedEquals([kept.id, backfilled.id]),
          );
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'checks again when a replay completes the backfill again',
        setUp: () {
          var lookups = 0;
          when(
            () => mockCommentsRepository.findAuthorDeletedComments(any()),
          ).thenAnswer(
            (_) async => ++lookups == 1 ? <String>{} : {backfilled.id},
          );
        },
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {kept.id: kept, backfilled.id: backfilled},
        ),
        act: (b) async {
          b.add(const CommentsInitialBackfillCompleted());
          await pumpEventQueue();
          expect(b.state.commentsById, hasLength(2));
          b.add(const CommentsInitialBackfillCompleted());
        },
        verify: (b) {
          expect(b.state.commentsById.keys, equals([kept.id]));
        },
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'reports a check that throws and still completes the backfill',
        setUp: () {
          when(
            () => mockCommentsRepository.findAuthorDeletedComments(any()),
          ).thenThrow(StateError('client disposed'));
        },
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {kept.id: kept},
        ),
        act: (b) => b.add(const CommentsInitialBackfillCompleted()),
        verify: (b) {
          expect(b.state.isBackfillComplete, isTrue);
          expect(b.state.commentsById.keys, equals([kept.id]));
        },
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'keeps a page loaded with load more when the check throws',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootAddressableId: any(named: 'rootAddressableId'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => CommentThread(
              rootEventId: validId('root'),
              comments: [backfilled],
              totalCount: 1,
              commentCache: {backfilled.id: backfilled},
            ),
          );
          when(
            () => mockCommentsRepository.findAuthorDeletedComments(any()),
          ).thenThrow(StateError('client disposed'));
        },
        build: createBloc,
        seed: () => CommentsListState(
          status: CommentsStatus.success,
          commentsById: {kept.id: kept},
        ),
        act: (b) => b.add(const CommentsLoadMoreRequested()),
        verify: (b) {
          expect(b.state.error, isNull);
          expect(
            b.state.commentsById.keys,
            unorderedEquals([kept.id, backfilled.id]),
          );
        },
        errors: () => [isA<Reportable<Object>>()],
      );

      blocTest<CommentsListBloc, CommentsListState>(
        'does not look up a comment that is still being posted',
        build: createBloc,
        seed: () {
          final placeholder = Comment(
            id: '${commentPlaceholderIdPrefix}1',
            content: 'uploading',
            authorPubkey: validId('me'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsListState(
            status: CommentsStatus.success,
            commentsById: {kept.id: kept, placeholder.id: placeholder},
          );
        },
        act: (b) => b.add(const CommentsInitialBackfillCompleted()),
        verify: (b) {
          final checked =
              verify(
                    () => mockCommentsRepository.findAuthorDeletedComments(
                      captureAny(),
                    ),
                  ).captured.single
                  as Iterable<Comment>;
          expect(checked.map((c) => c.id), equals([kept.id]));
        },
      );
    });
  });
}
