// ABOUTME: Widget tests for VideoEditorClipSpeedSheet.
// ABOUTME: Covers title rendering, speed clamping, and cancel/confirm navigation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_clip_speed_sheet.dart';

// Sentinel shown on the base route so navigation-back tests can confirm
// that the sheet was popped.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

Widget _buildSubject({double initialSpeed = 1.0}) {
  return MaterialApp.router(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _HomeScreen(),
          routes: [
            GoRoute(
              path: 'speed',
              builder: (context, state) => Scaffold(
                body: VideoEditorClipSpeedSheet(initialSpeed: initialSpeed),
              ),
            ),
          ],
        ),
      ],
      initialLocation: '/speed',
    ),
  );
}

void main() {
  group(VideoEditorClipSpeedSheet, () {
    group('renders', () {
      testWidgets('shows sheet title', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('de'),
            ).videoEditorSpeedSheetTitle,
          ),
          findsNothing,
        );
      });

      testWidgets('shows speed label', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedLabel), findsOneWidget);
      });

      testWidgets('shows formatted initial speed value', (tester) async {
        await tester.pumpWidget(_buildSubject(initialSpeed: 1.5));
        await tester.pumpAndSettle();

        expect(find.text('1.50×'), findsOneWidget);
      });

      testWidgets('shows DivineSlider', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(DivineSlider), findsOneWidget);
      });

      testWidgets('shows cancel and confirm buttons', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton && widget.icon == DivineIconName.x,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.icon == DivineIconName.check,
          ),
          findsOneWidget,
        );
      });
    });

    group('initial speed clamping', () {
      testWidgets('clamps below clipSpeedMin to clipSpeedMin', (tester) async {
        await tester.pumpWidget(_buildSubject(initialSpeed: -5));
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMin.toStringAsFixed(2)}×';
        expect(find.text(expected), findsOneWidget);
      });

      testWidgets('clamps above clipSpeedMax to clipSpeedMax', (tester) async {
        await tester.pumpWidget(_buildSubject(initialSpeed: 99));
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMax.toStringAsFixed(2)}×';
        expect(find.text(expected), findsOneWidget);
      });

      testWidgets('shows exact value at clipSpeedMin boundary', (tester) async {
        await tester.pumpWidget(
          _buildSubject(initialSpeed: VideoEditorConstants.clipSpeedMin),
        );
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMin.toStringAsFixed(2)}×';
        expect(find.text(expected), findsOneWidget);
      });

      testWidgets('shows exact value at clipSpeedMax boundary', (tester) async {
        await tester.pumpWidget(
          _buildSubject(initialSpeed: VideoEditorConstants.clipSpeedMax),
        );
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMax.toStringAsFixed(2)}×';
        expect(find.text(expected), findsOneWidget);
      });
    });

    group('cancel button', () {
      testWidgets('tapping X pops the sheet', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsOneWidget);

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton && widget.icon == DivineIconName.x,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsNothing);
      });
    });

    group('confirm button', () {
      testWidgets('tapping check pops the sheet', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsOneWidget);

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.icon == DivineIconName.check,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsNothing);
      });
    });
  });
}
