import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';

void main() {
  group(ModeratedContentOverlay, () {
    late AppLocalizations enL10n;

    setUpAll(() {
      enL10n = lookupAppLocalizations(const Locale('en'));
    });

    Future<void> pumpOverlay(
      WidgetTester tester, {
      required PlaybackStatus status,
      VoidCallback? onSkip,
      VoidCallback? onVerifyAge,
      bool isVerifying = false,
      ThemeData? theme,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: Scaffold(
            body: ModeratedContentOverlay(
              status: status,
              onSkip: onSkip ?? () {},
              onVerifyAge: onVerifyAge,
              isVerifying: isVerifying,
            ),
          ),
        ),
      );
    }

    testWidgets('renders content-restricted message for forbidden', (
      tester,
    ) async {
      await pumpOverlay(tester, status: PlaybackStatus.forbidden);

      expect(find.text(enL10n.videoErrorContentRestricted), findsOneWidget);
      expect(find.text(enL10n.videoErrorSkip), findsOneWidget);
      expect(find.text(enL10n.videoErrorVerifyAgeButton), findsNothing);
    });

    testWidgets('renders age-restricted message and Verify age button', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        status: PlaybackStatus.ageRestricted,
        onVerifyAge: () {},
      );

      expect(find.text(enL10n.videoErrorAgeRestricted), findsOneWidget);
      expect(find.text(enL10n.videoErrorVerifyAgeButton), findsOneWidget);
      expect(find.text(enL10n.videoErrorSkip), findsOneWidget);
    });

    testWidgets('renders unavailable message with Skip and no Verify age', (
      tester,
    ) async {
      await pumpOverlay(tester, status: PlaybackStatus.unavailable);

      expect(find.text(enL10n.videoErrorUnavailable), findsOneWidget);
      expect(find.text(enL10n.videoErrorUnavailableBody), findsOneWidget);
      expect(find.text(enL10n.videoErrorSkip), findsOneWidget);
      expect(find.text(enL10n.videoErrorVerifyAgeButton), findsNothing);
    });

    testWidgets('calls onSkip when Skip is tapped', (tester) async {
      var skipped = 0;
      await pumpOverlay(
        tester,
        status: PlaybackStatus.forbidden,
        onSkip: () => skipped++,
      );
      await tester.tap(find.text(enL10n.videoErrorSkip));
      await tester.pumpAndSettle();

      expect(skipped, equals(1));
    });

    testWidgets('calls onVerifyAge when Verify age is tapped', (tester) async {
      var verified = 0;
      await pumpOverlay(
        tester,
        status: PlaybackStatus.ageRestricted,
        onVerifyAge: () => verified++,
      );
      await tester.tap(find.text(enL10n.videoErrorVerifyAgeButton));
      await tester.pumpAndSettle();

      expect(verified, equals(1));
    });

    testWidgets(
      'shows a loading spinner and disables Verify age while verifying',
      (tester) async {
        var verified = 0;
        await pumpOverlay(
          tester,
          status: PlaybackStatus.ageRestricted,
          onVerifyAge: () => verified++,
          isVerifying: true,
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Disabled while verifying — a tap must be a no-op.
        await tester.tap(find.text(enL10n.videoErrorVerifyAgeButton));
        await tester.pump();
        expect(verified, equals(0));
      },
    );

    testWidgets('calls onSkip when Skip is tapped in ageRestricted state', (
      tester,
    ) async {
      var skipped = 0;
      await pumpOverlay(
        tester,
        status: PlaybackStatus.ageRestricted,
        onSkip: () => skipped++,
        onVerifyAge: () {},
      );
      await tester.tap(find.text(enL10n.videoErrorSkip));
      await tester.pumpAndSettle();

      expect(skipped, equals(1));
    });

    testWidgets('does not render author info or action buttons', (
      tester,
    ) async {
      await pumpOverlay(tester, status: PlaybackStatus.forbidden);

      // The overlay must NOT show the usual interactive feed chrome.
      final videoAuthorSemanticsPrefix = RegExp(
        '^${RegExp.escape(enL10n.videoAuthorSemanticLabel(''))}',
      );
      expect(find.bySemanticsLabel(videoAuthorSemanticsPrefix), findsNothing);
      // The description tap target uses an action-oriented label
      // ("Open video details"); either that or the older content-echoing
      // label would still indicate chrome leaked through, so we assert both
      // are absent.
      expect(find.bySemanticsLabel('Open video details'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Video description: .*')),
        findsNothing,
      );
    });

    testWidgets('reads its explanation from the palette, not fixed white', (
      tester,
    ) async {
      // The overlay replaces the video instead of sitting on it, so its
      // background follows the palette. Text pinned to white would be
      // invisible on the light one.
      await pumpOverlay(
        tester,
        status: PlaybackStatus.forbidden,
        theme: VineTheme.lightTheme,
      );

      final title = tester.widget<Text>(
        find.text(enL10n.videoErrorContentRestricted),
      );
      final body = tester.widget<Text>(
        find.text(enL10n.videoErrorContentRestrictedBody),
      );
      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon).first);

      expect(title.style?.color, equals(VineTheme.lightColors.primaryText));
      expect(body.style?.color, equals(VineTheme.lightColors.primaryText));
      expect(icon.color, equals(VineTheme.lightColors.primaryText));
    });

    test('asserts when constructed with a non-restricted status', () {
      expect(
        () => ModeratedContentOverlay(
          status: PlaybackStatus.generic,
          onSkip: () {},
        ),
        throwsAssertionError,
      );
    });

    test('asserts when ageRestricted without onVerifyAge', () {
      expect(
        () => ModeratedContentOverlay(
          status: PlaybackStatus.ageRestricted,
          onSkip: () {},
        ),
        throwsAssertionError,
      );
    });
  });
}
