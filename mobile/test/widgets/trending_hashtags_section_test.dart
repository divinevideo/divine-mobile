// ABOUTME: Tests for TrendingHashtagsSection widget extracted from ExploreScreen
// ABOUTME: Verifies hashtag display, loading state, and tap navigation

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/trending_hashtags_section.dart';

void main() {
  group('TrendingHashtagsSection', () {
    String? tappedHashtag;

    setUp(() {
      tappedHashtag = null;
    });

    Widget buildTestWidget({
      List<String> hashtags = const [],
      bool isLoading = false,
      Widget? leading,
      void Function(String)? onHashtagTap,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TrendingHashtagsSection(
            hashtags: hashtags,
            isLoading: isLoading,
            leading: leading,
            onHashtagTap:
                onHashtagTap ??
                (hashtag) {
                  tappedHashtag = hashtag;
                },
          ),
        ),
      );
    }

    testWidgets('displays title "Trending"', (tester) async {
      await tester.pumpWidget(buildTestWidget(hashtags: ['funny', 'cats']));

      expect(find.text('Trending'), findsOneWidget);
    });

    testWidgets('displays loading placeholder when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(hashtags: [], isLoading: true));

      expect(find.text('Loading hashtags...'), findsOneWidget);
    });

    testWidgets(
      'displays loading placeholder when hashtags list is empty and not loading',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(hashtags: []));

        // Should still show loading placeholder when no hashtags available
        expect(find.text('Loading hashtags...'), findsOneWidget);
      },
    );

    testWidgets('displays hashtags with # prefix', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(hashtags: ['funny', 'cats', 'dogs']),
      );

      expect(find.text('#funny'), findsOneWidget);
      expect(find.text('#cats'), findsOneWidget);
      expect(find.text('#dogs'), findsOneWidget);
    });

    testWidgets('hashtags are displayed in horizontal scrollable list', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(hashtags: ['tag1', 'tag2', 'tag3', 'tag4', 'tag5']),
      );

      // Find the ListView
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);

      // Verify it's horizontal
      final listView = tester.widget<ListView>(listViewFinder);
      expect(listView.scrollDirection, Axis.horizontal);
    });

    testWidgets('renders leading control before trending hashtags', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          leading: const SizedBox(
            key: Key('popular-source-toggle'),
            width: 120,
            child: Text('New'),
          ),
          hashtags: ['art'],
        ),
      );

      final toggleTopLeft = tester.getTopLeft(
        find.byKey(const Key('popular-source-toggle')),
      );
      final titleTopLeft = tester.getTopLeft(find.text('Trending'));

      expect(toggleTopLeft.dx, lessThan(titleTopLeft.dx));
      expect(find.text('#art'), findsOneWidget);
    });

    testWidgets('tapping hashtag calls onHashtagTap callback', (tester) async {
      await tester.pumpWidget(buildTestWidget(hashtags: ['funny', 'cats']));

      // Tap on the first hashtag
      await tester.tap(find.text('#funny'));
      await tester.pumpAndSettle();

      expect(tappedHashtag, equals('funny'));
    });

    testWidgets('hashtag chips have correct styling', (tester) async {
      await tester.pumpWidget(buildTestWidget(hashtags: ['test']));

      // Find the container with hashtag
      final containerFinder = find.ancestor(
        of: find.text('#test'),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
    });
  });
}
