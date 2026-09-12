// ABOUTME: Composition tests for the feed author row's follow tap target.
// ABOUTME: Pins the designed geometry: a 44dp target overhanging the avatar
// ABOUTME: by 16dp, ending flush with the name column and the caption.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

/// The author avatar's size, mirrored from `video_feed_item.dart`.
const double _avatarSize = 44;

/// Where the target's top-start corner sits, from the avatar's.
const double _targetOffset = 16;

/// The painted badge is centred in the target, so it sits one padding further
/// in on both axes.
const double _badgeOffset = _targetOffset + followButtonPadding;

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late VideoEvent testVideo;

  setUp(() {
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockInteractionsBloc.state,
    ).thenReturn(const VideoInteractionsState());

    testVideo = VideoEvent(
      id: 'follow-target-test-0123456789abcdef0123456789abcdef0123456789ab',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'A description',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: 'Test Video',
    );
  });

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required bool alreadyFollowing,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final follow = createMockFollowRepository();
    when(() => follow.isFollowing(any())).thenReturn(alreadyFollowing);
    // The badge only paints once MyFollowingBloc reports; the shared mock
    // yields an empty stream, which would leave it invisible.
    when(follow.watchMyFollowingCached).thenAnswer(
      (_) => Stream.value(
        const CacheResult.live(FollowingSnapshot(pubkeys: [], count: 0)),
      ),
    );

    await tester.pumpWidget(
      testProviderScope(
        mockFollowRepository: follow,
        additionalOverrides: [
          userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
            yield UserProfile(
              pubkey: pubkey,
              displayName: 'Alice',
              rawData: const {},
              createdAt: DateTime(2026),
              eventId: 'kind0_event_id',
            );
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: BlocProvider<VideoInteractionsBloc>.value(
                  value: mockInteractionsBloc,
                  child: VideoOverlayActions(
                    video: testVideo,
                    isVisible: true,
                    isActive: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder authorRow() => find
      .ancestor(of: find.byType(UserAvatar), matching: find.byType(Row))
      .first;

  Finder paintedBadge() => find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  Finder metaLine() => find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_VideoCardMetaLine',
  );

  group('VideoOverlayActions follow target', () {
    testWidgets('the avatar is 44dp and starts the row with no padding', (
      tester,
    ) async {
      await pumpOverlay(tester, alreadyFollowing: false);

      final avatar = tester.getRect(find.byType(UserAvatar));
      final row = tester.getRect(authorRow());
      expect(avatar.size, const Size(_avatarSize, _avatarSize));
      expect(avatar.topLeft, row.topLeft);
      expect(row.height, _avatarSize);
    });

    testWidgets('a 44dp target costs the author row no height', (
      tester,
    ) async {
      await pumpOverlay(tester, alreadyFollowing: false);

      expect(
        tester.getSize(find.byType(VideoFollowButton)),
        const Size(followButtonTapTargetSize, followButtonTapTargetSize),
      );
      // The target is positioned, so it does not size its parent: the row
      // stays exactly one avatar tall.
      expect(tester.getSize(authorRow()).height, _avatarSize);
    });

    testWidgets('the row is identical whether or not the badge shows', (
      tester,
    ) async {
      await pumpOverlay(tester, alreadyFollowing: false);
      final withBadge = tester.getSize(authorRow());
      final nameWithBadge = tester.getTopLeft(find.text('Alice'));
      expect(find.byType(VideoFollowButton), findsOneWidget);

      // Unmount: VideoFollowButton decides in initState, so re-pumping the
      // same tree would re-measure the first state.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await pumpOverlay(tester, alreadyFollowing: true);

      expect(tester.getSize(authorRow()), withBadge);
      expect(tester.getTopLeft(find.text('Alice')), nameWithBadge);
    });

    testWidgets(
      'the target overhangs the avatar by 16dp with the badge centred',
      (
        tester,
      ) async {
        await pumpOverlay(tester, alreadyFollowing: false);

        final avatar = tester.getTopLeft(find.byType(UserAvatar));
        final target = tester.getTopLeft(find.byType(VideoFollowButton));
        expect(target - avatar, const Offset(_targetOffset, _targetOffset));

        final circle = tester.getTopLeft(paintedBadge());
        expect(circle - avatar, const Offset(_badgeOffset, _badgeOffset));
      },
    );

    testWidgets('the target ends where the name column starts', (
      tester,
    ) async {
      // The overhang equals the gap between avatar and name, so the target
      // owns that gap and stops flush with the name rather than under it.
      await pumpOverlay(tester, alreadyFollowing: false);

      final target = tester.getRect(find.byType(VideoFollowButton));
      final avatarRight = tester.getRect(find.byType(UserAvatar)).right;
      final nameLeft = tester.getRect(find.text('Alice')).left;
      expect(target.right, avatarRight + _targetOffset);
      expect(nameLeft, target.right);

      final badgeRenderObjects = <RenderObject>{};
      void collect(Element e) {
        final ro = e.renderObject;
        if (ro != null) badgeRenderObjects.add(ro);
        e.visitChildren(collect);
      }

      collect(find.byType(VideoFollowButton).evaluate().single);

      final viewId = View.of(
        tester.element(find.byType(VideoOverlayActions)),
      ).viewId;
      bool followOwns(Offset point) {
        final result = HitTestResult();
        WidgetsBinding.instance.hitTestInView(result, point, viewId);
        return result.path.any((e) => badgeRenderObjects.contains(e.target));
      }

      // Inside the gap between avatar and name: the target's.
      expect(followOwns(Offset(avatarRight + 8, target.center.dy)), isTrue);
      // Just past the target, on the name: not the target's.
      expect(followOwns(Offset(target.right + 4, target.center.dy)), isFalse);
      // The avatar's bottom-end corner, under the overhang: the target's.
      // Measured from the avatar's bottom, not the target's: the target
      // reaches 16dp below the avatar, so a point measured from its bottom
      // lies outside the avatar and cannot tell which of the two wins.
      final avatarBottom = tester.getRect(find.byType(UserAvatar)).bottom;
      expect(followOwns(Offset(avatarRight - 8, avatarBottom - 8)), isTrue);
    });

    testWidgets('the target ends where the caption starts', (tester) async {
      // The gap below the row equals the overhang, so the target's bottom
      // edge is flush with the title without reaching into it.
      await pumpOverlay(tester, alreadyFollowing: false);

      final target = tester.getRect(find.byType(VideoFollowButton));
      final title = tester.getRect(find.text('Test Video'));
      expect(title.top, target.bottom);
      expect(
        title.top,
        tester.getRect(find.byType(UserAvatar)).bottom + _targetOffset,
      );
    });

    testWidgets('the name and meta line are centred on the avatar', (
      tester,
    ) async {
      await pumpOverlay(tester, alreadyFollowing: false);

      final avatar = tester.getRect(find.byType(UserAvatar));
      final name = tester.getRect(find.text('Alice'));
      final meta = tester.getRect(metaLine());
      expect(meta.top, greaterThanOrEqualTo(name.bottom));

      final textBlock = name.expandToInclude(meta);
      expect(textBlock.center.dy, closeTo(avatar.center.dy, 0.5));
    });

    testWidgets('the badge stays with the avatar at a large text scale', (
      tester,
    ) async {
      // The author row is not one of the clamped subtrees in
      // `text_scale_limits.dart`, so it takes the full system scale. The
      // target is positioned from the row's top, so a row that centred its
      // avatar would leave the badge floating away from it.
      await pumpOverlay(
        tester,
        alreadyFollowing: false,
        textScaler: const TextScaler.linear(3),
      );

      expect(
        tester.getSize(authorRow()).height,
        greaterThan(_avatarSize),
        reason: 'the case only exists once the column outgrows the avatar',
      );
      expect(
        tester.getTopLeft(find.byType(VideoFollowButton)) -
            tester.getTopLeft(find.byType(UserAvatar)),
        const Offset(_targetOffset, _targetOffset),
      );
    });
  });
}
