// ABOUTME: PROTOTYPE (#8076) — pins that the tuning panel renders cleanly,
// ABOUTME: that Save returns the edited settings and back discards them.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_settings.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tuning_view.dart';

import '../../helpers/scroll.dart';
import '../../helpers/test_provider_overrides.dart';

void main() {
  group(DmInboxTuningView, () {
    /// Pushes the panel over a launcher and records what it pops.
    Future<List<DmPrototypeSettings?>> pumpTuning(
      WidgetTester tester, {
      DmPrototypeSettings settings = const DmPrototypeSettings(),
    }) async {
      final popped = <DmPrototypeSettings?>[];
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  popped.add(
                    await Navigator.of(context).push<DmPrototypeSettings>(
                      MaterialPageRoute<DmPrototypeSettings>(
                        builder: (_) => DmInboxTuningView(settings: settings),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return popped;
    }

    Future<void> scrollToAndTap(WidgetTester tester, String text) async {
      final target = find.text(text);
      await scrollUntilTappable(
        tester,
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('opens without a framework exception', (tester) async {
        await pumpTuning(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('My request filter'), findsOneWidget);
        expect(find.text('Shield: Default'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('applying a community recipe names it in the hero', (
        tester,
      ) async {
        await pumpTuning(tester);

        await tester.tap(find.text('Remix').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Quiet Porch applied'), findsOneWidget);
        expect(find.text('Shield: Quiet Porch'), findsOneWidget);
      });

      testWidgets('names the saved recipe when reopened', (tester) async {
        await pumpTuning(
          tester,
          settings: const DmPrototypeSettings(
            heuristics: DmSpamHeuristics(
              spamThreshold: 42,
              weightHighFanOut: 70,
              weightContainsLink: 45,
              weightReportedByOthers: 75,
              weightHasDivineVideos: -25,
              weightPriorPublicInteraction: -40,
            ),
          ),
        );

        expect(find.text('Shield: Quiet Porch'), findsOneWidget);
      });

      testWidgets('calls saved hand-edited weights custom when reopened', (
        tester,
      ) async {
        await pumpTuning(
          tester,
          settings: const DmPrototypeSettings(
            heuristics: DmSpamHeuristics(spamThreshold: 77),
          ),
        );

        expect(find.text('Shield: Custom'), findsOneWidget);
      });

      testWidgets('Save returns every edited setting', (tester) async {
        final popped = await pumpTuning(tester);

        await tester.tap(find.text('Remix').first);
        await tester.pumpAndSettle();
        await scrollToAndTap(tester, 'Show scores');
        await scrollToAndTap(tester, 'Context and a caution label');
        await scrollToAndTap(tester, 'Official gets its own tab');
        await scrollToAndTap(tester, 'Save filter');

        expect(popped, hasLength(1));
        final saved = popped.single!;
        expect(saved.placement, OfficialPlacement.pinnedInInbox);
        expect(saved.presentation, RequestPresentation.contextWithCaution);
        expect(saved.heuristics.spamThreshold, equals(42));
        expect(saved.showScores, isTrue);
      });

      testWidgets('back discards every edit', (tester) async {
        final popped = await pumpTuning(tester);

        await scrollToAndTap(tester, 'Official gets its own tab');
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(popped, equals([null]));
        expect(find.text('open'), findsOneWidget);
      });
    });
  });
}
