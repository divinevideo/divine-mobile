// ABOUTME: Regression test for the Explore Lists tab's top inset (#6797).
// ABOUTME: Pins that the tab's ListView carries an explicit padding, so the
// ABOUTME: status-bar inset never reappears as a gap above the first button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/explore/tabs/explore_lists_tab.dart';
import 'package:openvine/services/curated_list_service.dart';

import '../../../helpers/test_provider_overrides.dart';

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => const [];
}

void main() {
  group(ExploreListsTab, () {
    testWidgets('drops the status-bar inset above the first button', (
      tester,
    ) async {
      // 120 physical px / 3.0 test devicePixelRatio = 40 logical px of status
      // bar. The tab renders inside Explore, whose shell Scaffold has no app
      // bar, so the top inset is still in MediaQuery here. Without an explicit
      // padding BoxScrollView would fall back to it and gap the first button.
      tester.view.padding = const FakeViewPadding(top: 120);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            allListsProvider.overrideWith(
              (ref) async =>
                  (userLists: <UserList>[], curatedLists: <CuratedList>[]),
            ),
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreListsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Discover Lists button's own EdgeInsets.all(16) is the only offset
      // that may sit between the viewport top and the button.
      expect(
        tester.getRect(find.byType(DivineButton).first).top -
            tester.getRect(find.byType(ListView)).top,
        moreOrLessEquals(16, epsilon: 0.5),
      );
    });
  });
}
