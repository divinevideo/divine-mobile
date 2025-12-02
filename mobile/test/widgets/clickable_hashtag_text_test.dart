import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';

void main() {
  group('ClickableHashtagText', () {
    testWidgets('displays plain text without hashtags correctly', (
      tester,
    ) async {
      const plainText = 'This is a simple text without hashtags';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClickableHashtagText(text: plainText)),
        ),
      );

      expect(find.text(plainText), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('displays text with single hashtag', (tester) async {
      const textWithHashtag = 'Check out this #vine';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClickableHashtagText(text: textWithHashtag)),
        ),
      );

      // The SelectableText should contain the full text
      expect(find.text(textWithHashtag), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('displays text with multiple hashtags', (tester) async {
      const textWithHashtags = '#trending videos on #vine are #amazing';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClickableHashtagText(text: textWithHashtags)),
        ),
      );

      expect(find.text(textWithHashtags), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('handles hashtags at end of text', (tester) async {
      const textWithTrailingHashtag = 'This is awesome #vine';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClickableHashtagText(text: textWithTrailingHashtag),
          ),
        ),
      );

      expect(find.text(textWithTrailingHashtag), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('handles hashtags with underscores and numbers', (
      tester,
    ) async {
      const textWithComplexHashtags = 'Testing #vine_2024 and #test_123';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClickableHashtagText(text: textWithComplexHashtags),
          ),
        ),
      );

      expect(find.text(textWithComplexHashtags), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('respects maxLines property', (tester) async {
      const longText =
          'This is a very long text with #hashtag1 and #hashtag2 '
          'that should be truncated based on maxLines property. '
          'Here is more text with #hashtag3 and #hashtag4 '
          'that might not be visible due to line limits.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClickableHashtagText(text: longText, maxLines: 2),
          ),
        ),
      );

      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectableText.maxLines, 2);
    });

    testWidgets('handles empty text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClickableHashtagText(text: '')),
        ),
      );

      // Empty text should render as SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('handles text with only spaces', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ClickableHashtagText(text: '   ')),
        ),
      );

      // Text with only spaces should still render
      expect(find.text('   '), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('widget builds without errors', (tester) async {
      // Test various edge cases to ensure no crashes
      final testCases = [
        'Normal text',
        '#hashtag',
        'Text with #hashtag in middle',
        'Multiple #hashtags #here',
        '#start with hashtag',
        'End with hashtag #end',
        '##double#hashtag',
        'Special chars #test!',
        '#',
        '# space after hash',
        'URL https://example.com/#anchor should not be hashtag',
      ];

      for (final testText in testCases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ClickableHashtagText(text: testText)),
          ),
        );

        // Should not crash
        expect(find.byType(ClickableHashtagText), findsOneWidget);

        // Clear the widget tree before next test
        await tester.pumpWidget(Container());
      }
    });

    // Note: Testing tap functionality and navigation requires integration testing
    // or mocking the navigation system, which is complex in this context.
    // The tap functionality would be tested in integration tests.
  });
}
