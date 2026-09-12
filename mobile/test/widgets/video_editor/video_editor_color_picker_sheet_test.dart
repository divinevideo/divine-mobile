// ABOUTME: Tests for VideoEditorColorPickerSheet widget.
// ABOUTME: Validates color grid rendering, selection, and callbacks.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorColorPickerSheet', () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
    });

    Widget buildWidget({
      Color selectedColor = Colors.white,
      ValueChanged<Color>? onColorSelected,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorColorPickerSheet(
              selectedColor: selectedColor,
              onColorSelected: onColorSelected ?? (_) {},
            ),
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders GridView with correct item count', (tester) async {
        await tester.pumpWidget(buildWidget());

        // Should have colors + 1 color picker button + 6 recent-color slots
        final gridView = tester.widget<GridView>(find.byType(GridView));
        expect(
          gridView.childrenDelegate.estimatedChildCount,
          VideoEditorConstants.colors.length + 1 + 6,
        );
      });

      testWidgets('renders color picker button as first item', (tester) async {
        await tester.pumpWidget(buildWidget());

        // First item should have color picker semantics
        expect(find.bySemanticsLabel('Color picker'), findsOneWidget);
      });

      testWidgets('renders paint brush icon in color picker button', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('renders all color options', (tester) async {
        await tester.pumpWidget(buildWidget());

        // Each grid item is a GestureDetector
        // Total: 1 color picker + all preset colors + 6 recent-color slots
        expect(
          find.byType(GestureDetector),
          findsNWidgets(VideoEditorConstants.colors.length + 1 + 6),
        );
      });
    });

    group('Interaction', () {
      testWidgets('calls onColorSelected when color is tapped', (tester) async {
        Color? tappedColor;
        await tester.pumpWidget(
          buildWidget(onColorSelected: (color) => tappedColor = color),
        );

        // Find a color button by its semantics (skip first which is color picker)
        final firstColor = VideoEditorConstants.colors[0];
        final r = (firstColor.r * 255.0).round().clamp(0, 255);
        final g = (firstColor.g * 255.0).round().clamp(0, 255);
        final b = (firstColor.b * 255.0).round().clamp(0, 255);
        final label = 'RGB $r, $g, $b';

        await tester.tap(find.bySemanticsLabel(label));
        await tester.pump();

        expect(tappedColor, firstColor);
      });

      testWidgets('does not call onColorSelected when color picker is tapped', (
        tester,
      ) async {
        // Suppress overflow errors from the third-party ColorPicker widget
        // that opens inside the bottom sheet in constrained test environments.
        final origOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed')) return;
          origOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = origOnError);

        Color? tappedColor;
        await tester.pumpWidget(
          buildWidget(onColorSelected: (color) => tappedColor = color),
        );

        await tester.tap(find.bySemanticsLabel('Color picker'));
        await tester.pump();

        // Color picker tap should not trigger onColorSelected
        expect(tappedColor, isNull);
      });

      testWidgets('can tap different colors sequentially', (tester) async {
        final tappedColors = <Color>[];
        await tester.pumpWidget(buildWidget(onColorSelected: tappedColors.add));

        // Tap first two colors
        for (var i = 0; i < 2; i++) {
          final color = VideoEditorConstants.colors[i];
          final r = (color.r * 255.0).round().clamp(0, 255);
          final g = (color.g * 255.0).round().clamp(0, 255);
          final b = (color.b * 255.0).round().clamp(0, 255);
          final label = 'RGB $r, $g, $b';

          await tester.tap(find.bySemanticsLabel(label));
          await tester.pump();
        }

        expect(tappedColors.length, 2);
        expect(tappedColors[0], VideoEditorConstants.colors[0]);
        expect(tappedColors[1], VideoEditorConstants.colors[1]);
      });
    });

    group('Accessibility', () {
      testWidgets('all color buttons have semantic labels', (tester) async {
        await tester.pumpWidget(buildWidget());

        // Color picker should have label
        expect(find.bySemanticsLabel('Color picker'), findsOneWidget);

        // Each color should have RGB label
        for (final color in VideoEditorConstants.colors.take(5)) {
          final r = (color.r * 255.0).round().clamp(0, 255);
          final g = (color.g * 255.0).round().clamp(0, 255);
          final b = (color.b * 255.0).round().clamp(0, 255);
          final label = 'RGB $r, $g, $b';

          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
      });

      testWidgets('selected color has "selected" in semantics', (tester) async {
        final selectedColor = VideoEditorConstants.colors[2];
        await tester.pumpWidget(buildWidget(selectedColor: selectedColor));

        final r = (selectedColor.r * 255.0).round().clamp(0, 255);
        final g = (selectedColor.g * 255.0).round().clamp(0, 255);
        final b = (selectedColor.b * 255.0).round().clamp(0, 255);
        final label = 'RGB $r, $g, $b, selected';

        expect(find.bySemanticsLabel(label), findsOneWidget);
      });
    });
  });
}
