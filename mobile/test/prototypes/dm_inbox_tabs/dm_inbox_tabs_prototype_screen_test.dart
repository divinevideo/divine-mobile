// ABOUTME: PROTOTYPE (#8076) — proves the four-tab screen renders, that
// ABOUTME: request content stays concealed until the user opens it, and that
// ABOUTME: sender context and request actions work before it is opened.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tabs_prototype_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/scroll.dart';
import '../../helpers/test_provider_overrides.dart';

void main() {
  group(DmInboxTabsPrototypeScreen, () {
    /// Tall enough that every row of a tab is built without scrolling.
    Future<void> pumpScreen(
      WidgetTester tester, {
      Size size = const Size(1000, 5000),
      SharedPreferences? preferences,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testMaterialApp(
          home: const DmInboxTabsPrototypeScreen(),
          mockSharedPreferences: preferences,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openTab(WidgetTester tester, String tab) async {
      final target = find.widgetWithText(Tab, tab);
      // The tab bar scrolls, so on a narrow screen a tab can be off-screen.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    String badgeOn(String tab) {
      final label = find.ancestor(
        of: find.text(tab),
        matching: find.byType(Tab),
      );
      return find
          .descendant(of: label, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .join('|');
    }

    /// The row whose title is [title].
    Finder rowOf(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ConversationRow',
      ),
    );

    Future<void> tapLabel(WidgetTester tester, String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    Future<void> saveTuningWith(WidgetTester tester, String option) async {
      await tester.tap(find.text('Tune'));
      await tester.pumpAndSettle();
      for (final text in [option, 'Save filter']) {
        final target = find.text(text).first;
        await scrollUntilTappable(
          tester,
          target,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
    }

    group('official room policy', () {
      testWidgets('mixed first contact stays concealed with ordinary actions', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpScreen(tester);
          await openTab(tester, 'Requests');
          final row = rowOf('Ines Duarte and 1 other');
          expect(row, findsOneWidget);
          expect(
            find.bySemanticsLabel(
              'Message request from Ines Duarte and 1 other, content hidden. Tap to open.',
            ),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(
              'Message request from Divine Support and 1 other, content hidden. Tap to open.',
            ),
            findsNothing,
          );
          expect(find.text('Synthetic mixed-room message'), findsNothing);
          expect(
            find
                .descendant(of: row, matching: find.byType(DivineIcon))
                .evaluate()
                .map((e) => (e.widget as DivineIcon).icon),
            isNot(contains(DivineIconName.sealCheckFill)),
          );
          expect(
            find.descendant(of: row, matching: find.text('Report')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.text('Delete')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.text('Block')),
            findsNothing,
          );
          await tester.tap(find.text('Ines Duarte and 1 other'));
          await tester.pumpAndSettle();
          expect(find.text('Synthetic mixed-room message'), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });

      for (final pinned in [false, true]) {
        testWidgets(
          'official actions target participants in ${pinned ? 'Inbox' : 'Official'}',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              await pumpScreen(tester);
              if (pinned) {
                await saveTuningWith(tester, 'Official gets its own tab');
              } else {
                await openTab(tester, 'Official');
              }
              const title = 'Divine Support, Liz';
              final group = rowOf(title);
              expect(group, findsOneWidget);
              expect(
                find.text('Synthetic official group message'),
                findsOneWidget,
              );
              Finder action(String label) => find.descendant(
                of: group,
                matching: find.bySemanticsLabel(label),
              );
              expect(action('Report Divine Support'), findsOneWidget);
              expect(action('Report Liz'), findsOneWidget);
              expect(action('Block Divine Support'), findsNothing);
              expect(action('Block Liz'), findsOneWidget);
              // Each participant names their role once, beside their name.
              expect(
                find.descendant(
                  of: group,
                  matching: find.text('Liz · Divine team'),
                ),
                findsOneWidget,
              );
              bool canTap(String label) => find.semantics
                  .byLabel(label)
                  .evaluate()
                  .any(
                    (node) => node.getSemanticsData().hasAction(
                      SemanticsAction.tap,
                    ),
                  );
              expect(canTap('Report Divine Support'), isTrue);
              await tester.tap(action('Report Divine Support'));
              await tester.pumpAndSettle();
              expect(group, findsOneWidget);
              expect(
                find.text(
                  'Prototype: reported Divine Support. Nothing was sent.',
                ),
                findsOneWidget,
              );
              expect(action('Reported Divine Support'), findsOneWidget);
              expect(canTap('Reported Divine Support'), isFalse);
              await tester.tap(action('Report Liz'));
              await tester.pumpAndSettle();
              expect(group, findsOneWidget);
              expect(action('Reported Liz'), findsOneWidget);
              expect(action('Reported Divine Support'), findsOneWidget);
              await tester.tap(action('Block Liz'));
              await tester.pumpAndSettle();
              expect(group, findsNothing);
              expect(rowOf('Liz'), findsNothing);
              expect(rowOf('Divine Support'), findsOneWidget);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    });

    group('renders', () {
      testWidgets('shows all four tabs', (tester) async {
        await pumpScreen(tester);

        expect(find.text('Inbox'), findsWidgets);
        expect(find.text('Official'), findsOneWidget);
        expect(find.text('Requests'), findsOneWidget);
        expect(find.text('Likely spam'), findsOneWidget);
      });

      testWidgets('opens on Inbox with consented conversations', (
        tester,
      ) async {
        await pumpScreen(tester);

        expect(find.text('Maya Okonkwo'), findsOneWidget);
        expect(find.text('crypto_signals_daily'), findsNothing);
      });

      testWidgets('shows sender context on a request that is still hidden', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');

        expect(find.text('22 videos'), findsOneWidget);
        expect(
          find.text('Followed by Maya Okonkwo and 3 others'),
          findsOneWidget,
        );
        expect(find.text('56K loops'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('About this sender: 22 videos')),
          findsOneWidget,
        );
        expect(find.textContaining('Lisbon'), findsNothing);
        expect(find.bySemanticsLabel(RegExp('Lisbon')), findsNothing);
        semantics.dispose();
      });

      testWidgets('never shows an unknown count as zero', (tester) async {
        await pumpScreen(tester);
        await openTab(tester, 'Requests');

        // Ines Duarte has nothing known; only Hollis Wray is a known zero.
        expect(find.text('Ines Duarte'), findsOneWidget);
        expect(find.text('No videos yet'), findsOneWidget);
        expect(
          find.descendant(
            of: rowOf('Ines Duarte'),
            matching: find.textContaining('video'),
          ),
          findsNothing,
        );
        expect(find.text('0 loops'), findsNothing);
      });

      testWidgets('hides loops when the viewer has turned them off', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'stats_show_total_loops': false,
        });
        final preferences = await SharedPreferences.getInstance();
        await pumpScreen(tester, preferences: preferences);
        await openTab(tester, 'Requests');

        expect(find.text('22 videos'), findsOneWidget);
        expect(find.text('56K loops'), findsNothing);
      });

      testWidgets('shows no scores or threshold to a participant', (
        tester,
      ) async {
        await pumpScreen(tester);
        await openTab(tester, 'Likely spam');

        expect(find.text('crypto_signals_daily'), findsOneWidget);
        expect(find.textContaining('risk '), findsNothing);
        expect(find.textContaining('filtered at'), findsNothing);
      });

      testWidgets('lays out on a narrow phone at a large text size', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpScreen(tester, size: const Size(320, 8000));
        await openTab(tester, 'Requests');

        expect(find.text('Priya Raman'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await openTab(tester, 'Official');
        expect(find.text('Divine Support, Liz'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('interactions', () {
      testWidgets('conceals request content until the row is opened', (
        tester,
      ) async {
        await pumpScreen(tester);
        await openTab(tester, 'Requests');

        expect(find.text('Priya Raman'), findsOneWidget);
        expect(find.textContaining('Lisbon'), findsNothing);
        expect(find.text('Message hidden until you open it'), findsWidgets);

        await tester.tap(find.text('Priya Raman'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Lisbon'), findsOneWidget);
      });

      testWidgets(
        'a screen reader hears a hidden request once and can open it',
        (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await pumpScreen(tester);
          await openTab(tester, 'Requests');
          const label =
              'Message request from Priya Raman, content hidden. Tap to open.';

          final node = find.semantics.byLabel(label);
          expect(node, findsOne);
          final data = node.evaluate().single.getSemanticsData();
          expect(data.label, equals(label), reason: 'the title is read once');
          expect(data.hasAction(SemanticsAction.tap), isTrue);

          tester.semantics.tap(node);
          await tester.pumpAndSettle();

          expect(find.textContaining('Lisbon'), findsOneWidget);
          semantics.dispose();
        },
      );

      testWidgets('opening a request clears its unread count', (tester) async {
        await pumpScreen(tester);
        await openTab(tester, 'Requests');
        final before = int.parse(badgeOn('Requests').split('|').last);

        await tester.tap(find.text('Priya Raman'));
        await tester.pumpAndSettle();

        expect(badgeOn('Requests'), equals('Requests|${before - 1}'));
      });

      testWidgets('counts pinned official rows in the Inbox badge', (
        tester,
      ) async {
        await pumpScreen(tester);

        expect(badgeOn('Inbox'), equals('Inbox|2'));
        expect(badgeOn('Official'), equals('Official|2'));

        await saveTuningWith(tester, 'Official gets its own tab');

        expect(find.text('Official'), findsNothing);
        expect(find.text('Divine Support'), findsOneWidget);
        expect(find.text('Divine Trust & Safety'), findsOneWidget);
        // 2 inbox + 2 official, not 2.
        expect(badgeOn('Inbox'), equals('Inbox|4'));
      });

      testWidgets('shows official previews and role-specific capability copy', (
        tester,
      ) async {
        await pumpScreen(tester);
        await openTab(tester, 'Official');

        expect(find.text('Divine Support'), findsOneWidget);
        expect(find.textContaining('report you filed'), findsOneWidget);
        // Scoped to rows: the tab header also says "cannot be blocked".
        expect(
          find.descendant(
            of: rowOf('Divine Support'),
            matching: find.text('Reportable · cannot be blocked'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: rowOf('Liz'),
            matching: find.text('Reportable · blockable'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('blocks a hidden request without opening it', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');

        await tapLabel(tester, 'Block Priya Raman');

        expect(find.text('Priya Raman'), findsNothing);
        expect(find.textContaining('Lisbon'), findsNothing);
        expect(find.text('Blocked Priya Raman.'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('deletes a hidden request without opening it', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');

        await tapLabel(tester, 'Delete request from Tobias Lund');

        expect(find.text('Tobias Lund'), findsNothing);
        expect(find.textContaining('quick question'), findsNothing);
        expect(find.text('Priya Raman'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('reporting a hidden request removes it', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');

        await tapLabel(tester, 'Report Nadia Broussard');

        expect(find.text('Nadia Broussard'), findsNothing);
        expect(
          find.text('Reported and removed from your requests.'),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('cancelling a reply leaves the request in place', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');
        await tester.tap(find.text('Priya Raman'));
        await tester.pumpAndSettle();

        await tapLabel(tester, 'Reply to Priya Raman');
        expect(find.byType(TextField), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Priya Raman'), findsOneWidget);
        expect(find.textContaining('Moved to Inbox'), findsNothing);
        semantics.dispose();
      });

      testWidgets('a sent reply moves the request to Inbox', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');
        await tester.tap(find.text('Priya Raman'));
        await tester.pumpAndSettle();
        await tapLabel(tester, 'Reply to Priya Raman');

        await tester.enterText(find.byType(TextField), 'yes! still filming');
        await tester.pump();
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(find.text('Reply sent. Moved to Inbox.'), findsOneWidget);
        expect(find.text('Priya Raman'), findsNothing);
        await openTab(tester, 'Inbox');
        expect(find.text('Priya Raman'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('a blank reply cannot be sent', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');
        await tester.tap(find.text('Priya Raman'));
        await tester.pumpAndSettle();
        await tapLabel(tester, 'Reply to Priya Raman');

        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.textContaining('Moved to Inbox'), findsNothing);
        semantics.dispose();
      });

      testWidgets('not spam survives a change to the weights', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Likely spam');

        await tapLabel(
          tester,
          'Not spam: move crypto_signals_daily to Requests',
        );
        expect(find.text('crypto_signals_daily'), findsNothing);

        await saveTuningWith(tester, 'Remix');
        await openTab(tester, 'Requests');

        expect(find.text('crypto_signals_daily'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets("shows the user's own not-spam call as a note, not a risk", (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Likely spam');
        await tapLabel(
          tester,
          'Not spam: move crypto_signals_daily to Requests',
        );
        await openTab(tester, 'Requests');
        final row = rowOf('crypto_signals_daily');

        await tester.tap(
          find.descendant(of: row, matching: find.text('Why is this here?')),
        );
        await tester.pumpAndSettle();

        DivineIconName iconBeside(String label) => tester
            .widget<DivineIcon>(
              find.descendant(
                of: find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(Row),
                    )
                    .first,
                matching: find.byType(DivineIcon),
              ),
            )
            .icon;

        expect(
          iconBeside('You marked this as not spam'),
          equals(DivineIconName.info),
        );
        expect(
          iconBeside('Reported by other people'),
          equals(DivineIconName.warningCircle),
          reason: 'a real risk keeps the warning style',
        );
        semantics.dispose();
      });

      testWidgets('holds back message facts until the request is opened', (
        tester,
      ) async {
        await pumpScreen(tester);
        await openTab(tester, 'Requests');
        final camille = rowOf('Camille Ndiaye');

        await tester.tap(
          find.descendant(
            of: camille,
            matching: find.text('Why is this here?'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: camille, matching: find.text('Follows you')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: camille,
            matching: find.text('First message contains a link'),
          ),
          findsNothing,
        );

        await tester.tap(find.text('Camille Ndiaye'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: camille,
            matching: find.text('First message contains a link'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('the caution line holds back message reasons until opened', (
        tester,
      ) async {
        await pumpScreen(tester);
        await saveTuningWith(tester, 'Context and a caution label');
        await openTab(tester, 'Requests');
        final camille = rowOf('Camille Ndiaye');
        final linkReason = find.descendant(
          of: camille,
          matching: find.textContaining('contains a link'),
        );

        expect(linkReason, findsNothing);

        await tester.tap(find.text('Camille Ndiaye'));
        await tester.pumpAndSettle();

        expect(linkReason, findsOneWidget);
      });

      testWidgets('shows reason points only in the facilitator view', (
        tester,
      ) async {
        await pumpScreen(tester);
        await openTab(tester, 'Requests');
        Finder points() => find.descendant(
          of: rowOf('Camille Ndiaye'),
          matching: find.textContaining(RegExp(r'^[+-]\d+$')),
        );
        await tester.tap(
          find.descendant(
            of: rowOf('Camille Ndiaye'),
            matching: find.text('Why is this here?'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hide reasons'), findsOneWidget);
        expect(points(), findsNothing);

        await saveTuningWith(tester, 'Show scores');
        await openTab(tester, 'Requests');

        expect(points(), findsWidgets);
      });

      testWidgets('a screen reader can open the reasons', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');

        final toggle = find.semantics.byLabel('Why is this here?').first;
        expect(
          toggle.evaluate().single.getSemanticsData().hasAction(
            SemanticsAction.tap,
          ),
          isTrue,
        );
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text('Why is this here?').first,
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(48),
        );

        tester.semantics.tap(toggle);
        await tester.pumpAndSettle();

        expect(find.text('Hide reasons'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('a new presentation resets the session and shows caution', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester);
        await openTab(tester, 'Requests');
        await tapLabel(tester, 'Delete request from Tobias Lund');
        expect(find.text('Tobias Lund'), findsNothing);

        await saveTuningWith(tester, 'Context and a caution label');
        await openTab(tester, 'Requests');

        expect(find.text('Tobias Lund'), findsOneWidget);
        expect(find.text('Why is this here?'), findsNothing);
        expect(
          find.descendant(
            of: rowOf('Jules Amari'),
            matching: find.text('First seen recently'),
          ),
          findsOneWidget,
        );
        semantics.dispose();
      });
    });
  });
}
