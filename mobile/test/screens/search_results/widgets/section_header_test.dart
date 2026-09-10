import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';

void main() {
  group(SectionHeader, () {
    Widget buildSubject({
      required String title,
      VoidCallback? onTap,
      String? semanticIdentifier,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: title,
                  onTap: onTap,
                  semanticIdentifier: semanticIdentifier,
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(buildSubject(title: 'People'));

      expect(find.text('People'), findsOneWidget);
    });

    testWidgets('exposes semanticIdentifier when supplied', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          title: 'People',
          semanticIdentifier: 'search_section_header_people',
        ),
      );

      expect(
        find.bySemanticsIdentifier('search_section_header_people'),
        findsOneWidget,
      );
    });

    testWidgets('carries no identifier by default', (tester) async {
      await tester.pumpWidget(buildSubject(title: 'People'));

      expect(
        find.bySemanticsIdentifier('search_section_header_people'),
        findsNothing,
      );
    });

    testWidgets('renders hairline borders above and below', (tester) async {
      await tester.pumpWidget(buildSubject(title: 'People'));

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final border = decoration.border! as Border;

      expect(
        border.top,
        equals(const BorderSide(color: VineTheme.outlineDisabled, width: 0)),
      );
      expect(
        border.bottom,
        equals(const BorderSide(color: VineTheme.outlineDisabled, width: 0)),
      );
    });

    testWidgets('shows caret icon when onTap is provided', (tester) async {
      await tester.pumpWidget(buildSubject(title: 'People', onTap: () {}));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.caretRight,
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides caret icon when onTap is null', (tester) async {
      await tester.pumpWidget(buildSubject(title: 'People'));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.caretRight,
        ),
        findsNothing,
      );
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(title: 'People', onTap: () => tapped = true),
      );

      await tester.tap(find.byType(SectionHeader));
      expect(tapped, isTrue);
    });

    testWidgets('is a header node with no button flag when onTap is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(title: 'Tags'));

      final semantics = tester.getSemantics(find.byType(SectionHeader));
      expect(semantics.flagsCollection.isHeader, isTrue);
      expect(semantics.flagsCollection.isButton, isFalse);
    });

    testWidgets('is a button node when onTap is provided', (tester) async {
      await tester.pumpWidget(buildSubject(title: 'Videos', onTap: () {}));

      final semantics = tester.getSemantics(find.byType(SectionHeader));
      expect(semantics.flagsCollection.isButton, isTrue);
    });
  });
}
