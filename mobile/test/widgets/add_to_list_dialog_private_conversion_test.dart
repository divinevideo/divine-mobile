// ABOUTME: Keeps an existing list editor draft when privacy conversion is too large.
// ABOUTME: Exercises the real service rejection before storage or publication.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';
import '../helpers/test_provider_overrides.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _EditorListsState extends CuratedListsState {
  _EditorListsState(this._service);

  final CuratedListService _service;

  @override
  CuratedListService get service => _service;

  @override
  Future<List<CuratedList>> build() async => _service.lists;
}

void main() {
  group('CreateListDialog existing-list privacy conversion', () {
    testWidgets('explains the size rejection and preserves the unsaved draft', (
      tester,
    ) async {
      const owner =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final source = CuratedList(
        id: 'large-public-list',
        pubkey: owner,
        name: 'Stored name',
        description: 'Stored description',
        videoEventIds: List.generate(
          1000,
          (i) => (i + 1).toRadixString(16).padLeft(64, '0'),
        ),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(CuratedListConverter.privateItemPayloadFits(source), isFalse);
      final encoded = jsonEncode([source.toJson()]);
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': owner,
        CuratedListService.listsStorageKey: encoded,
      });
      final preferences = await SharedPreferences.getInstance();
      final client = _Client();
      final auth = _Auth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      stubListPublishing(client: client, auth: auth, pubkey: owner);
      final signer = client.signer;
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: preferences,
      );
      addTearDown(service.dispose);
      expect(service.getListById(source.authorScopedId), source);
      expect(
        preferences.getString(CuratedListService.listsStorageKey),
        encoded,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(
              () => _EditorListsState(service),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CreateListDialog(existingList: source),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Unsaved name');
      await tester.enterText(
        find.byType(TextField).last,
        'Unsaved description',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text(l10n.listSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.listMakePrivateTitle), findsOneWidget);
      await tester.tap(find.text(l10n.listContinue));
      await tester.pumpAndSettle();

      expect(find.text(l10n.listPrivateConversionTooLarge), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(l10n.listPrivateConversionTooLarge),
          matching: find.byType(AlertDialog),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.listPrivateConversionTooLarge).hitTestable(),
        findsOneWidget,
      );
      expect(find.text(l10n.listUpdateFailed), findsNothing);
      expect(find.text(l10n.listEditTitle), findsOneWidget);
      expect(find.text('Unsaved name'), findsOneWidget);
      expect(find.text('Unsaved description'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(service.getListById(source.authorScopedId), source);
      expect(
        preferences.getString(CuratedListService.listsStorageKey),
        encoded,
      );
      verifyNever(() => signer.nip44Encrypt(any(), any()));
      verifyNever(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      );
      verifyNever(() => client.publishEventAwaitOk(any()));
      await tester.tap(find.text(l10n.listCancel));
      await tester.pumpAndSettle();
      expect(find.byType(CreateListDialog), findsNothing);
      expect(
        preferences.getString(CuratedListService.listsStorageKey),
        encoded,
      );
    });
  });
}
