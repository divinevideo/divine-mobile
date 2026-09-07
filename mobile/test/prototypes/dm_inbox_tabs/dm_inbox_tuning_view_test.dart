// ABOUTME: PROTOTYPE (#8076) — pins that the tuning panel renders cleanly.
// ABOUTME: Nothing pumped this view before, which is why a ListTile nested
// ABOUTME: inside a coloured DecoratedBox went unnoticed.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tabs_prototype_screen.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tuning_view.dart';

import '../../helpers/test_provider_overrides.dart';

void main() {
  group(DmInboxTuningView, () {
    Future<void> pumpTuning(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: DmInboxTuningView(
            heuristics: const DmSpamHeuristics(),
            placement: OfficialPlacement.ownTab,
            onPlacementChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('opens without a framework exception', (tester) async {
        await pumpTuning(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('My request filter'), findsOneWidget);
      });

      testWidgets('renders the placement switch cleanly', (tester) async {
        await pumpTuning(tester);

        expect(find.text('Official gets its own tab'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('interactions', () {
      testWidgets('toggling placement reports the new value', (tester) async {
        OfficialPlacement? reported;
        await tester.pumpWidget(
          testMaterialApp(
            home: DmInboxTuningView(
              heuristics: const DmSpamHeuristics(),
              placement: OfficialPlacement.ownTab,
              onPlacementChanged: (value) => reported = value,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Official gets its own tab'));
        await tester.pumpAndSettle();

        expect(reported, OfficialPlacement.pinnedInInbox);
        expect(tester.takeException(), isNull);
      });

      testWidgets('applying a community recipe replaces the weights', (
        tester,
      ) async {
        await pumpTuning(tester);

        // The tap target is the recipe's own Remix button, not its title.
        expect(find.text('Quiet Porch'), findsOneWidget);
        await tester.tap(find.text('Remix').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Quiet Porch applied'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
