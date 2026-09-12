import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/apps/nostr_app_permission_prompt_sheet.dart';

void main() {
  group('NostrAppPermissionPromptSheet', () {
    testWidgets('renders the requested app permission details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NostrAppPermissionPromptSheet(
              appName: 'Primal',
              origin: 'https://primal.net',
              method: 'nip44.decrypt',
              capability: 'nip44.decrypt',
              eventKind: 4,
              onAllow: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Primal wants your approval'), findsOneWidget);
      expect(find.text('https://primal.net'), findsOneWidget);
      expect(find.text('Method'), findsOneWidget);
      expect(find.text('nip44.decrypt'), findsWidgets);
      expect(find.text('Capability'), findsOneWidget);
      expect(find.text('Event kind'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('omits the event kind row when not provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NostrAppPermissionPromptSheet(
              appName: 'Primal',
              origin: 'https://primal.net',
              method: 'getPublicKey',
              capability: 'getPublicKey',
              onAllow: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Event kind'), findsNothing);
    });

    testWidgets('invokes the callbacks from the action buttons', (
      tester,
    ) async {
      var allowed = false;
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NostrAppPermissionPromptSheet(
              appName: 'Primal',
              origin: 'https://primal.net',
              method: 'signEvent',
              capability: 'signEvent:1',
              onAllow: () => allowed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Allow'));
      await tester.pump();
      expect(allowed, isTrue);
      expect(cancelled, isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });
}
