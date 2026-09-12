// ABOUTME: Widget tests for InboxSegmentedToggle.
// ABOUTME: Tests rendering of labels, notification badge, and tap interactions.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/widgets/inbox_segmented_toggle.dart';

void main() {
  group(InboxSegmentedToggle, () {
    group('renders', () {
      testWidgets('renders Messages label', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InboxSegmentedToggle(
                selected: InboxTab.messages,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Messages'), findsOneWidget);
      });

      testWidgets('renders Notifications label', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InboxSegmentedToggle(
                selected: InboxTab.messages,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Notifications'), findsOneWidget);
      });

      testWidgets('renders notification badge when notificationCount > 0', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InboxSegmentedToggle(
                selected: InboxTab.messages,
                onChanged: (_) {},
                notificationCount: 5,
              ),
            ),
          ),
        );

        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('does not render badge when notificationCount is 0', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InboxSegmentedToggle(
                selected: InboxTab.messages,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        // Badge text should not exist — no count to display.
        expect(find.text('0'), findsNothing);
      });

      testWidgets('renders badge text as "99+" when count exceeds 99', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InboxSegmentedToggle(
                selected: InboxTab.messages,
                onChanged: (_) {},
                notificationCount: 150,
              ),
            ),
          ),
        );

        expect(find.text('99+'), findsOneWidget);
        expect(find.text('150'), findsNothing);
      });

      testWidgets('limits localized labels to one line with ellipsis', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('de'));

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 180,
                  child: InboxSegmentedToggle(
                    selected: InboxTab.messages,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        final notificationsLabel = tester.renderObject<RenderParagraph>(
          find.text(l10n.settingsNotifications),
        );
        expect(notificationsLabel.didExceedMaxLines, isTrue);
      });
    });

    group('interactions', () {
      testWidgets(
        'calls onChanged with ${InboxTab.messages} when Messages is tapped',
        (tester) async {
          InboxTab? tappedTab;

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: InboxSegmentedToggle(
                  selected: InboxTab.notifications,
                  onChanged: (tab) => tappedTab = tab,
                ),
              ),
            ),
          );

          await tester.tap(find.text('Messages'));
          await tester.pump();

          expect(tappedTab, equals(InboxTab.messages));
        },
      );

      testWidgets('calls onChanged with ${InboxTab.notifications} '
          'when Notifications is tapped', (tester) async {
        InboxTab? tappedTab;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InboxSegmentedToggle(
                selected: InboxTab.messages,
                onChanged: (tab) => tappedTab = tab,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Notifications'));
        await tester.pump();

        expect(tappedTab, equals(InboxTab.notifications));
      });
    });
  });
}
