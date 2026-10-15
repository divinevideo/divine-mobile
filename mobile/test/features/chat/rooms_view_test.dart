import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/rooms_view.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group(RoomsView, () {
    testWidgets('keeps same-named channels bound to their community', (
      tester,
    ) async {
      (String, String)? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RoomsView(
              communities: const [
                ChatCommunity('one', 'First', ['general']),
                ChatCommunity('two', 'Second', ['general']),
              ],
              onRoomSelected: (community, channel) =>
                  selected = (community, channel),
            ),
          ),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.messagesPublicTestDisclosure), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      await tester.tap(find.text('general').last);
      expect(selected, ('two', 'general'));
    });

    testWidgets('rows draw cleanly on the coloured Messages surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The Messages tab hosts this list inside a coloured box.
            body: ColoredBox(
              color: VineTheme.surfaceBackground,
              child: RoomsView(
                communities: const [
                  ChatCommunity('one', 'First', ['general']),
                ],
                onRoomSelected: (_, _) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('general'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list does not invent a join action or a room', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RoomsView(
              communities: const [],
              onRoomSelected: (_, _) => fail('no room should be selectable'),
            ),
          ),
        ),
      );
      expect(
        find.text(lookupAppLocalizations(const Locale('en')).messagesNoRooms),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsNothing);
    });
  });
}
