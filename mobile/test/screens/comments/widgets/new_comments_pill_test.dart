// ABOUTME: Tests for NewCommentsPill widget
// ABOUTME: Verifies rendering, tap behavior, and styling

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/widgets/new_comments_pill.dart';

void main() {
  group(NewCommentsPill, () {
    Widget buildSubject({required int count, VoidCallback? onTap}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NewCommentsPill(count: count, onTap: onTap ?? () {}),
        ),
      );
    }

    testWidgets('renders count and "new" text', (tester) async {
      await tester.pumpWidget(buildSubject(count: 3));

      expect(find.text('3 new'), findsOneWidget);
    });

    testWidgets('renders different count values', (tester) async {
      await tester.pumpWidget(buildSubject(count: 12));

      expect(find.text('12 new'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(count: 1, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(NewCommentsPill));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('uses vineGreen background color', (tester) async {
      await tester.pumpWidget(buildSubject(count: 5));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, equals(VineTheme.vineGreen));
    });

    testWidgets('has capsule-shaped border radius', (tester) async {
      await tester.pumpWidget(buildSubject(count: 1));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
    });
  });
}
