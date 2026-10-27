import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/explore_tab_labels.dart';

void main() {
  group('challenges_explore', () {
    test(
      'test-build tab preserves stable Explore navigation across optional tabs',
      () {
        const state = ExploreTabsState(challengesAvailable: true);
        expect(
          state.nameForIndex(state.indexForName('challenges')),
          'challenges',
        );
        final changed = state.copyWith(
          classicsAvailable: true,
          appsAvailable: true,
        );
        expect(
          changed.nameForIndex(changed.indexForName('challenges')),
          'challenges',
        );
        expect(
          labelForExploreTabName(
            lookupAppLocalizations(const Locale('en')),
            'challenges',
          ),
          'Challenges',
        );
        expect(
          const ExploreTabsState().tabNames,
          isNot(contains('challenges')),
        );
      },
    );
  });
}
