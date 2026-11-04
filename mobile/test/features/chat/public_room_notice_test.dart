import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/chat/public_room_notice.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group(PublicRoomNotice, () {
    Future<void> pumpNotice(WidgetTester tester, {required bool isTest}) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PublicRoomNotice(isTest: isTest)),
          ),
        );

    testWidgets('a real room says its messages can reach Discord', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pumpNotice(tester, isTest: false);
      expect(find.text(l10n.messagesPublicRoomsDisclosure), findsOneWidget);
      expect(find.text(l10n.messagesPublicTestDisclosure), findsNothing);
      expect(l10n.messagesPublicRoomsDisclosure, contains('Discord'));
    });

    testWidgets('a test room keeps the test-room notice', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pumpNotice(tester, isTest: true);
      expect(find.text(l10n.messagesPublicTestDisclosure), findsOneWidget);
    });
  });
}
