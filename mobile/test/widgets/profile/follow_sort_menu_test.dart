import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/follow_sort_menu.dart';

void main() {
  group('follow sort menu', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('localized three options with Smart selected: $locale', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(locale);
        FollowListSort? selected;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () async {
                    selected = await showFollowSortMenu(
                      context: context,
                      current: FollowListSort.smart,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        expect(find.text(l10n.followSortSmart), findsOneWidget);
        expect(find.text(l10n.followSortNewest), findsOneWidget);
        expect(find.text(l10n.followSortOldest), findsOneWidget);
        final smart = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == l10n.followSortSmart,
          ),
        );
        expect(smart.properties.selected, isTrue);
        expect(
          tester.getTopLeft(find.text(l10n.followSortSmart)).dy,
          lessThan(tester.getTopLeft(find.text(l10n.followSortNewest)).dy),
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.sparkle,
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.followSortOldest));
        await tester.pumpAndSettle();
        expect(selected, FollowListSort.oldestFirst);
      });
    }
  });
}
