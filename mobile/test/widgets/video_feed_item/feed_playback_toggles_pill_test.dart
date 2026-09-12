import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

void main() {
  group(FeedPlaybackTogglesPill, () {
    late FeedAutoAdvanceCubit autoAdvanceCubit;
    late VideoVolumeCubit volumeCubit;
    late SharedPreferences mockPrefs;

    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      autoAdvanceCubit = FeedAutoAdvanceCubit();
      volumeCubit = _MockVideoVolumeCubit();
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      mockPrefs = createMockSharedPreferences();
    });

    tearDown(() async {
      await autoAdvanceCubit.close();
    });

    Widget buildSubject({
      bool reducedMotion = false,
      bool provideAutoAdvance = true,
      ThemeData? theme,
      String? videoId,
    }) {
      Widget pill = Scaffold(body: FeedPlaybackTogglesPill(videoId: videoId));

      pill = provideAutoAdvance
          ? MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(
                  value: autoAdvanceCubit,
                ),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: pill,
            )
          : BlocProvider<VideoVolumeCubit>.value(
              value: volumeCubit,
              child: pill,
            );

      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: pill,
          ),
        ),
      );
    }

    testWidgets('renders all three toggles when cubits are in scope', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
        findsOneWidget,
      );
    });

    testWidgets('hides the compilations toggle under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(reducedMotion: true));
      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(l10n.videoActionDisableAutoAdvance),
        findsNothing,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
    });

    testWidgets(
      'uses light media chrome under the light theme',
      (tester) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.lightTheme));

        final chromeBox = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .firstWhere(
              (box) =>
                  box.decoration is BoxDecoration &&
                  (box.decoration as BoxDecoration).color ==
                      VineTheme.lightColors.mediaChrome,
            );

        expect(chromeBox, isNotNull);
        final icons = tester.widgetList<DivineIcon>(find.byType(DivineIcon));
        expect(
          icons.map((icon) => icon.color),
          everyElement(equals(VineTheme.lightColors.mediaChromeForeground)),
        );
      },
    );

    testWidgets('tapping the captions toggle flips subtitle visibility', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );
      addTearDown(container.dispose);
      // Keep the provider subscribed so auto-dispose timers don't fire
      // mid-test and trip the timer-pending invariant in testWidgets.
      container.listen(subtitleVisibilityProvider, (_, _) {});
      expect(container.read(subtitleVisibilityProvider), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(
                  value: autoAdvanceCubit,
                ),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: const Scaffold(body: FeedPlaybackTogglesPill()),
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
      );
      await tester.pump();
      expect(container.read(subtitleVisibilityProvider), isFalse);

      expect(find.text(l10n.videoSettingsCaptionsOff), findsOneWidget);
    });

    testWidgets('scoped captions toggle leaves global preference untouched', (
      tester,
    ) async {
      const videoId =
          'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
      const otherVideoId =
          'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(subtitleVisibilityProvider), isTrue);
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoId)),
        isTrue,
      );
      expect(
        container.read(subtitleVisibilityForVideoProvider(otherVideoId)),
        isTrue,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(
                  value: autoAdvanceCubit,
                ),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: const Scaffold(
                body: FeedPlaybackTogglesPill(videoId: videoId),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
      );
      await tester.pump();

      expect(container.read(subtitleVisibilityProvider), isTrue);
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoId)),
        isFalse,
      );
      expect(
        container.read(subtitleVisibilityForVideoProvider(otherVideoId)),
        isTrue,
      );
      verifyNever(
        () => mockPrefs.setBool('subtitle_visibility_enabled', any()),
      );
      expect(find.text(l10n.videoSettingsCaptionsOffForVideo), findsOneWidget);
    });

    testWidgets(
      'tapping the mute toggle calls VideoVolumeCubit.onPlaybackVolumeChanged',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.tap(find.bySemanticsLabel(l10n.videoPlayerMute));
        await tester.pump();

        verify(() => volumeCubit.onPlaybackVolumeChanged(0)).called(1);
        // Muting is self-evident — the sound stops and the icon flips — so it
        // deliberately stays banner-free.
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'tapping the compilations toggle calls FeedAutoAdvanceCubit.toggle',
      (tester) async {
        expect(autoAdvanceCubit.state.enabled, isFalse);
        await tester.pumpWidget(buildSubject());

        await tester.tap(
          find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        );
        await tester.pump();

        expect(autoAdvanceCubit.state.enabled, isTrue);
        expect(find.text(l10n.videoSettingsAutoAdvanceOn), findsOneWidget);
      },
    );

    testWidgets('turns Auto off in one tap while it is suppressed', (
      tester,
    ) async {
      // The paused-video overlay's own reveal tap suppresses Auto
      // (`_handlePlayerTap` calls `onSuppressAutoAdvance` before pausing), so
      // enabled-and-suppressed is the normal state of the pill on that
      // surface — not an edge case.
      autoAdvanceCubit
        ..toggle()
        ..suppressForInteraction();
      expect(autoAdvanceCubit.state.enabled, isTrue);
      expect(autoAdvanceCubit.state.suppressed, isTrue);

      await tester.pumpWidget(buildSubject());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoActionDisableAutoAdvance),
      );
      await tester.pump();

      expect(autoAdvanceCubit.state.enabled, isFalse);
      expect(find.text(l10n.videoSettingsAutoAdvanceOff), findsOneWidget);
    });

    testWidgets('re-toggling replaces the banner instead of queueing it', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
      );
      await tester.pump();
      // Let the first banner finish animating in before re-toggling. With no
      // elapsed time its entrance controller sits at 0, so dismissing it
      // collapses to a zero-duration reverse and the second banner takes over
      // no matter how it was requested — which is exactly the distinction this
      // test exists to pin.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.videoSettingsAutoAdvanceOn), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel(l10n.videoActionDisableAutoAdvance),
      );
      await tester.pump();

      expect(find.text(l10n.videoSettingsAutoAdvanceOn), findsNothing);
      expect(find.text(l10n.videoSettingsAutoAdvanceOff), findsOneWidget);
    });

    testWidgets('renders without the compilations toggle when '
        'FeedAutoAdvanceCubit is not provided', (tester) async {
      await tester.pumpWidget(buildSubject(provideAutoAdvance: false));

      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsNothing,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
    });

    testWidgets('keeps the scrim-30 capsule under the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(theme: VineTheme.theme));

      expect(
        tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .where(
              (box) =>
                  box.decoration is BoxDecoration &&
                  (box.decoration as BoxDecoration).color == VineTheme.scrim30,
            ),
        isNotEmpty,
      );
      expect(
        tester
            .widgetList<DivineIcon>(find.byType(DivineIcon))
            .map((i) => i.color),
        everyElement(equals(VineTheme.onSurface)),
      );
    });
  });
}
