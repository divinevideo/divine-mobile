import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

class _FakeDivineVideoPlayerController extends DivineVideoPlayerController {
  _FakeDivineVideoPlayerController() : super();

  final _streamController =
      StreamController<DivineVideoPlayerState>.broadcast();
  DivineVideoPlayerState _state = const DivineVideoPlayerState();

  @override
  DivineVideoPlayerState get state => _state;

  @override
  Stream<DivineVideoPlayerState> get stateStream => _streamController.stream;

  void pushState(DivineVideoPlayerState state) {
    _state = state;
    _streamController.add(state);
  }

  @override
  Future<void> dispose() => _streamController.close();
}

void main() {
  group(PausedVideoOverlay, () {
    late _FakeDivineVideoPlayerController controller;
    late FeedAutoAdvanceCubit autoAdvanceCubit;
    late VideoVolumeCubit volumeCubit;
    late SharedPreferences mockPrefs;

    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      controller = _FakeDivineVideoPlayerController();
      autoAdvanceCubit = FeedAutoAdvanceCubit();
      volumeCubit = _MockVideoVolumeCubit();
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      mockPrefs = createMockSharedPreferences();
    });

    tearDown(() async {
      await controller.dispose();
      await autoAdvanceCubit.close();
    });

    Widget buildSubject() {
      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<FeedAutoAdvanceCubit>.value(value: autoAdvanceCubit),
              BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
            ],
            child: Scaffold(
              body: PausedVideoOverlay(
                controller: controller,
                videoId: 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
              ),
            ),
          ),
        ),
      );
    }

    Finder findPlayControl() => find.byWidgetPredicate(
      (widget) =>
          widget is CenterPlaybackControl &&
          widget.state == CenterPlaybackControlState.play,
    );

    testWidgets(
      'shows play affordance for a first-frame paused controller even when '
      'visible playback was never observed',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        controller.pushState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.paused,
            isFirstFrameRendered: true,
            videoWidth: 1280,
            videoHeight: 720,
          ),
        );
        await tester.pump();
        // Stable paused state is promoted after a short debounce, then
        // the AnimatedSwitcher fades the play affordance in. Wait long
        // enough for both.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 220));

        expect(findPlayControl(), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'suppresses transient first-frame paused state that resolves quickly',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        controller.pushState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.paused,
            isFirstFrameRendered: true,
            videoWidth: 1280,
            videoHeight: 720,
          ),
        );
        await tester.pump();
        expect(findPlayControl(), findsNothing);

        await tester.pump(const Duration(milliseconds: 150));
        expect(findPlayControl(), findsNothing);

        controller.pushState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.playing,
            isFirstFrameRendered: true,
            videoWidth: 1280,
            videoHeight: 720,
          ),
        );
        await tester.pump();
        expect(findPlayControl(), findsNothing);

        await tester.pump(const Duration(milliseconds: 350));
        expect(findPlayControl(), findsNothing);
      },
    );
  });
}
