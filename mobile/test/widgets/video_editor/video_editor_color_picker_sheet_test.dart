// ABOUTME: Tests for VideoEditorColorPickerSheet widget.
// ABOUTME: Validates color grid rendering, selection, and callbacks.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_source.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/text_lines.dart';

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
      EyedropperSourceRegistry? eyedropperSources,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: EyedropperSources(
          registry: eyedropperSources,
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

    group('Eyedropper', () {
      /// Six recent colors, none of them in the palette.
      const recents = [
        Color(0xFF010203),
        Color(0xFF040506),
        Color(0xFF070809),
        Color(0xFF0A0B0C),
        Color(0xFF0D0E0F),
        Color(0xFF101112),
      ];
      const fromVideo = Color(0xFF19A55B);

      late _FakeEyedropperSource source;
      late EyedropperSourceRegistry registry;

      setUp(() {
        source = _FakeEyedropperSource(fromVideo);
        registry = EyedropperSourceRegistry()..register(source);
      });

      Future<void> storeRecents() async {
        SharedPreferences.setMockInitialValues({
          'video_editor_recent_colors': [
            for (final color in recents) color.toARGB32().toString(),
          ],
        });
        sharedPreferences = await SharedPreferences.getInstance();
      }

      String labelOf(Color color) {
        int channel(double value) => (value * 255.0).round().clamp(0, 255);
        return 'RGB ${channel(color.r)}, ${channel(color.g)}, '
            '${channel(color.b)}';
      }

      testWidgets('stays out of the grid of colors', (tester) async {
        await storeRecents();
        await tester.pumpWidget(buildWidget(eyedropperSources: registry));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoEditorEyedropperSemanticLabel),
          findsNothing,
        );
        for (final color in recents) {
          expect(find.bySemanticsLabel(labelOf(color)), findsOneWidget);
        }
      });

      testWidgets('is offered in the custom color sheet too', (tester) async {
        Color? selected;
        await tester.pumpWidget(
          buildWidget(
            eyedropperSources: registry,
            onColorSelected: (color) => selected = color,
          ),
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorColorPickerSemanticLabel),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.videoEditorPickColorTitle), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.bySemanticsLabel(
              l10n.videoEditorEyedropperSemanticLabel,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(source.picks, 1);
        expect(selected, fromVideo);
        expect(find.text(l10n.videoEditorPickColorTitle), findsNothing);
        // Kept like any custom color.
        expect(
          sharedPreferences.getStringList('video_editor_recent_colors'),
          [fromVideo.toARGB32().toString()],
        );
      });
    });

    group('showFullColorPicker', () {
      const fromVideo = Color(0xFF19A55B);

      Future<void> pumpOpener(
        WidgetTester tester, {
        required void Function(Color?) onResult,
        EyedropperSource? source,
        Locale? locale,
      }) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          EyedropperSources(
            registry: EyedropperSourceRegistry()..registerIfAny(source),
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async => onResult(
                      await showFullColorPicker(
                        context,
                        initialColor: Colors.white,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      testWidgets('resolves with the color the eyedropper picked', (
        tester,
      ) async {
        Color? result;
        await pumpOpener(
          tester,
          source: _FakeEyedropperSource(fromVideo),
          onResult: (color) => result = color,
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorEyedropperSemanticLabel),
        );
        await tester.pumpAndSettle();

        expect(result, fromVideo);
        expect(find.text(l10n.videoEditorPickColorTitle), findsNothing);
      });

      testWidgets('stays open when the eyedropper is closed', (tester) async {
        var resolved = false;
        final source = _FakeEyedropperSource(null);
        await pumpOpener(
          tester,
          source: source,
          onResult: (_) => resolved = true,
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorEyedropperSemanticLabel),
        );
        await tester.pumpAndSettle();

        expect(source.picks, 1);
        expect(resolved, isFalse);
        expect(find.text(l10n.videoEditorPickColorTitle), findsOneWidget);
      });

      testWidgets('keeps the words of the title whole beside the eyedropper '
          'at a large text size', (tester) async {
        // German at 1.5x on a 360 pt wide phone split "auswähl/en".
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const german = Locale('de');
        await pumpOpener(
          tester,
          locale: german,
          source: _FakeEyedropperSource(fromVideo),
          onResult: (_) {},
        );

        final title = find.text(
          lookupAppLocalizations(german).videoEditorPickColorTitle,
        );
        expect(wordsSplitAcrossLines(tester, title), isEmpty);
      });

      testWidgets('offers no eyedropper while no video is on screen', (
        tester,
      ) async {
        await pumpOpener(tester, onResult: (_) {});

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorPickColorTitle), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.videoEditorEyedropperSemanticLabel),
          findsNothing,
        );
      });
    });
  });
}

/// A video view on screen whose eyedropper always picks [color], or is closed
/// without a color when [color] is `null`.
class _FakeEyedropperSource implements EyedropperSource {
  _FakeEyedropperSource(this.color);

  final Color? color;

  int picks = 0;

  @override
  bool isVisible = true;

  @override
  Future<Color?> pick(BuildContext context) async {
    picks++;
    return color;
  }
}

extension on EyedropperSourceRegistry {
  void registerIfAny(EyedropperSource? source) {
    if (source != null) register(source);
  }
}
