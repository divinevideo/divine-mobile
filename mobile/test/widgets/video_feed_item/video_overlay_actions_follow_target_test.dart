// ABOUTME: Composition tests for the feed author row's follow tap target.
// ABOUTME: Pins that the 48dp target costs no layout and wins its overlaps.

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

/// The author cluster's height, mirrored from `video_feed_item.dart`.
const double _clusterSize = 58;

/// Where the painted badge sits inside the cluster.
const double _badgeOffset = 31;

/// The target is bottom-aligned to the cluster, so it fits inside the row.
const double _targetTop = _clusterSize - followButtonTapTargetSize;

/// The avatar's painted size, which is smaller than the cluster it sits in.
const double _avatarSize = 48;

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

  group('VideoOverlayActions follow target', () {
    testWidgets('a 48dp target costs the author row no height', (
      tester,
    ) async {
      await pumpOverlay(tester, alreadyFollowing: false);

      expect(
        tester.getSize(find.byType(VideoFollowButton)),
        const Size(followButtonTapTargetSize, followButtonTapTargetSize),
      );
      // The target is larger than the row's avatar block and still costs
      // nothing: it is positioned, so it does not size its parent.
      expect(tester.getSize(authorRow()).height, _clusterSize);
    });

    testWidgets('the avatar paints at 48dp inside its 58dp slot', (
      tester,
    ) async {
      await pumpOverlay(tester, alreadyFollowing: false);

      // The cluster is 58dp so the row keeps its height and the name keeps
      // its x, but the avatar itself must stay the 48dp it has always been.
      // A tight 58dp parent would override UserAvatar(size: 48) and repaint
      // every author 10dp larger.
      expect(tester.getSize(authorRow()).height, _clusterSize);
      expect(
        tester.getSize(find.byType(UserAvatar)),
        const Size(_avatarSize, _avatarSize),
      );
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

    testWidgets('the painted badge keeps the corner it has always drawn in', (
      tester,
    ) async {
      await pumpOverlay(tester, alreadyFollowing: false);

      final avatar = tester.getTopLeft(find.byType(UserAvatar));
      final target = tester.getTopLeft(find.byType(VideoFollowButton));
      // The target is bottom-aligned to the cluster, so it starts above the
      // badge; the badge itself is inset back down to (31, 31).
      expect(target - avatar, const Offset(_badgeOffset, _targetTop));

      final circle = tester.getTopLeft(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(circle - avatar, const Offset(_badgeOffset, _badgeOffset));
    });

    testWidgets('the target wins the strip it shares with the author name', (
      tester,
    ) async {
      // The target is wider than the avatar block, so it overlaps the name
      // column. Overlaying it on the row rather than nesting it inside is
      // what makes it win those taps — nested, the name column is hit-tested
      // first and swallows them.
      await pumpOverlay(tester, alreadyFollowing: false);

      final target = tester.getRect(find.byType(VideoFollowButton));
      final avatarRight = tester.getRect(find.byType(UserAvatar)).right;
      expect(
        target.right,
        greaterThan(avatarRight),
        reason: 'the overlap this test is about must exist',
      );

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

      // Past the avatar block, inside the target: the name's strip.
      expect(followOwns(Offset(avatarRight + 20, target.center.dy)), isTrue);
      // Outside the target entirely: still the name's.
      expect(followOwns(Offset(target.right + 20, target.center.dy)), isFalse);
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
        greaterThan(_clusterSize),
        reason: 'the case only exists once the column outgrows the cluster',
      );
      expect(
        tester.getTopLeft(find.byType(VideoFollowButton)) -
            tester.getTopLeft(find.byType(UserAvatar)),
        const Offset(_badgeOffset, _targetTop),
      );
    });
  });
}
