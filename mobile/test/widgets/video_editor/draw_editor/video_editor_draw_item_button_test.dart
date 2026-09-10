// ABOUTME: Tests for VideoEditorDrawItemButton widget.
// ABOUTME: Validates tap handling, selection state, and accessibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

class _TestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simple test painter
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorDrawItemButton', () {
    Widget buildWidget({
      required bool isSelected,
      required VoidCallback onTap,
      String semanticLabel = 'Test tool',
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 20)),
            child: SizedBox(
              width: 200,
              height: 400,
              child: VideoEditorDrawItemButton(
                onTap: onTap,
                isSelected: isSelected,
                painter: _TestPainter(),
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ),
      );
    }

    group('Tap handling', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          buildWidget(isSelected: false, onTap: () => tapped = true),
        );
        await tester.pump();

        await tester.tap(find.byType(VideoEditorDrawItemButton));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('calls onTap when tapped while selected', (tester) async {
        var tapCount = 0;

        await tester.pumpWidget(
          buildWidget(isSelected: true, onTap: () => tapCount++),
        );
        await tester.pump();

        await tester.tap(find.byType(VideoEditorDrawItemButton));
        await tester.pump();

        expect(tapCount, 1);
      });
    });

    group('Semantics', () {
      testWidgets('has correct semantic label', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            isSelected: false,
            onTap: () {},
            semanticLabel: 'Custom tool label',
          ),
        );
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Custom tool label',
          ),
          findsOneWidget,
        );
      });

      testWidgets('indicates button role in semantics', (tester) async {
        await tester.pumpWidget(buildWidget(isSelected: false, onTap: () {}));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Test tool',
          ),
        );
        expect(semantics.properties.button, isTrue);
      });

      testWidgets('indicates selected state in semantics when selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isSelected: true, onTap: () {}));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Test tool',
          ),
        );
        expect(semantics.properties.selected, isTrue);
      });

      testWidgets('indicates not selected in semantics when not selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isSelected: false, onTap: () {}));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Test tool',
          ),
        );
        expect(semantics.properties.selected, isFalse);
      });
    });

    group('CustomPaint', () {
      testWidgets('renders CustomPaint widget', (tester) async {
        await tester.pumpWidget(buildWidget(isSelected: false, onTap: () {}));
        await tester.pump();

        expect(find.byType(CustomPaint), findsWidgets);
      });
    });

    group('AnimatedContainer', () {
      testWidgets('uses AnimatedContainer for animations', (tester) async {
        await tester.pumpWidget(buildWidget(isSelected: false, onTap: () {}));
        await tester.pump();

        expect(find.byType(AnimatedContainer), findsOneWidget);
      });
    });
  });
}
