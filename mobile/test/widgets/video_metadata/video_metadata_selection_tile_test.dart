import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

void main() {
  group(VideoMetadataSelectionTile, () {
    Widget buildWidget({
      String semanticsLabel = 'Select option',
      String labelText = 'Label',
      String value = 'Value',
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: VideoMetadataSelectionTile(
            semanticsLabel: semanticsLabel,
            labelText: labelText,
            value: value,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders $VideoMetadataSelectionTile', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });

    testWidgets('displays labelText in $DivineTextField', (tester) async {
      await tester.pumpWidget(buildWidget(labelText: 'Expiration'));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineTextField && w.labelText == 'Expiration',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays value as text', (tester) async {
      await tester.pumpWidget(buildWidget(value: '1 week'));

      expect(find.text('1 week'), findsOneWidget);
    });

    testWidgets('renders caret down icon', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.caretDown,
        ),
        findsOneWidget,
      );
    });

    testWidgets('has semantics button with semanticsLabel', (tester) async {
      await tester.pumpWidget(buildWidget(semanticsLabel: 'Select expiration'));

      expect(
        tester.getSemantics(find.byType(VideoMetadataSelectionTile)),
        matchesSemantics(
          isButton: true,
          label: 'Select expiration',
        ),
      );
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));

      await tester.tap(find.byType(VideoMetadataSelectionTile));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not crash when onTap is null', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.byType(VideoMetadataSelectionTile));
      await tester.pump();

      // No exception thrown — widget silently ignores taps when onTap is null.
    });

    testWidgets('updates displayed value when value prop changes', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoMetadataSelectionTile(
              key: key,
              semanticsLabel: 'Select option',
              labelText: 'Label',
              value: 'Old value',
            ),
          ),
        ),
      );

      expect(find.text('Old value'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoMetadataSelectionTile(
              key: key,
              semanticsLabel: 'Select option',
              labelText: 'Label',
              value: 'New value',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('New value'), findsOneWidget);
      expect(find.text('Old value'), findsNothing);
    });
  });
}
