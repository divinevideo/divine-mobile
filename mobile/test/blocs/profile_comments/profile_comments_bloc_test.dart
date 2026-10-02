import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

const _testAuthorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testRootEventId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _testRootAuthorPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

bool _disabledVideoReplies() => false;

void main() {
  group(ProfileCommentsBloc, () {
    late _MockCommentsRepository mockCommentsRepository;

    setUp(() {
      mockCommentsRepository = _MockCommentsRepository();
    });

    ProfileCommentsBloc createBloc({bool includeVideoReplies = true}) =>
        ProfileCommentsBloc(
          commentsRepository: mockCommentsRepository,
          targetUserPubkey: _testAuthorPubkey,
          includeVideoReplies: includeVideoReplies,
        );

    Comment createTextComment({
      required String id,
      required int createdAtSeconds,
    }) => Comment(
      id: id,
      content: 'Text comment $id',
      authorPubkey: _testAuthorPubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
      rootEventId: _testRootEventId,
      rootAuthorPubkey: _testRootAuthorPubkey,
    );

    Comment createVideoComment({
      required String id,
      required int createdAtSeconds,
    }) => Comment(
      id: id,
      content: 'Video reply $id',
      authorPubkey: _testAuthorPubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
      rootEventId: _testRootEventId,
      rootAuthorPubkey: _testRootAuthorPubkey,
      videoUrl: 'https://example.com/$id.mp4',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    );

    group(ProfileCommentsState, () {
      test('has correct initial state', () async {
        final bloc = createBloc();
        expect(bloc.state.status, equals(ProfileCommentsStatus.initial));
        expect(bloc.state.videoReplies, isEmpty);
        expect(bloc.state.textComments, isEmpty);
        expect(bloc.state.isLoadingMore, isFalse);
        expect(bloc.state.hasMoreContent, isTrue);
        expect(bloc.state.paginationCursor, isNull);
        expect(bloc.state.totalCount, equals(0));
        await bloc.close();
      });

      test('copyWith preserves existing values', () {
        const state = ProfileCommentsState();
        final updated = state.copyWith(status: ProfileCommentsStatus.success);
        expect(updated.status, equals(ProfileCommentsStatus.success));
        expect(updated.videoReplies, isEmpty);
        expect(updated.textComments, isEmpty);
      });

      test('isLoaded returns true when status is success', () {
        final state = const ProfileCommentsState().copyWith(
          status: ProfileCommentsStatus.success,
        );
        expect(state.isLoaded, isTrue);
        expect(state.isLoading, isFalse);
      });

      test('isLoading returns true when status is loading', () {
        final state = const ProfileCommentsState().copyWith(
          status: ProfileCommentsStatus.loading,
        );
        expect(state.isLoading, isTrue);
        expect(state.isLoaded, isFalse);
      });

      test('totalCount returns sum of video and text comments', () {
        final state = ProfileCommentsState(
          videoReplies: [createVideoComment(id: 'v1', createdAtSeconds: 1000)],
          textComments: [
            createTextComment(id: 't1', createdAtSeconds: 1000),
            createTextComment(id: 't2', createdAtSeconds: 1001),
          ],
        );
        expect(state.totalCount, equals(3));
      });
    });

    group('ProfileCommentsSyncRequested', () {
      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'emits [loading, success] with split video/text comments',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              includeVideoReplies: true,
            ),
          ).thenAnswer(
            (_) async => AuthorCommentsPage(
              comments: [
                createVideoComment(id: 'v1', createdAtSeconds: 1700001000),
                createTextComment(id: 't1', createdAtSeconds: 1700000500),
                createTextComment(id: 't2', createdAtSeconds: 1700000000),
              ],
            ),
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.status, 'status', ProfileCommentsStatus.success)
              .having((s) => s.videoReplies.length, 'videoReplies.length', 1)
              .having((s) => s.textComments.length, 'textComments.length', 2)
              .having((s) => s.hasMoreContent, 'hasMoreContent', isFalse),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'emits [loading, success] with empty lists when no comments',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              includeVideoReplies: true,
            ),
          ).thenAnswer((_) async => const AuthorCommentsPage(comments: []));
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.status, 'status', ProfileCommentsStatus.success)
              .having((s) => s.videoReplies, 'videoReplies', isEmpty)
              .having((s) => s.textComments, 'textComments', isEmpty),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'emits [loading, failure] on repository error',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              includeVideoReplies: true,
            ),
          ).thenThrow(
            const LoadCommentsByAuthorFailedException('Network error'),
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.failure,
          ),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'passes disabled video replies flag to repository',
        build: () {
          final includeVideoReplies = _disabledVideoReplies();
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              includeVideoReplies: includeVideoReplies,
            ),
          ).thenAnswer(
            (_) async => AuthorCommentsPage(
              comments: [
                createTextComment(id: 't1', createdAtSeconds: 1700000500),
              ],
            ),
          );
          return createBloc(includeVideoReplies: includeVideoReplies);
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.status, 'status', ProfileCommentsStatus.success)
              .having((s) => s.videoReplies, 'videoReplies', isEmpty)
              .having((s) => s.textComments.length, 'textComments.length', 1),
        ],
        verify: (_) {
          verify(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: _testAuthorPubkey,
              includeVideoReplies: _disabledVideoReplies(),
            ),
          ).called(1);
        },
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'keeps paging from the repository cursor when deleted comments '
        'shortened the page',
        build: () {
          // A full page from the relay with one comment its author deleted.
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              includeVideoReplies: true,
            ),
          ).thenAnswer(
            (_) async => AuthorCommentsPage(
              comments: List.generate(
                49,
                (i) => createTextComment(
                  id: 'c$i',
                  createdAtSeconds: 1700000000 - i,
                ),
              ),
              nextCursor: DateTime.fromMillisecondsSinceEpoch(
                1699999900 * 1000,
              ),
            ),
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.hasMoreContent, 'hasMoreContent', isTrue)
              .having(
                (s) => s.paginationCursor,
                'paginationCursor',
                DateTime.fromMillisecondsSinceEpoch(1699999900 * 1000),
              ),
        ],
      );

      test('a sync arriving while another is in flight still runs', () async {
        final inFlight = Completer<AuthorCommentsPage>();
        var calls = 0;
        when(
          () => mockCommentsRepository.loadCommentsByAuthor(
            authorPubkey: any(named: 'authorPubkey'),
            limit: any(named: 'limit'),
            includeVideoReplies: true,
          ),
        ).thenAnswer((_) {
          calls++;
          return calls == 1
              ? inFlight.future
              : Future.value(const AuthorCommentsPage(comments: []));
        });
        final bloc = createBloc();
        addTearDown(bloc.close);

        final firstSync = Completer<void>();
        bloc.add(ProfileCommentsSyncRequested(completer: firstSync));
        await bloc.stream.firstWhere(
          (state) => state.status == ProfileCommentsStatus.loading,
        );

        // This one used to hit the in-handler "already loading" guard and
        // return without doing anything — including without completing.
        final secondSync = Completer<void>();
        bloc.add(ProfileCommentsSyncRequested(completer: secondSync));
        inFlight.complete(const AuthorCommentsPage(comments: []));

        await Future.wait([firstSync.future, secondSync.future]).timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail(
            'a sync dispatched during an in-flight sync never completed — '
            'pull-to-refresh would spin forever',
          ),
        );
        expect(calls, 2);
      });
    });

    group('ProfileCommentsLoadMoreRequested', () {
      final seedVideoReplies = [
        createVideoComment(id: 'v1', createdAtSeconds: 1700001000),
      ];
      final seedTextComments = [
        createTextComment(id: 't1', createdAtSeconds: 1700000500),
        createTextComment(id: 't2', createdAtSeconds: 1700000000),
      ];
      final seedCursor = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'appends new comments to existing lists',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              includeVideoReplies: true,
            ),
          ).thenAnswer(
            (_) async => AuthorCommentsPage(
              comments: [
                createVideoComment(id: 'v2', createdAtSeconds: 1699999500),
                createTextComment(id: 't3', createdAtSeconds: 1699999000),
              ],
            ),
          );
          return createBloc();
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          videoReplies: seedVideoReplies,
          textComments: seedTextComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.videoReplies.length, 'videoReplies.length', 2)
              .having((s) => s.textComments.length, 'textComments.length', 3),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'deduplicates against existing comments',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              includeVideoReplies: true,
            ),
          ).thenAnswer(
            (_) async => AuthorCommentsPage(
              comments: [
                // Duplicate of existing
                createTextComment(id: 't2', createdAtSeconds: 1700000000),
                // New
                createTextComment(id: 't3', createdAtSeconds: 1699999000),
              ],
            ),
          );
          return createBloc();
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          videoReplies: seedVideoReplies,
          textComments: seedTextComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.textComments.length, 'textComments.length', 3)
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'moves past a page whose comments were all deleted',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              includeVideoReplies: true,
            ),
          ).thenAnswer(
            (_) async => AuthorCommentsPage(
              comments: const [],
              nextCursor: DateTime.fromMillisecondsSinceEpoch(
                1699990000 * 1000,
              ),
            ),
          );
          return createBloc();
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          videoReplies: seedVideoReplies,
          textComments: seedTextComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.hasMoreContent, 'hasMoreContent', isTrue)
              .having(
                (s) => s.paginationCursor,
                'paginationCursor',
                DateTime.fromMillisecondsSinceEpoch(1699990000 * 1000),
              ),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'does nothing when not in success state',
        build: createBloc,
        seed: () =>
            const ProfileCommentsState(status: ProfileCommentsStatus.loading),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => <ProfileCommentsState>[],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          videoReplies: seedVideoReplies,
          textComments: seedTextComments,
          isLoadingMore: true,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => <ProfileCommentsState>[],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'does nothing when no more content',
        build: createBloc,
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          videoReplies: seedVideoReplies,
          textComments: seedTextComments,
          hasMoreContent: false,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => <ProfileCommentsState>[],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'resets isLoadingMore on error and preserves existing data',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              includeVideoReplies: true,
            ),
          ).thenThrow(Exception('Network error'));
          return createBloc();
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          videoReplies: seedVideoReplies,
          textComments: seedTextComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.videoReplies.length, 'videoReplies.length', 1)
              .having((s) => s.textComments.length, 'textComments.length', 2),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'passes disabled video replies flag when loading more',
        build: () {
          final includeVideoReplies = _disabledVideoReplies();
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
              includeVideoReplies: includeVideoReplies,
            ),
          ).thenAnswer(
            (_) async => AuthorCommentsPage(
              comments: [
                createTextComment(id: 't3', createdAtSeconds: 1699999000),
              ],
            ),
          );
          return createBloc(includeVideoReplies: includeVideoReplies);
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          videoReplies: seedVideoReplies,
          textComments: seedTextComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.videoReplies.length, 'videoReplies.length', 1)
              .having((s) => s.textComments.length, 'textComments.length', 3),
        ],
        verify: (_) {
          verify(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: _testAuthorPubkey,
              before: seedCursor.subtract(const Duration(seconds: 1)),
              includeVideoReplies: _disabledVideoReplies(),
            ),
          ).called(1);
        },
      );
    });
  });
}
