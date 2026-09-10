import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppsPermissionsScreen', () {
    late SharedPreferences sharedPreferences;
    late NostrAppGrantStore grantStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      grantStore = NostrAppGrantStore(sharedPreferences: sharedPreferences);
    });

    testWidgets('lists remembered grants for the current user', (tester) async {
      await grantStore.saveGrant(
        userPubkey: 'f' * 64,
        appId: 'primal-app',
        origin: 'https://primal.net',
        capability: 'signEvent:1',
      );
      await grantStore.saveGrant(
        userPubkey: 'a' * 64,
        appId: 'other-app',
        origin: 'https://other.example',
        capability: 'getPublicKey',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppsPermissionsScreen(
            grantStore: grantStore,
            currentUserPubkey: 'f' * 64,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('primal-app'), findsOneWidget);
      expect(find.text('https://primal.net'), findsOneWidget);
      expect(find.text('signEvent:1'), findsOneWidget);
      expect(find.text('other-app'), findsNothing);
      expect(find.text('No saved integration permissions'), findsNothing);
    });

    testWidgets('revokes a single grant', (tester) async {
      await grantStore.saveGrant(
        userPubkey: 'f' * 64,
        appId: 'primal-app',
        origin: 'https://primal.net',
        capability: 'signEvent:1',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppsPermissionsScreen(
            grantStore: grantStore,
            currentUserPubkey: 'f' * 64,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();

      expect(grantStore.listGrants(userPubkey: 'f' * 64), isEmpty);
      expect(find.text('No saved integration permissions'), findsOneWidget);
    });
  });
}
