import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/screens/search_results/widgets/search_tag_chip.dart';

void main() {
  group(SearchTagChip, () {
    Widget buildSubject({
      required String tag,
      required VoidCallback onTap,
      double? width,
    }) {
      Widget chip = SearchTagChip(tag: tag, onTap: onTap);
      if (width != null) {
        chip = SizedBox(width: width, child: chip);
      }
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: chip)),
      );
    }

    testWidgets('renders the # prefix and the tag name', (tester) async {
      await tester.pumpWidget(buildSubject(tag: 'flutter', onTap: () {}));

      expect(find.text('#'), findsOneWidget);
      expect(find.text('flutter'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(SemanticIds.searchTag('flutter')),
        findsOneWidget,
      );
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(tag: 'flutter', onTap: () => tapped = true),
      );

      await tester.tap(find.byType(SearchTagChip));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('exposes a button semantics label for the tag', (tester) async {
      await tester.pumpWidget(buildSubject(tag: 'flutter', onTap: () {}));

      final semantics = tester.getSemantics(find.byType(SearchTagChip));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(
        semantics.label,
        contains(
          AppLocalizationsEn().searchTagChipViewVideosTaggedLabel('flutter'),
        ),
      );
    });

    testWidgets('renders a long tag without overflowing', (tester) async {
      const longTag =
          'thisisanextremelylonghashtagthatwouldotherwiseoverflowthechip';

      await tester.pumpWidget(
        buildSubject(tag: longTag, onTap: () {}, width: 160),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(longTag), findsOneWidget);
    });
  });
}
