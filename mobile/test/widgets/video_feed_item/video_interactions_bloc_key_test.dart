import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/like_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/repost_action_button.dart';
import 'package:openvine/widgets/video_feed_item/video_interactions_bloc_key.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  group(videoInteractionsBlocKey, () {
    late _MockLikesRepository likesRepository;
    late _MockCommentsRepository commentsRepository;
    late _MockRepostsRepository repostsRepository;

    setUp(() {
      likesRepository = _MockLikesRepository();
      commentsRepository = _MockCommentsRepository();
      repostsRepository = _MockRepostsRepository();
    });

    test('changes when the hosted video changes', () {
      final firstKey = videoInteractionsBlocKey(
        likesRepository: likesRepository,
        commentsRepository: commentsRepository,
        repostsRepository: repostsRepository,
        video: _video(id: 'video-a'),
      );
      final secondKey = videoInteractionsBlocKey(
        likesRepository: likesRepository,
        commentsRepository: commentsRepository,
        repostsRepository: repostsRepository,
        video: _video(id: 'video-b'),
      );

      expect(firstKey, isNot(equals(secondKey)));
    });

    testWidgets('does not keep fetched counts after feed cell reuse', (
      tester,
    ) async {
      when(
        () => likesRepository.isLikedResolvingCoordinate(
          eventId: any(named: 'eventId'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => likesRepository.getLikeCount(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((invocation) async {
        final eventId = invocation.positionalArguments.single as String;
        return eventId == 'video-a' ? 100 : 0;
      });
      when(
        () => commentsRepository.getCommentsCount(
          any(),
          rootAddressableId: any(named: 'rootAddressableId'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => repostsRepository.getRepostCountByEventId(any()),
      ).thenAnswer((invocation) async {
        final eventId = invocation.positionalArguments.single as String;
        return eventId == 'video-a' ? 40 : 0;
      });

      await tester.pumpWidget(
        _InteractionHost(
          likesRepository: likesRepository,
          commentsRepository: commentsRepository,
          repostsRepository: repostsRepository,
          video: _video(id: 'video-a'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);

      await tester.pumpWidget(
        _InteractionHost(
          likesRepository: likesRepository,
          commentsRepository: commentsRepository,
          repostsRepository: repostsRepository,
          video: _video(id: 'video-b'),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text('100'), findsNothing);
      expect(find.text('40'), findsNothing);
      expect(find.text(l10n.videoActionLikeLabel), findsOneWidget);
      expect(find.text(l10n.videoActionRepostLabel), findsOneWidget);
    });
  });
}

class _InteractionHost extends StatelessWidget {
  const _InteractionHost({
    required this.likesRepository,
    required this.commentsRepository,
    required this.repostsRepository,
    required this.video,
  });

  final LikesRepository likesRepository;
  final CommentsRepository commentsRepository;
  final RepostsRepository repostsRepository;
  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<VideoInteractionsBloc>(
          key: videoInteractionsBlocKey(
            likesRepository: likesRepository,
            commentsRepository: commentsRepository,
            repostsRepository: repostsRepository,
            video: video,
          ),
          create: (_) => VideoInteractionsBloc(
            eventId: video.id,
            authorPubkey: video.pubkey,
            likesRepository: likesRepository,
            commentsRepository: commentsRepository,
            repostsRepository: repostsRepository,
          )..add(const VideoInteractionsFetchRequested()),
          child: Column(
            children: [
              LikeActionButton(video: video),
              RepostActionButton(video: video),
            ],
          ),
        ),
      ),
    );
  }
}

VideoEvent _video({required String id}) {
  return VideoEvent(
    id: id,
    pubkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    createdAt: 1757385263,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
  );
}
