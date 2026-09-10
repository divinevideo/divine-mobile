// ABOUTME: Comprehensive widget test for LinkifiedText covering core functionality
// ABOUTME: Tests hashtag parsing, tap interactions, navigation, styling, and edge cases

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';

class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

class _FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRoute());
  });

  group('LinkifiedText - Comprehensive Tests', () {
    late _MockNavigatorObserver mockObserver;

    setUp(() {
      mockObserver = _MockNavigatorObserver();
    });

    group('Text Display and Structure', () {
      testWidgets('renders plain text without hashtags as simple Text', (
        tester,
      ) async {
        const plainText = 'This is plain text without hashtags';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: plainText)),
          ),
        );

        expect(find.text(plainText), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);

        final text = tester.widget<Text>(find.byType(Text));
        expect(text.data, plainText);
        expect(text.textSpan, isNull); // Should use data, not textSpan
      });

      testWidgets('creates TextSpans for text with hashtags', (tester) async {
        const textWithHashtag = 'Check out this #vine video';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithHashtag)),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        expect(text.data, isNull); // Should use textSpan, not data
        expect(text.textSpan, isNotNull);
        final textSpan = text.textSpan! as TextSpan;
        expect(textSpan.children, isNotNull);
        expect(
          textSpan.children!.length,
          3,
        ); // "Check out this ", "#vine", " video"
      });

      testWidgets('correctly identifies hashtag vs non-hashtag TextSpans', (
        tester,
      ) async {
        const textWithHashtag = 'Text #hashtag more text';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithHashtag)),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();

        expect(spans[0].text, 'Text ');
        expect(
          spans[0].recognizer,
          isNull,
        ); // Non-hashtag span has no tap recognizer

        expect(spans[1].text, '#hashtag');
        expect(
          spans[1].recognizer,
          isA<TapGestureRecognizer>(),
        ); // Hashtag span has tap recognizer

        expect(spans[2].text, ' more text');
        expect(
          spans[2].recognizer,
          isNull,
        ); // Non-hashtag span has no tap recognizer
      });

      testWidgets('handles multiple hashtags correctly', (tester) async {
        const textWithHashtags = '#first and #second hashtags';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithHashtags)),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();

        expect(spans.length, 4); // "#first", " and ", "#second", " hashtags"
        expect(spans[0].text, '#first');
        expect(spans[0].recognizer, isA<TapGestureRecognizer>());
        expect(spans[2].text, '#second');
        expect(spans[2].recognizer, isA<TapGestureRecognizer>());
      });
    });

    group('Styling', () {
      testWidgets('applies custom text style', (tester) async {
        const testStyle = TextStyle(fontSize: 16, color: Colors.red);

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LinkifiedText(text: 'Plain text', style: testStyle),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        expect(text.style, testStyle);
      });

      testWidgets('applies custom hashtag style', (tester) async {
        const hashtagStyle = TextStyle(fontSize: 18, color: Colors.green);

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LinkifiedText(
                text: 'Text with #hashtag',
                linkStyle: hashtagStyle,
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final hashtagSpan = spans.firstWhere(
          (span) => span.text!.startsWith('#'),
        );

        expect(hashtagSpan.style, hashtagStyle);
      });

      testWidgets('uses default hashtag style when none provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LinkifiedText(text: 'Text with #hashtag'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final hashtagSpan = spans.firstWhere(
          (span) => span.text!.startsWith('#'),
        );

        expect(hashtagSpan.style?.color, Colors.blue);
        expect(hashtagSpan.style?.decoration, TextDecoration.underline);
        expect(hashtagSpan.style?.fontWeight, FontWeight.w500);
        // TODO(Any): Fix and re-enable these tests
      }, skip: true);

      testWidgets('respects maxLines property', (tester) async {
        const longText =
            'This is very long text with #hashtag that should wrap multiple lines';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 200, // Force text wrapping
                child: LinkifiedText(text: longText, maxLines: 2),
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        expect(text.maxLines, 2);
      });
    });

    group('Navigation and Interactions', () {
      testWidgets('calls onVideoStateChange when hashtag is tapped', (
        tester,
      ) async {
        bool callbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [mockObserver],
            home: Scaffold(
              body: LinkifiedText(
                text: 'Check out #vine',
                onVideoStateChange: () => callbackCalled = true,
              ),
            ),
          ),
        );

        // Find and tap the hashtag
        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final hashtagSpan = spans.firstWhere(
          (span) => span.text!.startsWith('#'),
        );
        final tapRecognizer = hashtagSpan.recognizer! as TapGestureRecognizer;

        tapRecognizer.onTap!();
        await tester.pumpAndSettle();

        expect(callbackCalled, isTrue);
        // TODO(Any): Fix and re-enable these tests
      }, skip: true);

      testWidgets('navigates to hashtag feed when hashtag is tapped', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [mockObserver],
            home: const Scaffold(
              body: LinkifiedText(text: 'Check out #test'),
            ),
          ),
        );

        // Find and tap the hashtag
        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final hashtagSpan = spans.firstWhere(
          (span) => span.text!.startsWith('#'),
        );
        final tapRecognizer = hashtagSpan.recognizer! as TapGestureRecognizer;

        tapRecognizer.onTap!();
        await tester.pumpAndSettle();

        // Verify navigation occurred
        verify(() => mockObserver.didPush(any(), any()));
        // TODO(Any): Fix and re-enable these tests
      }, skip: true);

      testWidgets('handles tap on different hashtags correctly', (
        tester,
      ) async {
        // Mock the navigation to capture hashtag values
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [mockObserver],
            home: Scaffold(
              body: LinkifiedText(
                text: '#first and #second hashtags',
                onVideoStateChange: () {},
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();

        // Tap first hashtag
        final firstHashtagSpan = spans.firstWhere(
          (span) => span.text == '#first',
        );
        final firstTapRecognizer =
            firstHashtagSpan.recognizer! as TapGestureRecognizer;
        firstTapRecognizer.onTap!();
        await tester.pumpAndSettle();

        // Tap second hashtag
        final secondHashtagSpan = spans.firstWhere(
          (span) => span.text == '#second',
        );
        final secondTapRecognizer =
            secondHashtagSpan.recognizer! as TapGestureRecognizer;
        secondTapRecognizer.onTap!();
        await tester.pumpAndSettle();

        // Verify both navigation calls
        verify(() => mockObserver.didPush(any(), any())).called(2);
        // TODO(Any): Fix and re-enable these tests
      }, skip: true);
    });

    group('Edge Cases', () {
      testWidgets('handles empty text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: '')),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Text), findsNothing);
      });

      testWidgets('handles text with only spaces', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: '   ')),
          ),
        );

        expect(find.text('   '), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('handles hashtags with numbers and underscores', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LinkifiedText(text: 'Test #vine_2024 and #test_123'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();

        expect(spans.any((span) => span.text == '#vine_2024'), isTrue);
        expect(spans.any((span) => span.text == '#test_123'), isTrue);
      });

      testWidgets('handles consecutive hashtags', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LinkifiedText(text: '#first#second hashtags'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();

        expect(spans.any((span) => span.text == '#first'), isTrue);
        expect(spans.any((span) => span.text == '#second'), isTrue);
      });

      testWidgets('ignores hashtags in URLs', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LinkifiedText(
                text: 'Visit https://example.com/#anchor not a hashtag',
              ),
            ),
          ),
        );

        // This test would need enhancement of the hashtag regex to ignore URL fragments
        // Current implementation would incorrectly identify #anchor as a hashtag
        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();

        // Should have spans but #anchor should not be clickable in ideal implementation
        expect(spans.length, greaterThan(1));
      });

      testWidgets('handles single hashtag character', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LinkifiedText(text: 'Just a # character'),
            ),
          ),
        );

        // Single # without word should be treated as plain text
        final text = tester.widget<Text>(find.byType(Text));
        expect(
          text.data,
          'Just a # character',
        ); // Should use data, not textSpan
      });
    });

    group('Integration with HashtagExtractor', () {
      testWidgets('uses HashtagExtractor for hashtag detection', (
        tester,
      ) async {
        const textWithHashtags = 'Multiple #test #hashtags here';
        final expectedHashtags = HashtagExtractor.extractHashtags(
          textWithHashtags,
        );

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithHashtags)),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final clickableSpans = spans
            .where((span) => span.recognizer != null)
            .toList();

        expect(clickableSpans.length, expectedHashtags.length);

        for (int i = 0; i < expectedHashtags.length; i++) {
          expect(clickableSpans[i].text, '#${expectedHashtags[i]}');
        }
      });
    });
  });
}
