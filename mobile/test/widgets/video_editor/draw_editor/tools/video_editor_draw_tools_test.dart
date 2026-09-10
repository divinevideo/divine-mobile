// ABOUTME: Tests for draw tool widgets (Pencil, Marker, Arrow, Eraser).
// ABOUTME: Validates tap handling, selection state, and semantics.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_arrow.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_eraser.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_marker.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_pencil.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  group('DrawToolArrow', () {
    testWidgets('renders VideoEditorDrawItemButton', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(DrawToolArrow(isSelected: false, onTap: () {})),
      );
      await tester.pump();

      expect(find.byType(VideoEditorDrawItemButton), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithApp(
          DrawToolArrow(isSelected: false, onTap: () => tapped = true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DrawToolArrow));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('passes isSelected to VideoEditorDrawItemButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(DrawToolArrow(isSelected: true, onTap: () {})),
      );
      await tester.pump();

      final button = tester.widget<VideoEditorDrawItemButton>(
        find.byType(VideoEditorDrawItemButton),
      );
      expect(button.isSelected, isTrue);
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(DrawToolArrow(isSelected: false, onTap: () {})),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Arrow tool',
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
}
