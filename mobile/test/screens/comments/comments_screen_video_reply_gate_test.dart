// ABOUTME: Tests that the comment input offers a video reply only to whoever
// ABOUTME: may answer the video's replies sticker.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCommentsListBloc
    extends MockBloc<CommentsListEvent, CommentsListState>
    implements CommentsListBloc {}

class _MockCommentComposerBloc
    extends MockBloc<CommentComposerEvent, CommentComposerState>
    implements CommentComposerBloc {}

class _MockCommentReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

class _Session extends NostrSession {
  _Session(this._pubkey);

  final String _pubkey;

  @override
  NostrSessionReadiness build() =>
      NostrSessionReadiness.identityKnown(pubkey: _pubkey);
}

final String _creator = 'a' * 64;
final String _friend = 'b' * 64;
final String _stranger = 'c' * 64;

final VideoEvent _video = VideoEvent(
  id: 'd' * 64,
  pubkey: _creator,
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
  stickerRegions: const [
    VideoStickerRegion(
      kind: VideoStickerKind.replies,
      target: '',
      centerX: 0.5,
      centerY: 0.5,
      width: 0.6,
      height: 0.3,
      label: 'Reply with a video',
      audience: VideoStickerAudience.following,
    ),
  ],
);

void main() {
  group(MainCommentInput, () {
    late _MockFollowRepository followRepository;

    setUp(() {
      followRepository = _MockFollowRepository();
      when(() => followRepository.getOthersFollowing(_creator)).thenAnswer(
        (_) async => FollowingSnapshot(pubkeys: [_friend], count: 1),
      );
    });

    Future<void> pump(WidgetTester tester, {required String viewer}) async {
      final list = _MockCommentsListBloc();
      when(() => list.state).thenReturn(
        CommentsListState(rootEventId: _video.id, rootAuthorPubkey: _creator),
      );
      final composer = _MockCommentComposerBloc();
      when(() => composer.state).thenReturn(const CommentComposerState());
      final reactions = _MockCommentReactionsBloc();
      when(() => reactions.state).thenReturn(const CommentReactionsState());
      final draggable = DraggableScrollableController();
      addTearDown(draggable.dispose);

      await tester.pumpWidget(
        testMaterialApp(
          mockFollowRepository: followRepository,
          additionalOverrides: [
            nostrSessionProvider.overrideWith(() => _Session(viewer)),
          ],
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentsListBloc>.value(value: list),
                BlocProvider<CommentComposerBloc>.value(value: composer),
                BlocProvider<CommentReactionsBloc>.value(value: reactions),
              ],
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MainCommentInput(
                  draggableController: draggable,
                  video: _video,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder videoReplyButton(WidgetTester tester) => find.bySemanticsLabel(
      lookupAppLocalizations(const Locale('en')).commentsRecordVideoButtonLabel,
    );

    group('renders', () {
      testWidgets('offers a video reply to someone the creator follows', (
        tester,
      ) async {
        await pump(tester, viewer: _friend);

        expect(videoReplyButton(tester), findsOneWidget);
      });

      testWidgets('offers no video reply to anyone else', (tester) async {
        await pump(tester, viewer: _stranger);

        expect(videoReplyButton(tester), findsNothing);
      });
    });
  });
}
