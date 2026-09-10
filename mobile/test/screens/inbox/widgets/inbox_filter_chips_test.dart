// ABOUTME: Widget tests for InboxFilterChips.
// ABOUTME: Verifies chip labels render, Blocked is gated, and taps report.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/widgets/inbox_filter_chips.dart';

void main() {
  group(InboxFilterChips, () {
    Widget buildSubject({
      required InboxFilter selected,
      required ValueChanged<InboxFilter> onChanged,
      bool hasBlocked = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InboxFilterChips(
            selected: selected,
            onChanged: onChanged,
            hasBlocked: hasBlocked,
          ),
        ),
      );
    }

    final l10n = lookupAppLocalizations(const Locale('en'));

    testWidgets('renders All and Unread chips', (tester) async {
      await tester.pumpWidget(
        buildSubject(selected: InboxFilter.all, onChanged: (_) {}),
      );

      expect(find.text(l10n.inboxFilterAll), findsOneWidget);
      expect(find.text(l10n.inboxFilterUnread), findsOneWidget);
    });

    testWidgets('hides the Blocked chip when nothing is blocked', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(selected: InboxFilter.all, onChanged: (_) {}),
      );

      expect(find.text(l10n.inboxFilterBlocked), findsNothing);
    });

    testWidgets('shows the Blocked chip once something is blocked', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          selected: InboxFilter.all,
          onChanged: (_) {},
          hasBlocked: true,
        ),
      );

      expect(find.text(l10n.inboxFilterBlocked), findsOneWidget);
    });

    testWidgets('tapping Unread reports it', (tester) async {
      InboxFilter? reported;
      await tester.pumpWidget(
        buildSubject(
          selected: InboxFilter.all,
          onChanged: (value) => reported = value,
        ),
      );

      await tester.tap(find.text(l10n.inboxFilterUnread));
      await tester.pump();

      expect(reported, equals(InboxFilter.unread));
    });

    testWidgets('tapping Blocked reports it', (tester) async {
      InboxFilter? reported;
      await tester.pumpWidget(
        buildSubject(
          selected: InboxFilter.all,
          onChanged: (value) => reported = value,
          hasBlocked: true,
        ),
      );

      await tester.tap(find.text(l10n.inboxFilterBlocked));
      await tester.pump();

      expect(reported, equals(InboxFilter.blocked));
    });

    testWidgets('tapping All reports it', (tester) async {
      InboxFilter? reported;
      await tester.pumpWidget(
        buildSubject(
          selected: InboxFilter.unread,
          onChanged: (value) => reported = value,
        ),
      );

      await tester.tap(find.text(l10n.inboxFilterAll));
      await tester.pump();

      expect(reported, equals(InboxFilter.all));
    });
  });
}
