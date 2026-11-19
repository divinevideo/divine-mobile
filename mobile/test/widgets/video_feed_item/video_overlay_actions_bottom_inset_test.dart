// ABOUTME: Pins how far above the bottom edge the fullscreen feed overlay
// ABOUTME: sits, with and without a home indicator, on large and phone screens

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

/// The iPhone Duo's inner display in landscape.
const Size _duoLandscape = Size(951, 669);

/// A phone held upright.
const Size _phone = Size(402, 874);

void main() {
  late _MockVideoInteractionsBloc interactionsBloc;
  late VideoEvent video;

  setUp(() {
    interactionsBloc = _MockVideoInteractionsBloc();
    when(() => interactionsBloc.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => interactionsBloc.state,
    ).thenReturn(const VideoInteractionsState());
    video = VideoEvent(
      id: 'bottom-inset-test-0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'A description',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
    );
  });

  /// The distance from the bottom edge to the action column's bottom.
  Future<double> actionColumnGap(
    WidgetTester tester, {
    required double bottomInset,
    Size surfaceSize = _duoLandscape,
    bool largeScreenLayout = true,
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    final follow = createMockFollowRepository();
    when(() => follow.isFollowing(any())).thenReturn(false);
    when(follow.watchMyFollowingCached).thenAnswer(
      (_) => Stream.value(
        const CacheResult.live(FollowingSnapshot(pubkeys: [], count: 0)),
      ),
    );
    await tester.pumpWidget(
      testProviderScope(
        mockFollowRepository: follow,
        additionalOverrides: [
          isFeatureEnabledProvider(
            FeatureFlag.largeScreenLayout,
          ).overrideWithValue(largeScreenLayout),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AdaptiveLayoutScope(child: child!),
          home: BlocProvider<VideoInteractionsBloc>.value(
            value: interactionsBloc,
            child: VideoOverlayActions(
              video: video,
              isVisible: true,
              isActive: true,
              isFullscreen: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return surfaceSize.height -
        tester.getRect(find.byType(VideoOverlayActionColumn)).bottom;
  }

  group(VideoOverlayActions, () {
    group('bottom edge', () {
      testWidgets('sits 20 px above an edge with no inset', (tester) async {
        expect(await actionColumnGap(tester, bottomInset: 0), equals(20));
      });

      testWidgets(
        'keeps clear of a home indicator without adding the 20 px to it '
        'on a large screen',
        (tester) async {
          expect(await actionColumnGap(tester, bottomInset: 34), equals(34));
        },
      );

      testWidgets('adds the 20 px to a home indicator on a phone', (
        tester,
      ) async {
        expect(
          await actionColumnGap(
            tester,
            bottomInset: 34,
            surfaceSize: _phone,
          ),
          equals(54),
        );
      });

      testWidgets('adds the 20 px to a home indicator with the flag off', (
        tester,
      ) async {
        expect(
          await actionColumnGap(
            tester,
            bottomInset: 34,
            largeScreenLayout: false,
          ),
          equals(54),
        );
      });
    });
  });
}
