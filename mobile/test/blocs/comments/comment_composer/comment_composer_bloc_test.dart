// ABOUTME: Tests for CommentComposerBloc — input/reply/edit state, mention
// ABOUTME: search (restartable), publish + edit flows with optimistic
// ABOUTME: placeholders signalled through ComposerOutbox. Asserts #4478 cache
// ABOUTME: fix: rootAddressableId threaded into postComment and deleteComment.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/mentions/mention_search.dart';
import 'package:openvine/mentions/mention_suggestion.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockMentionResolutionService extends Mock
    implements MentionResolutionService {}

bool _dupYes({
  required String content,
  required String authorPubkey,
  String? parentCommentId,
}) => true;

bool _dupNo({
  required String content,
  required String authorPubkey,
  String? parentCommentId,
}) => false;

void main() {
  group(CommentComposerBloc, () {
    late _MockCommentsRepository mockCommentsRepository;
    late _MockAuthService mockAuthService;
    late _MockProfileRepository mockProfileRepository;
    late _MockMentionResolutionService mockMentionResolutionService;

    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockCommentsRepository = _MockCommentsRepository();
      mockAuthService = _MockAuthService();
      mockProfileRepository = _MockProfileRepository();
      mockMentionResolutionService = _MockMentionResolutionService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(validId('currentuser'));

      // Default mention resolution returns text unchanged.
      when(
        () => mockMentionResolutionService.resolveTextMentions(
          rawText: any(named: 'rawText'),
          selectedMentions: any(named: 'selectedMentions'),
          currentUserPubkey: any(named: 'currentUserPubkey'),
        ),
      ).thenAnswer(
        (i) async => MentionResolutionResult(
          canonicalText: i.namedArguments[#rawText] as String,
          resolvedPubkeys: const [],
          unresolvedTokens: const [],
        ),
      );

      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.searchUsersFromApi(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
        ),
      ).thenAnswer((_) async => []);
    });

    CommentComposerBloc createBloc({
      String? rootAddressableId,
      MentionCandidatePubkeysProvider? candidateProvider,
      DuplicateCommentChecker? isDuplicate,
    }) => CommentComposerBloc(
      commentsRepository: mockCommentsRepository,
      authService: mockAuthService,
      rootEventId: validId('root'),
      rootEventKind: 34236,
      rootAuthorPubkey: validId('author'),
      rootAddressableId: rootAddressableId,
      profileRepository: mockProfileRepository,
      mentionResolutionService: mockMentionResolutionService,
      mentionCandidatePubkeysProvider: candidateProvider,
      isDuplicateSubmission: isDuplicate,
    );

    Comment makeComment(
      String id, {
      String? content,
      String? authorPubkey,
      String? replyToEventId,
      String? replyToAuthorPubkey,
    }) => Comment(
      id: id,
      content: content ?? 'hello',
      authorPubkey: authorPubkey ?? validId('currentuser'),
      createdAt: DateTime.now(),
      rootEventId: validId('root'),
      rootAuthorPubkey: validId('author'),
      replyToEventId: replyToEventId,
      replyToAuthorPubkey: replyToAuthorPubkey,
    );

    test('initial state is empty', () {
      final bloc = createBloc();
      expect(bloc.state.mainInputText, '');
      expect(bloc.state.replyInputText, '');
      expect(bloc.state.editInputText, '');
      expect(bloc.state.activeReplyCommentId, isNull);
      expect(bloc.state.activeEditCommentId, isNull);
      expect(bloc.state.outbox, isNull);
      bloc.close();
    });

    group('CommentTextChanged', () {
      blocTest<CommentComposerBloc, CommentComposerState>(
        'updates mainInputText when no commentId',
        build: createBloc,
        act: (b) => b.add(const CommentTextChanged('hi')),
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.mainInputText,
            'main',
            'hi',
          ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'updates replyInputText when commentId given',
        build: createBloc,
        seed: () => const CommentComposerState(activeReplyCommentId: 'p1'),
        act: (b) => b.add(const CommentTextChanged('reply', commentId: 'p1')),
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.replyInputText,
            'reply',
            'reply',
          ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'updates editInputText when in edit mode',
        build: createBloc,
        seed: () => const CommentComposerState(activeEditCommentId: 'e1'),
        act: (b) => b.add(const CommentTextChanged('edited')),
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.editInputText,
            'edit',
            'edited',
          ),
        ],
      );
    });

    group('CommentReplyToggled', () {
      blocTest<CommentComposerBloc, CommentComposerState>(
        'sets activeReplyCommentId on first tap',
        build: createBloc,
        act: (b) => b.add(CommentReplyToggled(validId('p1'))),
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.activeReplyCommentId,
            'activeReply',
            validId('p1'),
          ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'clears activeReply on second tap (toggle off)',
        build: createBloc,
        seed: () => CommentComposerState(
          activeReplyCommentId: validId('p1'),
          replyInputText: 'draft',
        ),
        act: (b) => b.add(CommentReplyToggled(validId('p1'))),
        expect: () => [
          isA<CommentComposerState>()
              .having((s) => s.activeReplyCommentId, 'activeReply', isNull)
              .having((s) => s.replyInputText, 'replyText', ''),
        ],
      );
    });

    group('CommentSubmitted', () {
      blocTest<CommentComposerBloc, CommentComposerState>(
        'submit pins outbox sequence: Insert THEN Confirm (regression guard)',
        setUp: () {
          final posted = makeComment(validId('confirmed'), content: 'pin');
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer((_) async => posted);
        },
        build: createBloc,
        seed: () => const CommentComposerState(mainInputText: 'pin'),
        act: (b) => b.add(const CommentSubmitted()),
        // Two outbox emissions in order: a refactor that collapses or skips
        // the optimistic Insert (e.g. only emitting Confirm) would break the
        // instant-render UX. The bridge listener reads each state emit, so
        // both must land — pin them here.
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.outbox,
            'outbox after first emit',
            isA<ComposerOutboxInsertPlaceholder>(),
          ),
          isA<CommentComposerState>().having(
            (s) => s.outbox,
            'outbox after second emit',
            isA<ComposerOutboxConfirmPlaceholder>(),
          ),
        ],
      );

      // #5854: a re-sent identical reply (the poster couldn't see the first
      // one because it rendered off-screen) must not publish a duplicate.
      blocTest<CommentComposerBloc, CommentComposerState>(
        'drops a duplicate reply: no publish, reply input cleared',
        build: () => createBloc(isDuplicate: _dupYes),
        seed: () => CommentComposerState(
          activeReplyCommentId: validId('parent'),
          replyInputText: 'same reply',
        ),
        act: (b) => b.add(
          CommentSubmitted(
            parentCommentId: validId('parent'),
            parentAuthorPubkey: validId('parentauthor'),
          ),
        ),
        verify: (b) {
          verifyNever(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          );
          expect(b.state.outbox, isNull);
          expect(b.state.activeReplyCommentId, isNull);
          expect(b.state.replyInputText, isEmpty);
        },
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'a non-duplicate reply publishes normally',
        setUp: () {
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer((_) async => makeComment(validId('confirmed')));
        },
        build: () => createBloc(isDuplicate: _dupNo),
        seed: () => CommentComposerState(
          activeReplyCommentId: validId('parent'),
          replyInputText: 'fresh reply',
        ),
        act: (b) => b.add(
          CommentSubmitted(
            parentCommentId: validId('parent'),
            parentAuthorPubkey: validId('parentauthor'),
          ),
        ),
        verify: (_) {
          verify(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).called(1);
        },
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'submit-fail pins outbox sequence: Insert THEN Rollback',
        setUp: () {
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenThrow(const PostCommentFailedException('boom'));
        },
        build: createBloc,
        seed: () => const CommentComposerState(mainInputText: 'pin'),
        act: (b) => b.add(const CommentSubmitted()),
        errors: () => [isA<PostCommentFailedException>()],
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.outbox,
            'outbox after first emit',
            isA<ComposerOutboxInsertPlaceholder>(),
          ),
          isA<CommentComposerState>().having(
            (s) => s.outbox,
            'outbox after second emit',
            isA<ComposerOutboxRollbackPlaceholder>(),
          ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'emits InsertPlaceholder then ConfirmPlaceholder on success, '
        'passing rootAddressableId (#4478)',
        setUp: () {
          final posted = makeComment(validId('confirmed'), content: 'hello');
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer((_) async => posted);
        },
        build: () => createBloc(rootAddressableId: 'fake-addr'),
        seed: () => const CommentComposerState(mainInputText: 'hello'),
        act: (b) => b.add(const CommentSubmitted()),
        verify: (b) {
          // #4478 — rootAddressableId must be threaded through.
          verify(
            () => mockCommentsRepository.postComment(
              content: 'hello',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: 'fake-addr',
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).called(1);
          expect(b.state.outbox, isA<ComposerOutboxConfirmPlaceholder>());
          final confirm = b.state.outbox! as ComposerOutboxConfirmPlaceholder;
          expect(confirm.confirmed.id, validId('confirmed'));
        },
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'emits RollbackPlaceholder + postCommentFailed on repo throw',
        setUp: () {
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenThrow(const PostCommentFailedException('boom'));
        },
        build: createBloc,
        seed: () => const CommentComposerState(mainInputText: 'hi'),
        act: (b) => b.add(const CommentSubmitted()),
        errors: () => [isA<PostCommentFailedException>()],
        verify: (b) {
          expect(b.state.outbox, isA<ComposerOutboxRollbackPlaceholder>());
          expect(b.state.error, ComposerError.postCommentFailed);
          expect(b.state.mainInputText, 'hi');
        },
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'noop when text empty',
        build: createBloc,
        act: (b) => b.add(const CommentSubmitted()),
        expect: () => isEmpty,
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'emits notAuthenticated when signed out',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
        },
        build: createBloc,
        seed: () => const CommentComposerState(mainInputText: 'hi'),
        act: (b) => b.add(const CommentSubmitted()),
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.error,
            'error',
            ComposerError.notAuthenticated,
          ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'reply submit clears activeReply state and uses postReplyFailed on error',
        setUp: () {
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenThrow(const PostCommentFailedException('boom'));
        },
        build: createBloc,
        seed: () => CommentComposerState(
          activeReplyCommentId: validId('p1'),
          replyInputText: 'a reply',
        ),
        act: (b) => b.add(
          CommentSubmitted(
            parentCommentId: validId('p1'),
            parentAuthorPubkey: validId('parentAuthor'),
          ),
        ),
        errors: () => [isA<PostCommentFailedException>()],
        verify: (b) {
          expect(b.state.error, ComposerError.postReplyFailed);
          expect(b.state.outbox, isA<ComposerOutboxRollbackPlaceholder>());
        },
      );
    });

    group('CommentEditMode', () {
      blocTest<CommentComposerBloc, CommentComposerState>(
        'CommentEditModeEntered captures content and threading info',
        build: createBloc,
        act: (b) => b.add(
          CommentEditModeEntered(
            commentId: validId('e1'),
            originalContent: 'original',
            originalComment: makeComment(validId('e1'), content: 'original'),
            originalReplyToEventId: validId('parent'),
            originalReplyToAuthorPubkey: validId('parentAuthor'),
          ),
        ),
        expect: () => [
          isA<CommentComposerState>()
              .having((s) => s.activeEditCommentId, 'editId', validId('e1'))
              .having((s) => s.editInputText, 'editText', 'original')
              .having(
                (s) => s.activeEditOriginalReplyToEventId,
                'replyToId',
                validId('parent'),
              )
              .having(
                (s) => s.activeEditOriginalComment?.id,
                'originalComment',
                validId('e1'),
              ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'CommentEditModeCancelled clears edit state',
        build: createBloc,
        seed: () => CommentComposerState(
          activeEditCommentId: validId('e1'),
          editInputText: 'wip',
        ),
        act: (b) => b.add(const CommentEditModeCancelled()),
        expect: () => [
          isA<CommentComposerState>()
              .having((s) => s.activeEditCommentId, 'editId', isNull)
              .having((s) => s.editInputText, 'editText', ''),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'CommentEditSubmitted deletes + reposts + emits ReplaceComment outbox '
        'with rootAddressableId (#4478)',
        setUp: () {
          when(
            () => mockCommentsRepository.deleteComment(
              commentId: any(named: 'commentId'),
              rootEventId: any(named: 'rootEventId'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenAnswer((_) async {});
          final reposted = makeComment(validId('reposted'), content: 'edited');
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer((_) async => reposted);
        },
        build: () => createBloc(rootAddressableId: 'fake-addr'),
        seed: () => CommentComposerState(
          activeEditCommentId: validId('e1'),
          editInputText: 'edited',
          activeEditOriginalComment: makeComment(
            validId('e1'),
            content: 'original',
          ),
          activeEditOriginalReplyToEventId: validId('parent'),
          activeEditOriginalReplyToAuthorPubkey: validId('parentAuthor'),
        ),
        act: (b) => b.add(const CommentEditSubmitted()),
        verify: (b) {
          verify(
            () => mockCommentsRepository.deleteComment(
              commentId: validId('e1'),
              rootEventId: any(named: 'rootEventId'),
              rootAddressableId: 'fake-addr',
            ),
          ).called(1);
          verify(
            () => mockCommentsRepository.postComment(
              content: 'edited',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: 'fake-addr',
              replyToEventId: validId('parent'),
              replyToAuthorPubkey: validId('parentAuthor'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).called(1);
          expect(b.state.outbox, isA<ComposerOutboxReplaceComment>());
          final replace = b.state.outbox! as ComposerOutboxReplaceComment;
          expect(replace.oldId, validId('e1'));
          expect(replace.newComment.id, validId('reposted'));
          expect(b.state.activeEditCommentId, isNull);
        },
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'CommentEditSubmitted emits editFailed when delete throws',
        setUp: () {
          when(
            () => mockCommentsRepository.deleteComment(
              commentId: any(named: 'commentId'),
              rootEventId: any(named: 'rootEventId'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenThrow(const DeleteCommentFailedException('relay error'));
        },
        build: createBloc,
        seed: () => CommentComposerState(
          activeEditCommentId: validId('e1'),
          editInputText: 'edited',
          activeEditOriginalComment: makeComment(
            validId('e1'),
            content: 'original',
          ),
        ),
        act: (b) => b.add(const CommentEditSubmitted()),
        errors: () => [isA<DeleteCommentFailedException>()],
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.error,
            'error',
            ComposerError.editFailed,
          ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'CommentEditSubmitted restores original comment when delete succeeds '
        'but replacement publish fails',
        setUp: () {
          when(
            () => mockCommentsRepository.deleteComment(
              commentId: any(named: 'commentId'),
              rootEventId: any(named: 'rootEventId'),
              rootAddressableId: any(named: 'rootAddressableId'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer((invocation) async {
            final content = invocation.namedArguments[#content] as String;
            if (content == 'edited') {
              throw const PostCommentFailedException('replacement failed');
            }
            return makeComment(validId('restored'), content: content);
          });
        },
        build: createBloc,
        seed: () => CommentComposerState(
          activeEditCommentId: validId('e1'),
          editInputText: 'edited',
          activeEditOriginalComment: makeComment(
            validId('e1'),
            content: 'original',
          ),
          activeEditOriginalReplyToEventId: validId('parent'),
          activeEditOriginalReplyToAuthorPubkey: validId('parentAuthor'),
        ),
        act: (b) => b.add(const CommentEditSubmitted()),
        errors: () => [isA<PostCommentFailedException>()],
        verify: (b) {
          verify(
            () => mockCommentsRepository.postComment(
              content: 'original',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: validId('parent'),
              replyToAuthorPubkey: validId('parentAuthor'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).called(1);
          expect(b.state.error, ComposerError.editFailed);
          expect(b.state.outbox, isA<ComposerOutboxReplaceComment>());
          final replace = b.state.outbox! as ComposerOutboxReplaceComment;
          expect(replace.newComment.content, 'original');
          expect(b.state.activeEditCommentId, isNull);
        },
      );
    });

    group('Mentions', () {
      blocTest<CommentComposerBloc, CommentComposerState>(
        'MentionSuggestionsCleared empties mention state',
        build: createBloc,
        seed: () => const CommentComposerState(
          mentionQuery: 'al',
          mentionSuggestions: [MentionSuggestion(pubkey: 'p1')],
        ),
        act: (b) => b.add(const MentionSuggestionsCleared()),
        expect: () => [
          isA<CommentComposerState>()
              .having((s) => s.mentionQuery, 'query', '')
              .having((s) => s.mentionSuggestions, 'suggestions', isEmpty),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'MentionRegistered appends to activeMentions and bindings',
        build: createBloc,
        act: (b) => b.add(
          MentionRegistered(
            displayName: 'Alice',
            pubkey: validId('alice'),
            start: 0,
            end: 6,
          ),
        ),
        expect: () => [
          isA<CommentComposerState>()
              .having(
                (s) => s.activeMentions['Alice'],
                'mention pubkey',
                validId('alice'),
              )
              .having((s) => s.activeMentionBindings.length, 'bindings', 1),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'MentionSearchRequested with empty query clears suggestions',
        build: createBloc,
        seed: () => const CommentComposerState(
          mentionSuggestions: [MentionSuggestion(pubkey: 'p1')],
        ),
        act: (b) => b.add(const MentionSearchRequested('')),
        expect: () => [
          isA<CommentComposerState>().having(
            (s) => s.mentionSuggestions,
            'suggestions',
            isEmpty,
          ),
        ],
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'MentionSearchRequested local tier-1 hit returns suggestion',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer(
            (_) async => UserProfile(
              pubkey: validId('author'),
              name: 'AlicePost',
              createdAt: DateTime.now(),
              eventId: 'eid',
              rawData: const <String, dynamic>{},
            ),
          );
        },
        build: createBloc,
        act: (b) => b.add(const MentionSearchRequested('alice')),
        verify: (b) {
          expect(b.state.mentionSuggestions.isNotEmpty, isTrue);
          expect(b.state.mentionSuggestions.first.displayName, 'AlicePost');
        },
      );
    });

    group('mention conversion on submit', () {
      blocTest<CommentComposerBloc, CommentComposerState>(
        'resolves selected mentions to canonical content and mentionedPubkeys '
        '— matrix-NO repo throwing does not block raw publish',
        setUp: () {
          when(
            () => mockMentionResolutionService.resolveTextMentions(
              rawText: any(named: 'rawText'),
              selectedMentions: any(named: 'selectedMentions'),
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer(
            (_) async => MentionResolutionResult(
              canonicalText: 'hello nostr:npub1alicexxxx',
              resolvedPubkeys: [validId('alice')],
              unresolvedTokens: const [],
            ),
          );
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer(
            (_) async => makeComment(validId('confirmed'), content: 'hello'),
          );
        },
        build: createBloc,
        seed: () => CommentComposerState(
          mainInputText: 'hello @Alice',
          activeMentions: {'Alice': validId('alice')},
          activeMentionBindings: [
            MentionBinding(display: 'Alice', pubkey: validId('alice')),
          ],
        ),
        act: (b) => b.add(const CommentSubmitted()),
        verify: (_) {
          verify(
            () => mockCommentsRepository.postComment(
              content: 'hello nostr:npub1alicexxxx',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: [validId('alice')],
            ),
          ).called(1);
        },
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'clears activeMentions / activeMentionBindings after successful post',
        setUp: () {
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer((_) async => makeComment(validId('confirmed')));
        },
        build: createBloc,
        seed: () => CommentComposerState(
          mainInputText: 'hi @Bob',
          activeMentions: {'Bob': validId('bob')},
          activeMentionBindings: [
            MentionBinding(display: 'Bob', pubkey: validId('bob')),
          ],
        ),
        act: (b) => b.add(const CommentSubmitted()),
        verify: (b) {
          expect(b.state.activeMentions, isEmpty);
          expect(b.state.activeMentionBindings, isEmpty);
          expect(b.state.mainInputText, '');
        },
      );

      blocTest<CommentComposerBloc, CommentComposerState>(
        'publish proceeds with raw text when MentionResolutionService throws',
        setUp: () {
          when(
            () => mockMentionResolutionService.resolveTextMentions(
              rawText: any(named: 'rawText'),
              selectedMentions: any(named: 'selectedMentions'),
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenThrow(Exception('typed resolution timeout'));
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any(named: 'mentionedPubkeys'),
            ),
          ).thenAnswer((_) async => makeComment(validId('raw')));
        },
        build: createBloc,
        seed: () => const CommentComposerState(mainInputText: 'raw hello'),
        // Mention-resolution-throw is Reportable; absorb it so the test
        // doesn't fail on the propagated error.
        errors: () => [isA<Object>()],
        act: (b) => b.add(const CommentSubmitted()),
        verify: (_) {
          // Raw text was published despite resolution throw.
          verify(
            () => mockCommentsRepository.postComment(
              content: 'raw hello',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              rootAddressableId: any(named: 'rootAddressableId'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
              mentionedPubkeys: any<List<String>>(
                named: 'mentionedPubkeys',
                that: isEmpty,
              ),
            ),
          ).called(1);
        },
      );
    });

    group('ComposerOutboxConsumed', () {
      blocTest<CommentComposerBloc, CommentComposerState>(
        'clears outbox to null',
        build: createBloc,
        seed: () => const CommentComposerState(
          outbox: ComposerOutboxRollbackPlaceholder('pending_comment_123'),
        ),
        act: (b) => b.add(const ComposerOutboxConsumed()),
        expect: () => [
          isA<CommentComposerState>().having((s) => s.outbox, 'outbox', isNull),
        ],
      );
    });
  });
}
