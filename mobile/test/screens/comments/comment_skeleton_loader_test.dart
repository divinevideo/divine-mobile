// ABOUTME: Widget tests for CommentsSkeletonLoader component
// ABOUTME: Tests skeleton loader rendering and accessibility

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/widgets/comment_skeleton_loader.dart';

void main() {
  group('CommentsSkeletonLoader', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CommentsSkeletonLoader()),
        ),
      );

      expect(find.byType(CommentsSkeletonLoader), findsOneWidget);
    });

    testWidgets('has semantic identifier for accessibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CommentsSkeletonLoader()),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.commentsLoadingSemanticLabel),
        findsOneWidget,
      );
      // Proves the label comes from l10n rather than a constant that happens
      // to read the same in English.
      expect(
        find.bySemanticsLabel(
          lookupAppLocalizations(
            const Locale('es'),
          ).commentsLoadingSemanticLabel,
        ),
        findsNothing,
      );
    });

    testWidgets('renders ListView with 6 skeleton items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CommentsSkeletonLoader()),
        ),
      );

      // Verify ListView is present
      expect(find.byType(ListView), findsOneWidget);

      // Verify 6 skeleton items
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.semanticChildCount, equals(6));
    });
  });
}
