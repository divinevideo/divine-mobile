import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedBlocState>
    implements VideoFeedBloc {}

void main() {
  group('VideoFeedView web', () {
    late MockVideoFeedBloc mockBloc;
    late MockProfileRepository mockProfileRepository;

    setUpAll(() {
      registerFallbackValue(const VideoFeedStarted());
    });

    setUp(() {
      mockBloc = MockVideoFeedBloc();
      mockProfileRepository = createMockProfileRepository();
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    testWidgets('opens and toggles Auto in home web playback settings', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final preferences = createMockSharedPreferences();
        final video = createTestVideoEvent(
          id: 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
          pubkey: 'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
          videoUrl: 'https://example.com/video1.mp4',
        );
        final state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        when(() => mockBloc.state).thenReturn(state);

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              routerLocationStreamProvider.overrideWith(
                (ref) => Stream.value('/home'),
              ),
            ],
            mockProfileRepository: mockProfileRepository,
            mockSharedPreferences: preferences,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: mockBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>(
                  create: (_) => VideoVolumeCubit(
                    sharedPreferences: preferences,
                  ),
                ),
              ],
              child: const Scaffold(body: VideoFeedView()),
            ),
          ),
        );
        await tester.pump();

        final l10n = tester.element(find.byType(VideoFeedView)).l10n;
        await tester.tap(find.bySemanticsLabel(l10n.videoSettingsMenuOpen));
        await tester.pump();
        expect(find.byType(FeedPlaybackTogglesPill), findsOneWidget);
        final autoAdvance = tester
            .element(find.byType(FeedPlaybackTogglesPill))
            .read<FeedAutoAdvanceCubit>();
        expect(autoAdvance.state.enabled, isFalse);
        expect(
          find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
          findsOneWidget,
        );
        await tester.tap(
          find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        );
        await tester.pump();
        expect(autoAdvance.state.enabled, isTrue);
        expect(find.text(l10n.videoSettingsAutoAdvanceOn), findsOneWidget);
        expect(find.byType(FeedPlaybackTogglesPill), findsNothing);
      } finally {
        semantics.dispose();
      }
    }, skip: !kIsWeb);
  });
}
