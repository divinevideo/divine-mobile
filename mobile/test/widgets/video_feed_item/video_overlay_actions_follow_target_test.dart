// ABOUTME: Composition tests for the feed author cluster's follow tap target.
// ABOUTME: Guards the cluster size in both badge states and the name's place.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// The cluster's floor: the avatar plus the sliver the badge overflows into.
const double _clusterFloor = 58;

/// The badge's offset inside the avatar, mirrored from `video_feed_item.dart`.
const double _badgeOffset = 31;

/// What the cluster grows to while the badge holds a tap target.
const double _clusterWithTarget = _badgeOffset + followButtonTapTargetSize;

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

  Finder clusterFinder() => find
      .ancestor(of: find.byType(UserAvatar), matching: find.byType(Stack))
      .first;

  group('VideoOverlayActions follow target', () {
    testWidgets('grows the cluster to hold a 48dp target', (tester) async {
      await pumpOverlay(tester, alreadyFollowing: false);

      // Not cosmetic: a positioned target outside the cluster is rejected by
      // the parent before it reaches the badge, so the cluster has to carry it.
      expect(
        tester.getSize(clusterFinder()),
        const Size(_clusterWithTarget, _clusterWithTarget),
      );
    });

    testWidgets('leaves the cluster at its floor for an author already '
        'followed', (tester) async {
      await pumpOverlay(tester, alreadyFollowing: true);

      // The state is known synchronously in initState, so this item never
      // reserves the target and never pays for it.
      expect(
        tester.getSize(clusterFinder()),
        const Size(_clusterFloor, _clusterFloor),
      );
    });

    testWidgets(
      'keeps the avatar at the top of the row at a large text scale',
      (
        tester,
      ) async {
        // The author row is not one of the clamped subtrees in
        // `text_scale_limits.dart`, so it takes the full system scale. Past a
        // point the text column outgrows the cluster, and the row's alignment
        // decides where the avatar sits: top-aligned it stays level with the
        // first line of the name, centred it drifts down the column.
        await pumpOverlay(
          tester,
          alreadyFollowing: true,
          textScaler: const TextScaler.linear(3),
        );

        final row = find
            .ancestor(of: clusterFinder(), matching: find.byType(Row))
            .first;
        final rowTop = tester.getTopLeft(row).dy;

        // Guard against a vacuous pass: the case only exists once the column is
        // taller than the cluster.
        expect(tester.getSize(row).height, greaterThan(_clusterFloor));
        expect(tester.getTopLeft(find.byType(UserAvatar)).dy, rowTop);
      },
    );

    testWidgets('keeps the author name level with the avatar in both states', (
      tester,
    ) async {
      // The cluster is taller than the text column while the target is
      // reserved. Centred, that would sink the name inside it — so the row is
      // top-aligned and the name must not move between the two states.
      await pumpOverlay(tester, alreadyFollowing: true);
      final floorOffset =
          tester.getTopLeft(find.text('Alice')).dy -
          tester.getTopLeft(find.byType(UserAvatar)).dy;

      // Unmount between the two states. VideoFollowButton decides whether to
      // reserve a target in initState, and pumping the same tree again reuses
      // the element, so without this the second half re-measures the first.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await pumpOverlay(tester, alreadyFollowing: false);
      final reservedOffset =
          tester.getTopLeft(find.text('Alice')).dy -
          tester.getTopLeft(find.byType(UserAvatar)).dy;

      expect(reservedOffset, floorOffset);
    });
  });
}
