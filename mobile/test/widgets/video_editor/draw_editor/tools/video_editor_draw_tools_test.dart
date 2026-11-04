// ABOUTME: Tests for the draw tool widgets, from the pencil to the eraser.
// ABOUTME: Validates tap handling, selection state, and semantics.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_brushes.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_eraser.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_marker.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_pencil.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 20)),
          child: SizedBox(width: 200, height: 400, child: child),
        ),
      ),
    );
  }

  group('DrawToolPencil', () {
    testWidgets('renders VideoEditorDrawItemButton', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          DrawToolPencil(isSelected: false, color: Colors.red, onTap: () {}),
        ),
      );
      await tester.pump();

      expect(find.byType(VideoEditorDrawItemButton), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithApp(
          DrawToolPencil(
            isSelected: false,
            color: Colors.red,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DrawToolPencil));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('passes isSelected to VideoEditorDrawItemButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          DrawToolPencil(isSelected: true, color: Colors.red, onTap: () {}),
        ),
      );
      await tester.pump();

      final button = tester.widget<VideoEditorDrawItemButton>(
        find.byType(VideoEditorDrawItemButton),
      );
      expect(button.isSelected, isTrue);
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          DrawToolPencil(isSelected: false, color: Colors.red, onTap: () {}),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Pencil tool',
        ),
        findsOneWidget,
      );
    });
  });

  group('DrawToolMarker', () {
    testWidgets('renders VideoEditorDrawItemButton', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          DrawToolMarker(isSelected: false, color: Colors.blue, onTap: () {}),
        ),
      );
      await tester.pump();

      expect(find.byType(VideoEditorDrawItemButton), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithApp(
          DrawToolMarker(
            isSelected: false,
            color: Colors.blue,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DrawToolMarker));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('passes isSelected to VideoEditorDrawItemButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          DrawToolMarker(isSelected: true, color: Colors.blue, onTap: () {}),
        ),
      );
      await tester.pump();

      final button = tester.widget<VideoEditorDrawItemButton>(
        find.byType(VideoEditorDrawItemButton),
      );
      expect(button.isSelected, isTrue);
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          DrawToolMarker(isSelected: false, color: Colors.blue, onTap: () {}),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Marker tool',
        ),
        findsOneWidget,
      );
    });
  });

  group('DrawToolEraser', () {
    testWidgets('renders VideoEditorDrawItemButton', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(DrawToolEraser(isSelected: false, onTap: () {})),
      );
      await tester.pump();

      expect(find.byType(VideoEditorDrawItemButton), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithApp(
          DrawToolEraser(isSelected: false, onTap: () => tapped = true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DrawToolEraser));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('passes isSelected to VideoEditorDrawItemButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(DrawToolEraser(isSelected: true, onTap: () {})),
      );
      await tester.pump();

      final button = tester.widget<VideoEditorDrawItemButton>(
        find.byType(VideoEditorDrawItemButton),
      );
      expect(button.isSelected, isTrue);
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(DrawToolEraser(isSelected: false, onTap: () {})),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Eraser tool',
        ),
        findsOneWidget,
      );
    });
  });

  final l10n = lookupAppLocalizations(const Locale('en'));
  for (final (:name, :build, :label)
      in <
        ({
          String name,
          Widget Function({
            required bool isSelected,
            required VoidCallback onTap,
          })
          build,
          String label,
        })
      >[
        (
          name: 'DrawToolNeon',
          build: ({required isSelected, required onTap}) => DrawToolNeon(
            isSelected: isSelected,
            color: Colors.red,
            onTap: onTap,
          ),
          label: l10n.videoEditorDrawToolNeonSemanticLabel,
        ),
        (
          name: 'DrawToolRainbow',
          build: ({required isSelected, required onTap}) =>
              DrawToolRainbow(isSelected: isSelected, onTap: onTap),
          label: l10n.videoEditorDrawToolRainbowSemanticLabel,
        ),
        (
          name: 'DrawToolCalligraphy',
          build: ({required isSelected, required onTap}) => DrawToolCalligraphy(
            isSelected: isSelected,
            color: Colors.red,
            onTap: onTap,
          ),
          label: l10n.videoEditorDrawToolCalligraphySemanticLabel,
        ),
      ]) {
    group(name, () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          wrapWithApp(build(isSelected: false, onTap: () => tapped = true)),
        );
        await tester.pump();

        await tester.tap(find.byType(VideoEditorDrawItemButton));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('passes isSelected to VideoEditorDrawItemButton', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithApp(build(isSelected: true, onTap: () {})),
        );
        await tester.pump();

        final button = tester.widget<VideoEditorDrawItemButton>(
          find.byType(VideoEditorDrawItemButton),
        );
        expect(button.isSelected, isTrue);
      });

      testWidgets('is announced by its own label', (tester) async {
        await tester.pumpWidget(
          wrapWithApp(build(isSelected: false, onTap: () {})),
        );
        await tester.pump();

        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
